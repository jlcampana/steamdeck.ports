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
  `castlevania-son`, `doa4`, `drakengard3`, `vf3tb`, `urban-reign`,
  `soulcalibur`, `doa4-linux`, `doax2`, `doax2-linux` (`vrdeluxe` se
  quitó el 2026-11-26).
- Nunca subir archivos de juego: `isos/`, `latest/`, `ports.db`,
  `games/*/latest/`, `games/*/build/` están en `.gitignore`.
- Los assets de Castlevania SON los extrae el usuario a mano en
  `isos/Castlevania SON/`.
- **Git:** al completar cada hito (un juego añadido, un arreglo, una
  herramienta nueva…), hacer commit **y push** sin preguntar (petición del
  usuario, 2026-11-25).

- **Versión específica para Steam Deck:** al añadir un juego o al buscar una
  versión nueva, comprobar si, además de la de Linux (o Windows), el port
  publica una versión para Steam Deck/SteamOS: archivos de la release, README,
  docs (`docs/building.md`, sección SteamOS) o scripts como
  `build_steamdeck.sh`. Si la hay y vale, puede sustituir a la que usamos
  (menos pasos, o sin Proton). `update.sh` avisa si una release trae un
  archivo con «steamdeck», «steam_deck» o «steamos» en el nombre, pero hay que
  mirar también README y docs.

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

- **doa3 ≥ 0.8.1** guarda en `private/disc-path.txt` la ruta absoluta del
  disco; `steamdeck.sh` la rehace al arrancar (ver 2026-11-25, punto 17). Si
  algún aviso de `check_absolute_paths` sale en un build, hay que mirarlo.
- `build_steamdeck.sh` de doa3 (revisado en la 0.8.1) **no es una versión
  para la Deck**: compila **en** la Deck (instala distrobox en `~/.local`,
  crea un Ubuntu 24.04 `doa3-build` que comparte `$HOME`, `install_deps.sh` +
  `build_game.sh`; ISO y juego dentro de `$HOME`). Es lo mismo que hacemos en
  el PC con podman, pero gastando en la Deck la imagen, las dependencias, el
  disco extraído y el tiempo de compilar. No sustituye a nuestro paquete.
  Como upstream compila y juega en la misma ruta, no le afectan las rutas
  absolutas (RUNPATH, `disc-path.txt`), que es lo que arregla `steamdeck.sh`.

