# Dead or Alive Xtreme 2 Recomp, Linux nativo — `doax2-linux`

Segunda variante de [`doax2`](../doax2/README.md): el mismo port,
**compilado por nosotros como programa nativo de Linux**, sin Proton. El
port solo publica la versión de Windows y su guía de build es solo para
Windows (PowerShell + Visual Studio), pero el código protege lo de Windows
con `#if defined(_WIN32)`, ya compila para Android y tanto el proyecto como
el SDK traen presets de CMake para Linux.

- Repo: https://github.com/hibikifukui22/Dead-or-Alive-Xtreme-2-Recompilation
- Release usada: `DOAX2-Recomp-v<x.y.z>-source.zip` (código + SDK; regex
  `-source\.zip$` en `ports.tsv`). Versión al añadirlo: v1.2.2.
- SDK: [rexglue/rexglue-sdk](https://github.com/rexglue/rexglue-sdk) v0.10.0
  en el commit del submódulo de esa etiqueta (`build.sh` lo pregunta a la
  API de GitHub; v1.2.2 → `c94f5eb`) +
  `patches/rexglue-sdk/0001-doax2-runtime-changes.patch`. No se usa el SDK
  que trae el zip: mezcla finales de línea CRLF/LF y el parche no se puede
  comprobar sobre él.
- ISO: la misma que `doax2`, `isos/DOAX2.iso` (`default.xex` con SHA-256
  `c4a14853…992870`). Si `games/doax2/build` ya tiene el juego extraído, se
  copia de ahí (reflink).

## doax2 o doax2-linux

| | `doax2` (Proton) | `doax2-linux` |
|---|---|---|
| Binario | release oficial de Windows | compilado aquí (no oficial) |
| En la Deck | Proton forzado | nativo (`steamdeck.sh`) |
| Lanzador | el del port (30/60 FPS, renderizador…) | ninguno: opciones por variables de entorno |
| Renderizador | el que elijas | Vulkan (Native) |
| Build | ~40 s | ~18 min la primera vez |

## Build

```
games/doax2-linux/build.sh            # isos/DOAX2.iso
DOAX2_JOBS=3 games/doax2-linux/build.sh
```

Hace lo mismo que los scripts del port (`setup-sdk.ps1`, `build-sdk.ps1`,
`generate-code.ps1`, `configure-game.ps1`), en el contenedor
`steamdeck-ports/doax2-linux:24.04` (`Dockerfile` = enlace a
`tools/docker/rexglue-build.Dockerfile`, clang 23, compartido con
doa4-linux), con `-march=x86-64-v2`:

1. `latest/` → `work/src` (`rsync`, sin `sdk/`, `out/`, `generated/`, `game/`).
2. SDK clonado en `work/rexglue-sdk`, commit + parche (se rehace si cambia
   alguno de los dos); `cmake --preset linux-amd64` y `--target install`
   (`out/install/linux-amd64`).
3. `work/src/game` = el disco extraído; se comprueba el SHA-256 del xex.
4. `rexglue codegen doax2_manifest.toml --ignore-stamp` → `generated/`
   (249 archivos; el código generado sale del disco y no se publica) y se
   comprueba que no queden llamadas sin resolver.
5. `cmake --preset linux-amd64-release -B out/game -DCMAKE_PREFIX_PATH=<SDK>`
   y `cmake --build out/game --config Release`.
6. `build/`: `doax2`, `librexruntime.so`, `librexgpu-xenos.so`,
   `libTracyClient.so` (RUNPATH `$ORIGIN`), licencias y `game/`.

Primera vez: ~18 min en este PC (`-j 2`). `work/` (en `.gitignore`) se
conserva: si se corta, sigue donde iba. Build 6,3 GB, paquete 2,9 GB.

## Jugar

`steamdeck.sh` se genera con `write_steamdeck_launcher` y el final de
`launch-options.sh`: las ~50 opciones que pasa el lanzador de Windows
(`src/launcher_public.cpp`, `Launch()`) con sus valores por defecto, salvo
`--gpu_backend=vulkan` (Vulkan (Native)), `--fullscreen=true` y sin las
opciones solo de D3D12. Variables para cambiarlas: `DOAX2_FPS` (60/30),
`DOAX2_FULLSCREEN`, `DOAX2_WIDTH`/`DOAX2_HEIGHT` (1280x720), `DOAX2_SCALE`,
`DOAX2_SHADOWS`, `DOAX2_FPS_OVERLAY`. En Steam: Opciones de lanzamiento,
p. ej. `DOAX2_FPS=30 %command%`.

- Partidas: `userdata/`; fotos: `photos/`; logs: `logs/`. `KEEP` conserva
  `userdata` y `photos`.
- Se cierra con SIGTERM (lo que hace Steam); SIGINT no le hace nada.
- En Steam: «Dead or Alive Xtreme 2 (Linux)», con las imágenes de `doax2`.

## Probado en el PC (2026-11-26, v1.2.2)

- `ldd` desde otra ruta: sus `.so` salen de la carpeta del juego; del
  sistema solo libc, libm, libstdc++, libgcc_s (SDL3 va dentro de
  `librexruntime.so`; Vulkan con `dlopen`).
- 4 arranques (RX 6400, RADV, Wayland): llega al título y va a 60 FPS
  estables cada vez. A diferencia de doa4-linux, no se ha congelado en este
  PC de 4 núcleos. Solo se ha probado hasta el título (sin jugar).
- Instalador probado con HOME falso.
- **Se cuelga al pulsar Start en el título** (2026-11-26, el usuario desde
  Steam y fuera de Steam, 5 de 5). Llega al título a 60 FPS, pero al pulsar
  Start lee la partida (`upsdrive0:`, `ups.dat`), la cierra y deja de
  sacar fotogramas («tick timeouts 100» en el log). Ya no hace ninguna
  llamada al kernel. El hilo principal del juego se queda al 100 % cambiando
  de fibra (`SwitchToFiber`, `swapcontext`) y dos hilos del juego siguen
  ocupados. Descartado: la afinidad de los hilos (repartir los 6 núcleos de
  la 360 entre las 4 CPU no lo cambia) y el parche del port (no toca las
  fibras de Linux), el compilador (igual con clang 20 que con clang 23)
  y el modo de 60 FPS (igual con `DOAX2_FPS=30`). Tampoco son las opciones:
  son las del lanzador de Windows salvo las de D3D12. **A `doax2` (Proton)
  no le pasa** en el mismo PC, así que es algo del build de Linux (SDK o
  código del port fuera de `#if defined(_WIN32)`, que solo está en
  `src/doax2_60fps.cpp` y no toca esto). Sin arreglo: usar `doax2`.
  Incidencia #23 del port; detalles e ideas en
  [`debug-cuelgue-start.md`](debug-cuelgue-start.md).

## Imagen Ubuntu 24.04 (contenedor de build)

`games/doax2-linux/Dockerfile` es un enlace a
`tools/docker/rexglue-build.Dockerfile` (`FROM
steamdeck-ports/ubuntu-build:24.04` + clang 23 de apt.llvm.org y
bibliotecas de desarrollo), la misma de doa4-linux. El preset del SDK pide
`clang-20`; se le pasa `clang-23` y compila sin problemas.
