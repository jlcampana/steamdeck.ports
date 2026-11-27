# Rumble Roses XX Recomp (Xbox 360), Linux nativo — `rumble-roses-xx`

Recompilación estática del Rumble Roses XX de Xbox 360 con el ReXGlue SDK,
**compilada por nosotros como programa nativo de Linux**, sin Proton. El
port solo publica la versión de Windows (juego ya compilado + lanzador
.NET que copia la ISO) y su guía de build es de Windows, pero el código
del juego solo usa el SDK y la biblioteca estándar, y el proyecto trae
presets de CMake para Linux.

- Repo: https://github.com/360recomper/RumbleRosesReX (fork de
  wowjinxy/RumbleRosesReX)
- Release usada: el código de la última release (`@source` en
  `ports.tsv`; la release trae `RRXX-Recomp-v<x>.zip` de Windows). Versión
  al añadirlo: v1.5.0.3 («v1.5c»).
- SDK: [rexglue/rexglue-sdk](https://github.com/rexglue/rexglue-sdk)
  v0.10.0 (`c94f5eb`, el que dice `BUILDING.md`; el mismo que doax2-linux)
  + `sdk-patch/rexglue-sdk-v0.10-all-fixes.patch` del port (menú F4,
  partidas, mods, rutas portables `../saves` y `../mods`) + los nuestros
  (`patches/rexglue-sdk/`).
- ISO: `isos/RumbleRosesXX.iso` (`default.xex` con SHA-1
  `78c5df22…9ddf`, el que comprueba el lanzador en `launcher/Xgd.cs`).
- En la Deck: Linux nativo (`steamdeck.sh`), Vulkan.

**Renderizador:** el «nativo» del port (rrxx-native, desde v1.5c el de por
defecto en Windows) es **solo D3D12** y no se compila aquí. En Linux va el
renderizador emulado del SDK (Vulkan), que en Windows es el de reserva (el
log dice «rrxx native: not implemented, using the emulated renderer»). Es
el mismo que usan doax2-linux y lollipop-chainsaw.

## Build

```
games/rumble-roses-xx/build.sh [-f] [ruta.iso]
RRXX_JOBS=3 games/rumble-roses-xx/build.sh
```

Lo mismo que `BUILDING.md` (pasos 1 y 2, sin el renderizador nativo), en
el contenedor `rexglue-build` (Ubuntu 24.04, clang 20, el del preset
`linux-base` del port), con `-march=x86-64-v2`:

1. `latest/` → `work/src` (`rsync`, sin `out/`, `assets/` ni el código
   generado).
2. SDK clonado en `work/rexglue-sdk`, commit + parche del port + los
   nuestros; `cmake --preset linux-amd64` y `--target install`.
3. `work/src/assets` = el disco extraído (extract-xiso); se comprueba el
   SHA-1 del xex.
4. `cmake --preset linux-amd64-release -B out/game
   -DCMAKE_PREFIX_PATH=<SDK>`, `--target rumble_roses_xx_codegen` (el
   código generado sale del disco: no se publica), se comprueba que no
   queden llamadas sin resolver, reconfigurar y compilar.
5. `build/` con la estructura de la release: `game/` (`rumble_roses_xx`,
   `librexruntime.so`, `librexgpu-xenos.so`, `libTracyClient.so`,
   `assets/` con reflink y `RumbleRosesReX.toml`), `saves/`, `mods/`,
   licencias y `steamdeck.sh`. Todas las rutas del juego son relativas al
   ejecutable.

Primera vez: ~15 min en este PC (`-j 2`, con otro build a la vez).
`work/` (6,3 GB) se conserva. `build/` 3,7 GB, paquete 2,8 GB.

Parches nuestros del SDK (`patches/rexglue-sdk/`): los de doax2-linux
(fibras de POSIX, `shm_unlink` de la memoria del juego, RenderDoc solo si
ya está cargado). El de fibras y `/dev/shm` se rehízo con el contexto de
este SDK (el parche de DOAX2 cambia `fiber_posix.cpp`).

`0003-linux-espera-activa.patch` (2026-11-27): `WaitMultiple` del SDK
truncaba a milisegundos el tiempo restante y, en las esperas «alertables»
(tramos de 1 ms), dormía 0: el hilo `Audio Worker` gastaba un núcleo entero
desde el arranque, en el PC y en la Deck. En la Deck, con el límite de 15 W,
eso quita potencia a la GPU (estaba al 100 % a 260-950 MHz de 1600). Ahora
duerme el tiempo exacto (el mismo arreglo que trae el SDK de doax2-linux).

## Jugar

- **Instalar en la Deck:** `tools/package.sh rumble-roses-xx` y «Ports
  por red».
- **`steamdeck.sh`** → `deck-launch.sh`: primero el **menú de opciones**
  con mando (`tools/deck/opciones.py` + `opciones.json`; `MENU=0` en
  `opciones.conf` lo quita), que cambia `game/RumbleRosesReX.toml` como el
  menú del juego: resolución, brillo (`bloom`), desenfoque (`blur`),
  filtro (`anisotropic_override`), nitidez (`present_effect` CAS), fotos
  (`readback_resolve`) y trucos. Luego `game/rumble_roses_xx` desde la
  carpeta del juego. Sin lanzador: lo que hace el de Windows al instalar (copiar el
  disco a `game/assets`) ya lo hace `build.sh`.
- **Menú de ajustes dentro del juego:** **F4**, o **Back+Start** en el
  mando (resolución interna, bloom, desenfoque del fondo, filtrado,
  nitidez, mods, trucos). Se guarda en `game/RumbleRosesReX.toml`.
  `build.sh` lo crea con `resolution_scale = 1` (720p; la release trae 2).
  No hace falta menú propio.
- Partidas, DLC instalados y caché de shaders en `saves/`; mods en
  `mods/` (misma ruta que dentro del juego); logs en `game/logs/`. El
  instalador conserva `saves`, `mods` y el `.toml` (`KEEP`).
- DLC y trajes nuevos: los instala el lanzador de Windows (STFS →
  `saves/0000000000000000/4B4E07D1/00000002`); aquí no hay lanzador.
- Pruebas sin nadie delante: `--input_script=<archivo>` (mando simulado;
  formato en `src/input/input_system.cpp` del SDK parcheado: `pad 0` y
  líneas `<segundos> 0 <duración> START`) y `--rrxx_selftest_keys=F4@20`.

## Probado (2026-11-27, en el PC)

Desde otra ruta: `ldd` con las `.so` de `game/`, arranque con Vulkan (RX
6400), y con un guion de mando (Start y A cada 5 s) el juego responde y
carga escenas nuevas (decenas de pipelines nuevas tras cada pulsación).
Sin restos en `/dev/shm`. Instalador probado con un HOME falso (instalar y
reinstalar conservando `saves/` y el `.toml`). **Sin ver la imagen** (no
hay forma de capturar la ventana desde aquí) ni probar en la Deck.

## Imagen Ubuntu 24.04 (contenedor de build)

`games/rumble-roses-xx/Dockerfile` es un enlace a
`tools/docker/rexglue-build.Dockerfile` (clang 20 y 23…), la misma imagen
que doax2-linux y lollipop-chainsaw.
