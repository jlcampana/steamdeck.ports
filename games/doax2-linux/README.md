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
`tools/docker/rexglue-build.Dockerfile`, clang 20 como pide el preset
del port, compartido con doa4-linux), con `-march=x86-64-v2`:

1. `latest/` → `work/src` (`rsync`, sin `sdk/`, `out/`, `generated/`, `game/`).
2. SDK clonado en `work/rexglue-sdk`, commit + parche del port + los
   nuestros de `patches/rexglue-sdk/` (se rehace si cambia alguno);
   `cmake --preset linux-amd64` y `--target install`
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
opciones solo de D3D12. Teclas: las del lanzador (`--keybind_*`: Enter = Start,
Espacio = A, Retroceso = B, WASD = stick izquierdo, flechas = cruceta…). Variables para cambiarlas: `DOAX2_FPS` (60/30),
`DOAX2_FULLSCREEN`, `DOAX2_WIDTH`/`DOAX2_HEIGHT` (1280x720), `DOAX2_SCALE`,
`DOAX2_SHADOWS`, `DOAX2_FPS_OVERLAY`, y las de gráficos del lanzador:
`DOAX2_MSAA` (`native`, `emulated`, `off`), `DOAX2_AA` (FXAA: 0, 1, 2) y
`DOAX2_ANISO` (-1…5; 3 = 4x). En Steam: Opciones de lanzamiento,
p. ej. `DOAX2_FPS=30 %command%`.

**No hay menú de gráficos dentro del juego:** en Windows se eligen en el
lanzador, y las teclas F5–F9 del port usan `GetAsyncKeyState` (solo
Windows). En la Deck (2026-11-26) va a 60 FPS de motor pero pinta unos
40 fotogramas/s (unos 25 ms por fotograma en la GPU). Para aligerarlo:
`DOAX2_MSAA=off DOAX2_AA=1 %command%`, luego `DOAX2_SHADOWS=0` o
`DOAX2_FPS=30`.

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
- **Se colgaba al pulsar Start en el título** (2026-11-26, 5 de 5; a
  `doax2` con Proton no le pasaba). **Resuelto** con un parche nuestro del
  SDK (`patches/rexglue-sdk/0001-linux-fibras-y-shm.patch`): al terminar el
  hilo que lee la partida, el SDK dejaba a nulo la fibra actual del hilo
  principal (`Fiber::Destroy` de POSIX) y este se quedaba en un bucle de
  `SIGSEGV` dentro de `swapcontext`. Ahora pasa del título, carga y guarda
  la partida y entra en el juego (probado con un mando virtual). Detalles
  en [`debug-cuelgue-start.md`](debug-cuelgue-start.md); incidencia #23 del
  port.
- El mismo parche evita que cada partida deje 4,8 GB en `/dev/shm`
  (`xenia_memory_*`, en RAM hasta reiniciar): el SDK solo los borraba al
  salir de forma ordenada, y el juego nunca sale así.

## Imagen Ubuntu 24.04 (contenedor de build)

`games/doax2-linux/Dockerfile` es un enlace a
`tools/docker/rexglue-build.Dockerfile` (`FROM
steamdeck-ports/ubuntu-build:24.04` + clang 20 y clang 23 de apt.llvm.org y
bibliotecas de desarrollo), la misma de doa4-linux. doax2-linux usa
clang 20, el que pide el preset del SDK (`DOAX2_CLANG=23` para probar el
otro; al cambiar de compilador se borran las carpetas de CMake).
