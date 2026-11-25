#!/usr/bin/env python3
"""Accesos directos de Steam (juegos no de Steam) en la Steam Deck o en un PC.

Solo usa la biblioteca estándar (vale el Python de SteamOS).
Busca Steam en ~/.local/share/Steam, ~/.steam/steam y el de Flatpak
(~/.var/app/com.valvesoftware.Steam/.local/share/Steam).

  steam-art.py find <carpeta-del-juego>
      Imprime el appid de cada acceso directo cuyo ejecutable o carpeta de
      inicio está en <carpeta-del-juego>. Sale con 1 si no hay ninguno.

  steam-art.py art <carpeta-del-juego> <carpeta-de-imagenes>
      Copia las imágenes a userdata/<usuario>/config/grid/ con el appid de
      esos accesos directos. Nombres en <carpeta-de-imagenes> (png o jpg):
        cover   portada vertical (600x900)  -> <appid>p
        header  cabecera horizontal (920x430) -> <appid>
        hero    fondo de la ficha (1920x620) -> <appid>_hero
        logo    logo sobre el fondo -> <appid>_logo
      (el icono va en el .desktop con el que se añade el juego).

  steam-art.py add <ejecutable> <nombre> [--icon <imagen>] [--proton]
      Para el PC (en la Deck se usa steamos-add-to-steam): añade el acceso
      directo a shortcuts.vdf de cada usuario de Steam e imprime su appid.
      Con --proton, además fuerza el Proton más reciente (como «proton»).
      Steam tiene que estar cerrado: si no, al salir pisa los archivos.

  steam-art.py proton <appid> [herramienta]
      Fuerza una herramienta de compatibilidad para ese appid en
      config/config.vdf (CompatToolMapping). Sin herramienta: el GE-Proton más
      reciente de compatibilitytools.d, o «proton_experimental» si no hay.

Steam guarda los accesos directos en userdata/<usuario>/config/shortcuts.vdf,
en VDF binario: 0x00 = mapa, 0x01 = texto, 0x02 = entero de 32 bits, 0x08 =
fin de mapa. Antes de cambiar un archivo se guarda una copia (<archivo>.bak).
"""
import os
import re
import shutil
import struct
import sys
import zlib
from pathlib import Path

STEAM_ROOTS = (
    "~/.local/share/Steam",
    "~/.steam/steam",
    "~/.var/app/com.valvesoftware.Steam/.local/share/Steam",
)
ART = {"cover": "p", "header": "", "hero": "_hero", "logo": "_logo"}


def read_cstring(data, pos):
    end = data.index(b"\x00", pos)
    return data[pos:end].decode("utf-8", "replace"), end + 1


def parse_map(data, pos=0):
    """Devuelve (dict, posición tras el 0x08 de cierre)."""
    result = {}
    while pos < len(data):
        kind = data[pos]
        pos += 1
        if kind == 0x08:
            return result, pos
        key, pos = read_cstring(data, pos)
        if kind == 0x00:
            result[key], pos = parse_map(data, pos)
        elif kind == 0x01:
            result[key], pos = read_cstring(data, pos)
        elif kind == 0x02:
            result[key] = struct.unpack_from("<i", data, pos)[0]
            pos += 4
        elif kind == 0x07:  # entero de 64 bits (no lo usa shortcuts.vdf, por si acaso)
            result[key] = struct.unpack_from("<q", data, pos)[0]
            pos += 8
        else:
            raise ValueError(f"Tipo VDF desconocido 0x{kind:02x} en {pos - 1}")
    return result, pos


def steam_roots():
    seen = set()
    for root in STEAM_ROOTS:
        base = Path(root).expanduser()
        if base.is_dir() and base.resolve() not in seen:
            seen.add(base.resolve())
            yield base.resolve()


def shortcut_files():
    for base in steam_roots():
        yield from sorted(base.glob("userdata/*/config/shortcuts.vdf"))


def user_config_dirs():
    """userdata/<usuario>/config de cada usuario real (no el 0 ni anonymous)."""
    for base in steam_roots():
        for config in sorted(base.glob("userdata/*/config")):
            if config.parent.name.isdigit() and config.parent.name != "0":
                yield base, config


def steam_running():
    for comm in Path("/proc").glob("[0-9]*/comm"):
        try:
            if comm.read_text().strip() == "steam":
                return True
        except OSError:
            pass
    return False


def backup(path):
    if path.is_file():
        shutil.copy2(path, path.with_name(path.name + ".bak"))


def write_atomic(path, data):
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_bytes(data) if isinstance(data, bytes) else tmp.write_text(data, encoding="utf-8")
    os.replace(tmp, path)


def inside(path_text, folder):
    path_text = path_text.strip().strip('"')
    if not path_text:
        return False
    try:
        path = Path(path_text).expanduser().resolve()
    except OSError:
        return False
    return path == folder or folder in path.parents


