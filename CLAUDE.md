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
- `tools/serve.sh`: sirve los paquetes por HTTP (y los anuncia por mDNS)
  para instalarlos en la Deck **por red** con «Ports por red»
  (`tools/deck/steamdeck-ports.sh`), sin copiar carpetas. Ver README, *Por red*.
- Juegos sin versión Linux → Proton en la Deck.

## Convenciones

- Idioma: español en docs, mensajes de scripts y commits, y **también al
  hablar con el usuario** (petición suya, 2026-11-27).
- Ids de juego (carpeta `games/<id>`): `doaxtreme`, `doa3`, `doa2u`, `doa1u`,
  `castlevania-son`, `doa4`, `drakengard3`, `vf3tb`, `urban-reign`,
  `soulcalibur`, `doa4-linux`, `doax2`, `doax2-linux`, `soulcalibur2`,
  `jsrf`, `hyrule-warriors`, `lollipop-chainsaw`, `bayonetta2`,
  `bayonetta3`, `bomberman64`, `bomberman-hero`, `tekken6`,
  `rumble-roses-xx` (`vrdeluxe` se quitó el 2026-11-26).
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

- **Menú de opciones:** si un juego no tiene menú propio para sus ajustes
  (gráficos, FPS, resolución…) y solo se cambian con opciones de arranque
  o con un lanzador que en la Deck no hay (p. ej. el de Windows), crear
  uno si se puede (petición del usuario, 2026-11-26). Si los ajustes están
  en un `.ini`: `tools/deck/opciones.py` + `games/<id>/opciones.json`
  (como Bayonetta 2 y 3). Si no, modelo:
  `games/doax2-linux/launcher.py` (Python + GTK3, que trae SteamOS; mando
  por `/dev/input/js*`, teclado y pantalla táctil; guarda en un
  `opciones.conf` junto a `steamdeck.sh`, que va en `KEEP`). Si no se
  puede, documentar las variables en el README del juego.

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

- **Juegos obsoletos:** `DEPRECATED=1` en `games/<id>/game.conf`
  (`tools/deprecated.sh`). Se conservan sus archivos; `update.sh`,
  `package.sh`, `fetch-art.sh` y `serve.sh` se los saltan al recorrer
  todos, pero funcionan si se nombran. Ahora: `doa4` (lo sustituye
  `doa4-linux`) y `doax2` (lo sustituye `doax2-linux`).
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
  núcleos, siempre). La Deck tiene 8 y allí va bien (prueba del usuario).
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
  Parches nuestros del SDK en `games/doax2-linux/patches/rexglue-sdk/`
  (fibras de POSIX y `/dev/shm`). Sin ellos, el juego se cuelga al pulsar
  Start. Los juegos del ReXGlue SDK crean `/dev/shm/xenia_memory_*`; si
  quedan archivos de procesos muertos, borrarlos (llenan la RAM y
  provocan `SIGBUS`).
- **Bañadores de DOAX2 en DOA4**: doa4-online los construye del disco USA de
  DOAX2 en `<partidas>/doax2_suits`. Se hacen en el PC con
  `games/doa4-linux/doax2-suits.sh` (caché en `games/doa4-linux/work/`,
  por versión de DOA4) y van en los paquetes de doa4 y doa4-linux.
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
- **Soulcalibur II** (Xbox, `soulcalibur2`): binario Linux listo con el
  código del juego ya compilado (`soulcalibur2`, y `soulcalibur2-pal` para
  el disco europeo); solo lee la ISO al jugar. `isos/Soulcalibur2.iso` es
  la USA con el parche de medios de extract-xiso (SHA-256 del `Default.xbe`
  en el README del port). Con `portable.txt` todo va a
  `user/Soulcalibur II/`; su `launcher.ini` guarda el disco con ruta
  absoluta, así que `deck-launch.sh` la reescribe al arrancar. El launcher
  (ImGui, con mando) hace de menú de opciones; `--play` entra directo.
  **Ojo:** `soulcalibur2-launcher --help` no es una ayuda: abre el
  launcher (y crea `~/.local/share/Soulcalibur II` si no hay
  `portable.txt`). `--screenshot <prefijo> --size WxH` saca una captura de
  cada página sin ventana.
- **Jet Set Radio Future** (Xbox, `jsrf`, JSRF-PC): la release no trae el
  motor; se compila del `default.xbe` con `kit/build_engine.py` y el
  archivo `JSRF-PC-tools-linux-x86_64.tar.gz` del mismo tag (Python,
  capstone y Zig propios; sin contenedor), guardado en
  `latest/jsrf/tools-<tag>.tar.gz`. `kit/expected.txt` trae los SHA-256 del
  motor y del código generado; con `isos/JSRF.iso` salen los dos «match».
  Modo portable (`portable/`); en `portable/settings.cfg`, `game_dir=game`
  (relativa) evita el selector de zenity. `JSRF_GAME_DIR` **no** lo evita.
