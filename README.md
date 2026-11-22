# steamdeck.ports

Scripts para descargar, preparar y empaquetar ports nativos (recompilaciones
estáticas) de juegos de Xbox / Xbox 360 para jugarlos en una Steam Deck.

El proyecto **no incluye ningún archivo de juego**. Las ISOs y paquetes se
aportan desde copias propias y quedan fuera de git (`isos/`).

## Juegos

| id (`games/<id>`)  | Juego | Repo | Archivo de release | Plataforma en la Deck | ISO / assets |
|---|---|---|---|---|---|
| `doaxtreme`        | Dead or Alive Xtreme Beach Volleyball | [NoRain211/doaxbv-re](https://github.com/NoRain211/doaxbv-re/releases) | `DOAXBV-<v>-Linux.zip` | Linux nativo (compilar) | `isos/DOAXtreme.iso` |
| `doa3`             | Dead or Alive 3 | [NoRain211/doa3-re](https://github.com/NoRain211/doa3-re/releases) | `DOA3-<v>-Linux.tar.gz` | Linux nativo (compilar) | `isos/DOA3.iso` |
| `doa2u`            | Dead or Alive 2 Ultimate | [NoRain211/doa2u-re](https://github.com/NoRain211/doa2u-re/releases) | `DOA2U-<v>-Alpha-Linux.zip` | Linux nativo (compilar) | `isos/DOA2U.iso` |
| `doa1u`            | Dead or Alive 1 Ultimate | [vini1264/DOA1U-XBERecomp](https://github.com/vini1264/DOA1U-XBERecomp/releases) | `DOA1U-XBERecomp.zip` | Windows → **Proton** | `isos/DOA2U.iso` (*) |
| `castlevania-son`  | Castlevania: Symphony of the Night (XBLA) | [birabittoh/NocturneRecomp](https://github.com/birabittoh/NocturneRecomp/releases) | `nocturnerecomp-<v>-linux-amd64.tar.gz` | Linux nativo (binario) | `isos/Castlevania SON/` (paquetes STFS) |

(*) DOA1U no tiene ISO propia: el disco de DOA2U trae los dos juegos
(`Doa1.xbe` y `DOA2.xbe` en la raíz, comprobado con `extract-xiso -l`).

La lista de juegos que usa `update.sh` está en [`ports.tsv`](ports.tsv);
[`ports.md`](ports.md) es la lista original en texto.

## Estructura

```
update.sh            descarga la última release de cada port y la descomprime
ports.tsv            id, repo de GitHub y regex del archivo de release a descargar
ports.db             SQLite con el histórico de versiones (no va a git)
latest/<id>/         archivo de release descargado, tal cual (no va a git)
games/<id>/
  README.md          notas del port: qué pide, cómo se construye, cómo se juega
  build.sh           genera games/<id>/build a partir de latest/ + la ISO
  latest/            release descomprimida (no va a git)
  build/             resultado final listo para copiar a la Deck (no va a git)
tools/
  install.sh         instala paquetes del sistema y extract-xiso
  lib.sh             funciones comunes de los build.sh
  docker/ubuntu-build.Dockerfile   imagen única de compilación (Ubuntu 24.04)
  bin/               extract-xiso (no va a git)
isos/                ISOs y paquetes de los juegos (no va a git)
```

## Flujo de trabajo

1. `tools/install.sh` — instala dependencias del PC (una vez).
2. `./update.sh` — comprueba las releases y descarga lo nuevo.
3. `games/<id>/build.sh [-f] [iso]` — genera `games/<id>/build`.
4. Copiar `games/<id>/build` a la Deck (por ejemplo a `~/Games/<id>`) y
   añadir el ejecutable a Steam como *juego no de Steam* (ver cada README).

## `update.sh`

```
./update.sh            # actualiza todos los juegos
./update.sh doa3 doa2u # solo esos
./update.sh -f doa3    # vuelve a descargar y descomprimir aunque esté al día
```

- Consulta `https://api.github.com/repos/<repo>/releases/latest` y elige el
  archivo cuyo nombre cumple la regex de `ports.tsv`.
- Lo descarga en `latest/<id>/` (borra las descargas anteriores de ese juego) y
  comprueba el SHA-256 con el `digest` que publica GitHub cuando existe.
- Lo descomprime en `games/<id>/latest/` (zip, tar.gz, tar.xz, tar.zst y 7z).
  Si el archivo tiene una sola carpeta raíz, la aplana. Escribe la versión en
  `games/<id>/latest/.release-tag`.
- Si la versión instalada ya es la última, no hace nada.
- Sin token, la API de GitHub permite 60 peticiones/hora. Para más:
  `GITHUB_TOKEN=$(gh auth token) ./update.sh`.

Dependencias: `curl`, `jq`, `sqlite3`, `unzip`, `tar`, `sha256sum`.

### Base de datos `ports.db`

| Tabla | Columnas | Contenido |
|---|---|---|
| `releases`  | `game, tag, asset, url, size, sha256, published_at, downloaded_at` | todas las versiones descargadas |
| `installed` | `game, tag, installed_at` | la versión que hay ahora en `games/<id>/latest` |

```
sqlite3 -header -column ports.db "SELECT * FROM installed"
```

## `tools/install.sh`

Comprueba `curl jq sqlite3 unzip tar python3 sha256sum git` y un motor de
contenedores (`podman` o `docker`), e instala lo que falte con dnf, apt o
pacman (`--print` solo enseña el comando). Descarga `extract-xiso` (release
oficial de XboxDev/extract-xiso, verificada por SHA-256) en `tools/bin/`.

## `games/<id>/build.sh`

Todos comparten `tools/lib.sh` y funcionan igual:

```
games/doa3/build.sh            # ISO por defecto (isos/DOA3.iso)
games/doa3/build.sh otra.iso   # otra ISO
games/doa3/build.sh -f         # build limpio
```

- Copian `games/<id>/latest` en `games/<id>/build` (con `--reflink`, sin
  gastar espacio en btrfs). Si `build/` ya es de esa versión, se reutiliza; si
  es de otra (o con `-f`), el anterior se mueve a `build.old/` para no perder
  partidas ni ajustes. Solo se guarda un `build.old/`.
- Al terminar escriben `build/.release-tag` con la versión construida.
- Los que compilan (doaxtreme, doa3, doa2u) construyen la imagen
  `steamdeck-ports/ubuntu-build:24.04` (una sola imagen para los tres, desde
  `tools/docker/ubuntu-build.Dockerfile`) y ejecutan
  `build_game.sh <iso> --extractor tools/bin/extract-xiso` dentro. Usan
  **podman** (rootless, `--userns=keep-id`) o docker si su daemon está activo.
  El proyecto se monta en la misma ruta que en el host, así que la ISO tiene
  que estar dentro del proyecto. Después avisan si algún `.json`/`.txt`/`.toml`
  del build guarda rutas absolutas del PC.

| Juego | Qué hace `build.sh` | Tiempo aprox. | Tamaño de `build/` |
|---|---|---|---|
| castlevania-son | descarga `scripts/extract_game.py` del mismo tag, instala World y Japón en `assets/`, crea `portable.txt` | segundos | ~300 MB |
| doa1u | extrae `isos/DOA2U.iso` en `assets/` con extract-xiso | ~20 s | ~4,3 GB |
| doa3 | compila en Ubuntu 24.04 (podman) | ~6 min | 4,4 GB |
| doaxtreme | compila en Ubuntu 24.04 (podman) | ~6 min | 4,4 GB |
| doa2u | crea `private/venv` y compila en Ubuntu 24.04 (podman) | ~12 min | 4,9 GB |

Casi todo el tamaño de los DOA es el disco extraído (`private/`).

### `build/steamdeck.sh`: punto de entrada común en la Deck

Todos los juegos Linux (doa3, doa2u, doaxtreme, castlevania-son) tienen
`build/steamdeck.sh`, así que en la Deck se añaden a Steam igual. En
castlevania-son solo lanza `nocturnerecomp`. En los DOA hace además esto:


Los ejecutables compilados en el contenedor guardan un RUNPATH absoluto a la
ruta de este PC para encontrar `libSDL3.so.0`, y los scripts del port no
ajustan `LD_LIBRARY_PATH` (upstream asume compilar y jugar en la misma ruta).
No se pueden parchear con `patchelf` porque `run_game.py` verifica el SHA-256
del runner. Por eso cada `build.sh` genera `build/steamdeck.sh`, que añade a
`LD_LIBRARY_PATH` (con rutas relativas) las carpetas con `.so` del build y
lanza `launcher.sh`. **En la Deck, el acceso de Steam debe apuntar a
`steamdeck.sh`.** `run_game.py` solo usa la librería estándar de Python, así
que funciona con el Python de SteamOS.

## Cómo se construye cada tipo de port

### Ports de NoRain211 (doaxtreme, doa3, doa2u)

El zip de Linux **no trae el juego compilado**: trae código fuente,
herramientas y scripts. `build_game.sh <iso>` extrae la ISO con
`extract-xiso`, levanta (*lift*) el `.xbe` a C con un recompilador estático
(Python + Capstone en `private/venv`) y compila el runner nativo con CMake,
Ninja y clang. Todo queda dentro de la propia carpeta (`private/`), que es la
que luego se juega con `run_game.sh` / `launcher.sh`.

- SteamOS no tiene compilador, así que se compila en **Ubuntu 24.04**. Los
  repos proponen `distrobox` en la propia Deck (`build_steamdeck.sh`); aquí se
  hace en el PC con podman/docker (`tools/docker/ubuntu-build.Dockerfile`).
- El runner y el launcher llevan su propio SDL3, así que el resultado funciona
  en SteamOS sin instalar nada. En tiempo de ejecución necesita
  `libshaderc_shared.so.1`, que SteamOS ya incluye.
- Paquetes de compilación en Ubuntu 24.04 (según `docs/building.md`):
  `build-essential cmake ninja-build clang git python3-venv libshaderc1
  libvulkan1 libvulkan-dev mesa-vulkan-drivers libx11-dev libxext-dev
  libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev libxss-dev libxtst-dev
  libxkbcommon-dev libwayland-dev libdecor-0-dev libegl-dev libasound2-dev
  libpulse-dev libpipewire-0.3-dev libudev-dev libdbus-1-dev`.
  Sin las cabeceras de ALSA/PulseAudio/PipeWire, SDL3 se queda sin audio y el
  build se detiene a propósito.
- En la Deck: añadir `launcher.sh` (o `run_game.sh`) como juego no de Steam.
  Si un mando controla dos puertos, desactivar Steam Input para ese acceso.

Diferencias entre los tres `build_game.sh`:

| | doaxtreme | doa3 | doa2u |
|---|---|---|---|
| Llamada | `build_game.sh <iso>` (= `--iso <iso>`) | `build_game.sh <iso>` | `build_game.sh <iso>` |
| Capstone / venv | lo crea `tools/setup_env.sh` | lo crea el script en `private/venv` | lo crea `build_game.py` |
| Python | 3 | 3.12+ | 3.12+ (lo comprueba) |
| `extract-xiso` | `--extractor` o el del PATH | `--extractor` o el del PATH | `--extractor`, PATH o descarga la release fijada |
| Extra | `--generate-only` | `--movies/--no-movies` | `--build-only`, `--lift-only`; `install_deps.sh` |

### DOA1U (Windows + Proton)

El zip trae `DOA1U.exe` ya compilado, más un `compiler/` propio: **la primera
vez que se arranca compila el código del juego para ese PC** (solo una vez).
Los datos van en `assets/`: puede ser la ISO o los archivos extraídos con
`Doa1.xbe` en la raíz. Requiere Direct3D 12 (en la Deck, vkd3d-proton de
Proton). Ajustes con F10.

### Castlevania SON (Linux nativo)

El tar.gz trae el binario `nocturnerecomp` ya compilado con sus `.so` y
`shaders/`. Los datos son los paquetes XBLA `LIVE`/STFS (sin extensión), que
se instalan en la biblioteca del juego:

| Paquete en `isos/Castlevania SON/` | Destino | Aporta |
|---|---|---|
| `world version/9F2DAA06…` | `assets/xbla-world` | el juego base |
| `japan version/EB9399B3…` | `assets/xbla-jp`    | vídeos, voces japonesas, arte de Dracula X |
| `addon/TU_1C42227…` (title update) | — | **no hace falta**: el port reproduce sus cambios sobre el ejecutable original (`src/hooks/tu_hooks.cpp`) |

La extracción se puede hacer desde la pantalla de inicio del juego
(**Select File** → **Extract**) o sin interfaz con
`scripts/extract_game.py <paquete> --assets <dir>` del repo (solo librería
estándar de Python). Identifica el paquete por el SHA-256 de su `default.xex`
y, para World, deja una copia en `assets/default.xex`.

Un `portable.txt` vacío junto al ejecutable guarda partidas, opciones y caché
al lado del juego en vez de en la carpeta del usuario. Las rutas se pueden
cambiar en `nocturnerecomp.toml` (`game_data_root`, `user_data_root`,
`cache_root`, `mods_data_root`…). Ajustes con F4.

## Estado

- [x] `update.sh` + `ports.tsv` + `ports.db` (probado: descarga y descomprime los 5).
- [x] Investigación de cada port (este README y `games/<id>/README.md`).
- [x] `tools/install.sh`.
- [x] `games/<id>/build.sh`. Los 5 construidos en el PC.
- [x] Una sola imagen de compilación (`tools/docker/ubuntu-build.Dockerfile`).
- [x] `steamdeck.sh` como punto de entrada común de los juegos Linux.
- [ ] Script para distribuir los builds a la Deck.
- [ ] Probar los builds en la Deck.

Espacio: cada build de un DOA extrae su ISO (~4 GB). Con btrfs, `cp
--reflink` evita duplicar datos al copiar ISOs dentro de `build/`.
