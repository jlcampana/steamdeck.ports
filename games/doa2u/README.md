# Dead or Alive 2 Ultimate — `doa2u`

- Repo: https://github.com/NoRain211/doa2u-re
- Release usada: `DOA2U-<v>-Alpha-Linux.zip` (código + herramientas, sin juego compilado)
- Versión probada al descargar: v0.4.0
- ISO: `isos/DOA2U.iso` (en la documentación del repo, `disc2.iso`). La misma
  ISO sirve para `doa1u`.
- En la Deck: Linux nativo (Vulkan vía SDL3)

## Build

Se compila en Ubuntu 24.04 (Docker en el PC). Requiere Python 3.12+:

```
./build_game.sh /ruta/DOA2U.iso
```

- `build_game.py` crea `private/venv` e instala Capstone. Se detiene si faltan
  CMake, Ninja, Git o un compilador de C++.
- Si no hay `extract-xiso` en el PATH, descarga la release fijada y comprueba
  su SHA-256 (necesita glibc 2.34+). Si no, `--extractor <ruta>`.
- `install_deps.sh` instala dependencias con apt/dnf/pacman (`--print` solo
  muestra el comando).
- Otros modos: `--build-only`, `--lift-only`, `--disassemble`.

## Jugar

- `./launcher.sh` o `./run_game.sh` (sin argumentos = `--play --saved`).
- Extras opcionales del repo: voces de golpe y banda sonora importadas de
  DOA3/DOA4 (`tools/import_doa4_voices.py`, `tools/import_soundtrack.py`),
  Xbox Live sobre rollback netcode.
- Añadir `launcher.sh` a Steam como juego no de Steam.

Docs del repo: `docs/building.md`.
