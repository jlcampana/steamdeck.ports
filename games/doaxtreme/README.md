# Dead or Alive Xtreme Beach Volleyball — `doaxtreme`

- Repo: https://github.com/NoRain211/doaxbv-re (antes `doaxvb-re`, GitHub redirige)
- Release usada: `DOAXBV-<v>-Linux.zip` (código + herramientas, sin juego compilado)
- Versión probada al descargar: v0.7.0
- ISO: `isos/DOAXtreme.iso` (versión USA de Xbox)
- En la Deck: Linux nativo (Vulkan vía SDL3)

## Build

Se compila en Ubuntu 24.04 (Docker en el PC):

```
./build_game.sh /ruta/DOAXtreme.iso      # equivale a --iso <iso>
```

- `tools/setup_env.sh` prepara Python y Capstone en `private/venv`.
- `--extractor <extract-xiso>` si no está en el PATH.
- `--generate-only` para parar antes de compilar (diagnóstico).
- Al terminar escribe `private/setup-*/build-receipt.json` con estado
  `built-unverified`.
- El zip de Linux trae un launcher precompilado
  (`tools/artifacts/launcher-linux-x86_64`, solo necesita glibc 2.34) que
  `launcher.sh` usa sin Python ni compilador.

## Jugar

- **Instalar en la Deck:** `tools/package.sh doaxtreme` y, en la Deck, doble clic en
  `Instalar <Nombre>.desktop` (ver «Distribución a la Steam Deck» en el README
  principal). Nombre en Steam, ejecutable y Proton: `game.conf`.
- **En la Deck, usar `steamdeck.sh`** (lo genera `build.sh`; es el punto de
  entrada común de todos los juegos Linux). Pone las librerías del build (SDL3)
  en `LD_LIBRARY_PATH` y lanza `launcher.sh` → `run_game.sh` → `run_game.py`
  (estos tres son del port, no nuestros). Sin él, el runner busca SDL3 en la
  ruta del PC donde se compiló.

- `./launcher.sh`: opciones (resolución, MSAA, niebla, volumen, trajes
  desbloqueados, cámara libre…) y **Play**. Guarda en `private/launcher.json`.
- `./run_game.sh`: arranca directamente con las opciones guardadas.
- Añadir `launcher.sh` a Steam como juego no de Steam. Con un mando para dos
  puertos, desactivar Steam Input.

Docs del repo: `docs/building.md` (sección *Linux and SteamOS build*),
`docs/recomp-controls.md`.

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
- Si este juego necesitara paquetes extra, se crearía `games/doaxtreme/Dockerfile`
  con `FROM steamdeck-ports/ubuntu-build:24.04` y solo lo suyo.
