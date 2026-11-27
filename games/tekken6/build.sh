#!/usr/bin/env bash
# Tekken 6 Recomp, versión NATIVA de Linux (Vulkan). El port solo publica un
# builder de Windows; la versión Linux está en la rama main (ports.tsv:
# @branch:main) y se compila aquí como hace su tools/build_linux.sh, pero en
# Ubuntu 24.04 + clang 19 (contenedor, games/tekken6/Dockerfile):
#
#   1. latest/ (el código de main) -> work/src
#   2. SDK rexglue/rexglue-sdk en el commit fijado por el port
#      (BASE_REVISION de tools/apply_rexglue_patches.py) + su parche
#      (patches/rexglue/0001-tekken6-runtime.patch) + los nuestros de
#      games/tekken6/patches/rexglue-sdk (fibras, /dev/shm, RenderDoc: los de
#      doax2-linux; sin el de /dev/shm cada partida deja 4,8 GB en /dev/shm)
#   3. work/src/game = el disco extraído (Default.xex de Europa/USA Rev 1)
#   4. SDK, codegen (tekken6_codegen) y juego (tekken6), con FMA3 (la CPU de
#      la Deck lo tiene)
#
# work/ se conserva entre builds (si falla, se sigue donde iba). El código
# generado sale del disco: no se publica nunca.
# Resultado: games/tekken6/build (bin/, tools/run_linux.sh, game/, steamdeck.sh),
# como el «app folder» de su tools/package_linux.py.
#
# Uso: games/tekken6/build.sh [-f] [ruta.iso]
#   -f          build limpio (el anterior pasa a build.old/; work/ se conserva)
#   -h, --help  muestra esta ayuda
#   ruta.iso    por defecto isos/Tekken6.iso
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

XEX_SHA256="ee138a4fe8d32a0edc131451377f4377041a49626153fa992db24f5420a7f15c"
JOBS="${TEKKEN6_JOBS:-2}"
WORK="$GAME_DIR/work"
SRC="$WORK/src"
SDK="$SRC/third_party/rexglue-sdk"
OUT="$SRC/build/linux-amd64"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ISO="$(realpath "${1:-$ISOS/Tekken6.iso}")"

require_latest
require_file "$ISO"
require_extract_xiso
TAG="$(release_tag)"

# --- 1. Código ---
mkdir -p "$WORK"
log "Copiando el código ($TAG) en work/src"
rsync -a --delete --exclude=/build/ --exclude=/generated/default/ --exclude=/game/ \
    --exclude=/third_party/rexglue-sdk/ --exclude=/user/ --exclude=/cache/ --exclude=/logs/ \
    "$LATEST/" "$SRC/"

