#!/usr/bin/env python3
"""Live PDF preview for headless / SSH work (GreyKnight's <leader>lw starts it, lua/devsuite/latex.lua).

Renders the PDF to PNGs whenever it changes and serves them on http://localhost:PORT. The page swaps the images in
place (the scroll position stays) and marks the pages that changed in the last build - their outline, and links to
them in the bar at the top.

Usage:  python3 latex_preview.py PDF [--port 8000] [--dpi 110]     (--port 0: a free one; the URL is printed)
Over SSH: ssh -L 8000:localhost:8000 <host>, then http://localhost:8000 in the local browser.
Needs pdftoppm (poppler-utils). Standard library only.
"""
import argparse, glob, hashlib, http.server, json, os, shutil, signal, subprocess, sys, tempfile, threading, time

PAGE = """<!doctype html><meta charset=utf-8><title>PDF preview</title>
<style>
body{margin:0;background:#2b2d30;font:13px system-ui,sans-serif;color:#c9ccd1}
#bar{position:sticky;top:0;z-index:1;background:#1e1f22;padding:7px 14px;display:flex;gap:14px;align-items:center;flex-wrap:wrap}
#bar a{color:#f5b041;text-decoration:none;margin-right:6px}#bar a:hover{text-decoration:underline}
#s{display:grid;grid-template-columns:repeat(auto-fill,minmax(var(--w,520px),1fr));gap:16px;padding:16px}
figure{margin:0;scroll-margin-top:48px}img{width:100%;display:block;outline:3px solid transparent;outline-offset:2px}
figure.changed img{outline-color:#f5b041}figcaption{padding:4px 0}figure.changed figcaption::after{content:" \\00b7 changed";color:#f5b041}
body.only figure:not(.changed){display:none}
</style>
<div id=bar><span id=st>waiting for the PDF</span><span id=ch></span>
<label>width <input type=range min=240 max=1600 value=520 oninput="document.body.style.setProperty('--w',this.value+'px')"></label>
<label><input type=checkbox onchange="document.body.classList.toggle('only',this.checked)"> only changed</label></div>
<div id=s></div><script>
let ver=-1;
async function tick(){
  try{
    const r=await (await fetch('/state')).json();
    if(r.version!==ver){
      ver=r.version;const s=document.getElementById('s'),ch=new Set(r.changed);
      while(s.children.length>r.pages)s.lastChild.remove();
      for(let i=0;i<r.pages;i++){
        let f=s.children[i];
        if(!f){f=document.createElement('figure');f.id='p'+(i+1);f.innerHTML='<img><figcaption></figcaption>';s.appendChild(f)}
        f.querySelector('img').src='/p/'+(i+1)+'?v='+ver;f.querySelector('figcaption').textContent=i+1;
        f.classList.toggle('changed',ch.has(i+1))}
      document.getElementById('st').textContent=r.pages+' pages \\u00b7 build '+ver+' \\u00b7 '+new Date().toLocaleTimeString();
      document.getElementById('ch').innerHTML=r.version<2?'':(r.changed.length?'changed: '+r.changed.map(n=>'<a href="#p'+n+'">'+n+'</a>').join(''):'no page changed')}
  }catch(e){}
  setTimeout(tick,700)}
tick()</script>"""


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
    ap.add_argument("--dpi", type=int, default=110)
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
