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
- El repo trae `build_steamdeck.sh`, que compila **en** la Deck con
  distrobox (contenedor `doa3-build`, Ubuntu 24.04, todo dentro de `$HOME`).
  Aquí no se usa: compilamos en el PC y la Deck recibe el juego hecho.

## Jugar

- **Instalar en la Deck:** `tools/package.sh doa3` y, en la Deck, doble clic en
  `Instalar <Nombre>.desktop` (ver «Distribución a la Steam Deck» en el README
  principal). Nombre en Steam, ejecutable y Proton: `game.conf`.
- **En la Deck, usar `steamdeck.sh`** (lo genera `build.sh`; es el punto de
  entrada común de todos los juegos Linux). Pone las librerías del build (SDL3)
  en `LD_LIBRARY_PATH` y lanza `launcher.sh` → `run_game.sh` → `run_game.py`
  (estos tres son del port, no nuestros). Sin él, el runner busca SDL3 en la
  ruta del PC donde se compiló.

- `./launcher.sh` (pantalla de ajustes con mando) o `./run_game.sh`.
- Las capturas de pantalla se guardan en `~/Pictures/DOA3` (la tecla está en
  `docs/runtime-options.md`).
- Añadir `launcher.sh` a Steam como juego no de Steam. Con un mando para dos
  puertos, desactivar Steam Input en ese acceso.

Docs del repo: `docs/building.md`, `docs/runtime-options.md`.

## Imagen Ubuntu 24.04 (contenedor de build)

- Dockerfile: [`tools/docker/ubuntu-build.Dockerfile`](../../tools/docker/ubuntu-build.Dockerfile),
  **compartido** por doaxtreme, doa3 y doa2u (los tres compilan con los mismos
  paquetes). Parte de `docker.io/library/ubuntu:24.04` e instala los paquetes de
  compilación de `docs/building.md` del repo (CMake, Ninja, clang, Python 3.12
  con venv, Vulkan/shaderc y las cabeceras que necesita SDL3, incluido el audio).
- Imagen: `steamdeck-ports/ubuntu-build:24.04`. La construye `build.sh` (vía
  `run_in_container` de `tools/lib.sh`) con podman, o con docker si su daemon
  está activo; si ya existe, sale de la caché al instante.
- A mano: `podman build -t steamdeck-ports/ubuntu-build:24.04 -f tools/docker/ubuntu-build.Dockerfile tools/docker`
  (desde la raíz del repo).
- Si este juego necesitara paquetes extra, se crearía `games/doa3/Dockerfile`
  con `FROM steamdeck-ports/ubuntu-build:24.04` y solo lo suyo.
