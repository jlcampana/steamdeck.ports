# Bayonetta 3 (Switch), B3-Express, Linux nativo — `bayonetta3`

Bayonetta 3 v1.2.0 recompilado con **ScarletNX** (recompilador estático de
Switch: el código ARM64 pasa por LLVM a un módulo nativo, y su runtime hace
de sistema y de GPU sobre Vulkan). B3-Express solo publica un lanzador de
Windows que compila el juego en el PC del jugador; ScarletNX compila en
Linux, así que aquí se hace lo mismo que el lanzador, sin él.

- Repo: https://github.com/LuvAbyss/B3-Express
- Release usada: el código de la última release (`@source` en `ports.tsv`;
  la release solo trae el zip de Windows). Al añadirlo: 0.4.0.
- `source/`: ScarletNX en el commit `5c97949` con los cambios de B3-Express
  (60 FPS en cinemáticas, panorámico, detalle de modelos, cámara con ratón:
  `src/nx/hle/{scene60,aspect,model_lod,mouse_look}.c`).
- En la Deck: Linux nativo (`steamdeck.sh`), Vulkan.

## Datos del juego

`isos/Bayonetta 3/`: el `.xci` (`[01004A4010FEA000][v0]`) y la update
`[01004A4010FEA800][v131072]`. **Esa update es la 1.2.0** aunque el nombre
de uno de los archivos diga 1.1.0: trae dos programas, el juego
(`…FEA000`, `control.nacp` 1.2.0) y otro (`…FEA001`, 1.1.0). Los dos
`.nsp` de update de la carpeta tienen los mismos `.nca`. El `exefs/` y los
552 archivos de la romfs coinciden con `game-files.txt` del port (tamaño y
SHA-256 de los 557).

`tools/switch-dump.sh` (hactool y las claves del usuario, como Bayonetta
2) saca `exefs/`, la romfs con la update y `control/`. El `.xci` es un
**`.xci` convertido de `.nsp`**: el hash de su partición raíz no coincide
y las particiones `update`/`normal` son de relleno, así que hactool lo
rechaza («XCI partition is corrupt»; el hactool de ScarletNX también).
`switch-dump.sh` lee él mismo las cabeceras HFS0 y saca los `.nca` de la
partición `secure`. La update trae dos `Program`: se usa el del Title ID
del juego.

Las claves no van en el paquete; la romfs y el código traducido, sí (salen
del juego del usuario: no compartir el paquete).

## Build

```
games/bayonetta3/build.sh [-f] [carpeta]
BAYONETTA3_TMP=/otro/disco BAYONETTA3_JOBS=4 games/bayonetta3/build.sh
```

1. Dump → `work/dump` (~7 min; 15 GB; los `.nca` intermedios, ~17 GB, en
   `BAYONETTA3_TMP`). Se comprueba contra `game-files.txt` (solo avisa).
2. `source/` → `work/src` (repo git, commit `base` = original) +
   `patches/source/*.patch`, y ScarletNX en el contenedor
   (`games/bayonetta3/Dockerfile`: `rexglue-build`, con clang 23, + LLVM 23
   de desarrollo, NASM, Perl, `patch`, `wayland-protocols`; SDL3, FFmpeg,
   OpenSSL y hactool los compila CMake con sus SHA-256). Opciones:
   - `llvm-config-static` (`llvm-config-23 --link-static`) y
     `-Wl,--as-needed`: el runtime lleva LLVM dentro. Con la `libLLVM-23`
     compartida no arrancaría en SteamOS, y `llvm-config` añade `libz3` y
     `libxml2.so.2`, que no usa. Queda: libc, libm, libstdc++, libgcc_s,
     zlib, zstd. `build.sh` lo comprueba.
   - Sin tests (`snx-test-scene60-counters`, de B3-Express, no enlaza
     `libm` en Linux), ni 3DS, ni el runtime de AArch64, ni el menú SDL3.
   - Nuestro parche: `0001-linux-stdlib.patch` (a `shadow.c` le falta
     `<stdlib.h>`; en Windows llega por otras cabeceras).
3. `scarletnx -r` como `build_code()` del lanzador: entrada con solo
   `exefs/`, nombre `Bayo3_120`, `-O 1`, `--cache code_cache` (bloques ya
   compilados: repetir tarda segundos) y sus listas de direcciones de la
   1.2.0 (`code-hints.txt`, `code-tablecalls.txt`, `code-insnhooks.txt`).
   Con **`SNX_RECOMPILE_PORTABLE=1`**: código para cualquier x86-64-v3 con
   AES y PCLMUL (la Deck), no para la CPU de este PC (el lanzador lo quita).
   107.997 funciones, 83 bloques, módulo de 275 MB.
