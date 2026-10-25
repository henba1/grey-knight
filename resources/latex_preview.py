#!/usr/bin/env python3
"""Live PDF preview for headless / SSH work (GreyKnight's <leader>lw starts it, lua/devsuite/latex.lua).

Renders the PDF to PNGs whenever it changes and serves them on http://localhost:PORT. The page swaps the images in
place (the scroll position stays) and marks the pages that changed in the last build - their outline, and links to
them in the bar at the top. Two views: the overview (all pages) and one slide at a time with a strip of the others
(a click on a page, or S; arrow keys / Space go on, Esc back).

Usage:  python3 latex_preview.py PDF [--port 8000] [--dpi 160]     (--port 0: a free one; the URL is printed)
Over SSH: ssh -L 8000:localhost:8000 <host>, then http://localhost:8000 in the local browser.
Needs pdftoppm (poppler-utils). Standard library only.
"""
import argparse, glob, hashlib, http.server, json, os, shutil, signal, subprocess, sys, tempfile, threading, time

PAGE = """<!doctype html><meta charset=utf-8><title>PDF preview</title>
<style>
body{margin:0;background:#2b2d30;font:13px system-ui,sans-serif;color:#c9ccd1}
#bar{position:sticky;top:0;z-index:2;background:#1e1f22;padding:7px 14px;display:flex;gap:14px;align-items:center;flex-wrap:wrap}
#bar a{color:#f5b041;text-decoration:none;margin-right:6px}#bar a:hover{text-decoration:underline}
#bar button{background:#2b2d30;color:#c9ccd1;border:1px solid #45484d;border-radius:3px;padding:2px 9px;font:inherit;cursor:pointer}
#bar button.on{background:#45484d;color:#fff}
.hint{color:#7d8187}
/* overview */
#s{display:grid;grid-template-columns:repeat(auto-fill,minmax(var(--w,520px),1fr));gap:16px;padding:16px}
#s figure{margin:0;scroll-margin-top:48px;cursor:zoom-in}
img{display:block;outline:3px solid transparent;outline-offset:2px}
#s img{width:100%}
.changed>img,.changed img{outline-color:#f5b041}
figcaption{padding:4px 0}.changed figcaption::after{content:" · changed";color:#f5b041}
body.only #s figure:not(.changed){display:none}
/* one slide */
#one{display:none;flex-direction:column;align-items:center;height:calc(100vh - 42px)}
#stage{flex:1;min-height:0;display:flex;align-items:center;justify-content:center;position:relative;width:100%;padding:14px 16px 6px;box-sizing:border-box}
#big{width:100%;height:100%;object-fit:contain;outline:none;cursor:pointer}
#cap{padding:2px 0 6px}
#strip{display:flex;gap:8px;overflow-x:auto;padding:6px 14px 10px;max-width:100%;box-sizing:border-box}
#strip img{height:58px;cursor:pointer;opacity:.55}#strip img.cur{opacity:1;outline-color:#fff}
#strip img.changed{outline-color:#f5b041}#strip img.cur.changed{opacity:1}
body.single #s,body.single .ov{display:none}body.single #one{display:flex}
body:not(.single) .sv{display:none}
</style>
<div id=bar><span id=st>waiting for the PDF</span><span id=ch></span>
<span><button id=bo onclick="overview()">Overview</button> <button id=bs onclick="single(cur)">Slide</button></span>
<label class=ov>width <input type=range min=240 max=1600 value=520 oninput="document.body.style.setProperty('--w',this.value+'px')"></label>
<label class=ov><input type=checkbox onchange="document.body.classList.toggle('only',this.checked)"> only changed</label>
<span class="hint ov">click a slide or S: one slide</span><span class="hint sv">← → Space: next / back · Home End · Esc or O: overview</span></div>
<div id=s></div>
<div id=one><div id=stage><img id=big alt=""></div><div id=cap></div><div id=strip></div></div>
<script>
let ver=-1,pages=0,changed=new Set(),cur=1;
const $=id=>document.getElementById(id),src=n=>'/p/'+n+'?v='+ver;
function view(){return document.body.classList.contains('single')}
function show(){
  $('bo').classList.toggle('on',!view());$('bs').classList.toggle('on',view());
  if(!view()||!pages)return;
  cur=Math.min(Math.max(cur,1),pages);
  $('big').src=src(cur);
  $('cap').innerHTML=cur+' / '+pages+(changed.has(cur)?' <span style="color:#f5b041">· changed</span>':'');
  const st=$('strip');
  [...st.children].forEach((im,i)=>{im.classList.toggle('cur',i+1===cur);im.classList.toggle('changed',changed.has(i+1))});
  const c=st.children[cur-1];if(c)c.scrollIntoView({block:'nearest',inline:'nearest'});
}
function single(n){cur=n||cur;document.body.classList.add('single');history.replaceState(null,'','#slide-'+cur);show()}
function overview(){document.body.classList.remove('single');history.replaceState(null,'','#');show();
  const f=$('p'+cur);if(f)f.scrollIntoView({block:'center'})}
function go(n){if(!pages)return;cur=Math.min(Math.max(n,1),pages);history.replaceState(null,'','#slide-'+cur);show()}
function jump(n){view()?go(n):($('p'+n)||{}).scrollIntoView&&$('p'+n).scrollIntoView({block:'start'});return false}
$('big').onclick=e=>{const r=e.target.getBoundingClientRect();go(cur+(e.clientX<r.left+r.width/2?-1:1))};
document.addEventListener('keydown',e=>{
  if(e.target.tagName==='INPUT'||e.ctrlKey||e.metaKey||e.altKey)return;
  const k=e.key;
  if(!view()){if(k==='s'||k==='S'){single(cur);e.preventDefault()}return}
  if(['ArrowRight','ArrowDown','PageDown',' ','Enter'].includes(k))go(cur+1);
  else if(['ArrowLeft','ArrowUp','PageUp','Backspace'].includes(k))go(cur-1);
  else if(k==='Home')go(1);else if(k==='End')go(pages);
  else if(k==='Escape'||k==='o'||k==='O')overview();else return;
  e.preventDefault()});
async function tick(){
  try{
    const r=await (await fetch('/state')).json();
    if(r.version!==ver){
      ver=r.version;pages=r.pages;changed=new Set(r.changed);
      const s=$('s'),st=$('strip');
      while(s.children.length>pages)s.lastChild.remove();
      while(st.children.length>pages)st.lastChild.remove();
      for(let i=1;i<=pages;i++){
        let f=s.children[i-1];
        if(!f){f=document.createElement('figure');f.id='p'+i;f.innerHTML='<img alt=""><figcaption></figcaption>';
          f.onclick=()=>single(i);s.appendChild(f)}
        f.querySelector('img').src=src(i);f.querySelector('figcaption').textContent=i;f.classList.toggle('changed',changed.has(i));
        let t=st.children[i-1];
        if(!t){t=document.createElement('img');t.alt='';t.onclick=()=>go(i);st.appendChild(t)}
        t.src=src(i)}
      $('st').textContent=pages+' pages · build '+ver+' · '+new Date().toLocaleTimeString();
      $('ch').innerHTML=ver<2?'':(r.changed.length?'changed: '+r.changed.map(n=>'<a href="#" onclick="return jump('+n+')">'+n+'</a>').join(''):'no page changed');
      show()}
  }catch(e){}
  setTimeout(tick,700)}
const m=location.hash.match(/^#slide-(\\d+)$/);if(m){cur=+m[1];document.body.classList.add('single')}
show();tick()</script>"""


