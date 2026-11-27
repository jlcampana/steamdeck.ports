#!/usr/bin/env bash
# Bayonetta 3 (Switch, B3-Express): versión Linux nativa compilada aquí. La
# release solo trae el lanzador de Windows, que compila el juego en el PC
# del jugador con ScarletNX (recompilador estático de Switch, en source/ del
# repo con los cambios de B3-Express). ScarletNX compila en Linux: aquí se
# hace lo mismo que el lanzador, sin él.
#   1. tools/switch-dump.sh: exefs/, romfs/ con la update 1.2.0 y control/
#      del .xci (o .nsp) y la update, con hactool y las claves del usuario
#      → work/dump (se rehace solo si cambian los archivos del juego). Los
#      .nca intermedios (~17 GB) van a BAYONETTA3_TMP.
#   2. source/ → work/src + patches/source/*.patch (nuestros) y ScarletNX
#      compilado en el contenedor (games/bayonetta3/Dockerfile: clang y LLVM
#      23; SDL3, FFmpeg y OpenSSL los compila CMake) → work/src/build.
#   3. scarletnx -r con el exefs, como build_code() del lanzador: nombre
#      Bayo3_120, -O 1, sus listas de direcciones de la 1.2.0 (pistas,
#      tablecalls, insnhooks) y SNX_RECOMPILE_PORTABLE=1 (código para
#      cualquier x86-64-v3 con AES: la Deck; el lanzador lo hace para la
#      CPU del PC) → work/out/Bayo3_120.
#   4. build/: Bayo3_120/ (runtime, código, datos con la romfs por reflink,
#      ajustes para la Deck) y deck-launch.sh.
# Las claves no van en el paquete (el juego no las usa).
#
# Uso: games/bayonetta3/build.sh [-f] [carpeta]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   carpeta     con el juego (.xci o .nsp [v0]) y la update 1.2.0 (.nsp
#               [v131072]); por defecto "isos/Bayonetta 3"
# Variables:
#   SWITCH_KEYS=<prod.keys>  claves (por defecto la primera prod.keys de la
#                            carpeta o de isos/*/)
#   BAYONETTA3_TMP=<dir>     para los .nca intermedios (por defecto work/tmp)
#   BAYONETTA3_JOBS=N        procesos del compilador (por defecto nproc)
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
SRC_DIR="$(realpath "${1:-$ISOS/Bayonetta 3}")"
first() { local f; for f in "$@"; do [[ -e "$f" ]] && { echo "$f"; return; }; done; echo "$1"; }
BASE="$(first "$SRC_DIR"/*\[01004A4010FEA000\]*.xci "$SRC_DIR"/*\[01004A4010FEA000\]*.nsp)"
UPD="$(first "$SRC_DIR"/*\[01004A4010FEA800\]*\[v131072\]*.nsp)"
KEYS="${SWITCH_KEYS:-$(first "$SRC_DIR/prod.keys" "$ISOS"/*/prod.keys)}"
WORK="$GAME_DIR/work"
TMP="${BAYONETTA3_TMP:-$WORK/tmp}"
JOBS="${BAYONETTA3_JOBS:-$(nproc)}"
NAME=Bayo3_120  # el nombre que usa el lanzador (B3_GAME_DIR, partidas)

require_latest
require_file "$BASE"
require_file "$UPD"
require_file "$KEYS"
[[ -x "$ROOT/tools/bin/hactool" ]] || die "Falta hactool: tools/install.sh"
command -v python3 >/dev/null || die "Falta python3"

prepare_build "$FORCE"
mkdir -p "$WORK"

# --- 1. Dump ---
DUMP="$WORK/dump"
dump_id="$(stat -c '%n %s %Y' "$BASE" "$UPD" | sha256sum | cut -c1-16)"
if [[ "$(cat "$DUMP/.steamdeck-ports-dump" 2>/dev/null)" != "$dump_id" ]]; then
    log "Extrayendo el juego con la update 1.2.0 (~7 min; .nca temporales en $TMP)"
    rm -rf "$DUMP"
    mkdir -p "$TMP"
    "$ROOT/tools/switch-dump.sh" "$DUMP" "$TMP" "$KEYS" "$BASE" "$UPD"
    echo "$dump_id" > "$DUMP/.steamdeck-ports-dump"