- **Hyrule Warriors DE** (Switch, `hyrule-warriors`, HWDER): la release de
  Linux es el Setup del port, sin el juego compilado. `build.sh` ejecuta
  `tools/linux_setup.py prepare` con `XDG_DATA_HOME=games/hyrule-warriors/work`
  (herramientas propias: Zig/Clang, CMake, Ninja, Python; sin contenedor).
  El juego lee **en cada arranque** el `.nsp` base, `prod.keys` (y
  `title.keys`) y la update descomprimida, así que van en el paquete
  (`game/base.nsp`, `keys/`, `update/`): **el paquete lleva las claves de la
  Switch del usuario**. `hwder_settings.ini` guarda rutas absolutas;
  `deck-launch.sh` las rehace al arrancar (también `save_dir` y
  `mods_dir`: si no, irían a `~/.local/share/HWDER`). `HWDER_LOG=<archivo>`
  abre la ventana minimizada (pruebas sin nadie); `skip_prelaunch=1` en el
  `.ini` se salta la pantalla de inicio.
- **Lollipop Chainsaw** (Xbox 360, `lollipop-chainsaw`): el port solo
  publica un lanzador de Windows (WPF) que compila el juego en el PC del
  jugador. Aquí: `@source` + SDK rexglue v0.11.0 en el commit de
  `scripts/sdk-package.ps1` + sus 5 parches + los nuestros (fibras,
  `/dev/shm`), Vulkan-Headers 1.4.313 y VMA 3.3.0 fijados por el port
  (Ubuntu 24.04 trae Vulkan 1.3), clang 20, y **un parche nuestro del
  juego** (`patches/game/0001-linux.patch`) que porta GDI+, recursos `.rc`,
  BCrypt y Win32. En Linux no hay iconos de teclado (solo los del mando).
  `work/src` es un repo git (commit `base` = código original) para sacar
  el parche con `git diff`. El «test bridge» del port
  (`--lollipop_test_directory=<dir>`, `command.txt` con «id\ncomando»:
  `capture`, `input <botones> 0 0 0 0 <ms>`, `input_device gamepad`) sirve
  para probarlo sin nadie delante.

- **Bayonetta 2** (Switch, `bayonetta2`, B2recomp): la versión Linux es
  una **prerelease** (`linux-test-N`, `B2recomp-linux-builder-*.zip`); la
  «latest» es la de Windows y `update.sh` coge la más reciente con el
  archivo. El port no descifra: pide `exefs/` y `romfs/` con la update 1.2
  aplicada. `build.sh` los saca con **hactool** (`tools/install.sh` lo
  compila de SciresM 1.4.0) con un HOME temporal: `prod.keys` filtrado
  (hactool se para en claves de longitud rara, como el
  `mariko_master_kek_source_05` de 34 cifras de las del usuario) y
  `title.keys` de los tickets (clave en 0x180, tipo en 0x281, rights ID
  en 0x2a0). **hactool escribe valores de claves en sus avisos**: filtrar
  su salida. `.nca` intermedios en `BAYONETTA2_TMP`. `setup.py` compila
  con su Zig (sin contenedor). El juego lee la romfs en cada arranque (va
  en el paquete; las claves no). `write_steamdeck_launcher` admite
  `LAUNCHER_SKIP_LIBS` (aquí `deps/python`, el Python del lanzador Tk).

- **Bayonetta 3** (Switch, `bayonetta3`, B3-Express): el port solo
  publica el lanzador de Windows; se compila aquí ScarletNX (`source/`,
  contenedor con clang/LLVM 23) y con él el código del juego, como
  `build_code()` del lanzador pero con `SNX_RECOMPILE_PORTABLE=1` (si no,
  el código es para la CPU del PC y podría no ir en la Deck). LLVM va
  **estático** (`games/bayonetta3/llvm-config-static` + `--as-needed`):
  el runtime de cada juego de ScarletNX lo enlaza. **La update de
  `isos/Bayonetta 3` es la 1.2.0** aunque un nombre diga 1.1.0 (ver su
  README). El `.xci` es convertido: hactool lo rechaza y
  `tools/switch-dump.sh` lee la partición `secure` él mismo. Arranque:
  `SNX_NVN_FRONTEND=2 SNX_NVN_RELEASE_ONLY=1` (renderizador rápido).

- **Bomberman 64 y Bomberman Hero** (N64, `bomberman64`,
  `bomberman-hero`, RevoSucks): N64: Recompiled + RT64, binario Linux
  listo (zip con un `.tar.gz` dentro). Común: `tools/n64recomp.sh`. El
  juego busca `portable.txt` en la **carpeta actual** (`steamdeck.sh` hace
  `cd`) y la ROM como `<game_id>.z64` (`bm64_us`, `bmhero`) en su carpeta de
  datos; si su XXH3-64 no es el de `rom_hash` (`src/main/main.cpp`), la
  borra y la pide. En este PC no hay `xxhsum` (paquete `xxhash`, sin
  `sudo`): `n64_check_rom` usa entonces el SHA-1 de una ROM ya comprobada.
  Ojo con las ROM modificadas: la primera `isos/Bomberman64.z64` era una
  (10 MB, «Zoinkity» en la cabecera) y el port la rechaza; la buena mide
  8 MB.
  Bomberman Hero solo publica prereleases.

