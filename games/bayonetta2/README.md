# Bayonetta 2 (Switch), B2recomp — `bayonetta2`

Recompilación estática de Bayonetta 2 de Switch: el código AArch64 del
juego se traduce a C y se compila en el PC, con una capa de sistema propia
(hilos, archivos, audio, mandos y NVN sobre Vulkan). Usamos la **versión
Linux en pruebas** del port (prereleases `linux-test-N`, el «Linux
builder»); la estable (`vX.Y.Z`) es solo de Windows.

- Repo: https://github.com/K0NL/B2recomp
- Release usada: la más reciente con `B2recomp-linux-builder-*.zip`
  (`ports.tsv`; la «latest» es la de Windows y no lo trae). Al añadirlo:
  `linux-test-9` (equivale a Windows v0.3.2).
- Contenido: el código del port y sus herramientas (Python 3.13 con Tk,
  Zig 0.17, SDL3, Vulkan-Headers, el shim de glslang). **No trae el
  juego:** `scripts/setup.py` lo genera a partir del juego del usuario.
- En la Deck: Linux nativo (`steamdeck.sh`), Vulkan.

## Datos del juego

`isos/Bayonetta 2/`: el `.nsp` base (`[v0]`) y la update 1.2
(`[v131072]`). Es la única versión que acepta el port (`setup.py`
comprueba los SHA-256 de `exefs/` y la lista de archivos de la romfs; no
trae `data004.cpk` y está bien).

El port **no descifra nada**: pide `exefs/` y `romfs/` ya extraídos, con la
update aplicada. `build.sh` los saca con **hactool** (SciresM 1.4.0,
compilado por `tools/install.sh` en `tools/bin`) y las claves de la Switch
del usuario (`SWITCH_KEYS`, o la primera `prod.keys` de la carpeta o de
`isos/*/`; ahora la de `isos/HyruleWarriors/`):

- hactool usa un HOME temporal con un `prod.keys` filtrado (se para en
  claves de longitud rara, como un `mariko_master_kek_source_05` de 34
  cifras) y un `title.keys` hecho de los tickets de los `.nsp` (clave en
  0x180, rights ID en 0x2a0; solo tickets comunes).
- `--basenca=<programa base> <programa de la update>` da la romfs con la
  update aplicada; el `Control` de la update, el icono (`control/`), del
  que `setup.py` hace el del lanzador.
- Los `.nca` intermedios (~13 GB) van a `BAYONETTA2_TMP` (por defecto
  `work/tmp`) y se borran al acabar. Ojo con su salida: hactool escribe
  valores de claves en sus avisos; `build.sh` los filtra.

**Las claves no van en el paquete** (el juego no las usa). Sí van la romfs
y el código traducido, que salen del juego del usuario: no compartir el
paquete.

## Build

```
games/bayonetta2/build.sh [-f] [carpeta]
BAYONETTA2_TMP=/otro/disco BAYONETTA2_JOBS=4 games/bayonetta2/build.sh
```

1. Dump → `work/dump` (`exefs/`, `romfs/`, `control/`; ~7 min, 13 GB). Se
   rehace solo si cambian los `.nsp`.
2. `latest/` → `work/src` y `scripts/setup.py --dump work/dump` con sus
   propias herramientas, sin contenedor: deps, verify, convert, mods,
   tables, lift, compile (388 archivos C con `zig cc -O2`), icon, link →
   `build-linux/game_native`, `game.so`, `libSDL3.so.0`,
   `libssbu_glslang.so`. `rsync` no borra lo que genera `setup.py`
   (`runtime/gen/`, `lifter/eh_main_tables.json`).
3. `build/`: lo anterior, `targets/exefs` (`main.elf`…), `targets/romfs`
   (reflink de `work/dump/romfs`), el lanzador del port con su Python,
   `config/` y licencias. Sin compilador ni código del port.

Primera vez (este PC, 4 núcleos): extracción ~6,5 min, `setup.py` 22 min
(casi todo `compile`, `-j 4`). `work/` 14 GB (`dump/` 13 GB y `src/`
1,1 GB), `build/` 14 GB (la romfs es un reflink de `work/dump`: apenas
ocupa más) y el paquete 12 GB (3,5 min).

## Jugar

- **Instalar en la Deck:** `tools/package.sh bayonetta2` y «Ports por red».
- **Usar `steamdeck.sh`**, sin Proton → `deck-launch.sh`, que hace lo
  mismo que `scripts/play.sh` del port: `build-linux/game_native
  targets/exefs/main.elf` desde `build-linux/`, con `SSBU_ROMFS`,
  `SSBU_USERDATA`, `SSBU_GRAPHICS_CONFIG` y `SSBU_CONFIG` de la
  instalación. Log: `build-linux/play/stdout.txt`.
- **Opciones:** el lanzador del port (Tk; ratón o pantalla táctil, no el
  mando): `./steamdeck.sh --opciones`. Escribe `config/graphics.ini` y
  `config/controllers.ini` (comentados; se pueden editar a mano). La
  primera vez se añade al menú de aplicaciones
  (`./B2recomp --remove-from-menu` lo quita).
- Ajustes para la Deck (`build.sh`, solo si no hay `config/graphics.ini`):
  `window = fullscreen`, 1280x800, `resolution_scale = 1.0` (1280x720, la
  del juego; el port trae 2.0).
- Partidas en `build-linux/play/userdata/`, shaders en `cache/vk`
  (`../cache/vk` desde `build-linux/`). El instalador conserva
  `build-linux/play`, `config`, `cache` y `mods` (`KEEP`).
- Fuentes: sin las de la consola (`targets/sysdata/fonts`), el juego usa
  una del sistema (`/usr/share/fonts`: Noto Sans, DejaVu Sans, Liberation…).

## Probado (2026-11-27, en el PC)

Desde otra ruta (copia con reflink): `ldd` (solo libc/libm; RUNPATH
`$ORIGIN`), arranque con Vulkan (RX 6400), romfs y partidas de la nueva
ruta, fuente Noto Sans del sistema, y con capturas del runtime
(`SSBU_SHOT_EVERY=600 SSBU_SHOT_DIR=<dir>`, `.bmp`) y A pulsada cada 4 s
(`SSBU_PRESS=Z,30,4`): llega a la primera escena del juego, en español y
con subtítulos. Instalador probado con HOME falso (instalar y reinstalar
conservando partidas y `config/`). Sin probar en la Deck.

## Imagen Ubuntu 24.04 (contenedor de build)

No se usa: `setup.py` compila con el Zig del propio paquete (glibc 2.35
como objetivo), sin nada del sistema salvo `python3` (para `build.sh`) y
hactool.