- **DOA4 solo publica prereleases** (`alpha-v…`): `update.sh` usa la release
  más reciente con el archivo si no hay «latest». Es solo Windows → Proton.
  Hasta alpha-v0.3.7 se congela al arrancar en Proton (puerto UDP 1000, issue
  #12; arreglado para la 0.3.8): `games/doa4/deck-post-install.sh` ofrece
  `net.ipv4.ip_unprivileged_port_start=1000`. Ese script también escribe
  `doa4_game_files`/`doa4_user_data` (rutas `Z:/…`) en `dead_or_alive_4.toml`
  para que no salga la pantalla de configuración.

- **doa4-linux**: segunda variante de DOA4, nativa de Linux, compilada aquí
  del código de la release (`@source`; `update.sh` admite ahora `@source`
  en repos con solo prereleases). SDK ReXGlue en el commit de
  `netplay_sdk.txt`, clang 23 (`games/doa4-linux/Dockerfile`, primer juego
  con Dockerfile propio: `run_in_container` lo usa si existe). Compila en
  `games/doa4-linux/work/` (se conserva; ~40 min la primera vez con
  `-j 2`). Se identifica como `dev`: online solo con el mismo build. En PCs
  con menos de 6 procesadores lógicos el SDK no fija la afinidad de los
  hilos y **se congela a veces al arrancar** (este PC, 4: 2 de 5; con 2
  núcleos, siempre). La Deck tiene 8.
- **DOAX2** (`doax2`, Proton): la release de Windows con su lanzador Win32
  (arranca `out/game/doax2.exe` con ~50 opciones y rutas relativas). El zip
  trae rutas con `\` y `out/game` sin permiso de lectura (`update.sh`:
  acepta el 1 de `unzip` y hace `chmod`). `isos/DOAX2.iso` mide lo mismo
  que la de DOA4 y sus primeros 100 MB coinciden (partición de vídeo
  común de los discos de 360), pero es DOAX2 (SHA-256 del xex comprobado).
- **doax2-linux**: DOAX2 nativo, compilado aquí del `-source.zip` de la
  release (no hay versión ni guía de Linux; el código sí es portable). SDK
  rexglue v0.10.0 en el commit del submódulo (API de GitHub) + el parche del
  proyecto; `rexglue codegen` genera el código desde el xex (no va en la
  release). Sin lanzador: `steamdeck.sh` lleva sus opciones
  (`games/doax2-linux/launch-options.sh`, Vulkan, 60 FPS, variables
  `DOAX2_*`). El zip trae `game/README.md`: ojo al copiar el juego.
- **Drakengard 3** (PS3, `drakengard3`): binario Linux listo (SDL2 del
  sistema, Vulkan 1.3). Solo prereleases. Pide la ISO USA **descifrada**
  (`isos/Drakengard3.iso`: su `EBOOT.BIN` coincide con el SHA-256 de
  `src/install/iso.cpp`) y la update 1.01
  (`UP0082-BLUS31197_00-DOD3PATCH0000000-A0101-V0101-PE.pkg`); DLC opcionales.
  `dod3 --install` va sin interfaz e instala junto al ejecutable; en Linux
  sus enlaces (`game/BLES00000DATA/…`) son relativos.
- **VF3 Team Battle** (`vf3tb`): la release trae un paquete **para Steam
  Deck** (`-deck.tar.gz`, compilado en el Steam Runtime) y es el que se usa.
  `isos/VF33tb.zip` es el set de MAME vf3tb **completo** (incluye las ROM de
  vf3), que funciona sin `vf3.zip`. `VF3_HIDDEN=1 VF3_QUIT_AFTER=<frames>`
  sirve para probarlo sin ventana.
- **Urban Reign** (PS2, `urban-reign`): el juego quiere una `.iso` en `game/`;
  `isos/UrbanReign.chd` es un CHD de DVD → `chdman extractdvd` (`mame-tools`).
  `steamdeck.sh` lanza `urban-reign --game`: el launcher (Python + GTK +
  WebKit) no hace falta y SteamOS no lo trae.
- **Virtua Racing Deluxe** (`vrdeluxe`): **quitado** por el usuario el
  2026-11-26 (`games/vrdeluxe`, su línea de `ports.tsv` y de `ports.md`).
  Lo que añadió sigue: `@source` en `update.sh` y SDL2/GL/zlib en la imagen.
- **SoulCalibur** (Dreamcast, `soulcalibur`, Voldorium): `voldorium` es el
  motor; el juego es `sc_game.so`, que se genera del disco (en el primer
  arranque o, aquí, en `build.sh` con `builder/tools/build.py --only module`,
  que descarga Zig). El disco hace falta también al jugar: CHD →
  `chdman extractcd` → `disc/SoulCalibur.gdi`; `disc =` en `voldorium.ini` es
  relativa a la carpeta actual. `--seconds N` para probarlo.

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
7. Imágenes elegidas por el usuario para los 5 juegos. Las imágenes siguen
   fuera de git (repo público, derechos), pero la elección se guarda en
   `game.conf` como id de SteamGridDB (`ART_<TIPO>=…`); `fetch-art.sh` las
   recupera aunque estén fuera del top N (probado con `-n 1`).
8. Paquetes regenerados con las imágenes elegidas. Cada paquete lleva un
   `README.md` (plantilla `tools/deck/README.md.in`, con las imágenes del
   juego y `SAVES` de `game.conf`). `package.sh -m` regenera solo metadatos.
   Ojo: en `game.conf` los valores con comillas invertidas van entre comillas
   simples (se carga con `source`).

9. **DOA4** (`/add-game`), con Proton + sysctl (decisión del usuario; el
   Linux nativo desde main está poco probado y no juega online con la
   release). `update.sh` admite repos con solo prereleases (de paso bajó
   doaxtreme v0.8.0 y doa3 v0.8.0, sin compilar todavía). Build ~45 s,
   6,8 GB; paquete ~4,8 GB. Nuevo en el empaquetado: `deck-post-install.sh` y
   `deck-notes.md` por juego. Instalador probado en el PC (toml, idempotente,
   sin pregunta de sysctl con 0.3.8). Imágenes elegidas por el usuario.

10. `isos` es un enlace a otro disco: los builds en contenedor fallaban
    («la ISO tiene que estar dentro del proyecto»). `run_in_container` monta
    también la carpeta real de `isos/` (solo lectura); `require_container_path`.
11. Bug arreglado: `prepare_build` copiaba `latest/.release-tag` a `build/`, así
    que un build fallido parecía terminado. Ahora la marca solo la escribe
    `finish_build`; a medias hay `.building-tag` (se continúa con la misma
    versión; con otra, se borra sin pisar `build.old/`). Probados 6 casos con
    un juego falso.
12. `update.sh`: resumen final (versiones nuevas, builds y paquetes atrasados)
    y `--build` (compila y empaqueta lo atrasado). Ayuda `-h/--help` en todos
    los scripts (`tools/help.sh`: la cabecera del script es la ayuda; los
    `build.sh` la reciben por `tools/lib.sh`).

13. doa3 v0.8.0 y doaxtreme v0.8.0 compilados (16,5 min en total con el
    empaquetado; paquetes 3,6 y 3,5 GB) y comprobados con `ldd` desde otra
    ruta. Lección: **no editar un `build.sh` mientras se ejecuta** (bash lee
    el script a trozos; el primer intento de doa3 compiló bien pero cortó en
    la línea 21 con «EOF inesperado»). Los builds 0.7.x están en `build.old/`.

14. `clean-old-builds.sh` (raíz): borra los `games/<id>/build.old/`
    (`-n` para ver, `-y` sin preguntar). Norma nueva (petición del usuario):
    comprobar siempre si hay versión específica para Steam Deck; `update.sh`
    avisa de archivos de release con ese nombre. Ninguno de los 6 repos la
    tiene ahora.

### 2026-11-25

1. `/add-game` con tres juegos nuevos de `ports.md` (PS3, recreativa y PS2;
   el proyecto ya no es solo Xbox): `drakengard3`, `vf3tb`, `urban-reign`.
   Los tres traen binario Linux listo. vf3tb publica versión para Steam Deck
   (`update.sh` avisó) y se usa esa.
2. `write_steamdeck_launcher <ejecutable> [args…]`: los argumentos quedan
   fijos en `steamdeck.sh` (Urban Reign: `--game`). `tools/install.sh`
   instala `chdman` (`mame-tools`).
3. vf3tb: build en segundos (87 MB); probado desde otra ruta sin ventana
   (recompila, Vulkan, sale bien). urban-reign: ~1 min (CHD → ISO), 3,8 GB,
   paquete 1,5 GB; probado desde otra ruta (intro con Vulkan). Paquete e
   instalador de los dos probados en el PC con HOME falso.
4. Lección: con `pipefail`, `unzip -l … | grep -q` falla (grep cierra la
   tubería antes de que termine unzip). Guardar la salida en una variable.
5. drakengard3: el usuario dejó la update 1.01 (`.pkg`) en `isos/`. Un repack
   «Gnarly Repacks» (FreeArc, para RPCS3) no valía: dod3 solo acepta la
   update como `.pkg`. Build ~2 min 15 s, 16 GB; probado desde otra ruta con
   `DOD3_LAUNCHER=0` (Vulkan, dibuja). Enlaces del instalador relativos.
6. Imágenes elegidas por el usuario para los tres.
7. Bug arreglado en `tools/package.sh`: `art_file` devolvía 1 si faltaba una
   imagen (vf3tb no tiene icono) y `set -e` cortaba el empaquetado tras
   comprimir, sin README (mismo patrón que el punto 12 del 2026-11-22). El
   instalador ya aceptaba que no hubiera icono (probado).
8. `clean-builds.sh` (raíz, petición del usuario: script aparte para no
   recordar un parámetro): borra `build.old/` y los `build/` con paquete
   terminado de la misma versión en `DEST` (`<id>.tar.zst` + `.sha256`, sin
   `.part`, y `VERSION` de su `game.conf`); `-f` borra también los demás.
   `clean-old-builds.sh` hace `exec clean-builds.sh --old-only`.
9. Empaquetados en `DEST` los tres nuevos (~6 min; vf3tb 74 MB, urban-reign
   1,5 GB, drakengard3 15 GB).
10. `update.sh`: menú de builds al final (petición del usuario), desde una
    terminal y sin `--build`: todos los juegos con nombre, versión y estado,
    los atrasados marcados; de cada elegido, `build.sh` si hace falta y
    siempre `package.sh` (regenerar paquetes si se pierde el disco de
    destino). whiptail o lista numerada (`UPDATE_MENU=text`); `-m`/`-M`.
    Bug arreglado de paso: `pkg_tag_of` devolvía 1 sin paquete en `DEST` y
    `set -e` cortaba el resumen (justo con el destino vacío). Probado con un
    `DEST` vacío. Llegaron doa3 v0.8.1 y DOA4 alpha-v0.3.8 (sin compilar).
11. Menú: estado `UPDATE vieja -> nueva` (petición del usuario), `falta el
    paquete` o `nuevo`. Arreglado: un juego con paquete al día pero sin
    `build/` (tras `clean-builds.sh`) salía como atrasado y `--build` lo
    habría recompilado; ahora el paquete al día basta. Por defecto solo van
    marcados los UPDATE (petición del usuario).
12. `update.sh` daba 403 en todo al usuario: sin token, la API de GitHub
    permite 60 peticiones/hora y se agotaron con varias pruebas. Ahora usa
    `GITHUB_TOKEN` (entorno o `local.conf`) o el de `gh auth token`, y
    comprueba el límite antes (`/rate_limit` no gasta). El token **no** va
    en el script: el repo es público.
13. Avisos de escritorio (petición del usuario): `tools/notify.sh`
    (`notify-send`; nada sin escritorio; `STEAMDECK_PORTS_NOTIFY=0` lo
    quita). `lib.sh` avisa al acabar cada `build.sh` (bien en
    `finish_build`, error con un `trap EXIT`) y `package.sh` al acabar cada
    paquete. Con `update.sh` en marcha: no se tocan los scripts que están
    corriendo y los demás se reescriben con un archivo nuevo (`os.replace`),
    así quien ya los leyó sigue con el viejo.
14. doa3 v0.8.1 compilado (4,4 GB). Novedad del port: el build descarga trajes
    de mods (usagiZ: 32 instalados; Gultigargar viene en RAR y se saltó por
    falta de `bsdtar`). `libarchive-tools` añadido a la imagen de build. El
    port reintenta los paquetes de trajes fallidos en el siguiente build.
15. **Error mío:** editar `update.sh` (con `open(…, 'w')`, que reescribe el
    mismo archivo) mientras el usuario lo tenía en marcha hizo que el
    proceso, al volver de los builds, leyera la versión nueva a medias:
    «error de sintaxis cerca de `}'» en el resumen final. Los builds y
    paquetes (doa3 v0.8.1, DOA4 alpha-v0.3.8) ya estaban terminados y bien.
    **Regla:** antes de editar un script, mirar si se está ejecutando
    (`pgrep -af`). Si lo está, esperar; o, si no hay más remedio, escribir
    un archivo nuevo y reemplazar (`os.replace`, `mv`, `sed -i`): el
    proceso sigue leyendo el archivo viejo, que sigue abierto.

