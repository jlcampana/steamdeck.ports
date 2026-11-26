# Soulcalibur II (Xbox) — `soulcalibur2`

- Repo: https://github.com/tmcleroy/soulcalibur2-recomp (Soulcalibur II Recomp)
- Release usada: `Soulcalibur2Recomp-linux-x86_64.tar.gz` (binario Linux
  listo; el README dice que va en Steam Deck y Steam Machine, pero no hay un
  archivo aparte para la Deck)
- Versión probada al descargar: v0.7.0-beta.1
- Datos: `isos/Soulcalibur2.iso` (disco USA de Xbox)
- En la Deck: Linux nativo

## Contenido de la release

`soulcalibur2` (el juego, disco USA), `soulcalibur2-pal` (el mismo para el
disco europeo), `soulcalibur2-launcher` (launcher SDL3 + Dear ImGui),
`libSDL3.so.0`, `libshaderc_shared.so.1` (RUNPATH `$ORIGIN`), `shaders/`
(presets de RetroArch), licencias y README.

El programa del juego **ya viene traducido y compilado** en `soulcalibur2`:
no hace falta compilar nada, solo el disco para los datos.

## Datos del juego

Una imagen del disco de Xbox, USA o europea. El port comprueba el SHA-256 de
su `Default.xbe` (los cuatro valores, tal cual o con el parche de medios de
extract-xiso, están en el README del port y en `build.sh`).
`isos/Soulcalibur2.iso` es la **USA con el parche de medios** (`7ce1…42c6`).

Link y Heihachi (invitados de GameCube y PS2) son opcionales: el launcher
los construye en su página *Guest* a partir de esos discos. No los tenemos.

## Build

```
games/soulcalibur2/build.sh [-f] [iso]
```

Solo copia archivos (~20 s, 1,4 GB; paquete 915 MB): comprueba el
`Default.xbe` (extrae el disco junto al juego un momento, porque
extract-xiso no saca un solo archivo), copia la ISO a
`disc/Soulcalibur2.iso` (reflink), crea `portable.txt` y copia
`deck-launch.sh`. Probado desde otra ruta: `ldd` con el SDL3 de la carpeta,
`steamdeck.sh --play` (Vulkan, lee el disco de la nueva ruta, ~57 FPS en
este PC) y la página del juego del launcher («disc image, verified»).

## Jugar

- **Instalar en la Deck:** `tools/package.sh soulcalibur2` y «Ports por red»
  (o doble clic en `Instalar <Nombre>.desktop`).
- **Usar `steamdeck.sh`**, sin Proton. Lanza `deck-launch.sh`, que escribe
  `[game] disc=` en `user/Soulcalibur II/launcher.ini` con la ruta del disco
  de **esta** instalación (el launcher la guarda absoluta) y abre el
  launcher.
- El **launcher** es el menú de opciones (se maneja con el mando y sale en
  español): Jugar, pantalla completa, panorámica, resolución, shaders,
  texturas HD, mandos, online… Con `--play` en las opciones de lanzamiento
  de Steam (`%command% --play`) se entra directo al juego con esos ajustes.
- Dentro del juego: menú con Esc, F1, o Guide/Back del mando.
- Ajustes, partidas, estados guardados y logs en `user/Soulcalibur II/`
  (por `portable.txt`), que el instalador conserva al reinstalar (`KEEP`).
  `logs/game.log` crece unos 300 KB cada 30 s de juego (traza de cada
  fotograma); sin comprobar si se vacía en cada arranque.
- El launcher puede **actualizarse solo** desde GitHub (botón Actualizar).
  Mejor no: la versión buena es la del paquete; para cambiar de versión,
  `./update.sh` y reempaquetar.

## Rendimiento (2026-11-26)

En los **combates no llega a 60 FPS** en la Deck LCD: 51-58 FPS, con
fotogramas de hasta ~27 ms; menús y pantalla de título, 60 FPS. Es del
port, no del paquete: lo limita **la CPU**, en un solo hilo (todos los
hilos de la Xbox corren en uno del sistema, al 99 %), con la GPU casi
parada. Da igual la resolución (1x y 2x dan los mismos números). En el PC
(i5-6500) el mismo combate va peor (18-55 FPS). Incidencia de upstream:
https://github.com/tmcleroy/soulcalibur2-recomp/issues/78 (abierta; otro
usuario lo cuenta igual en la Deck).

Cómo se midió (sirve para comparar versiones nuevas):
`RECOMP_PERF_COUNTER=1` escribe cada segundo en el log
`recomp performance: … fps=… max_ms=…`. Con `--skip-intro --quick-match
0:0:1:0` (P1:traje:P2:traje[:escenario]) la primera demo del título, ~30 s
tras arrancar y sin tocar nada, es un combate de esos dos (escenario 8), y
el log marca `recomp sc2: quick match …` al empezar. **Ojo:** sin
`--skip-intro`, lo que se ve al principio es el vídeo de la intro, que no
sirve para medir. Las líneas `vblank miss` dicen qué hilo de la Xbox se
pasó del fotograma (`bee10014=…` ms). Desde SSH, en el modo Juego:
`DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000` y `--settings`/`--storage` a
una carpeta temporal para no tocar las partidas.

## Imagen Ubuntu 24.04 (contenedor de build)

No la usa: el build solo copia archivos.
