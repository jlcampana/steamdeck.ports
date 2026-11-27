# Tekken 6 Recomp (Xbox 360), Linux nativo — `tekken6`

Recompilación estática del Tekken 6 de Xbox 360 con el ReXGlue SDK,
**compilada por nosotros como programa nativo de Linux** (Vulkan), sin
Proton. La release del port solo trae el builder de Windows (y uno de
macOS), pero el repo tiene una versión Linux con su propio script de build
(`tools/build_linux.sh`) y su lanzador (`tools/run_linux.sh`).

- Repo: https://github.com/mahmoud-mess/tekken6-recomp
- Versión usada: **la rama `main`** (`@branch:main` en `ports.tsv`). La
  última release («Iterate», 0.9.4, 2026-10-16) es anterior a la versión
  Linux, que está en `main` (28 commits más, «Prepare Linux beta release»).
  `update.sh` baja el último commit de `main` y la versión es
  `main-<sha>` (al añadirlo: `main-e561781`).
- SDK: [rexglue/rexglue-sdk](https://github.com/rexglue/rexglue-sdk) en el
  commit que fija el port (`BASE_REVISION` de
  `tools/apply_rexglue_patches.py`: `0c7b01a`) + su parche
  (`patches/rexglue/0001-tekken6-runtime.patch`) + los nuestros
  (`patches/rexglue-sdk/`).
- ISO: `isos/Tekken6.iso`, Europa/USA Rev 1 (`Default.xex` con SHA-256
  `ee138a4f…7f15c`, el que comprueba `tools/build_linux.sh`).
- En la Deck: Linux nativo (`steamdeck.sh`), Vulkan.

## Build

```
games/tekken6/build.sh [-f] [ruta.iso]
TEKKEN6_JOBS=3 games/tekken6/build.sh
```

Lo mismo que `tools/build_linux.sh`, en el contenedor
`steamdeck-ports/tekken6:24.04` (`Dockerfile`: `rexglue-build` + clang 19
y lld 19, los que pide el README del port):

1. `latest/` → `work/src` (`rsync`, sin `build/`, `game/`, el SDK ni el
   código generado).
2. SDK clonado en `work/src/third_party/rexglue-sdk` (en el tarball el
   submódulo viene vacío), en `BASE_REVISION`, con el parche del port
   (`apply_rexglue_patches.py`) y los nuestros. Se rehace si cambia alguno.
3. `work/src/game` = el disco extraído (extract-xiso); se comprueba el xex.
4. `cmake` con clang 19, Vulkan, sin D3D12, `TEKKEN6_ENABLE_FMA3=ON` (la
   CPU de la Deck, Zen 2, tiene FMA3; el script del port lo decide según la
   CPU del PC); targets `rexglue rexruntime rexgpu-xenos`, luego
   `tekken6_codegen`, reconfigurar y `tekken6`.
5. `build/` como el «app folder» de `tools/package_linux.py`: `bin/`
   (`tekken6`, `librexruntime.so`, `librexgpu-xenos.so`),
   `tools/run_linux.sh`, `game/` (con reflink) y `steamdeck.sh`.

Primera vez: ~20 min en este PC (`-j 2`, con otro build a la vez).
`work/` (9,5 GB) se conserva. `build/` 6,7 GB, paquete 6,6 GB.

Parches nuestros del SDK (`patches/rexglue-sdk/`): los mismos que
doax2-linux y rumble-roses-xx. `Fiber::Destroy` de POSIX solo borra la
fibra actual si es la suya. La memoria del juego se desvincula de
`/dev/shm` nada más crearla: **sin él, cada partida dejaba un
`/dev/shm/xenia_memory_*` de 4,8 GB** (comprobado: tres arranques, tres
archivos). RenderDoc solo se engancha si ya está cargado (SteamOS trae
`librenderdoc.so`).

## Jugar

- **Instalar en la Deck:** `tools/package.sh tekken6` y «Ports por red».
- **`steamdeck.sh`** → `deck-launch.sh`: primero el **menú de opciones**
  (`tools/deck/opciones.py` + `opciones.json`; mando, teclado o pantalla
  táctil), que guarda en `opciones.conf` (el instalador lo conserva):
  - `ESCALA` 1/2/3 → `--resolution_scale` del SDK (×2 = 2048×1152, que se
    muestra a 720p: más nítido). La resolución de la consola es 1024×576
    y la opción `--res` del port solo **baja** (768×432, 640×360).
  - `RES` → `--res` del port; `OFFSCREEN` 512 → `--offscreen 512`.
  - `ANISO` → `--anisotropic_override` (0 = no, como el port; 3 = 4x, el
    nuestro por defecto).
  - **En la Deck, ×1** (2026-11-27): con ×2 va a 30 FPS (la GPU al 100 %
    a 1600 MHz, su máximo, y 15 W). ×1 con 4x de filtro va a
    60 FPS (prueba del usuario).
  - `MENU=0` lo quita (para volver, `MENU=1` en `opciones.conf`).

  Luego `tools/run_linux.sh --build-dir bin --fullscreen` (el `cd` y las
  opciones del runtime son las del port: reloj de 60 Hz, FIFO,
  `--execute_unclipped_draw_vs_on_cpu`…). Lo que se ponga en Steam
  (Opciones de lanzamiento) va detrás y manda: `%command% --log`, y las
  del juego tras `--` (`%command% -- --resolution_scale=2`). Con opciones
  repetidas, el SDK (CLI11) se queda con la última (comprobado).
- **F3** muestra los FPS. Mando por SDL3; teclas en el README del port.
- Partidas y ajustes en `user/`, shaders en `cache/linux-fbo/`. El
  instalador conserva las dos al reinstalar (`KEEP`).
- No hay online. El nombre del jugador es el de la cuenta de Linux.
- Medir el rendimiento: `TEKKEN6_GPU_PROFILE=<archivo.csv>` y
  `python3 latest/tools/analyze_gpu_profile.py <archivo.csv>`.

## Probado (2026-11-27, en el PC)

Desde otra ruta: `ldd` con las `.so` de `bin/`, arranque con Vulkan (RX
6400), y con `TEKKEN6_GPU_PROFILE` 3.517 fotogramas en 60 s: **60 FPS**
estables (intro y demo, sin tocar nada). Instalador probado con un HOME
falso (instalar y reinstalar conservando `user/`). Sin probar en la Deck
ni jugado (no hay forma de ver la ventana desde aquí).

## Imagen Ubuntu 24.04 (contenedor de build)

`games/tekken6/Dockerfile`: `FROM steamdeck-ports/rexglue-build:24.04`
(`tools/docker/rexglue-build.Dockerfile`) + `clang-19`, `lld-19` y `nasm`.
`run_in_container` construye las dos imágenes.