16. **Instalar en el PC** (petición del usuario: probar los juegos también
    aquí, y en su Steam). `instalar.sh` detecta si no es SteamOS: destino
    `PC_GAMES` (`local.conf` → `game.conf` del paquete;
    `/run/media/pandi/Stuff/games`) o `~/Games` si no existe; añade a Steam
    escribiendo `shortcuts.vdf` (`steam-art.py add`, con Steam cerrado y
    copia `.bak`) y, si es de Windows, el GE-Proton más reciente en
    `config.vdf` (`steam-art.py proton`; leer y reescribir el `config.vdf`
    real da el mismo archivo byte a byte). Los Linux van además al menú.
    Steam del usuario: **Flatpak** (`~/.var/app/com.valvesoftware.Steam`),
    ve `/run/media`, no `~/Games` (el instalador da el `flatpak override`).
    Su runtime trae SDL2/SDL3/shaderc/Vulkan/python3: los juegos Linux van
    sin `flatpak-spawn`. Los appid de Steam actual no siguen la fórmula
    crc32: Steam usa el que hay en `shortcuts.vdf`, así que el nuestro vale.
    No arrancaba: una carpeta vacía `~/.var/app/com.valvesoftware.Steam/Ports`
    chocaba con el enlace `~/Ports` del permiso `filesystems` (bwrap);
    el usuario la borró.

