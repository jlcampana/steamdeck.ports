#!/usr/bin/env bash
# Rumble Roses XX Recomp, versión NATIVA de Linux (sin Proton). El port solo
# publica la de Windows (juego ya compilado + lanzador .NET) y su guía de
# build es de Windows, pero el código y el ReXGlue SDK tienen presets de
# Linux: aquí se hace lo mismo que BUILDING.md en Ubuntu 24.04 + clang 20
# (contenedor, games/rumble-roses-xx/Dockerfile):
#
#   1. latest/ (el código de la release) -> work/src
#   2. SDK rexglue/rexglue-sdk v0.10.0 (c94f5eb) + sdk-patch/ del port + los
#      nuestros de games/rumble-roses-xx/patches/rexglue-sdk (fibras,
#      /dev/shm, RenderDoc: los mismos que doax2-linux, mismo SDK); se
#      compila e instala en work/rexglue-sdk/out/install/linux-amd64
#   3. work/src/assets = el disco extraído (codegen lee assets/default.xex)
#   4. el juego (codegen incluido): cmake --preset linux-amd64-release
#
# Sin el renderizador nativo del port (rrxx-native: solo D3D12): en Linux va
# el renderizador emulado del SDK (Vulkan), que en Windows es el de reserva.
#
# work/ se conserva entre builds. El código generado sale del disco: no se
# publica nunca.
# Resultado: games/rumble-roses-xx/build, con la estructura de la release:
# game/ (rumble_roses_xx, sus .so, assets/ y RumbleRosesReX.toml), saves/,
# mods/ y steamdeck.sh.
#
# Uso: games/rumble-roses-xx/build.sh [-f] [ruta.iso]
#   -f          build limpio (el anterior pasa a build.old/; work/ se conserva)
#   -h, --help  muestra esta ayuda
#   ruta.iso    por defecto isos/RumbleRosesXX.iso
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

SDK_COMMIT="c94f5ebdcb3c9d1a460ca48e04f9758448f8d518"   # «Release v0.10.0» (BUILDING.md)
XEX_SHA1="78c5df22b3ed4527cc9f8b1f43321a46b62d9ddf"      # launcher/Xgd.cs
JOBS="${RRXX_JOBS:-2}"
WORK="$GAME_DIR/work"
SRC="$WORK/src"
SDK="$WORK/rexglue-sdk"
SDK_INSTALL="$SDK/out/install/linux-amd64"
OUT="$SRC/out/game"
CC_FLAGS=(-DCMAKE_C_COMPILER=clang-20 -DCMAKE_CXX_COMPILER=clang++-20
          '-DCMAKE_C_FLAGS=-march=x86-64-v2' '-DCMAKE_CXX_FLAGS=-march=x86-64-v2')

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ISO="$(realpath "${1:-$ISOS/RumbleRosesXX.iso}")"

require_latest
require_file "$ISO"
require_extract_xiso
TAG="$(release_tag)"

# --- 1. Código ---
mkdir -p "$WORK"
log "Copiando el código ($TAG) en work/src"
rsync -a --delete --exclude=/out/ --exclude=/generated/default/ --exclude=/assets/ \
    "$LATEST/" "$SRC/"