- **Tekken 6** (Xbox 360, `tekken6`): la versión Linux (Vulkan, con sus
  `tools/build_linux.sh` y `run_linux.sh`) solo está en la rama `main`;
  la última release («Iterate», 0.9.4) es anterior. `ports.tsv` usa
  `@branch:main` (nuevo en `update.sh`: versión `main-<sha7>`). SDK en
  `BASE_REVISION` de `tools/apply_rexglue_patches.py` (el tarball no trae
  el submódulo), clang 19 (`games/tekken6/Dockerfile`), FMA3 forzado (la
  Deck lo tiene). Su SDK también dejaba 4,8 GB en `/dev/shm` por partida:
  lleva nuestros parches del SDK. Sin forma de ver la ventana aquí:
  `TEKKEN6_GPU_PROFILE=<csv>` da los fotogramas.
- **Rumble Roses XX** (Xbox 360, `rumble-roses-xx`): versión Linux
  compilada aquí del código de la release (`@source`); SDK v0.10.0
  (`c94f5eb`, el de doax2-linux) + `sdk-patch/` del port + los nuestros
  (el de fibras rehecho: el contexto cambia). El renderizador «nativo» del
  port es solo D3D12: en Linux va el emulado (Vulkan). Menú de ajustes del
  juego: F4 o Back+Start. `--input_script=<archivo>` simula el mando.
- **Tekken Tag Tournament 2** (`shihabal3amri/tekken-tag-tournament-2-pc`,
  en `ports.md`): **no añadido** (decisión del usuario, 2026-11-27: lo
  quería Linux y no es viable; Proton queda para más tarde). Usa
  XenonRecomp con un runtime propio solo de Windows (~3 MB: D3D11 a mano,
  Win32, Steamworks). Su instalador pide la ISO (`isos/TTT2.iso`) y la
  Title Update 3 (`isos/TU_174Q22P_0000008000000.00000000000O2`).

## Entorno del PC de build

Fedora (btrfs en `/home`, ~61 GB libres el 2026-11-22), con `docker`,
`podman`, `extract-xiso` v2.7.1 (`~/.local/bin`), `sqlite3`, `jq`, `unzip`,
`curl`, `gh`. Sin `distrobox`. En btrfs, `cp --reflink=auto` copia ISOs sin
gastar espacio.

## Probar en la Deck (para agentes)

- **Encontrarla:** SteamOS se anuncia por mDNS como servicio
  `_steamos-devkit._tcp` (puerto 32000):
  `avahi-browse -rt _steamos-devkit._tcp` da su nombre `.local` y sus IPs
  (puede estar a la vez por cable y por Wi-Fi; el cable es mucho más rápido).
- **Entrar:** usuario `deck`, por SSH con la clave del PC
  (`ssh-copy-id deck@<ip>` una vez; hace falta que el usuario active `sshd` y
  ponga contraseña con `passwd` en la Deck). Sin contraseña de `sudo`: lo que
  sea de root (p. ej. plugins de Decky) lo hace el usuario.
- **`steamos-add-to-steam`** manda `steam://addnonsteamgame/…`: con Steam
  cerrado, en una sesión gráfica **abre Steam** y no vuelve hasta que se
  cierra; desde SSH (`XDG_SESSION_TYPE=tty`) se niega («Cannot run this
  script from a tty if Steam is not running»). Por eso `instalar.sh` solo lo
  usa con Steam abierto y, si no, escribe `shortcuts.vdf`. Para simular la
  sesión gráfica desde SSH: `XDG_SESSION_TYPE=x11` y las variables de abajo.
  En el modo escritorio se abre desde SSH con
  `DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus systemd-run --user --collect steam`,
  y los comandos que lo usan llevan esas mismas variables.
- **Instalación por red sin interacción** (con `tools/serve.sh` en marcha en
  el PC): `printf '<nº>\ns\n' | ~/.local/share/steamdeck-ports/steamdeck-ports.sh`
  (el número del menú y «s» para confirmar si ya estaba instalado). Sin
  terminal no hay pausas. El juego pequeño para probar es `vf3tb` (77 MB).
- **Instalador a mano:** bajar `game.conf` y `<id>.tar.zst.sha256` de
  `<servidor>/<id>/` y `instalar.sh`, `steam-art.py`, `proton-dpi.sh` de
  `<servidor>/comun/` a una carpeta y ejecutar
  `PKG_URL=<servidor>/<id>/<id>.tar.zst INSTALAR_SIN_PAUSA=1 bash instalar.sh`.
  Así se probó también el error de suma (`.sha256` con ceros): la
  instalación anterior queda intacta.
- **Ojo con rsync a una carpeta de la Deck:** copia primero las carpetas
  ocultas del origen; no borres en el destino lo que no sabes de dónde viene
  mientras copia (el 2026-11-26 se perdieron así 3,7 GB copiados).
- **Cuelgues al salir de un juego con monitor externo:** con la Deck en
  un monitor (DP, 1080p a 120 Hz), al cerrar Bayonetta 2 y Bayonetta 3
  la pantalla se quedó congelada aunque el juego había salido bien
  (2026-11-27). En el journal, gamescope: `xwm: Failed to prepare 1-layer
  flip (Invalid argument)` y vuelve a elegir conector. Antes de culpar al
  juego, mirar su log y `journalctl -b` por SSH. Reiniciar Steam
  (`pkill -TERM -x steam`) lo devuelve; `systemctl reboot` pide contraseña.
