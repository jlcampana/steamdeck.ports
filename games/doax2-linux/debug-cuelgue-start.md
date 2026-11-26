# doax2-linux: cuelgue al pulsar Start (resuelto)

**Resuelto el 2026-11-26** con un parche nuestro del SDK,
[`patches/rexglue-sdk/0001-linux-fibras-y-shm.patch`](patches/rexglue-sdk/0001-linux-fibras-y-shm.patch),
que `build.sh` aplica después del parche del port. Incidencia del port:
https://github.com/hibikifukui22/Dead-or-Alive-Xtreme-2-Recompilation/issues/23

## Síntoma

- El juego llegaba al título a 60 FPS (Vulkan). Al pulsar Start se congelaba
  siempre: la ventana seguía viva, pero el juego dejaba de entregar
  fotogramas («tick timeouts 100» en el log).
- `doax2` (la release de Windows con Proton) **no** se colgaba en el mismo PC.

## Causa

Al pulsar Start, el juego lee la partida (`ups.dat`) desde un hilo que
luego termina. El hilo principal del juego cierra su handle, así que
`~XThread` de ese hilo se ejecuta **en el hilo principal** y destruye la
fibra principal del hilo que ha terminado. En `src/core/fiber_posix.cpp`,
`Fiber::Destroy` de una fibra de hilo hacía `tls_current_ = nullptr`
pensando que se ejecutaba en su propio hilo. En realidad dejaba a nulo la
fibra actual **del hilo principal**.

Su siguiente `SwitchToFiber` llamaba a `swapcontext(nullptr, …)`. Eso da
un `SIGSEGV` al escribir en la dirección `0x80`, y el manejador de
excepciones del SDK lo daba por resuelto y volvía a la misma instrucción.
El resultado era un bucle infinito al 100 % de CPU: en las pilas parecía
que el hilo principal no paraba de cambiar de fibra.

En Windows las fibras son las del sistema y `SwitchTo` no usa ese puntero,
así que allí no pasa.

**Arreglo:** borrar `tls_current_` solo si la fibra destruida es la actual de
ese hilo. Es el mismo arreglo que tiene el SDK de doa4-online
(Dwreckgg/rexglue-sdk, commit `5f4a591`, «POSIX Fiber::Destroy: a thread
fiber destroyed from another thread leaves that thread's current fiber
alone»). En rexglue/rexglue-sdk (main) sigue sin arreglar el 2026-11-26.

## Segundo arreglo del mismo parche: memoria en /dev/shm

El SDK crea la memoria del guest con `shm_open("/xenia_memory_<n>")`
(4,8 GB, dispersa) y solo la borra en `~Memory`. El juego sale con un
«hard exit», tanto con SIGTERM (lo que hace Steam) como con SIGKILL, así
que **cada partida dejaba un archivo en `/dev/shm`**. Esos archivos
ocupaban RAM hasta reiniciar: el 2026-11-26 había 14, unos 6 GB, de
doa4-linux y de las pruebas. Con `/dev/shm` lleno, el juego moría con
`SIGBUS` al arrancar.

**Arreglo:** `shm_unlink` justo después de crearlo. Las vistas se mapean desde
el descriptor y nadie vuelve a abrir la memoria por el nombre. Arriba, en
main, lo han resuelto de otra manera: al arrancar borran los archivos de
procesos muertos (`RemoveStaleFileMappings`). **doa4-linux también tiene
esta fuga** (su SDK `ca6b928` no lo arregla).

## Cómo se encontró (para otra vez)

- **Mando virtual:** `uinput` (python-evdev, con `/dev/uinput` accesible por
  ACL) crea un mando «Xbox 360» y pulsa Start cada pocos segundos. Así el
  cuelgue se reproduce sin nadie delante. El script está más abajo.
- **Proton sin lanzador:** `proton run doax2.exe <opciones del lanzador>
  --log_level=trace`, con `STEAM_COMPAT_DATA_PATH` del prefijo de Steam y
  `STEAM_COMPAT_CLIENT_INSTALL_PATH`. También admite variables `REX_<CVAR>`
  y un `doax2.toml` junto al exe.
- **Comparar los logs** de Linux y Proton tras Start: en Proton, después de
  `ups.dat` vienen otra enumeración y `rdsdrive0:`; en Linux no venía nada.
  Descartado: la partida (con la de Proton se colgaba igual), las teclas,
  el mando, la afinidad, el compilador y los 60 FPS.
- **eu-stack varias veces:** el hilo principal estaba el 65 % de las veces
  en `ExceptionHandlerCallback`, llamado desde una señal dentro de
  `swapcontext`.
- **gdb** con `handle SIGSEGV stop`, conectado al proceso colgado:
  `swapcontext+4: mov %rbx,0x80(%rdi)` con `si_addr=0x80`, siempre en la
  misma instrucción.

Mando virtual (`pad.py <cada_s> <total_s>`):

```python
import sys, time
from evdev import UInput, AbsInfo, ecodes as e
every, total = float(sys.argv[1]), float(sys.argv[2])
ax = lambda: AbsInfo(0, -32768, 32767, 16, 128, 0)
caps = {e.EV_KEY: [e.BTN_SOUTH, e.BTN_EAST, e.BTN_NORTH, e.BTN_WEST, e.BTN_TL, e.BTN_TR,
                   e.BTN_SELECT, e.BTN_START, e.BTN_MODE, e.BTN_THUMBL, e.BTN_THUMBR],
        e.EV_ABS: [(e.ABS_X, ax()), (e.ABS_Y, ax()), (e.ABS_RX, ax()), (e.ABS_RY, ax()),
                   (e.ABS_Z, AbsInfo(0, 0, 255, 0, 0, 0)), (e.ABS_RZ, AbsInfo(0, 0, 255, 0, 0, 0)),
                   (e.ABS_HAT0X, AbsInfo(0, -1, 1, 0, 0, 0)), (e.ABS_HAT0Y, AbsInfo(0, -1, 1, 0, 0, 0))]}
ui = UInput(caps, name="Microsoft X-Box 360 pad", vendor=0x045e, product=0x028e,
            version=0x110, bustype=e.BUS_USB)
t0 = time.time(); time.sleep(3)
while time.time() - t0 < total:
    time.sleep(every)
    ui.write(e.EV_KEY, e.BTN_START, 1); ui.syn(); time.sleep(0.15)
    ui.write(e.EV_KEY, e.BTN_START, 0); ui.syn()
ui.close()
```

Recompilar solo el SDK tras tocarlo:
`podman run --rm --userns=keep-id --security-opt label=disable -v <repo>:<repo>
-w games/doax2-linux/work/rexglue-sdk steamdeck-ports/doax2-linux:24.04 cmake
--build out/build/linux-amd64 --config Release --target install` y copiar
`out/install/linux-amd64/lib/librexruntime.so` junto a `doax2`.