17. **DOA3 desde Steam: el launcher se abría pero «Start» no hacía nada.**
    Novedad de doa3 0.8.1: `build_game.py` escribe `private/disc-path.txt`
    con la ruta **absoluta** del disco (la del PC de build) y `run_game.py`
    la resuelve con `strict=True` antes de lanzar el runner → excepción sin
    log (no llega a crear `private/play-logs`). `check_absolute_paths` no lo
    detectó (ver punto 18). Ahora `write_steamdeck_launcher` lo detecta y
    `steamdeck.sh` reescribe ese archivo al arrancar con la ruta de la
    instalación. Probado en la instalación del PC (`play_disc` resuelve).

18. **DOA3: versión europea y trajes solo de chicas** (peticiones del
    usuario). `isos/DOA3.EUR.iso` (Europe 3.2: trae español). El port admite
    varias versiones en un build (`build/recomp-program-eur`,
    `private/play-disc-eur`, se elige en el launcher): `games/doa3/build.sh`
    compila todas las `isos/DOA3*.iso` y salta las ya hechas (SHA-256 de la
    ISO en `private/imported-disc*/receipt.json`). EUR: ~5 min; build 9,3 GB.
    Trajes: `build_game.sh --no-costumes` y luego `games/doa3/costumes.py`
    (contenedor), que usa `install_costumes` del port ofreciendo solo los
    códigos de chicas y borra los de chicos: 113 de 128 huecos (antes 50
    de chicas). Códigos sacados de las imágenes de muestra de los paquetes
    y de `loadfile.afs`: `kas` Kasumi, `aya` Ayane, `lei` Lei Fang, `tin`
    Tina, `hik` Helena (*hika*, Pi Gua), `kor` Hitomi, `gok` Christie, `alp`
    Alpha-152; chicos: `kte` (karate), `nin` Hayate, `bni` Genra, `sui`
    Brad… El port no pone trajes en la europea (otro title ID); a petición
    del usuario se copian a `TDATA/4D53002D` **en prueba** (¿mayúsculas?
    mirar la carpeta que cree el juego al guardar).
    Bug arreglado en `check_absolute_paths`: `find -size -1M` solo encaja
    con archivos vacíos (redondea a MiB), así que nunca avisó de nada; ahora
    `-size -1024k`, sin lo de CMake.