4. `build/Bayo3_120/`: runtime, `Bayo3_120_code.so`, listas, `.ini` con
   ajustes para la Deck, `Bayo3_120_data/` (exefs, romfs por reflink,
   `control.nacp`) y `deck-launch.sh`.

Primera vez (4 núcleos): ScarletNX ~25 min, el código del juego 12,5 min.
`work/` ~17 GB (dump 15 GB), `build/` 15 GB (la romfs es un reflink) y el
paquete 15 GB (5,5 min; la romfs ya viene comprimida).

## Jugar

- **Instalar en la Deck:** `tools/package.sh bayonetta3` y «Ports por red».
- **Usar `steamdeck.sh`**, sin Proton → `deck-launch.sh`: lo que hace Play
  en el lanzador, `Bayo3_120/Bayo3_120 --game=Bayo3_120` con
  `SNX_NVN_FRONTEND=2 SNX_NVN_RELEASE_ONLY=1` (el renderizador rápido).
- **Menú de opciones** (con mando, antes de jugar): `tools/deck/opciones.py`
  con `opciones.json` (modo TV/portátil, resolución, FSR, sombras,
  filtro, difuminado, forma de la imagen, cinemáticas a 60, grano,
  VSync, idioma). Escribe en `Bayo3_120.ini`; no sale con `MENU=0` en
  `opciones.conf`.
- **Más opciones:** el menú del propio ScarletNX, con el mando (F2, o Home; en
  la Deck hay que asignar F2 a un botón). F1 ayuda, F3 captura, F4 límite
  de FPS, F11 pantalla completa. El `.ini` (`Bayo3_120/Bayo3_120.ini`)
  tiene el resto; el lanzador de Windows solo cambia valores de ese
  archivo. Para la Deck (`build.sh`, si no hay `.ini`): `fullscreen = 1`,
  `resolution = 1` y `fsr = 0` («Smooth 60», la escena al tamaño de la
  consola) y `dither = 3` (difuminado transparente, el recomendado), y `language = 5`
  (español; ScarletNX pone inglés).
- Todo queda en `Bayo3_120/`: partidas (`Bayo3_120_data/save/`), log,
  `shader_cache/`, `threads.txt`. El instalador conserva partidas, `.ini`,
  caché de shaders y `mods/` (`KEEP`).
- Pruebas sin nadie: `steamdeck.sh --seconds=90 --shot=<archivo>` (deja
  `<archivo>.ppm` y sale; `frames=` al final de la salida).

## Probado (2026-11-27, en el PC)

Desde otra ruta (copia con reflink): `ldd` (solo librerías del sistema),
romfs de la nueva ruta (557 archivos), y llega a la pantalla de título
(«PRESS ANY BUTTON», versión 1.2.0) con Vulkan. **Muy lento en este PC:**
~3,5 FPS con la caché de shaders hecha. El log (`nvn-live: frame N took…`)
pone casi todo el tiempo en dibujar (`windows` 300-500 ms por fotograma):
la GPU de este PC (RX 6400, PCIe x4) con más de 2 GB de memoria del juego
importada. Hay que medirlo en la Deck (memoria unificada). Instalador
probado con HOME falso.

## En la Deck (2026-11-27)

Prueba del usuario, con la Deck en un monitor externo (1080p a 120 Hz) y
`docked=1`, `fsr=2` en el `.ini`. Del log (`Bayo3_120/Bayo3_120.log`,
líneas `nvn-live: frame times`, cada 600 fotogramas):

- Jugando: **~20 FPS** (mediana 50 ms). Por fotograma, ~29 ms de GPU
  (`GPU time of the host's windows`) y ~31 ms de CPU preparando los dibujos
  (`recording … draw setup`): las dos cosas a la vez.
- Vídeos: ~35 FPS (los descodifica el runtime: `host1x: VIC` ~26 ms cada uno).
- El juego sale bien (`Exit.` en el log). Lo que se queda congelado es
  la pantalla: justo después, gamescope falla al cambiar de modo en el
  monitor externo (`xwm: Failed to prepare 1-layer flip`) y vuelve a
  elegir el conector.
- Por probar: modo portátil (`docked=0`, menos resolución) y sin el monitor.

## Imagen Ubuntu 24.04 (contenedor de build)

`games/bayonetta3/Dockerfile` (`FROM steamdeck-ports/rexglue-build:24.04`).
`run_in_container` construye antes `rexglue-build` desde
`tools/docker/rexglue-build.Dockerfile` (las capas son las de doa4-linux y
doax2-linux: no ocupa más).