- **Steam y `shortcuts.vdf`:** Steam lo reescribe al salir. Para editarlo a
  mano, antes `steam -shutdown` y esperar a que no quede proceso `steam`.

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
5. **DOAX2 en el Steam del PC** (petición del usuario): las dos variantes,
   `doax2` (Proton, GE-Proton más reciente) y `doax2-linux`, instaladas en
   `PC_GAMES` con imágenes (Steam cerrado con `-shutdown` y abierto otra
   vez).
6. **doax2-linux se cuelga al pulsar Start en el título** (prueba del
   usuario; 5 de 5). Detalles en `games/doax2-linux/README.md`. Probado y
   descartado: fijar la afinidad de los hilos con menos de 6 CPU (cambio
   en `xthread.cpp` del SDK, revertido). Falta saber si a `doax2` (Proton)
   le pasa lo mismo. **A `doax2` (Proton) no le pasa** (prueba del
   usuario): es cosa del build de Linux. Primera sospecha: clang 23 (el
   preset del port pide clang 20; Windows usa el clang de VS). La imagen
   `rexglue-build` trae ahora también clang 20 y `doax2-linux/build.sh` lo
   usa (`DOAX2_CLANG`; con otro compilador borra las carpetas de CMake).
   **Con clang 20 se cuelga igual**, y también a 30 FPS. Se queda clang 20
   (el del port). Tampoco son las teclas: con las `--keybind_*` del
   lanzador de Windows (ahora en `launch-options.sh`) se cuelga igual, con
   Start del mando y con Enter.
7. **Bañadores de DOAX2 en los paquetes de DOA4** (petición del usuario):
   `games/doa4-linux/doax2-suits.sh` los genera con el propio juego
   (`DOA4_SETUP_TEST=doax2=…`, interruptor de pruebas del port, y
   `--doa4_suits_import_pending=true`): 34 trajes, 300 MB, ~40 s. Los
   `build.sh` de doa4 y doa4-linux los copian a `user_data/doax2_suits`.
8. **DOAX2 (Proton) se veía mal con 192 DPI** (aviso del usuario).
   `PROTON_DPI` en `games/<id>/game.conf` manda sobre `PC_PROTON_DPI` de
   `local.conf`; doax2 lleva 96. En el PC: `.proton-dpi` = 96 y el prefijo
   puesto a 96 con Steam cerrado.
9. **Instalación por red** (petición del usuario: hasta ahora se copiaban
   los 57 GB de paquetes a la Deck con rsync). Detalles en el README,
   *Por red*.
   - `tools/serve.sh`: `python3 -m http.server` sobre una carpeta temporal
     en `$XDG_RUNTIME_DIR` (índice `index.tsv`, `listas/<id>.lst`,
     `comun/` con los scripts de `tools/deck`, el cliente y enlaces a cada
     paquete) + `avahi-publish` de `_steamdeck-ports._tcp`. Al parar
     (Ctrl+C o `kill`) borra la carpeta y deja de anunciarse (comprobado).
   - `tools/deck/steamdeck-ports.sh` («Ports por red»): se instala con
     `curl … | bash -s -- --instalar <url>`, busca el PC por mDNS (cable
     antes que Wi-Fi: el campo de interfaz de `avahi-browse -p`), se
     actualiza solo, menú con versión del PC / instalada, y lanza
     `instalar.sh` por juego.
   - `instalar.sh`: `PKG_URL` (descarga y descomprime a la vez; SHA-256 con
     `tee` a un fifo; si falla, vuelve la instalación anterior) e
     `INSTALAR_SIN_PAUSA`. El modo de siempre (archivo local) no cambia.
   - **Por qué `comun/`:** la primera prueba falló porque el cliente usaba
     el `instalar.sh` guardado en el paquete, anterior a `PKG_URL`. Ahora
     la Deck usa siempre los scripts del repo y cambiarlos no obliga a
     reempaquetar.
   - Probado en la Deck (SteamOS, cable a 192.168.1.64) con vf3tb: mDNS,
     autoactualización del cliente, instalación nueva, reinstalación (con
     `.old`) y una suma falsa (la instalación anterior queda intacta).
     `steamos-add-to-steam` desde SSH necesita Steam abierto (si no:
     «Cannot run this script from a tty if Steam is not running»); con
     Steam abierto añade el acceso y las imágenes bien.
   - mDNS: la Deck ve el PC por las dos redes (`enp4s0f3u1u4c2`, cable, y
     `wlan0`); el cliente elige el cable.
10. **Instalar con Steam cerrado en la Deck** (aviso del usuario: al
    instalar doa4-linux por red, la terminal se llenó de mensajes). Con
    Steam cerrado, `steamos-add-to-steam` lo abrió para el enlace
    `steam://addnonsteamgame/…`, Steam quedó colgado de la terminal del
    instalador y este esperaba a que se cerrara (el juego sí se añadió;
    faltaban las imágenes, puestas a mano). Primer intento: lanzarlo
    aparte (`setsid`) y esperar 120 s; Steam no guardaba el acceso a tiempo
    y acababa cerrándose, descartado. **Ahora**, con Steam cerrado,
    `instalar.sh` escribe `shortcuts.vdf` (`steam-art.py add`, como en un
    PC; con `--proton` en los de Windows) y no abre Steam. Probado con
    vf3tb (4 s, Steam sigue cerrado, acceso + 4 imágenes). El appid es
    distinto del que da `steamos-add-to-steam` (que no es el CRC de
    `exe+nombre`): al cambiar de uno a otro quedan imágenes huérfanas en
    `grid/`. Sin probar en la Deck: un juego de Proton por esta vía (elige
    el GE-Proton más reciente de `compatibilitytools.d` o
    `proton_experimental`).
