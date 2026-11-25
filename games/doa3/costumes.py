#!/usr/bin/env python3
"""Trajes de mods de DOA3 (Gultigargar y usagiZ) solo para las chicas.

El port los instala con build_game.py y reparte los 128 huecos de la carpeta
de partidas entre todos los personajes. Aquí se usa su misma función
(install_costumes) pero ofreciendo solo los de las chicas, que caben todos
(113). Si la carpeta tiene trajes de chicos (un build anterior), se borran y
se vuelven a instalar los paquetes.

Europa (title ID 0x4D53002D) guarda en otra carpeta y el port no le pone
trajes. A petición del usuario se le copian los mismos (de USA o Japón), en
prueba: si el juego no los carga, quitar EUR_TITLE.

Se ejecuta en el contenedor de build, con build/ como carpeta actual:
    python3 games/doa3/costumes.py
"""
import re
import sys
from pathlib import Path

ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / "tools"))
import build_game  # noqa: E402  (del port)

# Códigos de personaje de los archivos (comprobados con las imágenes de
# muestra de los paquetes): kas Kasumi, aya Ayane, lei Lei Fang, tin Tina,
# hik Helena, kor Hitomi, gok Christie, alp Alpha-152.
GIRLS = ("kas", "aya", "lei", "tin", "hik", "kor", "gok", "alp")
MARK = "steamdeck-ports: solo chicas\n"
# Carpeta de partidas de la versión europea (docs/doa3-eur-test.md).
EUR_TITLE = "4D53002D"


def main():
    girls_only = re.compile(r"(?:%s)(?:[0-9]{2}|A[0-9])" % "|".join(GIRLS))
    source = None  # carpeta de trajes ya filtrada, para copiarla a Europa
    for version in sorted(build_game.VERSIONS.values(), key=lambda v: v["eur"]):
        if version["eur"]:
            copy_to_europe(version, source, girls_only)
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
                if (file.suffix in (".xpr", ".cat") and build_game.COSTUME_NAME.fullmatch(file.stem)
                        and not girls_only.fullmatch(file.stem)):
                    file.unlink()
                    removed += 1
            print(f"{play}: borrados {removed // 2} trajes de chicos", flush=True)
            # Para que install_costumes vuelva a ofrecer los paquetes.
            (storage / "costume-packs.txt").unlink(missing_ok=True)
        build_game.COSTUME_NAME = girls_only
        build_game.install_costumes(play)
        storage.mkdir(parents=True, exist_ok=True)
        mark.write_text(MARK, encoding="utf-8")
        count = len({f.stem for f in saves.glob("*.xpr")}) if saves.is_dir() else 0
        print(f"{play}: {count} trajes de mods", flush=True)
        source = source or saves


def copy_to_europe(version, source, girls_only):
    """Los trajes de chicas de USA/Japón, a la carpeta de partidas de Europa."""
    play = "play-disc" + version["suffix"]
    if not (ROOT / "private" / play).is_dir():
        return
    if source is None or not source.is_dir():
        print(f"{play}: sin trajes (hace falta también la versión USA o la japonesa)", flush=True)
        return
    saves = ROOT / "private" / play / ".recomp-storage" / "partition1" / "TDATA" / EUR_TITLE
    saves.mkdir(parents=True, exist_ok=True)
    copied = 0
    for file in sorted(source.iterdir()):
        if file.suffix in (".xpr", ".cat") and girls_only.fullmatch(file.stem):
            target = saves / file.name
            if not target.exists():
                partial = saves / (file.name + ".tmp")
                build_game.shutil.copyfile(file, partial)
                build_game.os.replace(partial, target)
                copied += 1
    count = len({f.stem for f in saves.glob("*.xpr")})
    print(f"{play}: {count} trajes de mods en TDATA/{EUR_TITLE} (copiados ahora: {copied // 2})", flush=True)


if __name__ == "__main__":
    main()
