#!/usr/bin/env python3
"""Live PDF / image preview for headless / SSH work (GreyKnight's <leader>lw starts it, lua/devsuite/latex.lua).

Renders the PDF to PNGs whenever it changes and serves them on http://localhost:PORT. The page swaps the images in
place (the scroll position stays) and marks the pages that changed in the last build - their outline, and links to
them in the bar at the top. Two views: the overview (all pages side by side) and the page view (one page after
another, each as large as it reads well: a slide fills the window, a document page the width; a click on a page,
or P; arrow keys / Space go on, Esc back).

An image (png, jpg, gif, svg, webp, bmp, avif, ico) is shown as it is - the browser draws it, nothing is rendered;
it is new on the page whenever the file changes. A PDF also opens as itself in the browser's viewer (/raw).

Gentle on a small machine: one render at a time (all previews of a hub share it), at the lowest priority and with
a memory cap; a few pages per pdftoppm run, so the first pages show while the rest render and a newer build stops
an old one; a page is never bigger than --max-px. A page's address names its picture (p/3?h=<hash>), so the browser
keeps it until it changes - a build loads only the pages that changed - and it loads only the pages in view.

Usage:  python3 latex_preview.py FILE [--port 8000] [--dpi 160]     (--port 0: a free one; the URL is printed)
Over SSH: ssh -L 8000:localhost:8000 <host>, then http://localhost:8000 in the local browser.
A PDF needs pdftoppm and pdfinfo (poppler-utils). Standard library only.
"""
import argparse, glob, hashlib, http.server, json, os, re, shutil, signal, subprocess, sys, tempfile, threading, time

# what the browser shows as it is - by extension
IMAGES = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".gif": "image/gif", ".svg": "image/svg+xml",
          ".webp": "image/webp", ".bmp": "image/bmp", ".avif": "image/avif", ".ico": "image/x-icon"}

BATCH = 8  # pages per pdftoppm run
RENDER = threading.Lock()  # one pdftoppm at a time, for every preview of the process
RENDER_MEM = 1536 << 20  # address space of a pdftoppm run: a broken or huge PDF fails instead of swapping the host
RENDER_TIMEOUT = 300  # seconds for one run of BATCH pages