9. **Arreglado el cuelgue de doax2-linux al pulsar Start** (el usuario lo
   dejó investigando). Se reprodujo sin nadie delante con un mando virtual
   (`uinput`). Se lanzó `doax2.exe` con Proton sin el lanzador para comparar
   logs. Con eu-stack y gdb se encontró la causa. Cuando termina un hilo
   del juego, `~XThread` se ejecuta en otro hilo, y `Fiber::Destroy` de
   POSIX dejaba a nulo la fibra actual de ese otro hilo (el principal). Su
   siguiente `swapcontext` fallaba en un bucle de `SIGSEGV` que el
   manejador del SDK se tragaba. El arreglo va en
   `games/doax2-linux/patches/rexglue-sdk/`, que `build.sh` aplica tras el
   parche del port: es el mismo que ya tenía el SDK de doa4-online
   (`5f4a591`). El mismo parche hace `shm_unlink` al crear la memoria
   del guest: cada partida dejaba 4,8 GB en `/dev/shm` (también
   doa4-linux), y con `/dev/shm` lleno el juego moría con `SIGBUS`.
   Las teclas del lanzador de Windows quedan en `launch-options.sh`
   (no eran la causa).

11. **doa4-linux sustituye a doa4 (Proton)** (decisión del usuario, tras
    probarlo en la Deck). `doa4` no se borra: `DEPRECATED=1` en su
    `game.conf` (`tools/deprecated.sh`). `update.sh` (descarga, menú y
    resumen), `package.sh` y `fetch-art.sh` sin ids, y `serve.sh`, se lo
    saltan; nombrándolo sigue funcionando y `build.sh` avisa.

12. **doa4-linux: arreglada la fuga de `/dev/shm`** con
    `games/doa4-linux/patches/rexglue-sdk/0001-linux-shm.patch` (el mismo
    `shm_unlink` que doax2-linux), que `build.sh` aplica tras el checkout
    del SDK (marca `.steamdeck-ports-stamp`). Como el SDK se compila con el
    juego, solo se recompilaron 10 objetos (~2 min). Probado: con el juego
    abierto, la memoria está en un descriptor borrado y `/dev/shm` queda
    vacío al cerrar.
13. **DOAX2 (Linux) se colgaba en la Deck** (aviso del usuario): tenía el
    paquete de las 02:50, anterior al arreglo (mismo cuelgue: «tick
    timeout» en el log, y un `xenia_memory_*` de 4,8 GB en `/dev/shm`,
    borrado). Reempaquetados doax2-linux y doa4-linux; doax2-linux
    y doa4-linux reinstalados en la Deck por red (partidas copiadas;
    `.old` sin borrar).
14. DOA1U en Linux (petición del usuario): **no viable por ahora**. El
    recompilador (TGP482/XboxXBE-Recomp) es solo Windows: D3D12, XAudio2,
    kernel de la Xbox sobre Win32 y el código del juego compilado en el
    primer arranque a una DLL con `clang.exe`/`lld-link.exe`. Ni upstream
    ni forks tienen nada de Linux. Sigue con Proton.
15. **DOAX2 (Linux) en la Deck: menú de gráficos y RenderDoc.** No hay
    menú dentro del juego (lo hace el lanzador de Windows): variables
    `DOAX2_MSAA`, `DOAX2_AA`, `DOAX2_ANISO` y archivo `opciones.conf`
    junto a `steamdeck.sh` (en `KEEP`; se edita por SSH sin cerrar Steam).
    En la Deck del usuario: MSAA off + FXAA; GPU de ~25 a ~1,3 ms por
    fotograma; sin RenderDoc, 60 FPS estables. El overlay «Capturing Vulkan» era RenderDoc: SteamOS trae
    `librenderdoc.so` (paquete `renderdoc-minimal`) y el SDK v0.10.0 la
    cargaba siempre. Parche `0002-linux-renderdoc.patch` (`RTLD_NOLOAD`).
    doa4-linux no lo necesita: su SDK ya lo trae.
16. **Lanzador de opciones para doax2-linux** (petición del usuario):
    `games/doax2-linux/launcher.py` (GTK3 + mando por `/dev/input/js*`,
    que en la Deck son legibles por el usuario: ACL de uaccess), lo abre
    `steamdeck.sh` antes del juego y escribe `opciones.conf`. Probado en
    el PC con un mando virtual (uinput); instalado en la Deck y en el PC
    sin reinstalar.
17. `/add-game` con dos juegos nuevos de `ports.md`: **Soulcalibur II**
    (`soulcalibur2`) y Jet Set Radio Future (`jsrf`, después: el usuario
    estaba descomprimiendo su ISO). En JSRF la regex excluye
    `JSRF-PC-tools-…` (las herramientas para compilar). soulcalibur2:
    binario listo, build ~20 s (1,4 GB), paquete 915 MB; probado desde otra
    ruta (`--play`: Vulkan, ~57 FPS, disco de la nueva ruta; capturas del
    launcher: disco verificado) e instalador con HOME falso (reinstalar
    conserva `user/`). Imágenes elegidas por el usuario.
    jsrf: motor compilado aquí (~6 min, 2,4 GB, paquete 1,6 GB; motor y
    código generado «match»), probado desde otra ruta (OpenGL, sin
    preguntas) e instalador con HOME falso (conserva `portable/`).
    Imágenes elegidas por el usuario.
