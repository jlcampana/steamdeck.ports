# doax2-linux: cuelgue al pulsar Start (notas para retomar la depuración)

Estado el 2026-11-26 (v1.2.2, SDK `c94f5eb` + parche del port). Incidencia
abierta en el port:
https://github.com/hibikifukui22/Dead-or-Alive-Xtreme-2-Recompilation/issues/23
(mirar si hay respuesta antes de seguir).

## Síntoma

- Llega al título a 60 FPS (Vulkan). Al pulsar Start se congela siempre
  (5 de 5, desde Steam y fuera). La ventana sigue viva y la interfaz pinta;
  el juego deja de entregar fotogramas: en el log, `DOAX2 UI paints: 20/s
  ... tick timeouts 100` desde ese momento.
- `doax2` (la release de Windows con Proton) **no** se cuelga en el mismo PC.

## Qué dice el log (`--log_level=trace --log_max_file_size_mb=2000`)

Justo tras Start: `XamNotifyCreateListener`, `XamContentCreateEnumerator:
added 1 items`, dos `CompleteOverlappedDeferredEx` que acaban en
`00000000`, `NtResumeThread` de un hilo nuevo, ese hilo resuelve
`upsdrive0:\` (la partida, `userdata/.../544307D2/00000001/ups.dat`) y
`Unregistered symbolic link: upsdrive0:`. Después **ninguna llamada al
kernel más**. Los fallos de `cache:\` y `D:\DOAX2\` salen igual en Proton.

## Pilas (eu-stack; con el juego lanzado fuera de Steam: dentro del Flatpak no deja)

- Hilo principal del juego (`Main XThread`, 100 % CPU): `swapcontext` <-
  `SwitchToFiber_entry` <- `sub_82783210` <- `sub_8250A0B8` <-
  `sub_8258CD28` (`FiberEntryPoint`). Bucle de fibras del motor.
- Dos hilos del juego al ~15 %: `sub_82717B38/82717A00/82717200` y
  `sub_8271B818/8271AD58/8271B6A0/82724300/…/82718020/827172C8`.
- El resto en espera; CPU ~40 % libre (no es falta de CPU).

## Descartado

- Afinidad de hilos: con < 6 CPU el SDK no fija afinidad
  (`XThread::SetActiveCpu`, `src/system/xthread.cpp`); fijar núcleo i →
  CPU i % 4 no cambia nada (cambio revertido).
- Compilador: igual con clang 20.1.8 (el del preset; se queda) y clang 23.
- Modo 60 FPS: igual con `DOAX2_FPS=30`.
- Partida: pasa con y sin partida previa.
- Código del port solo de Windows: `#if defined(_WIN32)` solo en
  `src/doax2_60fps.cpp` (diagnósticos, `VirtualProtect`/`mprotect` del paso
  de física, timer de 1 ms, XInput para saltar vídeos). Nada de esto.
- Fibras POSIX: el parche del port solo añade la variante de Android;
  Linux usa el `swapcontext` del SDK original.
- Teclas y mando: igual pulsando Start en el mando que Enter en el teclado,
  y también con las mismas `--keybind_*` que pasa el lanzador de Windows
  (las del SDK por defecto son otras; ahora `launch-options.sh` las pasa).

## Sin probar todavía (ideas)

1. Comparar con un log trace de la versión de Proton tras Start
   (`--log_level=trace` añadido a mano) para ver qué llamada viene después
   de `Unregistered symbolic link: upsdrive0:` en Windows.
2. Mirar en `generated/default/` qué hacen `sub_82783210` (planificador
   de fibras) y los dos hilos: ¿esperan una variable que en Linux no
   cambia (p. ej. un evento/overlapped del SDK que en POSIX no se marca)?
   `log_high_frequency_kernel_calls=true` saca también las llamadas
   frecuentes (KeWait…, KeDelay…), ocultas en el trace normal.
3. Rutas: en Linux `game_data_root` distingue mayúsculas; buscar en el
   trace opens fallidos de `game:\` tras Start.

## Cómo reproducir rápido

```
cd games/doax2-linux/build     # o la instalación
DOAX2_FULLSCREEN=0 ./steamdeck.sh --log_level=trace --log_max_file_size_mb=2000
# título → Start; congelado cuando el log da «tick timeouts 100»
eu-stack -p $(pgrep -x doax2) > pilas.txt
```

Recompilar solo el SDK tras tocarlo (~segundos por archivo):
`podman run … -w games/doax2-linux/work/rexglue-sdk steamdeck-ports/doax2-linux:24.04
cmake --build out/build/linux-amd64 --target install` y copiar
`out/install/linux-amd64/lib/librexruntime.so` junto a `doax2` (misma ABI).
Ojo: `build.sh` no rehace el SDK si su sello (commit + parche) no cambia,
así que un cambio a mano en `work/rexglue-sdk` se queda: revertirlo con
`git checkout` + `git apply` del parche.