def matches(game_dir):
    """[(shortcuts.vdf, appid sin signo, nombre)] de los accesos directos del juego."""
    folder = Path(game_dir).expanduser().resolve()
    found = []
    for vdf in shortcut_files():
        try:
            tree, _ = parse_map(vdf.read_bytes())
        except (OSError, ValueError, IndexError, struct.error) as error:
            print(f"Aviso: no se pudo leer {vdf}: {error}", file=sys.stderr)
            continue
        for entry in tree.get("shortcuts", {}).values():
            if not isinstance(entry, dict):
                continue
            # Las claves cambian de mayúsculas según la versión de Steam.
            fields = {key.lower(): value for key, value in entry.items()}
            exe, start = fields.get("exe", ""), fields.get("startdir", "")
            if inside(exe, folder) or inside(start, folder):
                appid = fields.get("appid", 0) & 0xFFFFFFFF
                if appid:
                    found.append((vdf, appid, fields.get("appname", "")))
    return found


def copy_art(game_dir, art_dir):
    art_dir = Path(art_dir)
    hits = matches(game_dir)
    if not hits:
        print("No hay ningún acceso directo de Steam para este juego.", file=sys.stderr)
        return 1
    copied = 0
    for vdf, appid, name in hits:
        grid = vdf.parent / "grid"
        grid.mkdir(exist_ok=True)
        for kind, suffix in ART.items():
            for ext in ("png", "jpg"):
                source = art_dir / f"{kind}.{ext}"
                if source.is_file():
                    for old in ("png", "jpg"):  # que no quede la imagen anterior en otro formato
                        (grid / f"{appid}{suffix}.{old}").unlink(missing_ok=True)
                    shutil.copyfile(source, grid / f"{appid}{suffix}.{ext}")
                    copied += 1
                    break
        print(f"Imágenes copiadas para «{name}» (appid {appid}) en {grid}")
    if not copied:
        print(f"No hay imágenes en {art_dir}", file=sys.stderr)
    return 0


# --- Escritura de shortcuts.vdf (binario) -----------------------------------

def vdf_entry(key, fields):
    out = b"\x00" + key.encode() + b"\x00"
    for name, value in fields:
        if isinstance(value, list):  # mapa anidado
            out += vdf_entry(name, value)
        elif isinstance(value, int):
            out += b"\x02" + name.encode() + b"\x00" + struct.pack("<i", value)
        else:
            out += b"\x01" + name.encode() + b"\x00" + value.encode() + b"\x00"
    return out + b"\x08"


def shortcut_appid(exe_field, name):
    """El appid que calcula Steam para un acceso directo (sin signo)."""
    return (zlib.crc32((exe_field + name).encode()) & 0xFFFFFFFF) | 0x80000000


def add_shortcut(exe, name, icon="", proton=False):
    if steam_running():
        print("Steam está abierto: ciérralo (Steam → Salir) y vuelve a intentarlo.", file=sys.stderr)
        return 3
    exe = Path(exe).expanduser().resolve()
    exe_field = f'"{exe}"'
    appid = shortcut_appid(exe_field, name)
    fields = [
        ("appid", struct.unpack("<i", struct.pack("<I", appid))[0]),
        ("AppName", name),
        ("Exe", exe_field),
        ("StartDir", f'"{exe.parent}"'),
        ("icon", str(icon) if icon else ""),
        ("ShortcutPath", ""),
        ("LaunchOptions", ""),
        ("IsHidden", 0),
        ("AllowDesktopConfig", 1),
        ("AllowOverlay", 1),
        ("OpenVR", 0),
        ("Devkit", 0),
        ("DevkitGameID", ""),
        ("DevkitOverrideAppID", 0),
        ("LastPlayTime", 0),
        ("FlatpakAppID", ""),
        ("tags", []),
    ]
    done = 0
    for base, config in user_config_dirs():
        vdf = config / "shortcuts.vdf"
        data = vdf.read_bytes() if vdf.is_file() else b""
        if not data:
            data = b"\x00shortcuts\x00\x08\x08"
        try:
            prefix = b"\x00shortcuts\x00"
            if not data.startswith(prefix):
                raise ValueError("no empieza por el mapa «shortcuts»")
            entries, end = parse_map(data, len(prefix))
        except (ValueError, IndexError, struct.error) as error:
            print(f"Aviso: no se pudo leer {vdf}: {error}; no se toca", file=sys.stderr)
            continue
        present = [e for e in entries.values() if isinstance(e, dict)
                   and ({k.lower(): v for k, v in e.items()}.get("appid", 0) & 0xFFFFFFFF) == appid]
        if present:
            print(f"Ya estaba en {vdf}")
        else:
            index = max((int(k) for k in entries if k.isdigit()), default=-1) + 1
            # El mapa «shortcuts» acaba en data[end - 1] (0x08): la entrada va justo antes.
            new = data[:end - 1] + vdf_entry(str(index), fields) + data[end - 1:]
            backup(vdf)
            write_atomic(vdf, new)
            print(f"Añadido «{name}» a {vdf}")
        done += 1
        if proton:
            set_proton(base, appid)
    if not done:
        print("No encuentro ningún usuario de Steam (¿no has iniciado sesión nunca?).", file=sys.stderr)
        return 1
    print(appid)
    return 0


