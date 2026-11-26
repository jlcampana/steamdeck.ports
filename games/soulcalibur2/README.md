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

## Imagen Ubuntu 24.04 (contenedor de build)

No la usa: el build solo copia archivos.