PAGE = """<!doctype html><meta charset=utf-8><title>PDF preview</title>
<style>
body{margin:0;background:#2b2d30;font:13px system-ui,sans-serif;color:#c9ccd1}
#bar{position:sticky;top:0;z-index:2;background:#1e1f22;padding:7px 14px;display:flex;gap:14px;align-items:center;flex-wrap:wrap}
#bar a{color:#f5b041;text-decoration:none;margin-right:6px;cursor:pointer}#bar a:hover{text-decoration:underline}
#bar button{background:#2b2d30;color:#c9ccd1;border:1px solid #45484d;border-radius:3px;padding:2px 9px;font:inherit;cursor:pointer}
#bar button.on{background:#45484d;color:#fff}
.hint{color:#7d8187}
figure{margin:0;scroll-margin-top:48px}
img{display:block;outline:3px solid transparent;outline-offset:2px;aspect-ratio:var(--a,0.707)}
.changed>img{outline-color:#f5b041}
figcaption{padding:4px 0}.changed figcaption::after{content:" · changed";color:#f5b041}
/* overview */
#s{display:grid;grid-template-columns:repeat(auto-fill,minmax(var(--w,520px),1fr));gap:16px;padding:16px}
#s figure{cursor:zoom-in}#s img{width:100%}
body.only #s figure:not(.changed){display:none}
/* page view: one page after another - a slide as large as the window, a document page as wide as reads well */
#col{display:none;flex-direction:column;align-items:center;gap:18px;padding:16px}
#col img{width:min(calc(100vw - 32px),1000px)}
#col.wide img{width:min(calc(100vw - 32px),calc((100vh - 70px) * var(--a)))}
#col figcaption{text-align:center}#col figure.cur figcaption{color:#fff}
body.single #s,body.single .ov{display:none}body.single #col{display:flex}
body:not(.single) .sv{display:none}
/* an image: its own size (no bigger than the window), on a checkerboard for transparency */
body.image #s{display:block}body.image #s img{width:auto;height:auto;max-width:100%;aspect-ratio:auto}
body.image #s img{background:repeating-conic-gradient(#3a3d41 0% 25%,#33363a 0% 50%) 0 0/16px 16px}
body.image .pg,body.image figcaption{display:none}
</style>
<div id=bar><a id=home href=/ style="display:none">◂ all previews</a><span id=st>waiting for the file</span><span id=ch></span><a id=raw href=raw target=_blank style="display:none">Open PDF</a>
<span class=pg><button id=bo onclick="overview()">Overview</button> <button id=bp onclick="single(cur)">Pages</button></span>
<label class="ov pg">width <input type=range min=240 max=1600 value=520 oninput="document.body.style.setProperty('--w',this.value+'px')"></label>
<label class="ov pg"><input type=checkbox onchange="document.body.classList.toggle('only',this.checked)"> only changed</label>
<span class="hint ov pg">click a page or P: one page after another</span><span class="hint sv pg">← → Space: next / back · Home End · Esc or O: overview</span></div>
<div id=s></div>
<div id=col></div>
<script>
let ver=-1,build=0,pages=0,hashes=[],changed=new Set(),cur=1,timer=0,fails=0,failedSince=0,gone=false;
const $=id=>document.getElementById(id),src=n=>'p/'+n+'?h='+(hashes[n-1]||'');
function view(){return document.body.classList.contains('single')}
// the page in view in the page view: the first one still visible below the bar
const seen=new IntersectionObserver(()=>{if(!view())return;
  for(const f of $('col').children){if(f.getBoundingClientRect().bottom>80){cur=+f.dataset.n;break}}mark()},{threshold:[0,.5,1]});
function mark(){$('bo').classList.toggle('on',!view());$('bp').classList.toggle('on',view());
  for(const f of $('col').children)f.classList.toggle('cur',+f.dataset.n===cur);
  if(view())history.replaceState(null,'','#page-'+cur)}
function go(n){if(!pages)return;cur=Math.min(Math.max(n,1),pages);const f=$('q'+cur);if(f)f.scrollIntoView({block:'start'});mark()}
function single(n){cur=n||cur;document.body.classList.add('single');go(cur)}
function overview(){document.body.classList.remove('single');history.replaceState(null,'','#');mark();
  const f=$('p'+cur);if(f)f.scrollIntoView({block:'center'})}
function jump(n){const f=$((view()?'q':'p')+n);if(f){cur=n;f.scrollIntoView({block:'start'})}return false}
document.addEventListener('keydown',e=>{
  if(e.target.tagName==='INPUT'||e.ctrlKey||e.metaKey||e.altKey)return;
  const k=e.key;
  if(!view()){if(k==='p'||k==='P'){single(cur);e.preventDefault()}return}
  if(['ArrowRight','PageDown',' ','Enter'].includes(k))go(cur+1);
  else if(['ArrowLeft','PageUp','Backspace'].includes(k))go(cur-1);
  else if(k==='Home')go(1);else if(k==='End')go(pages);
  else if(k==='Escape'||k==='o'||k==='O')overview();else return;
  e.preventDefault()});
// a page in the overview (p<n>) or the page view (q<n>); its picture loads when it comes into view
function fig(id,n,box){let f=$(id+n);
  if(!f){f=document.createElement('figure');f.id=id+n;f.dataset.n=n;
    f.innerHTML='<img alt="" loading=lazy decoding=async><figcaption></figcaption>';box.appendChild(f);
    if(id==='p')f.onclick=()=>single(n);else seen.observe(f)}
  const im=f.querySelector('img'),s=src(n);if(im.getAttribute('src')!==s)im.src=s;
  f.querySelector('figcaption').textContent=n;f.classList.toggle('changed',changed.has(n))}
function later(ms){clearTimeout(timer);if(!gone)timer=setTimeout(tick,ms)}
async function tick(){
  let res;
  try{res=await fetch('state',{cache:'no-store'})}catch(e){ // no server (the tunnel's far end): back off, give up after 3 min
    fails++;failedSince=failedSince||Date.now();
    if(Date.now()-failedSince>180000){gone=true;
      $('st').innerHTML='The preview server is gone - <a onclick="reconnect()">reconnect</a>';return}
    $('st').textContent='the preview server does not answer - trying again';return later(Math.min(30000,500*2**fails))}
  fails=0;failedSince=0;
  if(res.status===404){gone=true; // the hub closed it: too many open, idle, its Neovim gone
    $('st').innerHTML='This preview is closed - <a href="/" style="color:#f5b041">the open previews</a>';
    $('s').innerHTML='';$('col').innerHTML='';$('ch').innerHTML='';return}
  try{const r=await res.json();
    if(r.version!==ver){
      const firstTime=ver<0;
      ver=r.version;build=r.build;pages=r.pages;hashes=r.hashes;changed=new Set(r.changed);
      document.title=r.name;document.body.classList.toggle('image',r.kind==='image');
      $('raw').style.display=r.kind==='pdf'?'':'none';$('home').style.display=r.hub?'':'none';
      if(r.aspect){document.body.style.setProperty('--a',r.aspect);$('col').classList.toggle('wide',r.aspect>1)}
      for(const [id,box] of [['p',$('s')],['q',$('col')]]){
        while(box.children.length>pages)box.lastChild.remove();
        for(let i=1;i<=pages;i++)fig(id,i,box)}
      $('st').textContent=r.name+' · '+(r.kind==='image'?'':pages+' pages · ')
        +(r.rendering?'rendering '+r.rendering[0]+' / '+r.rendering[1]:'build '+build+' · '+new Date().toLocaleTimeString());
      $('ch').innerHTML=build<2?'':r.kind==='image'?(r.changed.length?'<a>changed</a>':''):(r.changed.length?'changed: '+r.changed.map(n=>'<a onclick="return jump('+n+')">'+n+'</a>').join(''):'no page changed');
      if(firstTime&&view())go(cur);else mark()}
  }catch(e){}
  later(document.hidden?4000:700)}
function reconnect(){gone=false;fails=0;failedSince=0;$('st').textContent='connecting';tick()}
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&!gone)later(0)});
const m=location.hash.match(/^#(page|slide)-([0-9]+)$/);if(m){cur=+m[2];document.body.classList.add('single')}
mark();tick()</script>"""