# --- config.vdf (texto) ----------------------------------------------------

TOKEN = re.compile(r'\s+|//[^\n]*|"((?:[^"\\]|\\.)*)"|([{}])|([^\s{}"]+)')


def parse_text_vdf(text):
    """Lista de (clave, valor) con valor texto o lista anidada (conserva el orden)."""
    tokens = []
    for m in TOKEN.finditer(text):
        if m.group(1) is not None:
            tokens.append(("s", m.group(1)))
        elif m.group(2):
            tokens.append((m.group(2), None))
        elif m.group(3):
            tokens.append(("s", m.group(3)))
    pos = 0

    def block():
        nonlocal pos
        items = []
        while pos < len(tokens):
            kind, value = tokens[pos]
            if kind == "}":
                pos += 1
                return items
            if kind != "s":
                raise ValueError("VDF de texto mal formado")
            key = value
            pos += 1
            kind, value = tokens[pos]
            pos += 1
            items.append((key, block() if kind == "{" else value))
        return items

    return block()


def dump_text_vdf(items, depth=0):
    tab = "\t" * depth
    out = ""
    for key, value in items:
        if isinstance(value, list):
            out += f'{tab}"{key}"\n{tab}{{\n{dump_text_vdf(value, depth + 1)}{tab}}}\n'
        else:
            out += f'{tab}"{key}"\t\t"{value}"\n'
    return out


def child(items, key, create=True):
    for k, v in items:
        if k.lower() == key.lower() and isinstance(v, list):
            return v
    if not create:
        return None
    new = []
    items.append((key, new))
    return new


def newest_proton(base):
    names = []
    for tool in base.glob("compatibilitytools.d/*/compatibilitytool.vdf"):
        try:
            tree = parse_text_vdf(tool.read_text(encoding="utf-8", errors="replace"))
        except (ValueError, IndexError):
            continue
        tools = child(child(tree, "compatibilitytools", False) or [], "compat_tools", False) or []
        names += [k for k, v in tools if isinstance(v, list)]
    ge = [n for n in names if n.lower().startswith("ge-proton")]
    if not ge:
        return "proton_experimental"
    return max(ge, key=lambda n: tuple(int(x) for x in re.findall(r"\d+", n)))


def set_proton(base, appid, tool=None):
    config = base / "config" / "config.vdf"
    tool = tool or newest_proton(base)
    text = config.read_text(encoding="utf-8") if config.is_file() else ""
    tree = parse_text_vdf(text) if text.strip() else []
    mapping = child(tree, "InstallConfigStore")
    for key in ("Software", "Valve", "Steam", "CompatToolMapping"):
        mapping = child(mapping, key)
    mapping[:] = [(k, v) for k, v in mapping if k != str(appid)]
    mapping.append((str(appid), [("name", tool), ("config", ""), ("priority", "250")]))
    config.parent.mkdir(parents=True, exist_ok=True)
    backup(config)
    write_atomic(config, dump_text_vdf(tree))
    print(f"Proton para el appid {appid}: {tool} ({config})")


def main(argv):
    if len(argv) >= 2 and argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0
    if len(argv) == 3 and argv[1] == "find":
        hits = matches(argv[2])
        for _, appid, _ in hits:
            print(appid)
        return 0 if hits else 1
    if len(argv) == 4 and argv[1] == "art":
        return copy_art(argv[2], argv[3])
    if len(argv) >= 4 and argv[1] == "add":
        icon, proton, rest = "", False, argv[4:]
        while rest:
            if rest[0] == "--proton":
                proton, rest = True, rest[1:]
            elif rest[0] == "--icon" and len(rest) >= 2:
                icon, rest = rest[1], rest[2:]
            else:
                print(__doc__, file=sys.stderr)
                return 2
        return add_shortcut(argv[2], argv[3], icon, proton)
    if len(argv) in (3, 4) and argv[1] == "proton" and argv[2].isdigit():
        if steam_running():
            print("Steam está abierto: ciérralo y vuelve a intentarlo.", file=sys.stderr)
            return 3
        for base in steam_roots():
            set_proton(base, int(argv[2]), argv[3] if len(argv) == 4 else None)
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