19. `/add-game` con dos juegos nuevos de `ports.md`: Virtua Racing Deluxe y
    Soulcalibur (uno detrás de otro, petición del usuario). `update.sh`:
    regex `@source` = tarball del código de la última release (sin tamaño
    ni SHA-256 de GitHub). **vrdeluxe:** ROM USA (SHA-1 correcto); build en
    contenedor ~1 min, 7,1 MB (solo `vrde`, ROM y licencias); paquete
    2,8 MB; probado desde otra ruta con `vrde -d 1500` (llega a la selección
    de coche). Instalador probado con HOME falso.
    **soulcalibur:** `sc_game.so` se genera en el PC (en contenedor, 2 min
    45 s; el disco pasa la comprobación SHA-1), así la Deck no compila.
    Build 1,3 GB, paquete 707 MB; probado desde otra ruta (`--seconds 25`,
    en ventana) e instalador con HOME falso. Quedó
    `/run/media/pandi/Stuff/sc-movido` (copia de prueba en la raíz de un
    disco: la comprobación de seguridad no deja borrarla; la borra el
    usuario).

20. DOA3, prueba del usuario: la **europea no enseña los trajes** (el log
    muestra que abre los 113 de `TDATA/4D53002D`: el nombre de carpeta
    vale, el juego los ignora) y la **USA no enseña todos**: parece haber un
    límite por personaje (en la incidencia #131 del port preguntan por «más
    de 9 por personaje», sin respuesta). A petición del usuario:
    `games/doa3/pick-costumes.py` (página local con las hojas de muestra de
    los paquetes y casillas; escribe `games/doa3/costumes.txt`) y
    `costumes.py` instala solo esa selección. Hasta que el port amplíe el
    límite. Ojo al probar `costumes.py` fuera de `build/`: `build_game.ROOT`
    es la carpeta de su propio archivo, no la actual.

