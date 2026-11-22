# Dead or Alive 3 — `doa3`

- Repo: https://github.com/NoRain211/doa3-re
- Release usada: `DOA3-<v>-Linux.tar.gz` (código + herramientas, sin juego compilado)
- Versión probada al descargar: v0.7.1
- ISO: `isos/DOA3.iso` (USA; también acepta la japonesa 3.1, cada una en su carpeta)
- En la Deck: Linux nativo (Vulkan vía SDL3)

## Build

Se compila en Ubuntu 24.04 (Docker en el PC). Requiere Python 3.12+ con `venv`:

```
./build_game.sh /ruta/DOA3.iso
```

- El script crea `private/venv`; Capstone (`capstone==5.0.7`) se instala ahí.
- `--extractor <extract-xiso>` si no está en el PATH.
- `--movies / --no-movies` controla los vídeos.
- El repo trae `build_steamdeck.sh`, que hace lo mismo en la Deck con
  distrobox (contenedor `doa3-build`, Ubuntu 24.04). Aquí no se usa.

## Jugar

- `./launcher.sh` (pantalla de ajustes con mando) o `./run_game.sh`.
- Las capturas de pantalla se guardan en `~/Pictures/DOA3` (la tecla está en
  `docs/runtime-options.md`).
- Añadir `launcher.sh` a Steam como juego no de Steam.

Docs del repo: `docs/building.md`, `docs/runtime-options.md`.
