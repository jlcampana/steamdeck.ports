# Hyrule Warriors: Definitive Edition (Switch) — `hyrule-warriors`

- Repo: https://github.com/blocker-3/HWDER (HWDER, recompilación estática
  del juego de Switch)
- Release usada: `HWDER-linux-x86_64-<v>.tar.gz` (Setup de Linux: código
  del port y dependencias; **no trae el juego compilado**). No hay archivo
  aparte para la Deck: el Setup de Linux está pensado para SteamOS y
  Bazzite, pero compila en la máquina del jugador.
- Versión probada al descargar: v0.3.6
- Datos: `isos/HyruleWarriors/` (el `.nsp` base, la update 1.0.1 en `.nsp`,
  `prod.keys` y `title.keys` de la Switch del usuario)
- En la Deck: Linux nativo

## Contenido de la release

`hwder-setup` (abre `setup/hwder-setup-ui`, ventana SDL3 + ImGui, o
`tools/linux_setup.py` con `--cli`), el código del port (`runtime/`,
`tools/`, `third_party/`), `linux-deps/` (SDL3, FFmpeg solo H.264 y
libcrypto de OpenSSL, estáticos, con licencias y código de FFmpeg) y
`release.json` (SHA-256 de cada archivo).

El Setup (`linux_setup.py prepare`) copia la release a
`$XDG_DATA_HOME/HWDER/app`, descarga una vez sus herramientas
(`tools/linux/toolchain.json`: Zig 0.15.2 con su Clang 20, CMake, Ninja,
Python 3.13 y unas ruedas; ~156 MB, cada una con su SHA-256), comprueba el
`.nsp` y las claves, saca el ExeFS, traduce el código a C y compila
`build/play/hwder`, que solo necesita `libc`, `libm` y el cargador de
Vulkan (`dlopen`). No usa nada del sistema ni contenedor.

## Datos del juego

- El `.nsp` del juego **base** (sin la update integrada) y, opcional, la
  update 1.0.1 (`.nsp` o `.nsz`). El Setup comprueba título y versión.
- `prod.keys` de la misma consola (y `title.keys`, opcional).
- **El juego los lee en cada arranque**: el `.nsp` (RomFS), las claves y la
  update descomprimida. Por eso van **dentro del paquete** (`game/base.nsp`,
  `keys/`, `update/`); el paquete lleva tus claves: no se comparte.
- La update se descomprime en la caché del build (ExeFS `main` y el parche
  del RomFS, unos MB); el juego se compila desde su `main`.

## Build

```
games/hyrule-warriors/build.sh [-f] [nsp [keys [update]]]
```

Ejecuta `tools/linux_setup.py prepare` de la release con
`XDG_DATA_HOME=games/hyrule-warriors/work` (herramientas, caché de
compilación y `prepare.log`; fuera de git, se conserva entre builds) y
luego deja en `build/` solo lo que hace falta para jugar: `hwder`,
`hwder_settings.ini` (ajustes iniciales, sin rutas), `game/base.nsp`
(copia del `.nsp`), `keys/`, `update/`, `save/`, `mods/`,
`deck-launch.sh`, `LICENSE` y las licencias de `linux-deps/`.

## Jugar

- **Instalar en la Deck:** `tools/package.sh hyrule-warriors` y «Ports por
  red» (o doble clic en `Instalar <Nombre>.desktop`).
- **Usar `steamdeck.sh`**, sin Proton. Lanza `deck-launch.sh`, que pone en
  `hwder_settings.ini` las rutas de **esta** instalación (`nsp_path`,
  `keys_path`, `update_path`, `save_dir`, `mods_dir`; el juego las guarda
  absolutas) y arranca `hwder`. Sin `save_dir`, las partidas irían a
  `~/.local/share/HWDER/save`.
- **Menú de opciones dentro del juego** (F1, o mantener View/Select):
  resolución (0,5x-3x de 1080p), 120 FPS experimental, FXAA, filtrado,
  mandos (reasignar, zonas muertas, giroscopio), mods, partidas. No hace
  falta lanzador propio.
- Partidas en `save/`, ajustes en `hwder_settings.ini`, mods en `mods/` y
  cachés de shaders `pipeline_cache.bin`/`pipeline_warmup.bin` junto a
  `hwder`: el instalador los conserva al reinstalar (`KEEP`).
- Log: `hwder.log` junto a `hwder` (se rehace en cada arranque).

## Imagen Ubuntu 24.04 (contenedor de build)

No se usa: el Setup del port trae sus propias herramientas (Zig/Clang
enlazando contra glibc 2.35) y se ejecuta directamente en el PC.