18. **Soulcalibur II no va fluido en la Deck** (aviso del usuario).
    Medido con `RECOMP_PERF_COUNTER=1 --skip-intro --quick-match 0:0:1:0`
    (combate de la demo): 51-58 FPS en combate, 60 en menús, limitado por
    la CPU en un hilo; igual a 1x que a 2x; en el PC, peor. Es la
    incidencia #78 de upstream (abierta). Mi primera medida fue sobre el
    vídeo de la intro (me avisó el usuario): sin `--skip-intro` no vale.
    Método en `games/soulcalibur2/README.md`, *Rendimiento*.
19. Soulcalibur II **v0.7.1-beta.1** (solo arreglos visuales; el
    rendimiento, igual): `update.sh`, build, paquete e instalado en la Deck
    por red. `serve.sh` hace su índice al arrancar: con el servidor en
    marcha, tras reempaquetar hay que rehacer su línea de `index.tsv` (o
    reiniciarlo).
20. **JSRF no arrancaba en la Deck** (aviso del usuario): `kit/lib` trae una
    `libGL.so.1` de mentira (14 KB, para enlazar) y `steamdeck.sh` metía
    `kit/lib` en `LD_LIBRARY_PATH`; `jsrf_recomp` (sin RUNPATH) y SDL2 la
    cargaban y en X11 (el modo Juego) fallaba la ventana: «[GL]
    SDL_CreateWindow failed: Could not retrieve OpenGL functions» en
    `portable/logs/last-run.log`. En el PC no salió porque el escritorio es
    Wayland (EGL). `write_steamdeck_launcher` ya no cuenta libGL, libEGL,
    libGLX, libGLES, libOpenGL ni libvulkan (ningún otro juego trae una).
    Probado en la Deck por SSH (X11): OpenGL 4.6 radeonsi.
21. **JSRF: el mando no hacía nada en el juego** (sí en su menú F1/Back).
    Dos causas. (1) En el modo Juego, SDL cree que la ventana no tiene el
    foco y no da los botones a `SDL_GameControllerGetButton`, que es lo
    que lee el juego: `steamdeck.sh` exporta
    `SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1` (`build.sh`). (2) El juego
    solo lee un mando y con un HORIPAD for Steam por Bluetooth cogía el de
    la Deck; el usuario lo resolvió con el orden de Steam (⋯ → Reordenar
    controladores): **con la Deck la primera, el juego toma el HORI**
    (al revés de lo esperado). En `games/jsrf/deck-notes.md`.
    Cómo se investigó: `RECOMP_INPUT_LATENCY=1` escribe en
    `portable/logs/last-run.log` cada pulsación del jugador 1; un script de
    Python con ctypes sobre el `libSDL2` del juego y el entorno de
    `/proc/<pid>/environ` (lanzado por SSH) lista mandos y botones; en la
    Deck, cualquier SDL ve los mandos físicos (`28de:1205`, HORI
    `0f0d:01ab`), no los virtuales de Steam (`28de:11ff`).
    `SDL_JOYSTICK_HIDAPI=0` no cambia nada. `gamescopectl screenshot
    /tmp/x.png` (con `DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000`) captura
    la pantalla de la Deck.

22. `/add-game` con dos juegos pendientes de `ports.md`: **Hyrule Warriors
    DE** (`hyrule-warriors`) y Lollipop Chainsaw (después). Hyrule: build
    ~30 min (Setup del port; `work/` 3,6 GB), `build/` 14 GB (casi todo el
    `.nsp`). Probado desde otra ruta: rutas del `.ini` rehechas, update
    1.0.1 cargada, Vulkan, menús y vídeo a 60 FPS exactos, `save/` dentro
    de la carpeta. Imágenes: las más votadas (a elegir por el usuario).
    Paquete 14 GB (5,5 min); instalador probado con HOME falso (instalar
    y reinstalar conservando `save/` y el `.ini`) en
    `/run/media/pandi/Stuff/hw-prueba` (28 GB; la borra el usuario: la
    comprobación de seguridad no deja). Sin probar en la Deck (el usuario
    la prueba el 2026-11-27; reiniciar `serve.sh` antes).

23. **Lollipop Chainsaw** (`lollipop-chainsaw`), versión **Linux nativa
    compilada aquí** (decisión del usuario, frente a Proton con el lanzador
    de Windows). El SDK v0.11.0 con los parches del port compila en Linux
    sin cambios; el juego necesitó nuestro parche (ver arriba). Build
    ~20 min la primera vez (`work/` 6,8 GB), `build/` 5,2 GB, paquete
    5,1 GB. Probado desde otra ruta: vídeos de inicio y prólogo jugable
    con el mando virtual del test bridge (Vulkan). Pendiente: manchas
    naranjas/verdes en la piel en un primer plano del prólogo (¿Vulkan?
    En Windows el port usa D3D12 ROV) y probar en la Deck. Instalador
    probado con HOME falso. **Error mío:** reescribí `build.sh` mientras se
    ejecutaba (iba a fallar igualmente; no hizo daño).