# --- 2. SDK v0.10.0 + parche del port + los nuestros ---
patch_file="$SRC/sdk-patch/rexglue-sdk-v0.10-all-fixes.patch"
our_patches=("$GAME_DIR"/patches/rexglue-sdk/*.patch)
patch_sum="$(cat "$patch_file" "${our_patches[@]}" | sha256sum | cut -d' ' -f1)"
sdk_stamp="$SDK_COMMIT $patch_sum"
if [[ "$(cat "$SDK/.steamdeck-ports-stamp" 2>/dev/null)" != "$sdk_stamp" ]]; then
    if [[ ! -d "$SDK/.git" ]]; then
        log "Clonando el SDK (rexglue/rexglue-sdk)"
        git clone --filter=blob:none https://github.com/rexglue/rexglue-sdk.git "$SDK"
    fi
    log "SDK -> $SDK_COMMIT + parche de RRXX"
    git -C "$SDK" reset -q --hard
    git -C "$SDK" clean -qfdx -e /out/
    git -C "$SDK" cat-file -e "$SDK_COMMIT^{commit}" 2>/dev/null || git -C "$SDK" fetch origin
    git -C "$SDK" checkout -q "$SDK_COMMIT"
    git -C "$SDK" submodule update --init --recursive
    git -C "$SDK" apply "$patch_file"
    for p in "${our_patches[@]}"; do
        log "SDK: parche nuestro $(basename "$p")"
        git -C "$SDK" apply "$p"
    done
    echo "$sdk_stamp" > "$SDK/.steamdeck-ports-stamp"
fi

# --- 3. Disco extraído (codegen lee assets/default.xex) ---
if [[ ! -f "$SRC/assets/default.xex" ]]; then
    log "Extrayendo $(basename "$ISO") en work/src/assets"
    # latest/assets trae archivos del port (iconos): se conservan
    "$EXTRACT_XISO" -q -x "$ISO" -d "$SRC/assets.tmp"
    cp -a --reflink=auto "$SRC/assets.tmp/." "$SRC/assets/"
    rm -rf "$SRC/assets.tmp"
fi
[[ "$(sha1sum "$SRC/assets/default.xex" | cut -d' ' -f1)" == "$XEX_SHA1" ]] \
    || die "default.xex no es el que admite el port (SHA-1 $XEX_SHA1)"
log "SHA-1 de default.xex correcto"

# --- 4. SDK, codegen y juego (contenedor) ---
log "Compilando SDK, código generado y juego con -j $JOBS"
CONTAINER_WORKDIR="$SRC" run_in_container bash -c "
    set -euo pipefail
    cd '$SDK'
    cmake --preset linux-amd64 -DCMAKE_EXPORT_NO_PACKAGE_REGISTRY=ON ${CC_FLAGS[*]@Q}
    cmake --build out/build/linux-amd64 --config Release --target install --parallel $JOBS
    cd '$SRC'
    cmake --preset linux-amd64-release -B out/game -DCMAKE_PREFIX_PATH='$SDK_INSTALL' ${CC_FLAGS[*]@Q}
    cmake --build out/game --config Release --target rumble_roses_xx_codegen --parallel $JOBS
    if grep -lE 'FATAL: unresolved|REX_FATAL\\(\"Unresolved' generated/default/*.cpp; then
        echo 'El código generado tiene llamadas sin resolver' >&2; exit 1
    fi
    cmake -S . -B out/game
    cmake --build out/game --config Release --parallel $JOBS"
BIN="$(find "$OUT" -type f -name rumble_roses_xx -perm -u+x | head -1)"
[[ -n "$BIN" ]] || die "No está el ejecutable rumble_roses_xx en work/src/out/game"

# --- build/: la estructura de la release ---
prepare_build "$FORCE"
log "Dejando en build/ el ejecutable, sus .so y las licencias"
find "$BUILD" -mindepth 1 -maxdepth 1 ! -name game ! -name saves ! -name mods ! -name logs \
    ! -name .building-tag -exec rm -rf {} +
find "$BUILD/game" -mindepth 1 -maxdepth 1 ! -name assets ! -name RumbleRosesReX.toml \
    -exec rm -rf {} + 2>/dev/null || true
mkdir -p "$BUILD/game" "$BUILD/saves" "$BUILD/mods/costumes"
cp "$BIN" "$BUILD/game/rumble_roses_xx"
find "$(dirname "$BIN")" "$SDK_INSTALL/lib" -maxdepth 1 -name '*.so*' -exec cp -an {} "$BUILD/game/" \; 2>/dev/null || true
cp -r "$SRC/README.md" "$SRC/CREDITS.md" "$SRC/licenses" "$BUILD/"
if [[ ! -f "$BUILD/game/assets/default.xex" ]]; then
    log "Copiando el juego (reflink) en build/game/assets"
    rm -rf "$BUILD/game/assets"
    cp -a --reflink=auto "$SRC/assets" "$BUILD/game/assets"
fi
# Ajustes iniciales: los de la release, con la resolución de la consola
# (720p; la release trae 2 = 1440p, demasiado para la Deck). Se cambian en el
# juego con F4 o Back+Start.
if [[ ! -f "$BUILD/game/RumbleRosesReX.toml" ]]; then
    cat > "$BUILD/game/RumbleRosesReX.toml" <<'EOF'
# Rumble Roses XX Recomp settings.
# Change them in game (F4, or Back+Start on the controller).
resolution_scale = 1
readback_resolve = "some"
EOF
fi

check_absolute_paths
write_steamdeck_launcher game/rumble_roses_xx
finish_build