fi
# Lo mismo que comprueba el lanzador (game-files.txt: tamaño y SHA-256 de
# exefs; tamaño de la romfs), sin rechazar: solo avisa.
python3 - "$LATEST/game-files.txt" "$DUMP" <<'EOF' || log "AVISO: el juego no es exactamente la 1.2.0 (ver arriba)"
import hashlib, os, sys
bad = []
for line in open(sys.argv[1]):
    size, digest, path = line.rstrip('\n').split(' ', 2)
    p = os.path.join(sys.argv[2], path)
    if not os.path.isfile(p) or os.path.getsize(p) != int(size):
        bad.append(path)
    elif path.startswith('exefs/') and hashlib.sha256(open(p, 'rb').read()).hexdigest() != digest:
        bad.append(path)
for b in bad[:10]:
    print('  distinto o falta:', b)
sys.exit(1 if bad else 0)
EOF

# --- 2. ScarletNX ---
SRC="$WORK/src"
patches=()
shopt -s nullglob
patches=("$GAME_DIR"/patches/source/*.patch)
shopt -u nullglob
stamp="$( (cat "$LATEST/.release-tag"; cat /dev/null "${patches[@]}") | sha256sum | cut -c1-16)"
if [[ "$(cat "$SRC/.steamdeck-ports-stamp" 2>/dev/null)" != "$stamp" ]]; then
    log "Copiando source/ a work/src y aplicando nuestros parches"
    mkdir -p "$SRC"
    # build/ y .cache/ (CMake y sus descargas) se conservan: solo se
    # recompila lo que cambia.
    rsync -a --delete --exclude=/build/ --exclude=/.cache/ --exclude=/.git/ \
        --exclude=/.steamdeck-ports-stamp "$LATEST/source/" "$SRC/"
    # Repo git con el código original (commit «base») para sacar los parches
    # con git diff.
    rm -rf "$SRC/.git"
    git -C "$SRC" init -q
    printf '/build/\n/.cache/\n/.steamdeck-ports-stamp\n' > "$SRC/.git/info/exclude"
    git -C "$SRC" add -A
    git -C "$SRC" -c user.name=base -c user.email=base@localhost commit -q -m base
    for p in "${patches[@]}"; do
        log "  $(basename "$p")"
        git -C "$SRC" apply "$p"
    done
    echo "$stamp" > "$SRC/.steamdeck-ports-stamp"
fi
# LLVM enlazado estático (llvm-config-static) y --as-needed: así el runtime
# del juego (una copia de scarletnx) solo depende de libc, libstdc++, zlib y
# zstd. Con la libLLVM-23 compartida no arrancaría en SteamOS (trae otra
# versión), y llvm-config pide además libz3 y libxml2.so.2, que no usa.
# Sin tests (uno de B3-Express no enlaza libm), ni 3DS, ni el runtime de
# AArch64, ni el menú gráfico (SDL3).
log "Compilando ScarletNX en el contenedor (la primera vez ~25 min)"
CONTAINER_WORKDIR="$SRC" run_in_container bash -c "
    set -e
    cmake --preset default -B build -DCMAKE_C_COMPILER=clang-23 -DCMAKE_CXX_COMPILER=clang++-23 \
        -DSNX_LLVM_CONFIG='$GAME_DIR/llvm-config-static' -DBUILD_TESTING=OFF -DSNX_BUILD_3DS=OFF \
        -DSNX_BUILD_GNUABI=OFF -DSNX_BUILD_GUI=OFF -DSNX_DEPLOY=OFF \
        -DCMAKE_EXE_LINKER_FLAGS=-Wl,--as-needed >/dev/null
    cmake --build build -j $JOBS"
[[ -x "$SRC/build/scarletnx" ]] || die "No se ha compilado ScarletNX"
if ldd "$SRC/build/scarletnx" | grep -q -E 'libLLVM|libz3|libxml2|not found'; then
    ldd "$SRC/build/scarletnx" >&2
    die "scarletnx depende de librerías que SteamOS no tiene (arriba)"
fi

# --- 3. Código del juego ---
log "Traduciendo y compilando el código del juego (scarletnx -r; ~1 h con 4 núcleos)"
rm -rf "$WORK/input" "$WORK/out" "$WORK/repo"
mkdir -p "$WORK/input" "$WORK/out/$NAME" "$WORK/repo"
cp -a "$DUMP/exefs" "$WORK/input/"
cp "$LATEST/launcher/code-hints.txt" "$WORK/out/$NAME/$NAME.hints"
cp "$LATEST/launcher/code-tablecalls.txt" "$WORK/out/$NAME/$NAME.tablecalls"
cp "$LATEST/launcher/code-insnhooks.txt" "$WORK/out/$NAME/$NAME.insnhooks"
CONTAINER_WORKDIR="$WORK" run_in_container env SNX_RECOMPILE_PORTABLE=1 \
    src/build/scarletnx -r input --name "$NAME" --outdir out --repo repo \
    --runtime src/build/scarletnx --jobs "$JOBS" -O 1 --cache code_cache 2>&1 \
    | tee "$WORK/recomp.log" | grep -v 'compiled block'
OUTG="$WORK/out/$NAME"
for f in "$NAME" "${NAME}_code.so" "$NAME.abi"; do
    [[ -f "$OUTG/$f" ]] || die "scarletnx -r no dejó $f (ver $WORK/recomp.log)"
done

# --- 4. Carpeta del juego ---
log "Montando build/"
G="$BUILD/$NAME"
# Lo del jugador se conserva (ajustes, partidas, caché de shaders, logs).
find "$BUILD" -mindepth 1 -maxdepth 1 ! -name .building-tag ! -name "$NAME" -exec rm -rf {} +
mkdir -p "$G/${NAME}_data"
find "$OUTG" -mindepth 1 -maxdepth 1 ! -name "${NAME}_data" ! -name "$NAME.ini" -exec cp -a {} "$G/" \;
if [[ -d "$OUTG/${NAME}_data" ]]; then
    find "$OUTG/${NAME}_data" -mindepth 1 -maxdepth 1 ! -name save ! -name romfs \
        -exec cp -a {} "$G/${NAME}_data/" \;
fi
rm -rf "$G/${NAME}_data/exefs" "$G/${NAME}_data/romfs"
cp -a "$DUMP/exefs" "$G/${NAME}_data/exefs"
log "Copiando la romfs (reflink si se puede)"
cp -a --reflink=auto "$DUMP/romfs" "$G/${NAME}_data/romfs"
[[ -f "$DUMP/control/control.nacp" ]] && cp "$DUMP/control/control.nacp" "$G/${NAME}_data/"
# Ajustes: los de ScarletNX y, para la Deck, pantalla completa, la escena
# a la resolución de la consola y el difuminado transparente (los que
# recomienda el lanzador: «Smooth 60», «Transparent»).
if [[ ! -f "$G/$NAME.ini" && -f "$OUTG/$NAME.ini" ]]; then
    python3 - "$OUTG/$NAME.ini" "$G/$NAME.ini" <<'EOF'
import re, sys
text = open(sys.argv[1], encoding='utf8').read()
for key, value in (('fullscreen', '1'), ('resolution', '1'), ('fsr', '0'), ('dither', '3')):
    text, n = re.subn(r'(?m)^%s *=.*$' % key, '%s = %s' % (key, value), text)
    if not n:
        text += '\n%s = %s\n' % (key, value)
open(sys.argv[2], 'w', encoding='utf8').write(text)
EOF
fi
install -m 755 "$GAME_DIR/deck-launch.sh" "$BUILD/deck-launch.sh"
cp "$LATEST/LICENSE" "$BUILD/LICENSE"

check_absolute_paths
write_steamdeck_launcher deck-launch.sh

finish_build
log "En la Deck: añade 'steamdeck.sh' a Steam como juego no de Steam (sin Proton)."