INDEX = """<!doctype html><meta charset=utf-8><title>Previews</title>
<style>body{margin:0;background:#2b2d30;font:13px system-ui,sans-serif;color:#c9ccd1}
h1{font-size:15px;font-weight:600;margin:0;padding:10px 16px;background:#1e1f22}
table{border-collapse:collapse;margin:12px 16px}td,th{text-align:left;padding:5px 14px 5px 0}th{color:#7d8187;font-weight:400}
a{color:#f5b041;text-decoration:none;cursor:pointer}a:hover{text-decoration:underline}.dim{color:#7d8187}</style>
<h1>Open previews <span class=dim id=n></span></h1><table><thead><tr><th>File</th><th>Kind</th><th>Folder</th><th>Last change</th></tr></thead>
<tbody id=t></tbody></table><p class=dim style="margin:0 16px">At most %(max)d open (a new one closes the oldest);
one closes after %(ttl)s without a view or a change, or when the Neovim that opened it ends.</p>
<script>
let fails=0,failedSince=0;
async function tick(){let r;const n=document.getElementById('n');
try{r=await (await fetch('/api/items',{cache:'no-store'})).json()}catch(e){fails++;failedSince=failedSince||Date.now();
  if(Date.now()-failedSince>180000){n.innerHTML='· the server is gone - <a onclick="fails=0;failedSince=0;tick()">reconnect</a>';return}
  n.textContent='· the server does not answer';return setTimeout(tick,Math.min(30000,500*2**fails))}
fails=0;failedSince=0;n.textContent='· '+r.length;
document.getElementById('t').innerHTML=r.length?r.map(i=>'<tr><td><a href="/'+i.id+'/">'+i.name+'</a></td><td>'+i.kind
+'</td><td class=dim>'+i.folder+'</td><td class=dim>'+(i.changed?new Date(i.changed*1000).toLocaleTimeString():'-')+'</td></tr>').join('')
:'<tr><td class=dim>none - &lt;leader&gt;lw on a .tex, a PDF or an image opens one</td></tr>';
setTimeout(tick,document.hidden?10000:2000)}tick()</script>"""


def limit():
    """pdftoppm's start: the lowest priority, and a memory cap (POSIX only)."""
    os.nice(19)
    import resource
    resource.setrlimit(resource.RLIMIT_AS, (RENDER_MEM, RENDER_MEM))


def pdfinfo(path):
    """(pages, width, height of the first page in pt), or None while the PDF is unreadable (still being written)."""
    try:
        out = subprocess.run(["pdfinfo", path], capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.TimeoutExpired):
        return None
    pages = re.search(r"^Pages:\s+(\d+)", out, re.M)
    size = re.search(r"^Page size:\s+([\d.]+) x ([\d.]+)", out, re.M)
    if not pages or not int(pages.group(1)):
        return None
    w, h = (float(size.group(1)), float(size.group(2))) if size else (595.0, 842.0)
    return int(pages.group(1)), w, h


