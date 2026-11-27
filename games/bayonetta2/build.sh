#!/usr/bin/env bash
# Bayonetta 2 (Switch, B2recomp): versión Linux en pruebas del port (el
# «Linux builder», prerelease linux-test-N). La release no trae el juego:
# scripts/setup.py lo traduce de AArch64 a C y lo compila con sus propias
# herramientas (Python 3.13, Zig 0.17, SDL3, Vulkan-Headers), sin
# contenedor y sin nada del sistema. Aquí:
#   1. Con hactool (tools/install.sh) y las claves de la Switch del usuario
#      se sacan de los .nsp (juego base + update 1.2) exefs/ y romfs/ con la
#      update aplicada, y el icono (control/) → work/dump. El port no
#      descifra nada: pide esos archivos ya extraídos. Los .nca intermedios
#      (~13 GB) van a BAYONETTA2_TMP y se borran al terminar.
#   2. setup.py --dump work/dump en una copia del port (work/src; se
#      conserva: si se repite, solo recompila lo que cambia).
#   3. build/: el juego (build-linux/), main.elf, la romfs (12,6 GB: el
#      juego la lee en cada arranque), ajustes para la Deck y el lanzador
#      del port (opciones; Tk, con su Python). Sin compilador ni código.
# Las claves no van en el paquete (el juego no las usa).
# Resultado: games/bayonetta2/build (steamdeck.sh → deck-launch.sh).
#
# Uso: games/bayonetta2/build.sh [-f] [carpeta]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   carpeta     con el .nsp base ([v0]), la update 1.2 ([v131072]) y, si
#               no, se busca prod.keys en isos/*/ (por defecto
#               "isos/Bayonetta 2")
# Variables:
#   SWITCH_KEYS=<prod.keys>  claves (por defecto la primera prod.keys de
#                            la carpeta o de isos/*/)
#   BAYONETTA2_TMP=<dir>     para los .nca intermedios (por defecto
#                            work/tmp; necesita ~13 GB)
#   BAYONETTA2_JOBS=N        procesos del compilador (por defecto nproc)
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
SRC_DIR="$(realpath "${1:-$ISOS/Bayonetta 2}")"
first() { local f; for f in "$@"; do [[ -e "$f" ]] && { echo "$f"; return; }; done; echo "$1"; }
BASE_NSP="$(first "$SRC_DIR"/*\[v0\].nsp)"
UPD_NSP="$(first "$SRC_DIR"/*\[v131072\]*.nsp)"
KEYS="${SWITCH_KEYS:-$(first "$SRC_DIR/prod.keys" "$ISOS"/*/prod.keys)}"
HACTOOL="$ROOT/tools/bin/hactool"
WORK="$GAME_DIR/work"
TMP="${BAYONETTA2_TMP:-$WORK/tmp}"
JOBS="${BAYONETTA2_JOBS:-$(nproc)}"

require_latest
require_file "$BASE_NSP"
require_file "$UPD_NSP"
require_file "$KEYS"
[[ -x "$HACTOOL" ]] || die "Falta hactool: tools/install.sh"
command -v python3 >/dev/null || die "Falta python3"

prepare_build "$FORCE"
mkdir -p "$WORK"