class State:
    def __init__(self, pdf, dpi):
        self.pdf, self.dpi = pdf, dpi
        self.dir = tempfile.mkdtemp(prefix="gk-pdf-preview-")
        self.pages, self.hashes, self.changed = [], [], []
        self.version, self.mtime = 0, None
        self.lock = threading.Lock()

    def render(self):
        out = tempfile.mkdtemp(dir=self.dir)
        r = subprocess.run(["pdftoppm", "-r", str(self.dpi), "-png", self.pdf, out + "/p"], capture_output=True)
        pages = sorted(glob.glob(out + "/p-*.png"))
        if r.returncode != 0 or not pages:  # the PDF is still being written: the next poll tries again
            shutil.rmtree(out, ignore_errors=True)
            return False
        hashes = []
        for page in pages:
            with open(page, "rb") as f:
                hashes.append(hashlib.sha1(f.read()).hexdigest())
        with self.lock:
            old = os.path.dirname(self.pages[0]) if self.pages else None
            # a page changed: its picture differs from the same page's in the build before (or it is new)
            changed = [i + 1 for i, h in enumerate(hashes) if self.hashes and (i >= len(self.hashes) or self.hashes[i] != h)]
            self.pages, self.hashes, self.changed = pages, hashes, changed
            self.version += 1
        if old:
            shutil.rmtree(old, ignore_errors=True)
        return True

    def watch(self):
        while True:
            try:
                m = os.stat(self.pdf).st_mtime
                if m != self.mtime:
                    time.sleep(0.3)  # let the engine finish writing
                    if self.render():
                        self.mtime = m
            except FileNotFoundError:
                pass
            time.sleep(0.5)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pdf")
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--dpi", type=int, default=160)  # sharp in the one-slide view; 12 slides: 1.5 s on a Pi 5
    a = ap.parse_args()
    if not shutil.which("pdftoppm"):
        sys.exit("no pdftoppm - install poppler-utils")
    st = State(os.path.abspath(a.pdf), a.dpi)

    class H(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def send(self, body, ctype):
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            path = self.path.split("?")[0]
            if path == "/":
                return self.send(PAGE.encode(), "text/html; charset=utf-8")
            if path == "/state":
                with st.lock:
                    state = {"version": st.version, "pages": len(st.pages), "changed": st.changed}
                return self.send(json.dumps(state).encode(), "application/json")
            if path.startswith("/p/"):
                with st.lock:
                    pages = list(st.pages)
                try:
                    with open(pages[int(path[3:]) - 1], "rb") as f:
                        return self.send(f.read(), "image/png")
                except (ValueError, IndexError, OSError):
                    pass
            self.send_error(404)

    try:
        server = http.server.ThreadingHTTPServer(("127.0.0.1", a.port), H)
    except OSError as e:
        sys.exit(f"port {a.port}: {e.strerror}")
    threading.Thread(target=st.watch, daemon=True).start()
    # Neovim stops the job with SIGTERM: exit through the finally below, so the rendered pages go too
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    print(f"preview of {st.pdf} on http://localhost:{server.server_address[1]}", flush=True)
    try:
        server.serve_forever()
    finally:
        shutil.rmtree(st.dir, ignore_errors=True)


if __name__ == "__main__":
    main()