### 2026-11-27

1. `/add-game` con dos juegos nuevos de `ports.md`: **Bayonetta 2**
   (`bayonetta2`) y Bayonetta 3 (después). Bayonetta 2 con la versión
   Linux en pruebas del port (`linux-test-9`): hactool nuevo en
   `tools/install.sh`, extracción ~6,5 min (`work/dump` 13 GB), `setup.py`
   22 min con 4 núcleos, `build/` 14 GB (romfs con reflink), paquete
   12 GB. Probado desde otra ruta (llega a la primera escena, Vulkan,
   español) e instalador con HOME falso. Ajustes para la Deck en
   `config/graphics.ini` (pantalla completa, `resolution_scale = 1.0`; el
   port trae 2.0). Opciones: el lanzador Tk del port con
   `./steamdeck.sh --opciones` (sin mando).
2. **Sin espacio en `/home`** (8,9 GB libres): `clean-builds.sh -y`
   (petición del usuario) borró los `build/` ya empaquetados; quedaron
   41 GB libres. Con reflinks, `du` engaña: `btrfs filesystem du -s`
   da lo que ocupa cada carpeta de verdad («Exclusive»).
3. Bayonetta 3: el usuario solo tiene la update **1.1.0** y B3-Express pide
   la 1.2.0 (petición del usuario: que no la rechace). El rechazo está solo
   en el lanzador de Windows; ScarletNX (`scarletnx -x/-r`) no mira la
   versión. Los extras con direcciones fijas de la 1.2.0
   (`source/src/nx/hle/aspect.c`, `scene60.c`, `model_lod.c`,
   `mouse_look.c`) comprueban las instrucciones antes de activarse; las
   listas `launcher/code-*.txt` del lanzador no se usan con la 1.1.0.

4. **Bayonetta 3** (`bayonetta3`), versión Linux nativa con ScarletNX.
   La update era ya la 1.2.0 (557 archivos idénticos a los de
   `game-files.txt`): no hizo falta saltarse la comprobación de versión.
   `tools/switch-dump.sh` (común; lee `.xci` convertidos) y
   `run_in_container` construye la imagen base que pida el Dockerfile de un
   juego (`FROM steamdeck-ports/rexglue-build`). ScarletNX ~25 min, código
   del juego 12,5 min (repetir: segundos, con `--cache`), `build/` 15 GB,
   paquete 15 GB. En el PC llega al título pero a ~3,5 FPS (la GPU: RX
   6400); hay que medirlo en la Deck. **Ojo:** `pgrep -f <patrón>` en un
   bucle de espera encuentra al propio bucle (su línea de comandos lleva el
   patrón) y no acaba nunca: anclar el patrón (`'^bash games/…'`).

5. **Prueba en la Deck** (usuario). **Bayonetta 2** arranca y el mando
   va, pero no llega a 60 FPS: su log (`build-linux/play/stdout.txt`,
   líneas `nvn_perf`) da 47-57 FPS (1 % bajo 22-25) y es la **CPU**: la
   GPU trabaja 0,5-1 ms por fotograma y el hilo de dibujo 11-15 ms (3-4
   de ellos, `texhash`: la versión Linux del port comprueba con sumas qué
   texturas cambian). Bajar la resolución no lo arregla. **Hyrule
   Warriors** (`hwder.log`, líneas `display: 300 frames`): 60 FPS en menús,
   39-67 en las primeras batallas (shaders nuevos) y 75-100 con `fps120=1`
   (la pantalla es de 60 Hz: mejor 60 con VSync).
6. **Menú de opciones común** (petición del usuario: Bayonetta 2 no tenía
   menú con mando): `tools/deck/opciones.py` (el de DOAX2, generalizado):
   lee `opciones.json` del juego (archivo, clave, valores) y cambia solo
   el valor de cada clave en su `.ini`; `MENU` en `opciones.conf` decide
   si sale. Bayonetta 2 (`config/graphics.ini` y `controllers.ini`) y
   Bayonetta 3 (`Bayo3_120.ini`, que además viene en español:
   `language = 5`). El de Bayonetta 2 se copió a la Deck sin reinstalar.
   `tools/switch-dump.sh` probado también con los `.nsp` de Bayonetta 2
   (mismo resultado que la extracción anterior): su `build.sh` lo usa ya.
7. **`doax2` (Proton) obsoleto** (sugerencia del usuario: que no salga en
   «Ports por red»): `DEPRECATED=1`; lo sustituye `doax2-linux`. Para que
   desaparezca de la lista hay que reiniciar `serve.sh`.

8. `/add-game` con dos juegos nuevos de `ports.md`: **Bomberman 64**
   (`bomberman64`) y **Bomberman Hero** (`bomberman-hero`), de N64
   (N64Recomp, binario Linux listo). `tools/n64recomp.sh` común: comprueba
   la ROM, la deja como `<game_id>.z64` con `portable.txt` y el juego no la
   pide. Hero: build en segundos (34 MB, paquete 16 MB en `DEST`); probado
   desde otra ruta (Vulkan, ajustes en su carpeta, ROM aceptada) e
   instalador con HOME falso (reinstalar conserva `saves/` y `*.json`).
   Bomberman 64: la ROM de `isos/` era una modificada; el usuario puso la
   USA 1.0 buena: build 49 MB, paquete 19 MB, probado igual. Imágenes:
   candidatas bajadas (a elegir por el usuario).

