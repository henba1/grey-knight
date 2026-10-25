#!/usr/bin/env python3
"""Live PDF / image preview for headless / SSH work (GreyKnight's <leader>lw starts it, lua/devsuite/latex.lua).

Renders the PDF to PNGs whenever it changes and serves them on http://localhost:PORT. The page swaps the images in
place (the scroll position stays) and marks the pages that changed in the last build - their outline, and links to
them in the bar at the top. Two views: the overview (all pages) and one slide at a time with a strip of the others
(a click on a page, or S; arrow keys / Space go on, Esc back).

An image (png, jpg, gif, svg, webp, bmp, avif, ico) is shown as it is - the browser draws it, nothing is rendered;
it is new on the page whenever the file changes. A PDF also opens as itself in the browser's viewer (/raw).

Usage:  python3 latex_preview.py FILE [--port 8000] [--dpi 160]     (--port 0: a free one; the URL is printed)
Over SSH: ssh -L 8000:localhost:8000 <host>, then http://localhost:8000 in the local browser.
A PDF needs pdftoppm (poppler-utils). Standard library only.
"""
import argparse, glob, hashlib, http.server, json, os, shutil, signal, subprocess, sys, tempfile, threading, time

# what the browser shows as it is - by extension
IMAGES = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".gif": "image/gif", ".svg": "image/svg+xml",
          ".webp": "image/webp", ".bmp": "image/bmp", ".avif": "image/avif", ".ico": "image/x-icon"}

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
/* an image: its own size (no bigger than the window), on a checkerboard for transparency */
body.image #s{display:block}body.image #s img,body.image #big{width:auto;height:auto;max-width:100%;max-height:100%}
body.image #s img,body.image #big{background:repeating-conic-gradient(#3a3d41 0% 25%,#33363a 0% 50%) 0 0/16px 16px}
body.image #strip,body.image .pg,body.image figcaption{display:none}
</style>
<div id=bar><a id=home href=/ style="display:none">◂ all previews</a><span id=st>waiting for the file</span><span id=ch></span><a id=raw href=raw target=_blank style="display:none">Open PDF</a>
<span class=pg><button id=bo onclick="overview()">Overview</button> <button id=bs onclick="single(cur)">Slide</button></span>
<label class="ov pg">width <input type=range min=240 max=1600 value=520 oninput="document.body.style.setProperty('--w',this.value+'px')"></label>
<label class="ov pg"><input type=checkbox onchange="document.body.classList.toggle('only',this.checked)"> only changed</label>
<span class="hint ov pg">click a slide or S: one slide</span><span class="hint sv pg">← → Space: next / back · Home End · Esc or O: overview</span></div>
<div id=s></div>
<div id=one><div id=stage><img id=big alt=""></div><div id=cap></div><div id=strip></div></div>
<script>
let ver=-1,pages=0,changed=new Set(),cur=1;
const $=id=>document.getElementById(id),src=n=>'p/'+n+'?v='+ver;
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
    const res=await fetch('state');
    if(res.status===404){ // the hub closed it: too many open, idle, its Neovim gone
      $('st').innerHTML='This preview is closed - <a href="/" style="color:#f5b041">the open previews</a>';
      $('s').innerHTML='';$('one').style.display='none';$('ch').innerHTML='';return}
    const r=await res.json();
    if(r.version!==ver){
      ver=r.version;pages=r.pages;changed=new Set(r.changed);
      document.title=r.name;document.body.classList.toggle('image',r.kind==='image');
      $('raw').style.display=r.kind==='pdf'?'':'none';$('home').style.display=r.hub?'':'none';
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
      $('st').textContent=r.name+' · '+(r.kind==='image'?'':pages+' pages · ')+'version '+ver+' · '+new Date().toLocaleTimeString();
      $('ch').innerHTML=ver<2?'':r.kind==='image'?(r.changed.length?'<a>changed</a>':''):(r.changed.length?'changed: '+r.changed.map(n=>'<a href="#" onclick="return jump('+n+')">'+n+'</a>').join(''):'no page changed');
      show()}
  }catch(e){}
  setTimeout(tick,700)}