# --- 2. SDK en el commit fijado + parche del port ---
sdk_commit="$(sed -n 's/^BASE_REVISION = "\([0-9a-f]\{40\}\)"$/\1/p' "$SRC/tools/apply_rexglue_patches.py")"
[[ -n "$sdk_commit" ]] || die "No se encuentra BASE_REVISION en tools/apply_rexglue_patches.py"
patch_file="$SRC/patches/rexglue/0001-tekken6-runtime.patch"
our_patches=("$GAME_DIR"/patches/rexglue-sdk/*.patch)
sdk_stamp="$sdk_commit $(cat "$patch_file" "${our_patches[@]}" | sha256sum | cut -d' ' -f1)"
if [[ "$(cat "$WORK/.sdk-stamp" 2>/dev/null)" != "$sdk_stamp" ]]; then
    if [[ ! -d "$SDK/.git" ]]; then
        log "Clonando el SDK (rexglue/rexglue-sdk)"
        rm -rf "$SDK"
        git clone --filter=blob:none https://github.com/rexglue/rexglue-sdk.git "$SDK"
    fi
    log "SDK -> $sdk_commit + parche de tekken6"
    git -C "$SDK" reset -q --hard
    git -C "$SDK" clean -qfdx
    git -C "$SDK" cat-file -e "$sdk_commit^{commit}" 2>/dev/null || git -C "$SDK" fetch origin
    git -C "$SDK" checkout -q "$sdk_commit"
    git -C "$SDK" submodule update --init --recursive
    python3 "$SRC/tools/apply_rexglue_patches.py" --sdk "$SDK"
    for p in "${our_patches[@]}"; do
        log "SDK: parche nuestro $(basename "$p")"
        git -C "$SDK" apply "$p"
    done
    echo "$sdk_stamp" > "$WORK/.sdk-stamp"
fi

# --- 3. Disco extraído ---
if [[ ! -f "$SRC/game/Default.xex" && ! -f "$SRC/game/default.xex" ]]; then
    rm -rf "$SRC/game"
    log "Extrayendo $(basename "$ISO") en work/src/game"
    mkdir -p "$SRC/game"
    "$EXTRACT_XISO" -q -x "$ISO" -d "$SRC/game"
fi
xex="$SRC/game/Default.xex"; [[ -f "$xex" ]] || xex="$SRC/game/default.xex"
[[ "$(sha256sum "$xex" | cut -d' ' -f1)" == "$XEX_SHA256" ]] \
    || die "Default.xex no es el que admite el port (Europa/USA Rev 1, SHA-256 $XEX_SHA256)"
log "SHA-256 de Default.xex correcto"

# --- 4. SDK, codegen y juego (contenedor) ---
log "Compilando SDK, código generado y juego con -j $JOBS"
CONTAINER_WORKDIR="$SRC" run_in_container bash -c "
    set -euo pipefail
    cd '$SRC'
    [[ -f game/Default.xex || ! -f game/default.xex ]] || ln -s default.xex game/Default.xex
    cmake -S . -B '$OUT' -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=clang-19 -DCMAKE_CXX_COMPILER=clang++-19 \
        -DCMAKE_CXX_FLAGS=-mssse3 -DTEKKEN6_ENABLE_FMA3=ON \
        -DREXGLUE_USE_D3D12=OFF -DREXGLUE_USE_VULKAN=ON \
        -DREXGLUE_ENABLE_TRACY=OFF -DREXGLUE_ENABLE_PERF_COUNTERS=OFF \
        -DREXGLUE_RECOMP_DEBUG_INFO=none
    cmake --build '$OUT' --target rexglue rexruntime rexgpu-xenos --parallel $JOBS
    cmake --build '$OUT' --target tekken6_codegen --parallel $JOBS
    cmake -S . -B '$OUT'
    cmake --build '$OUT' --target tekken6 --parallel $JOBS"
for f in tekken6 librexruntime.so librexgpu-xenos.so; do
    [[ -f "$OUT/$f" ]] || die "Falta $f en work/src/build/linux-amd64"
done

# --- build/: lo mismo que tools/package_linux.py ---
prepare_build "$FORCE"
log "Dejando en build/ el ejecutable, sus .so, run_linux.sh y el juego"
find "$BUILD" -mindepth 1 -maxdepth 1 ! -name game ! -name user ! -name cache ! -name logs \
    ! -name .building-tag -exec rm -rf {} +
mkdir -p "$BUILD/bin" "$BUILD/tools"
cp "$OUT/tekken6" "$OUT/librexruntime.so" "$OUT/librexgpu-xenos.so" "$BUILD/bin/"
install -m 755 "$SRC/tools/run_linux.sh" "$BUILD/tools/run_linux.sh"
cp "$SRC/README.md" "$SRC/VERSION.txt" "$BUILD/"
[[ -f "$SRC/LICENSE" ]] && cp "$SRC/LICENSE" "$BUILD/"
if [[ ! -f "$BUILD/game/Default.xex" && ! -f "$BUILD/game/default.xex" ]]; then
    log "Copiando el juego (reflink) en build/game"
    rm -rf "$BUILD/game"
    cp -a --reflink=auto "$SRC/game" "$BUILD/game"
fi

check_absolute_paths
# run_linux.sh hace cd a su carpeta padre (build/): --build-dir relativo.
# Pantalla completa (en el modo Juego la pone gamescope igualmente).
write_steamdeck_launcher tools/run_linux.sh --build-dir bin --fullscreen
finish_build