21. DOA3 reinstalado en el PC con los 31 trajes elegidos por el usuario
    (`costumes.txt`) y la europea sin trajes; partidas copiadas a mano de
    `doa3.old` (comprobadas con `cmp`) y `doa3.old` borrado (11 GB, a
    petición del usuario). **El instalador conserva ahora las partidas**
    (petición del usuario): `KEEP`/`KEEP_EXCLUDE` en cada `game.conf` (sacado
    del README de cada port y de las cadenas de sus binarios: vf3tb
    `settings.ini`, `eeprom`, `Screenshots`; urban-reign `game/memcards`,
    `game/states`…), `package.sh` los pasa al paquete y `instalar.sh` los
    copia de `<id>.old` antes de `post-install.sh` (doa4 reescribe sus rutas
    después). Probado con un paquete de prueba (copia ajustes y partida, se
    salta `*.xpr`). `package.sh -m` sin `build/` toma versión y tamaño del
    paquete: metadatos de los 11 paquetes de `DEST` regenerados.

22. **Menús diminutos con Proton en el PC** (DOA4: su menú, F1/Esc, es
    ImGui y crece con los DPI de Windows; Wine da 96). Ahora el instalador,
    **solo en PC** (en la Deck, 1280×800, no hace falta, decisión del
    usuario) y en juegos con Proton, añade el acceso con las opciones de
    lanzamiento `".proton-dpi.sh" %command%`: antes de arrancar pone
    `LogPixels` (`[Control Panel\\Desktop]` y `[Software\\Wine\\Fonts]`
    de `user.reg`) en `$STEAM_COMPAT_DATA_PATH/pfx` con `steam-art.py
    dpi-reg`. El prefijo se crea en el primer arranque: vale desde el
    segundo. Si el acceso ya estaba, `steam-art.py dpi <carpeta> <dpi>`
    directamente (el juego cerrado: Wine reescribe el registro al salir).
    `PC_PROTON_DPI` en `local.conf` (192 por defecto; 0 = no tocar).
    Aplicado a mano a DOA4 y DOA1U en el PC. Ojo: DOA4 pintaba a
    5012×2862 («Output size»), más que los monitores del usuario.