# --- 1. Dump: exefs/ y romfs/ con la update 1.2, y control/ (icono) ---
DUMP="$WORK/dump"
dump_id="$(stat -c '%n %s %Y' "$BASE_NSP" "$UPD_NSP" | sha256sum | cut -c1-16)"
if [[ "$(cat "$DUMP/.steamdeck-ports-dump" 2>/dev/null)" != "$dump_id" ]]; then
    log "Extrayendo el juego de los .nsp con hactool (~7 min; .nca temporales en $TMP)"
    rm -rf "$DUMP"
    TMPW="$TMP/steamdeck-ports-bayonetta2"
    rm -rf "$TMPW"
    mkdir -p "$TMPW"
    # hactool lee las claves de $HOME/.switch: un HOME propio, solo para
    # esto. prod.keys sin las líneas que no entiende (claves de longitud
    # rara: hactool se para en ellas) y title.keys de los tickets.
    HH="$TMPW/home"
    (umask 077; mkdir -p "$HH/.switch"
     awk -F'[ =]+' 'NF>=2 && (length($2)==32 || length($2)==64)' "$KEYS" > "$HH/.switch/prod.keys")
    hac() { HOME="$HH" "$HACTOOL" --disablekeywarns --suppresskeys "$@" 2>&1 | grep -v -i key || true; }
    hac -t pfs0 --outdir="$TMPW/base" "$BASE_NSP" >/dev/null
    hac -t pfs0 --outdir="$TMPW/upd" "$UPD_NSP" >/dev/null
    (umask 077; python3 - "$TMPW"/base/*.tik "$TMPW"/upd/*.tik > "$HH/.switch/title.keys" <<'EOF'
import sys
# Ticket: firma RSA-2048 (0x140 bytes), clave de título en 0x180, tipo en
# 0x281 (0 = común), rights ID en 0x2a0.
for p in sys.argv[1:]:
    t = open(p, 'rb').read()
    if t[0:4] != b'\x04\x00\x01\x00' or t[0x281] != 0:
        sys.exit('%s: ticket no común o de formato inesperado' % p)
    print('%s = %s' % (t[0x2a0:0x2b0].hex(), t[0x180:0x190].hex()))
EOF
    )
    # El .nca de cada tipo (Program, Control) según su cabecera.
    nca_of() {  # carpeta tipo
        local n
        for n in "$1"/*.nca; do
            [[ "$n" == *.cnmt.nca ]] && continue
            if hac -i "$n" | grep -q "Content Type: *$2"; then echo "$n"; return; fi
        done
        die "No hay .nca de tipo $2 en $1"
    }
    base_prog="$(nca_of "$TMPW/base" Program)"
    upd_prog="$(nca_of "$TMPW/upd" Program)"
    upd_ctrl="$(nca_of "$TMPW/upd" Control)"
    mkdir -p "$DUMP.part"
    hac --basenca="$base_prog" --exefsdir="$DUMP.part/exefs" --romfsdir="$DUMP.part/romfs" "$upd_prog" \
        | grep -v '^Saving' || true
    hac --romfsdir="$DUMP.part/control" "$upd_ctrl" >/dev/null
    rm -rf "$TMPW"
    [[ -f "$DUMP.part/exefs/main" && -d "$DUMP.part/romfs/movie" ]] \
        || die "La extracción no dejó exefs/main y romfs/ (¿claves?)"
    echo "$dump_id" > "$DUMP.part/.steamdeck-ports-dump"
    mv "$DUMP.part" "$DUMP"
fi

# --- 2. El port en work/src y su setup.py ---
SRC="$WORK/src"
log "Copiando el port a work/src"
mkdir -p "$SRC"
# Sin --delete en lo que genera setup.py (build/, build-linux/, targets/,
# runtime/gen/, lifter/*.json) ni en config/ (ajustes): así repetir solo
# recompila lo que cambia.
rsync -a --delete --exclude=/build/ --exclude=/build-linux/ --exclude=/targets/ \
    --exclude=/config/*.ini --exclude=/cache/ --exclude=__pycache__/ \
    --filter='P /runtime/gen/**' --filter='P /lifter/eh_main_tables.json' "$LATEST/" "$SRC/"
log "Compilando el juego con scripts/setup.py (-j $JOBS; la primera vez ~45 min con 4 núcleos)"
(cd "$SRC" && ./deps/python/bin/python3.13 -u scripts/setup.py --dump "$DUMP" --jobs "$JOBS") 2>&1 \
    | tee "$WORK/setup.log"
for f in game_native game.so libssbu_glslang.so; do
    [[ -f "$SRC/build-linux/$f" ]] || die "setup.py no dejó build-linux/$f (ver $WORK/setup.log y $SRC/build/logs)"
done

# --- 3. Carpeta del juego ---
log "Montando build/"
# Se conserva lo que es del jugador (si se reconstruye sobre un build/ usado).
find "$BUILD" -mindepth 1 -maxdepth 1 ! -name .building-tag ! -name config ! -name cache \
    ! -name build-linux -exec rm -rf {} +
find "$BUILD/build-linux" -mindepth 1 -maxdepth 1 ! -name play -exec rm -rf {} + 2>/dev/null || true
mkdir -p "$BUILD/build-linux" "$BUILD/targets/exefs" "$BUILD/config/defaults" "$BUILD/build" \
    "$BUILD/scripts" "$BUILD/launcher"
cp -a "$SRC"/build-linux/{game_native,game.so,libssbu_glslang.so} "$BUILD/build-linux/"
[[ -f "$SRC/build-linux/libSDL3.so.0" ]] && cp -a "$SRC/build-linux/libSDL3.so.0" "$BUILD/build-linux/"
cp -a "$SRC/targets/exefs/." "$BUILD/targets/exefs/"
log "Copiando la romfs (reflink si se puede)"
cp -a --reflink=auto "$DUMP/romfs" "$BUILD/targets/romfs"
# Lanzador del port (ajustes de gráficos y mandos; Play): su script, su
# Python con Tk y el icono que hace setup.py del juego del usuario.
cp -a "$SRC/B2recomp" "$SRC/VERSION" "$BUILD/"
cp -a "$SRC/launcher/launcher_linux.py" "$BUILD/launcher/"
cp -a "$SRC/scripts/play.sh" "$SRC/scripts/report.sh" "$BUILD/scripts/"
mkdir -p "$BUILD/deps"
cp -a "$SRC/deps/python" "$BUILD/deps/"
for f in "$SRC"/build/bayonetta2.*; do [[ -f "$f" ]] && cp -a "$f" "$BUILD/build/"; done
cp -a "$SRC"/LICENSE "$SRC"/NOTICE.md "$SRC"/THIRD-PARTY-NOTICES.md "$SRC"/licenses "$BUILD/"
# Ajustes: los del port en config/defaults; config/*.ini solo si no hay
# (son del jugador). Para la Deck: pantalla completa a 1280x800 y la
# resolución del propio juego (1280x720; el port trae 2.0 = 2560x1440).
cp -a "$SRC"/config/defaults/*.ini "$BUILD/config/defaults/"
[[ -f "$BUILD/config/controllers.ini" ]] || cp -a "$SRC/config/defaults/controllers.ini" "$BUILD/config/"
if [[ ! -f "$BUILD/config/graphics.ini" ]]; then
    sed -e 's/^window = .*/window = fullscreen/' -e 's/^height = .*/height = 800/' \
        -e 's/^resolution_scale = .*/resolution_scale = 1.0/' \
        "$SRC/config/defaults/graphics.ini" > "$BUILD/config/graphics.ini"
fi
install -m 755 "$GAME_DIR/deck-launch.sh" "$BUILD/deck-launch.sh"

check_absolute_paths
LAUNCHER_SKIP_LIBS=deps/python write_steamdeck_launcher deck-launch.sh

finish_build
log "En la Deck: añade 'steamdeck.sh' a Steam como juego no de Steam (sin Proton)."