const m=location.hash.match(/^#slide-(\\d+)$/);if(m){cur=+m[1];document.body.classList.add('single')}
show();tick()</script>"""



INDEX = """<!doctype html><meta charset=utf-8><title>Previews</title>
<style>body{margin:0;background:#2b2d30;font:13px system-ui,sans-serif;color:#c9ccd1}
h1{font-size:15px;font-weight:600;margin:0;padding:10px 16px;background:#1e1f22}
table{border-collapse:collapse;margin:12px 16px}td,th{text-align:left;padding:5px 14px 5px 0}th{color:#7d8187;font-weight:400}
a{color:#f5b041;text-decoration:none}a:hover{text-decoration:underline}.dim{color:#7d8187}</style>
<h1>Open previews <span class=dim id=n></span></h1><table><thead><tr><th>File</th><th>Kind</th><th>Folder</th><th>Last change</th></tr></thead>
<tbody id=t></tbody></table><p class=dim style="margin:0 16px">At most %(max)d open (a new one closes the oldest);
one closes after %(ttl)s without a view or a change, or when the Neovim that opened it ends.</p>
<script>
async function tick(){try{const r=await (await fetch('/api/items')).json();
document.getElementById('n').textContent='· '+r.length;
document.getElementById('t').innerHTML=r.length?r.map(i=>'<tr><td><a href="/'+i.id+'/">'+i.name+'</a></td><td>'+i.kind
+'</td><td class=dim>'+i.folder+'</td><td class=dim>'+(i.changed?new Date(i.changed*1000).toLocaleTimeString():'-')+'</td></tr>').join('')
:'<tr><td class=dim>none - &lt;leader&gt;lw on a .tex, a PDF or an image opens one</td></tr>'}catch(e){}setTimeout(tick,2000)}tick()</script>"""


class State:
    """One previewed file: a PDF rendered to pictures, or an image as it is."""

    def __init__(self, path, dpi):
        self.path, self.dpi = path, dpi
        ext = os.path.splitext(path)[1].lower()
        self.kind, self.ctype = ("image", IMAGES[ext]) if ext in IMAGES else ("pdf", "application/pdf")
        self.dir = tempfile.mkdtemp(prefix="gk-pdf-preview-")
        self.pages, self.hashes, self.changed = [], [], []
        self.image = b""  # an image: the bytes shown, as read when it changed
        self.version, self.mtime, self.changed_at = 0, None, None
        self.touched = time.time()  # the last view or change: a hub closes it after --ttl without either
        self.lock = threading.Lock()
        self.stopped = threading.Event()

    def render(self):
        if self.kind == "image":
            with open(self.path, "rb") as f:
                data = f.read()
            if not data:  # still being written
                return False
            h = hashlib.sha1(data).hexdigest()
            with self.lock:
                self.changed = [1] if self.hashes and self.hashes[0] != h else []
                self.image, self.pages, self.hashes = data, [self.path], [h]
                self.version += 1
            return True
        out = tempfile.mkdtemp(dir=self.dir)
        r = subprocess.run(["pdftoppm", "-r", str(self.dpi), "-png", self.path, out + "/p"], capture_output=True)
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
        while not self.stopped.is_set():
            try:
                m = os.stat(self.path).st_mtime
                if m != self.mtime:
                    time.sleep(0.3)  # let the engine finish writing
                    if self.render():
                        self.mtime, self.changed_at = m, time.time()
                        self.touched = time.time()
            except FileNotFoundError:
                pass
            self.stopped.wait(0.5)

    def start(self):
        threading.Thread(target=self.watch, daemon=True).start()
        return self

    def stop(self):
        self.stopped.set()
        shutil.rmtree(self.dir, ignore_errors=True)

    def state(self, hub):
        self.touched = time.time()  # an open page asks every 0.7 s: it keeps the preview alive
        with self.lock:
            return {"version": self.version, "pages": len(self.pages), "changed": self.changed, "kind": self.kind,
                    "name": os.path.basename(self.path), "hub": hub}

    def page(self, n):
        with self.lock:
            if self.kind == "image":
                return (self.image, self.ctype) if n == 1 and self.image else None
            pages = list(self.pages)
        try:
            with open(pages[n - 1], "rb") as f:
                return f.read(), "image/png"
        except (IndexError, OSError):
            return None


def owner_alive(pid):
    """The Neovim that opened a preview still runs (Windows: not checked - os.kill(pid, 0) would end it there)."""
    if not isinstance(pid, int) or os.name == "nt":
        return True
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:  # it runs, as another user
        return True


class Hub:
    """Every preview of this user on one port: Neovim puts <dir>/items/<id>.json ({path, owner, opened}) there and
    takes it away; the hub serves each at /<id>/. One SSH tunnel (one -L) shows them all, wherever they were opened."""

    def __init__(self, folder, dpi, max_items, ttl, linger):
        self.folder, self.dpi, self.max, self.ttl, self.linger = folder, dpi, max_items, ttl, linger
        self.items_dir = os.path.join(folder, "items")
        os.makedirs(self.items_dir, exist_ok=True)
        self.items, self.lock = {}, threading.Lock()
        self.empty_since = time.time()

    def registrations(self):
        regs = {}
        for f in glob.glob(os.path.join(self.items_dir, "*.json")):
            try:
                with open(f) as fh:
                    reg = json.load(fh)
                regs[os.path.basename(f)[:-5]] = (f, reg)
            except (OSError, ValueError):
                pass  # being written: the next scan reads it
        return regs

    def scan(self):
        """Closes what is over (owner gone, idle, more than --max: the oldest), opens what is new."""
        regs, now = self.registrations(), time.time()
        for id_, (f, reg) in list(regs.items()):
            item = self.items.get(id_)
            idle = item and now - item.touched > self.ttl
            if not owner_alive(reg.get("owner")) or idle or not os.path.exists(reg.get("path", "")):
                os.remove(f) if os.path.exists(f) else None
                del regs[id_]
        for id_, (f, reg) in sorted(regs.items(), key=lambda kv: kv[1][1].get("opened", 0))[:max(0, len(regs) - self.max)]:
            os.remove(f)  # too many open: the oldest goes - its page says so
            del regs[id_]
        with self.lock:
            for id_ in list(self.items):
                if id_ not in regs or self.items[id_].path != os.path.abspath(regs[id_][1]["path"]):
                    self.items.pop(id_).stop()
            for id_, (f, reg) in regs.items():
                if id_ not in self.items:
                    self.items[id_] = State(os.path.abspath(reg["path"]), self.dpi).start()
            if self.items:
                self.empty_since = None
            elif self.empty_since is None:
                self.empty_since = now
        return self.empty_since is not None and now - self.empty_since > self.linger

    def listing(self):
        with self.lock:
            items = sorted(self.items.items(), key=lambda kv: os.path.basename(kv[1].path).lower())
        return [{"id": id_, "name": os.path.basename(st.path), "kind": st.kind, "changed": st.changed_at,
                 "folder": os.path.dirname(st.path).replace(os.path.expanduser("~"), "~", 1)} for id_, st in items]

    def get(self, id_):
        with self.lock:
            return self.items.get(id_)


def handler(single=None, hub=None, index=""):
    class H(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def send(self, body, ctype, code=200, extra=None):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Cache-Control", "no-store")
            for k, v in (extra or {}).items():
                self.send_header(k, v)
            self.end_headers()
            self.wfile.write(body)

        def item(self, st, sub):
            if sub == "":
                return self.send(PAGE.encode(), "text/html; charset=utf-8")
            if sub == "state":
                return self.send(json.dumps(st.state(hub is not None)).encode(), "application/json")
            if sub == "raw":  # the file itself: a PDF in the browser's own viewer
                try:
                    with open(st.path, "rb") as f:
                        return self.send(f.read(), st.ctype)
                except OSError:
                    pass
            if sub.startswith("p/") and sub[2:].isdigit():
                got = st.page(int(sub[2:]))
                if got:
                    return self.send(*got)
            self.send_error(404)

        def do_GET(self):
            path = self.path.split("?")[0]
            if single:
                return self.item(single, path.lstrip("/"))
            if path == "/":
                return self.send(index.encode(), "text/html; charset=utf-8")
            if path == "/api/items":
                return self.send(json.dumps(hub.listing()).encode(), "application/json")
            id_, slash, sub = path.lstrip("/").partition("/")
            st = hub.get(id_)
            if not st:
                return self.send_error(404)
            if not slash:  # /<id>: the page's links are relative to /<id>/
                return self.send(b"", "text/plain", 301, {"Location": "/" + id_ + "/"})
            return self.item(st, sub)
    return H


def bind(port, count, h):
    """The server on the first free port of port .. port+count-1 (0: any free one)."""
    last = None
    for p in ([0] if port == 0 else range(port, port + max(1, count))):
        try:
            return http.server.ThreadingHTTPServer(("127.0.0.1", p), h)
        except OSError as e:
            last = e
    sys.exit(f"port {port}{'-' + str(port + count - 1) if count > 1 and port else ''}: {last.strerror if last else 'busy'}")



def serve(server, cleanup):
    # Neovim stops a single preview's job with SIGTERM: exit through the finally, so the rendered pages go too
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        server.serve_forever()
    finally:
        cleanup()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file", nargs="?", help="a PDF or an image (without --hub: just this one)")
    ap.add_argument("--hub", metavar="DIR", help="serve every preview registered in DIR/items (GreyKnight)")
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--ports", type=int, default=1, help="try PORT .. PORT+N-1 when PORT is taken")
    ap.add_argument("--dpi", type=int, default=160)  # sharp in the one-slide view; 12 slides: 1.5 s on a Pi 5
    ap.add_argument("--max", type=int, default=20, help="hub: previews at most (a new one closes the oldest)")
    ap.add_argument("--ttl", type=float, default=4 * 3600, help="hub: seconds without a view or change before one closes")
    ap.add_argument("--linger", type=float, default=60, help="hub: seconds without previews before it ends")
    a = ap.parse_args()

    if not a.hub:
        if not a.file:
            ap.error("a file, or --hub DIR")
        st = State(os.path.abspath(a.file), a.dpi)
        if st.kind == "pdf" and not shutil.which("pdftoppm"):
            sys.exit("no pdftoppm - install poppler-utils")
        server = bind(a.port, a.ports, handler(single=st))
        st.start()
        print(f"preview of {st.path} on http://localhost:{server.server_address[1]}", flush=True)
        return serve(server, st.stop)

    os.makedirs(a.hub, exist_ok=True)
    try:  # one hub per folder: a second one started at the same time leaves
        import fcntl
        lock = open(os.path.join(a.hub, "hub.lock"), "w")
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            sys.exit(0)
    except ImportError:  # Windows: no flock - Neovim checks hub.json before it starts one
        pass
    hub = Hub(a.hub, a.dpi, a.max, a.ttl, a.linger)
    ttl = f"{a.ttl / 3600:g} h" if a.ttl >= 3600 else f"{a.ttl:g} s"
    server = bind(a.port, a.ports, handler(hub=hub, index=INDEX % {"max": a.max, "ttl": ttl}))
    info = os.path.join(a.hub, "hub.json")
    with open(info + ".tmp", "w") as f:
        json.dump({"pid": os.getpid(), "port": server.server_address[1]}, f)
    os.replace(info + ".tmp", info)
    print(f"previews on http://localhost:{server.server_address[1]}", flush=True)

    def housekeeping():
        while True:
            if hub.scan():  # nothing open for --linger seconds: the hub ends
                return server.shutdown()
            time.sleep(0.5)
    threading.Thread(target=housekeeping, daemon=True).start()

    def cleanup():
        with hub.lock:
            for st in hub.items.values():
                st.stop()
        try:
            with open(info) as f:
                if json.load(f).get("pid") == os.getpid():
                    os.remove(info)
        except (OSError, ValueError):
            pass
    serve(server, cleanup)


if __name__ == "__main__":
    main()
