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

- `build_game.py` instala Capstone con `pip` usando el Python que lo lanza
  (la doc dice que crea el venv, pero no lo hace). En Ubuntu 24.04 eso falla
  fuera de un venv (PEP 668), así que nuestro `build.sh` crea `private/venv`
  antes. Se detiene si faltan
  CMake, Ninja, Git o un compilador de C++.
- Si no hay `extract-xiso` en el PATH, descarga la release fijada y comprueba
  su SHA-256 (necesita glibc 2.34+). Si no, `--extractor <ruta>`.
- `install_deps.sh` instala dependencias con apt/dnf/pacman (`--print` solo
  muestra el comando).
- Otros modos: `--build-only`, `--lift-only`, `--disassemble`.

## Jugar

- **Instalar en la Deck:** `tools/package.sh doa2u` y, en la Deck, doble clic en
  `Instalar <Nombre>.desktop` (ver «Distribución a la Steam Deck» en el README
  principal). Nombre en Steam, ejecutable y Proton: `game.conf`.
- **En la Deck, usar `steamdeck.sh`** (lo genera `build.sh`; es el punto de
  entrada común de todos los juegos Linux). Pone las librerías del build (SDL3)
  en `LD_LIBRARY_PATH` y lanza `launcher.sh` → `run_game.sh` → `run_game.py`
  (estos tres son del port, no nuestros). Sin él, el runner busca SDL3 en la
  ruta del PC donde se compiló.

- `./launcher.sh` o `./run_game.sh` (sin argumentos = `--play --saved`).
- Extras opcionales del repo: voces de golpe y banda sonora importadas de
  DOA3/DOA4 (`tools/import_doa4_voices.py`, `tools/import_soundtrack.py`),
  Xbox Live sobre rollback netcode.
- Añadir `launcher.sh` a Steam como juego no de Steam.

Docs del repo: `docs/building.md`.

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
- Si este juego necesitara paquetes extra, se crearía `games/doa2u/Dockerfile`
  con `FROM steamdeck-ports/ubuntu-build:24.04` y solo lo suyo.
