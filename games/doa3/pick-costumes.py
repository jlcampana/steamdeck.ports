#!/usr/bin/env python3
"""Elige los trajes de mods de DOA3 que se instalan en el build.

Descarga (una vez) los paquetes de trajes de Gultigargar y usagiZ a
games/doa3/costume-packs/ (fuera de git) y abre en el navegador una página
local con las hojas de muestra de cada chica y una casilla por traje. «Guardar»
escribe la selección en games/doa3/costumes.txt, que usa costumes.py en el
build (games/doa3/build.sh). Sin costumes.txt se instalan todos los de chicas.

Motivo: el juego solo enseña unos pocos trajes extra por personaje (¿9?), no
todos los que hay en la carpeta, hasta que el port lo amplíe.

Uso: games/doa3/pick-costumes.py [-n] [--port N]
  -n, --no-browser  no abre el navegador (solo muestra la dirección)
  --port N          puerto local (por defecto uno libre)
  -h, --help        muestra esta ayuda
Después: games/doa3/build.sh (aplica la selección) y tools/package.sh doa3.
"""
import argparse
import html
import http.server
import json
import re
import shutil
import subprocess
import sys
import threading
import webbrowser
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
CACHE = HERE / "costume-packs"
SELECTION = HERE / "costumes.txt"
sys.path.insert(0, str(HERE / "latest" / "tools"))
try:
    import build_game  # noqa: E402  (del port: enlaces, SHA-256 y descarga de MediaFire)
except ImportError:
    sys.exit("Falta games/doa3/latest: ejecuta antes ./update.sh doa3")

# Mismos códigos que costumes.py
GIRLS = {"kas": "Kasumi", "aya": "Ayane", "lei": "Lei Fang", "tin": "Tina",
         "hik": "Helena", "kor": "Hitomi", "gok": "Christie", "alp": "Alpha-152"}
NAME = re.compile(r"([a-z]{3})(?:[0-9]{2}|A[0-9])")
DEFAULT_LIMIT = 9


def unpack(archive, folder):
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as z:
            z.extractall(folder)
        return
    for tool, args in (("bsdtar", ["-xf", archive, "-C", folder]),
                       ("unrar", ["x", "-o+", "-inul", archive, str(folder) + "/"]),
                       ("7z", ["x", "-y", f"-o{folder}", archive])):
        if shutil.which(tool):
            subprocess.run([tool, *map(str, args)], check=True, stdout=subprocess.DEVNULL)
            return
    sys.exit("Para descomprimir el RAR hace falta bsdtar, unrar o 7z")


def fetch_packs():
    """[(nombre del paquete, carpeta descomprimida)]"""
    packs = []
    for index, (name, page, expected) in enumerate(build_game.COSTUME_PACKS):
        folder = CACHE / str(index)
        if not (folder / ".ok").is_file():
            CACHE.mkdir(exist_ok=True)
            archive = CACHE / f"{index}.download"
            if not archive.is_file() or build_game.sha256(archive) != expected:
                print(f"Descargando los trajes de {name}…", flush=True)
                build_game.download_mediafire(page, archive)
                if build_game.sha256(archive) != expected:
                    sys.exit(f"{name}: la descarga no coincide con su SHA-256")
            shutil.rmtree(folder, ignore_errors=True)
            folder.mkdir()
            unpack(archive, folder)
            (folder / ".ok").touch()
            archive.unlink()
        packs.append((name.removesuffix("'s"), folder))
    return packs


