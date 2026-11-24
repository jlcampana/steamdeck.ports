# CLAUDE.md

Guía para Claude Code (y para cualquiera) sobre este proyecto. Toda la
documentación y el registro de trabajo van en el repo, **no** en la memoria de
`~/.claude`. La documentación para usuarios está en `README.md` y en
`games/<id>/README.md`.

## Objetivo

Scripts para jugar en una Steam Deck ports (recompilaciones estáticas) de
juegos de Xbox/Xbox 360:

- `update.sh`: descarga la última release de cada repo (`ports.tsv`) en
  `latest/<id>/`, la descomprime en `games/<id>/latest/` y registra versiones en
  `ports.db` (SQLite).
- `games/<id>/build.sh`: genera `games/<id>/build/` (port + assets) listo para la
  Deck. Si hace falta compilar, en un contenedor Ubuntu 24.04
  (`tools/docker/ubuntu-build.Dockerfile`, imagen única compartida).
- `tools/`: herramientas externas y `tools/install.sh` para instalarlas.
- `tools/package.sh`: empaqueta cada `build/` (`tar.zst`) con un instalador
  `.desktop` para la Deck (`tools/deck/`), que lo añade a Steam con imágenes
  (`games/<id>/art`, de SteamGridDB con `tools/fetch-art.sh`).
- Juegos sin versión Linux → Proton en la Deck.

## Convenciones

- Idioma: español en docs, mensajes de scripts y commits.
- Ids de juego (carpeta `games/<id>`): `doaxtreme`, `doa3`, `doa2u`, `doa1u`,
  `castlevania-son`.
- Nunca subir archivos de juego: `isos/`, `latest/`, `ports.db`,
  `games/*/latest/`, `games/*/build/` están en `.gitignore`.
- Los assets de Castlevania SON los extrae el usuario a mano en
  `isos/Castlevania SON/`.

## Añadir un juego nuevo

El usuario lo añade a `ports.md` (nombre + enlace a releases) y lanza
**`/add-game [nombre]`**, o simplemente avisa. Los pasos están en la skill de
proyecto [`.claude/skills/add-game/SKILL.md`](.claude/skills/add-game/SKILL.md):
`ports.tsv` → `update.sh` → investigar el port → ISO → `build.sh` con
`tools/lib.sh` → verificar desde otra ruta → documentar → commit.

## Datos que no se deducen del código

- **DOA1U usa `isos/DOA2U.iso`**: no hay ISO propia. El disco trae `Doa1.xbe`
  y `DOA2.xbe` en la raíz (comprobado con `extract-xiso -l`).
- El repo `NoRain211/doaxvb-re` se llama ahora `doaxbv-re` (GitHub redirige);
  en `ports.tsv` está el nombre nuevo.
- Los zips "Linux" de NoRain211 (doaxtreme, doa3, doa2u) **no traen el juego
  compilado**: hay que ejecutar `build_game.sh <iso>` en Ubuntu 24.04
  (SteamOS no tiene compilador). El resultado queda en la propia carpeta
  (`private/`) y funciona en SteamOS (lleva su SDL3; usa
  `libshaderc_shared.so.1` del sistema).
- DOA1U es solo Windows: `assets/` + `DOA1U.exe`, que compila el juego en el
  primer arranque. Necesita D3D12 (Proton/vkd3d).
- Castlevania SON: binario Linux listo. Los paquetes STFS se extraen con
  `scripts/extract_game.py` del repo (no viene en la release; solo stdlib) a
  `assets/xbla-world` y `assets/xbla-jp`. El title update (`addon/TU_…`) **no
  hace falta**: sus cambios están portados en `src/hooks/tu_hooks.cpp`.

## Entorno del PC de build

Fedora (btrfs en `/home`, ~61 GB libres el 2026-11-22), con `docker`,
`podman`, `extract-xiso` v2.7.1 (`~/.local/bin`), `sqlite3`, `jq`, `unzip`,
`curl`, `gh`. Sin `distrobox`. En btrfs, `cp --reflink=auto` copia ISOs sin
gastar espacio.

## Registro de trabajo

### 2026-11-22

