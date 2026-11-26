# Dead or Alive 4 Online, Linux nativo — `doa4-linux`

Segunda variante de [`doa4`](../doa4/README.md): el mismo port, pero
**compilado por nosotros como programa nativo de Linux**, sin Proton.

- Repo: https://github.com/dwreckgg/doa4-online (recompilación estática con el
  ReXGlue SDK, fork [Dwreckgg/rexglue-sdk](https://github.com/Dwreckgg/rexglue-sdk))
- Release usada: **el código fuente** de la última release (`@source` en
  `ports.tsv`; solo hay prereleases `alpha-v…`, así que `update.sh` coge la
  más reciente). Versión al añadirlo: alpha-v0.3.8 (la primera que compila en
  Linux, gracias a rynoster).
- ISO: la misma que `doa4`, `isos/DOA4.iso` (Rev 1, `default.xex` con SHA-1
  `af8011945037b37c98fb8a78d5a4e844dd56c33f`). Si `games/doa4/build/game` ya
  tiene el juego extraído, se copia de ahí (en btrfs, sin gastar espacio).

## doa4 o doa4-linux

| | `doa4` (Proton) | `doa4-linux` |
|---|---|---|
| Binario | release oficial de Windows | compilado aquí |
| En la Deck | Proton forzado | nativo (`steamdeck.sh`) |
| Online | con todos los de la misma release | **solo con este mismo build** (se identifica como `dev`) |
| Probado upstream | sí | el CI compila y pasa tests, pero no arranca el juego |
| Build | ~45 s | ~40 min la primera vez (6,8 GB; paquete 4,8 GB) |

## Build

```
games/doa4-linux/build.sh            # isos/DOA4.iso
DOA4_JOBS=3 games/doa4-linux/build.sh   # más procesos (más RAM)
```

Sigue `docs/BUILDING.md` (sección 12) y el job `linux-build.yml` del port:

1. `latest/` (el código) → `work/src` con `rsync` (conserva fechas: entre
   versiones ninja solo recompila lo que cambie).
2. El SDK se clona en `work/rexglue-sdk` y se pone en el commit de
   `netplay_sdk.txt`, con sus submódulos.
3. En el contenedor `steamdeck-ports/doa4-linux:24.04` (`Dockerfile` de esta
   carpeta, `FROM` de la imagen común): `cmake --preset linux-amd64-release`
   con clang 23 y `-march=x86-64-v2`, y `cmake --build … -j $DOA4_JOBS`
   (2 por defecto: los archivos grandes del código recompilado piden varios
   GB de RAM cada uno). La primera vez, ~40 min en este PC (4 núcleos,
   15 GB); upstream da hasta 4 h en su CI. `work/` ocupa 2,1 GB.
4. `build/` lleva solo `dead_or_alive_4`, `librexruntime.so` (RUNPATH
   `$ORIGIN`: tienen que ir juntos), las licencias y `game/`.

`work/` (código, SDK y objetos) está en `.gitignore` y se conserva; si se
corta el build, la siguiente vez sigue donde iba. Borrarlo obliga a
recompilar todo.

## Jugar

- `steamdeck.sh` lanza `dead_or_alive_4 --game_data_root=<carpeta>/game
  --user_data_root=<carpeta>/user_data` (rutas de la instalación, calculadas
  al arrancar): no sale la pantalla de configuración ni hace falta
  `post-install.sh`.
- Ajustes: `dead_or_alive_4.toml` y `logs/` junto al ejecutable.
- Instalar: `tools/package.sh doa4-linux` y el instalador, como los demás.
  En Steam sale como «Dead or Alive 4 (Linux)», con las mismas imágenes que
  `doa4`. Notas del paquete: `deck-notes.md`.

## Bañadores de DOAX2

Los genera `doax2-suits.sh` y van en el paquete (también en el de `doa4`):
ver [doa4](../doa4/README.md#bañadores-de-doax2).

## Probado en el PC (2026-11-25, alpha-v0.3.8)

- `ldd` desde otra ruta: `librexruntime.so` y `libTracyClient.so` salen de
  la carpeta del juego (RUNPATH `$ORIGIN`); el resto es del sistema (glibc
  ≥ 2.38, GLIBCXX ≥ 3.4.32, X11/xcb/wayland; SDL3 va dentro de
  `librexruntime.so`). Vulkan y el audio se abren con `dlopen`.
- Arranca con Vulkan (RADV, RX 6400): vídeo de intro, título, «PRESS START»
  y la demo, a 60 fps.
- **Congelaciones al arrancar en este PC:** 2 de cada 5 arranques se quedan
  parados (antes del vídeo o justo después; el log repite `FREEZE: no fiber
  progress`); con `taskset -c 0,1` (2 núcleos), 4 de 4. El SDK solo fija
  cada hilo del juego a un núcleo (como en la Xbox 360) si hay **6 o más
  procesadores lógicos** (`src/system/xthread.cpp`, `SetActiveCpu`: «Too few
  processor cores - scheduling will be wonky»); este PC tiene 4. La Deck
  tiene 8, como los equipos donde upstream lo probó sin problemas (también
  una Deck). La versión de Windows con Proton no se congela en este PC.
- **En la Deck funciona bien** (prueba del usuario, 2026-11-26).

## Imagen Ubuntu 24.04 (contenedor de build)

`games/doa4-linux/Dockerfile` (enlace a `tools/docker/rexglue-build.Dockerfile`, compartido con doax2-linux) hace `FROM steamdeck-ports/ubuntu-build:24.04`
y añade clang 23 (de apt.llvm.org, con su `llvm.sh`), `libstdc++-14-dev`
(`<print>`), GTK 3, x11-xcb, ibus, drm/gbm y `glslc`/`glslang-tools`.
`run_in_container` (`tools/lib.sh`) construye las dos imágenes.