def catalog(packs):
    """costumes: {chica: [(código, paquete)]}; sheets: {chica|'varias': [ruta relativa]}"""
    costumes, sheets = {g: [] for g in GIRLS}, {g: [] for g in GIRLS}
    sheets["varias"] = []
    seen = set()
    for pack, folder in packs:
        for xpr in sorted(folder.rglob("*.xpr")):
            m = NAME.fullmatch(xpr.stem)
            if m and m.group(1) in GIRLS and xpr.with_suffix(".cat").is_file() and xpr.stem not in seen:
                seen.add(xpr.stem)
                costumes[m.group(1)].append((xpr.stem, pack))
        for img in sorted([*folder.rglob("*.jpg"), *folder.rglob("*.png")]):
            rel = img.relative_to(CACHE).as_posix()
            if img.stem in GIRLS:
                sheets[img.stem].append(rel)
            elif not re.fullmatch(r"[a-z]{3}", img.stem):   # bas.jpg, zac.jpg…: chicos
                sheets["varias"].append(rel)
    for g in costumes:
        costumes[g].sort(key=lambda c: (c[0][3] == "A", c[0]))
    return costumes, sheets


def page(costumes, sheets, chosen):
    def imgs(paths):
        return "".join(f'<a href="img/{html.escape(p)}" target="_blank"><img src="img/{html.escape(p)}" '
                       f'loading="lazy" alt="{html.escape(p)}"></a>' for p in paths)
    sections = []
    for g, name in GIRLS.items():
        boxes = "".join(
            f'<label class="c"><input type="checkbox" name="c" value="{c}" data-g="{g}"'
            f'{" checked" if c in chosen else ""}> {c} <small>{p}</small></label>'
            for c, p in costumes[g])
        sections.append(f'''<section id="{g}"><h2>{name} <code>{g}</code>
<span class="count" data-g="{g}"></span></h2>
<div class="sheets">{imgs(sheets[g]) or "<p class=note>Sin hoja propia: mira «Varias».</p>"}</div>
<div class="boxes">{boxes}</div>
<p><button type="button" data-all="{g}">Todos</button> <button type="button" data-none="{g}">Ninguno</button></p>
</section>''')
    return f'''<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DOA3: trajes de mods</title><style>
body{{font-family:system-ui,sans-serif;margin:0;background:#15181d;color:#e8e8e8}}
header{{position:sticky;top:0;background:#1f242b;padding:.6em 1em;border-bottom:1px solid #333;z-index:1;
  display:flex;gap:1em;align-items:center;flex-wrap:wrap}}
header nav a{{color:#9cf;margin-right:.6em}} main{{padding:1em}} section{{margin-bottom:2.5em}}
h2{{border-bottom:1px solid #333;padding-bottom:.2em}} code{{color:#9cf}}
.sheets img{{max-width:100%;max-height:420px;margin:.3em;border:1px solid #333;background:#36c}}
.boxes{{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:.3em}}
label.c{{background:#232932;padding:.35em .5em;border-radius:4px;cursor:pointer}}
label.c:has(input:checked){{background:#2d5a3a}} small{{color:#999}}
.count{{font-size:.7em;font-weight:normal;margin-left:.5em}} .over{{color:#f86}}
button{{background:#2b6cb0;color:#fff;border:0;padding:.45em .9em;border-radius:4px;cursor:pointer}}
#status{{color:#8d8}} .note{{color:#999}}
</style></head><body>
<header><strong>DOA3 — trajes de mods</strong>
<label>Límite por personaje <input id="limit" type="number" min="1" max="99" value="{DEFAULT_LIMIT}" style="width:4em"></label>
<span id="total"></span><button id="save">Guardar en costumes.txt</button><span id="status"></span>
<nav>{"".join(f'<a href="#{g}">{n}</a>' for g, n in GIRLS.items())}<a href="#varias">Varias</a></nav></header>
<main><p class="note">El número de cada traje sale debajo de su dibujo en las hojas (p. ej. <code>kas17-19</code>
son kas17, kas18 y kas19). Pulsa una hoja para verla en grande. El juego enseña unos pocos trajes extra por
personaje: el límite solo avisa, no impide marcar más.</p>
{"".join(sections)}
<section id="varias"><h2>Hojas con varios personajes</h2><div class="sheets">{imgs(sheets["varias"])}</div></section>
</main><script>
const boxes=[...document.querySelectorAll('input[name=c]')], limit=document.getElementById('limit');
function update(){{
  let total=0;
  document.querySelectorAll('.count').forEach(s=>{{
    const n=boxes.filter(b=>b.dataset.g===s.dataset.g&&b.checked).length; total+=n;
    s.textContent=n+' marcados'; s.classList.toggle('over', n>+limit.value);
    if(n>+limit.value) s.textContent+=' (más que el límite)';
  }});
  document.getElementById('total').textContent=total+' en total (máximo del juego: 128)';
}}
boxes.forEach(b=>b.addEventListener('change',update)); limit.addEventListener('input',update);
document.querySelectorAll('[data-all]').forEach(b=>b.onclick=()=>{{boxes.filter(x=>x.dataset.g===b.dataset.all).forEach(x=>x.checked=true);update()}});
document.querySelectorAll('[data-none]').forEach(b=>b.onclick=()=>{{boxes.filter(x=>x.dataset.g===b.dataset.none).forEach(x=>x.checked=false);update()}});
document.getElementById('save').onclick=async()=>{{
  const chosen=boxes.filter(b=>b.checked).map(b=>b.value);
  const r=await fetch('save',{{method:'POST',headers:{{'Content-Type':'application/json'}},body:JSON.stringify(chosen)}});
  document.getElementById('status').textContent=r.ok?'Guardado ('+chosen.length+'). Ya puedes cerrar la página.':'Error al guardar';
}};
update();
</script></body></html>'''