1. Leídos `leeme.md` y `ports.md`; propuesta de estructura aceptada.
2. Consultadas las releases de los 5 repos (`gh api …/releases/latest`):
   doaxtreme v0.7.0, doa3 v0.7.1, doa2u v0.4.0, doa1u DOA1U-XBERecomp-V2,
   castlevania-son v1.5.2. Solo hay zip y tar.gz.
3. Escrito `ports.tsv` + `update.sh` (curl + jq + sqlite3; verifica el SHA-256
   con el `digest` de GitHub; aplana la carpeta raíz del archivo). Probado: los
   5 descargados y descomprimidos.
4. Leídos los README y `docs/building.md` de cada repo; revisados los
   `build_game.sh` de NoRain y `extract_game.py` de NocturneRecomp.
5. Documentación: `README.md`, `games/<id>/README.md`, `.gitignore`, este
   `CLAUDE.md`.
6. `tools/install.sh` (paquetes + `extract-xiso` en `tools/bin`) y
   `tools/lib.sh` (funciones comunes de los `build.sh`).
7. Docker no tiene el daemon activo en este PC (`DOCKER_HOST` apunta a
   `/run/kiri/docker.sock`, que no existe) → `run_in_container` usa **podman
   rootless** (`--userns=keep-id`, `--security-opt label=disable` por SELinux).
8. Builds hechos: castlevania-son (2 s, 301 MB), doa1u (18 s, 4,3 GB),
   doa3 (OK, 4,4 GB: `private/` 4,0 GB con el disco extraído; `build/` 298 MB).
9. **Problema de rutas en los ports de NoRain:** los ejecutables compilados
   (`recomp_program_runner`, `recomp_launcher`) tienen RUNPATH absoluto a
   `<ruta del PC>/build/recomp-program/_deps/sdl3-build` y ningún script del
   port ajusta `LD_LIBRARY_PATH` (upstream asume compilar y jugar en la misma
   ruta, con distrobox). No se pueden parchear con `patchelf` porque
   `run_game.py` verifica el SHA-256 del runner contra el recibo del build.
   Solución: `write_steamdeck_launcher` genera `build/steamdeck.sh`, que pone
   en `LD_LIBRARY_PATH` (con rutas relativas) las carpetas con `.so` y lanza
   `launcher.sh`. Comprobado con `ldd` sobre una copia en otra ruta.
   `check_absolute_paths` avisa ahora también de RUNPATH absolutos.