23. **`doa4-linux`** (petición del usuario: versión nativa de Linux de
    DOA4 como segunda variante, sin quitar la de Proton). Código de
    alpha-v0.3.8 + SDK `ca6b9284`, compilado en contenedor (clang 23,
    `-j 2`): ~40 min, `work/` 2,1 GB, build 6,8 GB (`game/` copiado con
    reflink de `games/doa4/build/game`), paquete 4,8 GB en `DEST`.
    `steamdeck.sh` le pasa `--game_data_root`/`--user_data_root` con la
    ruta de la instalación (sin `post-install.sh`). Probado: `ldd` desde
    otra ruta, arranque con Vulkan (intro, título, demo a 60 fps),
    instalador con HOME falso. Congelaciones al arrancar en este PC de 4
    núcleos (ver arriba; pilas con `eu-stack`: el hilo principal del juego
    espera en un bucle de `KeDelayExecutionThread`). No se ha añadido al
    Steam del usuario (estaba abierto).

### 2026-11-26

1. **vrdeluxe quitado** (petición del usuario: commit de su borrado de
   `games/vrdeluxe`, `ports.tsv` y `ports.md`). Fuera también de las tablas
   del README.

2. **doa4-linux en el Steam del PC** (petición del usuario): Steam cerrado
   con `-shutdown`, `instalar.sh` del paquete (a `PC_GAMES`, con
   imágenes) y Steam abierto otra vez.
3. **Incidencia en doa4-online** (petición del usuario, en su nombre):
   https://github.com/dwreckgg/doa4-online/issues/26 (congelación al
   arrancar con menos de 6 procesadores lógicos).
4. `/add-game` **DOAX2** (`ports.md`) y versión Linux (petición del
   usuario). `doax2` (Proton, con su lanzador): 40 s, 6,3 GB, paquete
   2,9 GB; sin probar en Proton. `doax2-linux`: compilado aquí (~18 min:
   SDK, codegen y juego), 4 arranques a 60 FPS hasta el título, paquete
   2,9 GB. `update.sh`: acepta el 1 de `unzip` (avisos) y hace `chmod -R
   u+rwX` al descomprimir. El Dockerfile de clang 23 pasa a
   `tools/docker/rexglue-build.Dockerfile` (enlazado desde cada juego).
   Imágenes: las más votadas (a elegir por el usuario).

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
- [x] Al reinstalar, el instalador copia las partidas de `<id>.old`
      (`KEEP` en `game.conf`, punto 21). Falta probarlo en la Deck.
- [ ] Podar los builds de NoRain (fuentes y `_deps` del compilado) sin romper
      la comprobación del runner en `run_game.py`.
- [x] DOA4 (`/add-game`).
- [x] Recompilar y empaquetar doaxtreme v0.8.0 y doa3 v0.8.0.
- [x] Imágenes de vf3tb elegidas (sin icono: no hay en
      SteamGridDB). urban-reign: las primeras candidatas.
- [ ] DOA3: el usuario elige los trajes (`games/doa3/pick-costumes.py`),
      luego `games/doa3/build.sh` + `tools/package.sh doa3`. La europea ya
      no lleva trajes (decisión del usuario).
- [x] Imágenes de vrdeluxe y soulcalibur elegidas por el usuario.
- [ ] doa4-linux: probarlo en la Deck (¿se congela al arrancar con 8
      hilos?) y, si va bien, decidir si sustituye a la de Proton.
- [ ] doax2: elegir imágenes (`tools/fetch-art.sh` bajó candidatas) y
      probar las dos versiones jugando (en el PC y en la Deck).
- [ ] DOA4: quitar el arreglo del puerto 1000 cuando salga la 0.3.8 (ya se
      salta solo por versión; probar en la Deck).
