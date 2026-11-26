# Jet Set Radio Future (Xbox) — `jsrf`

- Repo: https://github.com/spriteice/JSRF-PC (sobre JSRF Unleashed de JuMatt)
- Release usada: `JSRF-PC-<v>-linux-x86_64.tar.gz` (la regex de `ports.tsv`
  excluye `JSRF-PC-tools-linux-x86_64.tar.gz`, que se baja aparte en el
  build). No hay versión aparte para la Deck: el README de la release solo
  dice «Not tested yet, but it should work».
- Versión probada al descargar: b2.2-hotfix
- Datos: `isos/JSRF.iso` (disco **USA suelto**; el combinado con Sega GT
  2002 trae otra build y no vale)
- En la Deck: Linux nativo

## Contenido de la release

`jsrf-pc` (launcher: pide el juego, compila el motor la primera vez y
arranca `bin/jsrf_recomp`), `lib/libSDL2-2.0.so.0`, `kit/` (runtime ya
compilado: `obj/`, `lib/*.a`, cabeceras, el traductor `pipeline/`,
`build_engine.py`, `kit.json` y `expected.txt` con los SHA-256 del código
generado y del motor), `share/jsrf-pc.png`, `README.txt` (opciones,
controles, menús) y licencias.

**No trae el motor:** el código del juego se traduce a C y se compila a
partir del `default.xbe` del disco. Upstream lo hace en el primer arranque
(descarga Python, capstone y Zig, ~100 MB, o usa el archivo `tools` de la
release).

## Datos del juego

El disco extraído en `game/` (`default.xbe` + `Media/`). jsrf-pc admite
también la ISO, pero la descomprime en su carpeta la primera vez; aquí se
extrae en el build con extract-xiso.

## Build

```
games/jsrf/build.sh [-f] [iso]
```

1. Baja `JSRF-PC-tools-linux-x86_64.tar.gz` del mismo tag (SHA-256 del
   `digest` de GitHub) a `latest/jsrf/tools-<tag>.tar.gz`.
2. Extrae la ISO en `game/`.
3. Descomprime las herramientas en `tools/` y ejecuta
   `tools/python/bin/python3 -E -s kit/build_engine.py --root build --xbe
   game/default.xbe`, lo mismo que haría jsrf-pc. Sin contenedor: el script
   usa solo los programas de `tools/` y `kit/` con su propio entorno. Log en
   `latest/jsrf/build-engine.log`.
4. Comprueba la línea `done <motor> match <código> match` (los SHA-256 de
   `kit/expected.txt`) y borra `tools/` y `build/` (código generado).
5. Crea `portable/settings.cfg` con `game_dir=game` y `steamdeck.sh`.

Primera vez: ~6 min en este PC (4 núcleos; ~5 min el motor), 2,4 GB
(`game/` 2,4 GB, `bin/` 33 MB, `kit/` 9 MB); paquete 1,6 GB. Motor y código
generado: `match`. Se descargan 95 MB de herramientas una vez por versión.
Probado desde otra ruta con `steamdeck.sh`: no pregunta nada, el motor lee
`game/` de la nueva ruta, OpenGL, `lib/libSDL2` de la carpeta, sin errores
en `portable/logs/last-run.log`. Instalador con HOME falso: reinstalar
conserva `portable/`.

## Jugar

- **Instalar en la Deck:** `tools/package.sh jsrf` y «Ports por red» (o doble
  clic en `Instalar <Nombre>.desktop`).
- **Usar `steamdeck.sh`**, sin Proton: lanza `jsrf-pc`, que lee
  `game_dir=game` de `portable/settings.cfg` (ruta relativa a su carpeta:
  vale en cualquier instalación), no pregunta dónde está el juego y no
  compila nada (el motor coincide con `kit/expected.txt`). Sin `game_dir`,
  en modo portable abre un selector de carpeta (zenity); `JSRF_GAME_DIR` no
  lo evita.
- Opciones: el juego tiene **menú propio** (F1 o Back/Select del mando):
  pantalla, gráficos, audio, controles, presets (empieza en Performance).
  Opciones de arranque en `README.txt` (`--fullscreen`, `--resolution`…).
- Modo portable (`portable/` junto a `jsrf-pc`): `settings.cfg`, `saves/`
  (UDATA/TDATA), `logs/last-run.log` y `cache/`. El instalador conserva
  `portable/` al reinstalar (`KEEP`).

## Ojo: `kit/lib/libGL.so.1`

Es una libGL **de mentira** (14 KB) para enlazar el motor. No puede ir en
`LD_LIBRARY_PATH`: `bin/jsrf_recomp` pide `libGL.so.1` sin RUNPATH y SDL2
también la carga, así que en X11 (el modo Juego de la Deck) la ventana
falla con «Could not retrieve OpenGL functions». `write_steamdeck_launcher`
se salta las librerías de driver; `steamdeck.sh` solo pone `lib/` (SDL2).

## Mandos en la Deck

- `steamdeck.sh` exporta `SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1`: en el modo
  Juego, sin eso el juego no recibe los botones (el menú F1 sí, porque los
  lee de los eventos de SDL).
- Solo lee un mando (el primero de su lista). Con un mando externo, si no
  responde, cambiar el orden en Steam (⋯ → Reordenar controladores): con un
  HORIPAD for Steam, **la Deck la primera** hace que el juego coja el HORI.
  Está en `deck-notes.md` (sale en el README del paquete).
- Para ver qué le llega: `RECOMP_INPUT_LATENCY=1` escribe cada pulsación del
  jugador 1 en `portable/logs/last-run.log`.

## Imagen Ubuntu 24.04 (contenedor de build)

No la usa: el motor se compila con las herramientas de la propia release
(Python, capstone y Zig 0.13, con destino `x86_64-linux-gnu.2.34`).