10. doaxtreme: compilado (~6 min, 4,4 GB; su build avisa "Gameplay has not
    been validated"). Su runner tiene RUNPATH `$ORIGIN:<ruta absoluta>`.
11. doa2u: primer intento falló. `docs/building.md` dice que `build_game.py`
    crea el venv, pero el código hace `pip install capstone` con el Python que
    lo lanza y Ubuntu 24.04 lo bloquea (PEP 668). `games/doa2u/build.sh` crea
    `private/venv` antes. Segundo intento OK (~12 min, 4,9 GB).
12. Bug propio arreglado: en `check_absolute_paths`, un `[[ … ]] && log` al
    final del bucle devolvía 1 y `set -e` cortaba el build.
13. Comprobado que `run_game.py` de los tres solo importa stdlib + módulos del
    propio port → funciona con el Python de SteamOS. El venv de `private/`
    enlaza a `/usr/bin/python3`.
14. **Imágenes de contenedor unificadas.** Los tres Dockerfiles eran idénticos
    y podman ya había deduplicado las tres etiquetas en una imagen
    (`e803ed19e106`, 2,33 GB). Ahora hay un solo
    `tools/docker/ubuntu-build.Dockerfile` → `steamdeck-ports/ubuntu-build:24.04`
    (sale de la caché con el mismo ID). Fuera los Dockerfiles y `.dockerignore`
    de cada juego y las etiquetas viejas. Regla: toda imagen sale de un
    Dockerfile versionado; si un juego necesitara más paquetes, su propio
    Dockerfile en `games/<id>/` haría `FROM` de esta.
15. **`steamdeck.sh` = punto de entrada común** de todos los juegos Linux en la
    Deck (petición del usuario: que todos arranquen igual). No se llama
    `run_game.sh` porque los DOA ya traen uno (el del port, que llama a su
    `run_game.py`; esos scripts son del port, no nuestros, y no se
    reescriben). Castlevania: `steamdeck.sh` → `nocturnerecomp` (RUNPATH
    `$ORIGIN`, no necesita más). Arreglado en `write_steamdeck_launcher`: la
    carpeta raíz salía con ruta absoluta y `*.so*` cogía archivos de
    `assets/`; ahora regex `\.so(\.N)*` + `realpath --relative-to`.
16. Idea para la distribución: instaladores `.desktop` (como Decky Loader o
    EmuDeck: se arrastran al escritorio de la Deck y doble clic). Podrían copiar
    el juego a `~/Games/<id>` y añadir `steamdeck.sh` a Steam
    (`steamos-add-to-steam`, a comprobar en la Deck). DOA1U necesita además
    forzar Proton.

### 2026-11-24

1. Leído `dudas.md` (formato de distribución, imágenes, pantalla completa).
   `isos` es ahora un enlace a `/run/media/pandi/Roms/isos.ports`: en
   `.gitignore` pasa de `isos/` a `isos` (con barra no cubre un enlace) y se
   ignora `_isos/` (copia antigua).
2. **Distribución:** `tar.zst` + instalador `.desktop`, no AppImage (solo
   lectura; los ports escriben en su carpeta). `games/<id>/game.conf` (nombre,
   ejecutable, Proton, SteamGridDB), `tools/package.sh` (destino en
   `local.conf`, sin `private/venv`, logs ni caché de shaders),
   `tools/deck/instalar.sh` (elige interna/SD, mueve la instalación anterior a
   `.old`, `steamos-add-to-steam` con un `.desktop` propio sin duplicar) y
   `tools/deck/steam-art.py` (lee `shortcuts.vdf` binario → appid → imágenes
   en `config/grid`). `tools/fetch-art.sh` descarga de SteamGridDB (API key).
3. El `Exec` del `.desktop` del instalador sigue la especificación (`\\$`,
   `\\"` dentro de comillas): validado con `desktop-file-validate` y
   ejecutado con `gio launch` desde una ruta con espacios. Instalador probado
   en el PC con HOME falso y un `shortcuts.vdf` sintético (instalar,
   reinstalar, imágenes).
4. Pantalla completa: gamescope en el modo Juego; los DOA de NoRain (SDL_GPU)
   ya abren a pantalla completa en la Deck; DOA1U tiene `display_mode` (F10).
5. Paquetes de los 5 juegos en `/run/media/pandi/tmp` (~4 min 45 s; 228 MB,
   2,8 GB, 4,0 GB, 3,5 GB, 3,5 GB). Sumas y enlaces duros de doa2u comprobados.
6. El usuario añadió los enlaces de SteamGridDB a `ports.md` (también DOA4) →
   `game.conf`. A petición suya, `fetch-art.sh` baja varias candidatas por tipo
   (`-n`, 10 por defecto) con un `index.html` para compararlas, y
   `tools/pick-art.sh` elige una. Al paquete solo van las elegidas.

### Pendiente

- [x] `tools/install.sh`.
- [x] `build.sh` de los 5 juegos (+ `Dockerfile` en doaxtreme, doa3, doa2u).
- [x] Rutas absolutas en los builds de NoRain → resuelto con `steamdeck.sh`.
- [x] Imagen única de compilación (ver punto 14).
- [x] `steamdeck.sh` en todos los juegos Linux (ver punto 15).
- [x] Distribución a la Steam Deck: `tools/package.sh` + instalador.
- [ ] Probar en la Deck: el instalador `.desktop` en KDE,
      `steamos-add-to-steam` con un `.desktop` (¿usa `Name`, `Exec` e `Icon`?),
      que Steam escriba `shortcuts.vdf` a tiempo para las imágenes, y cada juego.
- [x] Enlaces de SteamGridDB: de `ports.md` a cada `game.conf`.
- [ ] API key de SteamGridDB en `local.conf` → `tools/fetch-art.sh` y volver a empaquetar.
- [ ] Al reinstalar, las partidas se quedan en `<id>.old`: ver si conviene
      copiarlas a la nueva instalación (dónde guarda cada port).
- [ ] Podar los builds de NoRain (fuentes y `_deps` del compilado) sin romper
      la comprobación del runner en `run_game.py`.
- [ ] DOA4 (`/add-game`).