9. `/add-game` con los tres juegos nuevos de `ports.md`: **Tekken 6**,
   **Rumble Roses XX** (los dos Linux nativo, compilados aquí, a la vez) y
   Tekken Tag Tournament 2 (no añadido, ver arriba). Sin espacio para los
   dos: se borraron `games/bayonetta{2,3}/work/dump` (28 GB, se rehacen
   del disco; petición del usuario). tekken6: ~20 min, `work/` 9,5 GB,
   `build/` 6,7 GB, paquete 6,6 GB; 60 FPS en el PC (intro y demo).
   rumble-roses-xx: ~15 min, `work/` 6,3 GB, `build/` 3,7 GB, paquete
   2,8 GB; arranca y responde al mando simulado. Los dos probados desde
   otra ruta e instalador con HOME falso en `/run/media/pandi/Stuff`
   (borrado). El disco de `DEST` no estaba montado: sin paquetes en `DEST`.
   Imágenes: candidatas bajadas (a elegir por el usuario).

10. **Rumble Roses XX va lento en la Deck jugando** (aviso del usuario).
    Por SSH, durante la partida: GPU al 100 % pero a 260-950 MHz, la Deck en su
    límite de 15 W, y el hilo `Audio Worker` gastando un núcleo entero
    (también en el PC, desde el arranque). Causa: `WaitMultiple` del SDK
    v0.10.0 (`src/core/threading_posix.cpp`) truncaba a milisegundos el
    tiempo restante y en las esperas «alertables» (tramos de 1 ms) hacía
    `sleep_for(0)`: espera activa. Parche nuestro (duerme el tiempo exacto)
    en rumble-roses-xx (`0003-…`) y doa4-linux (`0002-…`); doax2-linux y
    tekken6 ya lo traían arreglado por su port, lollipop-chainsaw (v0.11)
    espera con variables de condición. En la Deck no se puede usar
    `eu-stack`/`gdb` (`ptrace_scope=1`, sin `sudo`): la pila se sacó en el
    PC. La IP de la Deck cambia; mejor `deck@steamdeck-familycat.local`.

### Pendiente

- [x] `tools/install.sh`.
- [x] `build.sh` de los 5 juegos (+ `Dockerfile` en doaxtreme, doa3, doa2u).
- [x] Rutas absolutas en los builds de NoRain → resuelto con `steamdeck.sh`.
- [x] Imagen única de compilación (ver punto 14).
- [x] `steamdeck.sh` en todos los juegos Linux (ver punto 15).
- [x] Distribución a la Steam Deck: `tools/package.sh` + instalador.
- [ ] Probar en la Deck: el instalador `.desktop` en KDE y cada juego.
      `steamos-add-to-steam` con el `.desktop` y las imágenes ya están
      probados (vf3tb, 2026-11-26, punto 9).
- [ ] «Ports por red» con doble clic en el modo escritorio (probado solo
      por SSH) y con un juego grande (doa3) por cable.
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
- [x] doa4-linux: probado en la Deck, funciona bien (prueba del usuario,
      2026-11-26). Sustituye a `doa4` (Proton), que queda obsoleto.
- [x] doax2-linux: se colgaba al pulsar Start. Arreglado con un parche del
      SDK (2026-11-26, punto 9). Falta jugar más allá de la primera
      pantalla, reempaquetar e instalar.
- [x] doa4-linux: `shm_unlink` en su SDK (punto 12).
- [ ] doax2: elegir imágenes (`tools/fetch-art.sh` bajó candidatas) y
      probar las dos versiones jugando (en el PC y en la Deck).
- [ ] hyrule-warriors: probar en la Deck (instalar por red, mando,
      rendimiento) y elegir imágenes.
- [ ] lollipop-chainsaw: probar en la Deck, jugar más allá del prólogo,
      revisar las manchas de color del prólogo y elegir imágenes.
- [ ] bayonetta2: probar en la Deck (rendimiento, mando, fuentes del
      sistema) y elegir imágenes. Al salir del juego, la Deck se quedó
      sin responder (2026-11-27; el juego ya había cerrado y Steam
      tardaba en volver; se arregló reiniciando Steam por SSH). Ver
      *Probar en la Deck*: monitor externo.
- [ ] bayonetta3: probar en la Deck (sobre todo el rendimiento: en el PC
      ~3,5 FPS), asignar F2 (menú) a un botón y elegir imágenes.
- [ ] bomberman64 y bomberman-hero: probar en la Deck (jugar, mando) y
      elegir imágenes.
- [ ] tekken6 y rumble-roses-xx: probar en la Deck (imagen, mando,
      rendimiento; rumble-roses-xx con el arreglo de la espera activa) y
      elegir imágenes.
- [ ] Tekken Tag Tournament 2: con Proton (su instalador con `/silent`)
      cuando lo diga el usuario.
- [ ] DOA4: quitar el arreglo del puerto 1000 cuando salga la 0.3.8 (ya se
      salta solo por versión; probar en la Deck).