def read_selection():
    if not SELECTION.is_file():
        return None
    return {line.strip() for line in SELECTION.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.startswith("#")}


def write_selection(chosen, valid):
    chosen = sorted(c for c in set(chosen) if c in valid)
    SELECTION.write_text(
        "# Trajes de mods de DOA3 que instala games/doa3/costumes.py en el build (uno por línea).\n"
        "# Se edita con games/doa3/pick-costumes.py. Sin este archivo: todos los de las chicas.\n"
        + "".join(f"{c}\n" for c in chosen), encoding="utf-8")
    return chosen


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("-n", "--no-browser", action="store_true")
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("-h", "--help", action="store_true")
    args = ap.parse_args()
    if args.help:
        print(__doc__.strip())
        return
    costumes, sheets = catalog(fetch_packs())
    valid = {c for cs in costumes.values() for c, _ in cs}
    current = read_selection()
    chosen = valid if current is None else current & valid
    body = page(costumes, sheets, chosen).encode("utf-8")

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def send(self, code, data, ctype):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            if self.path in ("/", "/index.html"):
                return self.send(200, body, "text/html; charset=utf-8")
            if self.path.startswith("/img/"):
                target = (CACHE / self.path[5:]).resolve()
                if target.is_file() and CACHE.resolve() in target.parents and target.suffix in (".jpg", ".png"):
                    return self.send(200, target.read_bytes(),
                                     "image/png" if target.suffix == ".png" else "image/jpeg")
            self.send(404, b"no", "text/plain")

        def do_POST(self):
            if self.path != "/save":
                return self.send(404, b"no", "text/plain")
            data = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"[]")
            saved = write_selection([c for c in data if isinstance(c, str)], valid)
            per = {g: sum(1 for c in saved if c.startswith(g)) for g in GIRLS}
            print(f"Guardados {len(saved)} trajes en {SELECTION}: "
                  + ", ".join(f"{GIRLS[g]} {n}" for g, n in per.items()), flush=True)
            self.send(200, b"ok", "text/plain")

    server = http.server.ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    url = f"http://127.0.0.1:{server.server_address[1]}/"
    print(f"Selector de trajes en {url} (Ctrl+C para terminar)", flush=True)
    if not args.no_browser:
        threading.Timer(0.5, webbrowser.open, [url]).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print()
    print("Para aplicarlo: games/doa3/build.sh y tools/package.sh doa3")


if __name__ == "__main__":
    main()
