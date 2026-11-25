#!/usr/bin/env python3
"""Trajes de mods de DOA3 (Gultigargar y usagiZ) solo para las chicas.

El port los instala con build_game.py y reparte los 128 huecos de la carpeta
de partidas entre todos los personajes. Aquí se usa su misma función
(install_costumes) pero ofreciendo solo los de las chicas, que caben todos
(113). Si la carpeta tiene trajes de chicos (un build anterior), se borran y
se vuelven a instalar los paquetes.

Si existe games/doa3/costumes.txt (lo escribe pick-costumes.py), solo se
instalan los trajes que lista y se quitan los demás: el juego enseña pocos
trajes extra por personaje.

Europa (title ID 0x4D53002D, carpeta TDATA/4D53002D): el port no le pone
trajes y, copiados a mano, el juego los abre pero no los enseña (probado por
el usuario). Se quitan los que hubiera de builds anteriores.

Se ejecuta en el contenedor de build, con build/ como carpeta actual:
    python3 games/doa3/costumes.py
"""
import hashlib
import re
import sys
from pathlib import Path

ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / "tools"))
import build_game  # noqa: E402  (del port)

# Cualquier nombre de traje (antes de que main() lo cambie por la selección)
ANY_COSTUME = build_game.COSTUME_NAME

# Códigos de personaje de los archivos (comprobados con las imágenes de
# muestra de los paquetes): kas Kasumi, aya Ayane, lei Lei Fang, tin Tina,
# hik Helena, kor Hitomi, gok Christie, alp Alpha-152.
GIRLS = ("kas", "aya", "lei", "tin", "hik", "kor", "gok", "alp")
SELECTION = Path(__file__).resolve().parent / "costumes.txt"
# Carpeta de partidas de la versión europea (docs/doa3-eur-test.md).
EUR_TITLE = "4D53002D"


def wanted_pattern():
    """(regex de los trajes que se quieren, marca que identifica la selección)"""
    if SELECTION.is_file():
        names = sorted({line.strip() for line in SELECTION.read_text(encoding="utf-8").splitlines()
                        if line.strip() and not line.startswith("#")})
        digest = hashlib.sha256("\n".join(names).encode()).hexdigest()[:16]
        print(f"Selección de costumes.txt: {len(names)} trajes", flush=True)
        return re.compile("|".join(map(re.escape, names)) or "(?!)"), f"steamdeck-ports: costumes.txt {digest}\n"
    return (re.compile(r"(?:%s)(?:[0-9]{2}|A[0-9])" % "|".join(GIRLS)),
            "steamdeck-ports: solo chicas\n")


def main():
    girls_only, MARK = wanted_pattern()
    for version in sorted(build_game.VERSIONS.values(), key=lambda v: v["eur"]):
        if version["eur"]:
            clean_europe(version)
            continue
        play = "play-disc" + version["suffix"]
        if not (ROOT / "private" / play).is_dir():
            continue
        storage = ROOT / "private" / play / ".recomp-storage"
        saves = storage / "partition1" / "TDATA" / "54430001"
        mark = storage / "costume-filter.txt"
        if not mark.is_file() or mark.read_text(encoding="utf-8") != MARK:
            removed = 0
            for file in list(saves.iterdir()) if saves.is_dir() else []:
                if (file.suffix in (".xpr", ".cat") and ANY_COSTUME.fullmatch(file.stem)
                        and not girls_only.fullmatch(file.stem)):
                    file.unlink()
                    removed += 1
            print(f"{play}: quitados {removed // 2} trajes que no están en la selección", flush=True)
            # Para que install_costumes vuelva a ofrecer los paquetes.
            (storage / "costume-packs.txt").unlink(missing_ok=True)
        build_game.COSTUME_NAME = girls_only
        build_game.install_costumes(play)
        storage.mkdir(parents=True, exist_ok=True)
        mark.write_text(MARK, encoding="utf-8")
        count = len({f.stem for f in saves.glob("*.xpr")}) if saves.is_dir() else 0
        print(f"{play}: {count} trajes de mods", flush=True)


def clean_europe(version):
    """Quita los trajes que copiaban builds anteriores a la carpeta de Europa."""
    saves = (ROOT / "private" / ("play-disc" + version["suffix"]) / ".recomp-storage"
             / "partition1" / "TDATA" / EUR_TITLE)
    removed = 0
    for file in list(saves.iterdir()) if saves.is_dir() else []:
        if file.suffix in (".xpr", ".cat") and ANY_COSTUME.fullmatch(file.stem):
            file.unlink()
            removed += 1
    if removed:
        print(f"Europa: quitados {removed // 2} trajes (no los enseña)", flush=True)

if __name__ == "__main__":
    main()