class State:
    """One previewed file: a PDF rendered to pictures, or an image as it is."""

    def __init__(self, path, dpi, max_px=2400):
        self.path, self.dpi, self.max_px = path, dpi, max_px
        ext = os.path.splitext(path)[1].lower()
        self.kind, self.ctype = ("image", IMAGES[ext]) if ext in IMAGES else ("pdf", "application/pdf")
        self.dir = tempfile.mkdtemp(prefix="gk-pdf-preview-")
        self.pages, self.hashes, self.changed = [], [], []  # what is shown: each page's picture and its hash
        self.done = []  # the hashes of the last complete build: what "changed" compares with
        self.image = b""  # an image: the bytes shown, as read when it changed
        self.aspect, self.rendering = None, None
        self.version, self.build, self.sig, self.changed_at = 0, 0, None, None
        self.touched = time.time()  # the last view or change: a hub closes it after --ttl without either
        self.lock = threading.Lock()
        self.stopped = threading.Event()
        self.proc = None

    def signature(self):
        try:
            st = os.stat(self.path)
            return st.st_mtime, st.st_size
        except OSError:
            return None

    def render(self, sig):
        """True: shown; False: failed (tried again later); None: stopped, or the file changed meanwhile."""
        if self.kind == "image":
            with open(self.path, "rb") as f:
                data = f.read()
            if not data:  # still being written
                return False
            h = hashlib.sha1(data).hexdigest()[:20]
            with self.lock:
                self.changed = [1] if self.done and self.done[0] != h else []
                self.image, self.pages, self.hashes, self.done = data, [self.path], [h], [h]
                self.version += 1
                self.build += 1
            return True
        info = pdfinfo(self.path)
        if not info:
            return False
        count, w, h = info
        dpi = max(1, min(self.dpi, int(self.max_px * 72 / max(w, h))))  # a poster: no 100-megapixel pages
        paths, hashes = [], []
        for first in range(1, count + 1, BATCH):
            last = min(count, first + BATCH - 1)
            out = tempfile.mkdtemp(dir=self.dir)
            try:
                with RENDER:
                    if self.stopped.is_set() or self.signature() != sig:  # closed, or a newer build to render instead
                        return None
                    self.proc = subprocess.Popen(
                        ["pdftoppm", "-r", str(dpi), "-png", "-f", str(first), "-l", str(last), self.path, out + "/p"],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, preexec_fn=limit if os.name == "posix" else None)
                    try:
                        code = self.proc.wait(RENDER_TIMEOUT)
                    except subprocess.TimeoutExpired:
                        self.proc.kill()
                        code = self.proc.wait()
                    self.proc = None
                files = sorted(glob.glob(out + "/p-*.png"), key=lambda p: int(re.search(r"(\d+)\.png$", p).group(1)))
                if code != 0 or len(files) != last - first + 1:
                    return None if self.stopped.is_set() else False
                for f in files:  # a picture is named by its hash: an unchanged page keeps its file
                    with open(f, "rb") as fh:
                        digest = hashlib.sha1(fh.read()).hexdigest()[:20]
                    dest = os.path.join(self.dir, digest + ".png")
                    os.replace(f, dest)
                    paths.append(dest)
                    hashes.append(digest)
            finally:
                shutil.rmtree(out, ignore_errors=True)
            with self.lock:  # what is rendered shows now; the pages after it are the last build's until their turn
                n = len(paths)
                self.pages = paths + self.pages[n:count]
                self.hashes = hashes + self.hashes[n:count]
                self.changed = [i + 1 for i, d in enumerate(hashes) if self.done and (i >= len(self.done) or self.done[i] != d)]
                self.aspect = round(w / h, 4)
                self.rendering = None if n == count else (n, count)
                self.version += 1
                if n == count:
                    self.done = hashes
                    self.build += 1
        keep = set(paths)
        for f in glob.glob(os.path.join(self.dir, "*.png")):  # the pictures no page shows any more
            if f not in keep:
                os.remove(f)
        return True

    def watch(self):
        fails, retry_at, failed = 0, 0, None
        while not self.stopped.is_set():
            sig = self.signature()
            # a new version of the file; one that failed to render: again after a while, longer each time
            if sig and sig != self.sig and (sig != failed or time.time() >= retry_at):
                time.sleep(0.4)
                if self.signature() == sig:  # not growing any more: the engine is done writing
                    try:
                        ok = self.render(sig)
                    except OSError:
                        ok = False
                    if ok:
                        self.sig, self.changed_at, self.touched, fails, failed = sig, time.time(), time.time(), 0, None
                    elif ok is False:
                        fails, failed = fails + 1, sig
                        retry_at = time.time() + min(60, 2 ** fails)
                continue
            self.stopped.wait(0.5)

    def start(self):
        threading.Thread(target=self.watch, daemon=True).start()
        return self

    def stop(self):
        self.stopped.set()
        proc = self.proc
        if proc:  # a render under way ends with the preview
            try:
                proc.kill()
            except OSError:
                pass
        shutil.rmtree(self.dir, ignore_errors=True)

    def state(self, hub):
        self.touched = time.time()  # an open page asks every 0.7 s: it keeps the preview alive
        with self.lock:
            return {"version": self.version, "build": self.build, "pages": len(self.pages), "changed": self.changed,
                    "hashes": self.hashes, "aspect": self.aspect, "rendering": self.rendering, "kind": self.kind,
                    "name": os.path.basename(self.path), "hub": hub}

    def page(self, n, h=None):
        """(bytes, type, whether it is the picture the hash h names) of page n"""
        with self.lock:
            if not 1 <= n <= len(self.pages):
                return None
            same = h == self.hashes[n - 1]
            if self.kind == "image":
                return (self.image, self.ctype, same) if self.image else None
            path = self.pages[n - 1]
        try:
            with open(path, "rb") as f:
                return f.read(), "image/png", same
        except OSError:
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

    def __init__(self, folder, dpi, max_px, max_items, ttl, linger):
        self.folder, self.dpi, self.max_px, self.max, self.ttl, self.linger = folder, dpi, max_px, max_items, ttl, linger
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
                    self.items[id_] = State(os.path.abspath(reg["path"]), self.dpi, self.max_px).start()
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
        timeout = 30  # a connection that went quiet (a dropped tunnel) does not hold its thread

        def log_message(self, *args):
            pass

        def send(self, body, ctype, code=200, extra=None, cache=False):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            # a page's picture asked for by its hash never changes: the browser keeps it, a build loads only new ones
            self.send_header("Cache-Control", "max-age=31536000, immutable" if cache else "no-store")
            for k, v in (extra or {}).items():
                self.send_header(k, v)
            self.end_headers()
            self.wfile.write(body)

        def item(self, st, sub, query):
            if sub == "":
                return self.send(PAGE.encode(), "text/html; charset=utf-8")
            if sub == "state":
                return self.send(json.dumps(st.state(hub is not None)).encode(), "application/json")
            if sub == "raw":  # the file itself, a piece at a time: a PDF in the browser's own viewer
                try:
                    with open(st.path, "rb") as f:
                        self.send_response(200)
                        self.send_header("Content-Type", st.ctype)
                        self.send_header("Content-Length", str(os.fstat(f.fileno()).st_size))
                        self.send_header("Cache-Control", "no-store")
                        self.end_headers()
                        return shutil.copyfileobj(f, self.wfile, 1 << 20)
                except OSError:
                    pass
            if sub.startswith("p/") and sub[2:].isdigit():
                got = st.page(int(sub[2:]), query.get("h"))
                if got:
                    body, ctype, same = got
                    return self.send(body, ctype, cache=same)
            self.send_error(404)

        def do_GET(self):
            path, _, qs = self.path.partition("?")
            query = dict(kv.partition("=")[::2] for kv in qs.split("&") if kv)
            try:
                if single:
                    return self.item(single, path.lstrip("/"), query)
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
                return self.item(st, sub, query)
            except (BrokenPipeError, ConnectionResetError):
                pass  # the browser went away mid-answer (a reload, a closed tab)
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
    ap.add_argument("--dpi", type=int, default=160)  # sharp in the page view; 12 slides: 1.5 s on a Pi 5
    ap.add_argument("--max-px", type=int, default=2400, help="a page's longest side at most (a poster at --dpi is huge)")
    ap.add_argument("--max", type=int, default=20, help="hub: previews at most (a new one closes the oldest)")
    ap.add_argument("--ttl", type=float, default=4 * 3600, help="hub: seconds without a view or change before one closes")
    ap.add_argument("--linger", type=float, default=60, help="hub: seconds without previews before it ends")
    a = ap.parse_args()

    if not a.hub:
        if not a.file:
            ap.error("a file, or --hub DIR")
        st = State(os.path.abspath(a.file), a.dpi, a.max_px)
        if st.kind == "pdf" and not (shutil.which("pdftoppm") and shutil.which("pdfinfo")):
            sys.exit("no pdftoppm / pdfinfo - install poppler-utils")
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
    hub = Hub(a.hub, a.dpi, a.max_px, a.max, a.ttl, a.linger)
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
