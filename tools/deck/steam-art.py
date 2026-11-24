#!/usr/bin/env python3
"""Accesos directos de Steam (juegos no de Steam) en la Steam Deck.

Solo usa la biblioteca estándar (vale el Python de SteamOS).

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

Steam guarda los accesos directos en userdata/<usuario>/config/shortcuts.vdf,
en VDF binario: 0x00 = mapa, 0x01 = texto, 0x02 = entero de 32 bits, 0x08 =
fin de mapa. Steam puede reescribir el archivo, así que aquí solo se lee.
"""
import shutil
import struct
import sys
from pathlib import Path

STEAM_ROOTS = ("~/.local/share/Steam", "~/.steam/steam")
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


def shortcut_files():
    seen = set()
    for root in STEAM_ROOTS:
        base = Path(root).expanduser()
        if not base.is_dir():
            continue
        for vdf in base.glob("userdata/*/config/shortcuts.vdf"):
            real = vdf.resolve()
            if real not in seen:
                seen.add(real)
                yield real


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


def main(argv):
    if len(argv) == 3 and argv[1] == "find":
        hits = matches(argv[2])
        for _, appid, _ in hits:
            print(appid)
        return 0 if hits else 1
    if len(argv) == 4 and argv[1] == "art":
        return copy_art(argv[2], argv[3])
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
