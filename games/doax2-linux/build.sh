#!/usr/bin/env bash
# Dead or Alive Xtreme 2 Recomp, versión NATIVA de Linux (sin Proton). El port
# solo publica la de Windows y su guía de build es solo para Windows, pero
# el código y el ReXGlue SDK tienen presets de Linux: aquí se hace lo mismo
# que sus scripts (setup-sdk, build-sdk, generate-code, configure-game) en
# Ubuntu 24.04 + clang 20 (contenedor, games/doax2-linux/Dockerfile).
#
#   1. latest/ (el -source.zip de la release) -> work/src
#   2. SDK rexglue/rexglue-sdk en el commit del submódulo de esa versión
#      (GitHub) + patches/rexglue-sdk/0001-doax2-runtime-changes.patch del port
#      + los nuestros de games/doax2-linux/patches/rexglue-sdk (fibras, /dev/shm);
#      se compila e instala en work/rexglue-sdk/out/install/linux-amd64
#   3. work/src/game = el disco extraído (de games/doax2/build si está)
#   4. rexglue codegen doax2_manifest.toml -> generated/ (no va en la release)
#   5. el juego: cmake --preset linux-amd64-release -B out/game
#
# work/ se conserva entre builds (si falla, se sigue donde iba). El código
# generado sale del disco: no se publica nunca.
# Resultado: games/doax2-linux/build (doax2, sus .so, game/, steamdeck.sh).
#
# Uso: games/doax2-linux/build.sh [-f] [ruta.iso]
#   -f          build limpio (el anterior pasa a build.old/; work/ se conserva)
#   -h, --help  muestra esta ayuda
#   ruta.iso    por defecto isos/DOAX2.iso (disco retail, title ID 544307D2);
#               si games/doax2/build ya tiene el juego extraído, se copia de ahí
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

REPO="hibikifukui22/Dead-or-Alive-Xtreme-2-Recompilation"
XEX_SHA256="c4a14853e1f7af951be34f380604113703638780b36d5e74e674fe7431992870"
JOBS="${DOAX2_JOBS:-2}"
WORK="$GAME_DIR/work"
SRC="$WORK/src"
SDK="$WORK/rexglue-sdk"
SDK_INSTALL="$SDK/out/install/linux-amd64"
OUT="$SRC/out/game"
# clang 20, el del preset linux-amd64 del port (DOAX2_CLANG=23 para probar otro)
CLANG="${DOAX2_CLANG:-20}"
CC_FLAGS=(-DCMAKE_C_COMPILER=clang-$CLANG -DCMAKE_CXX_COMPILER=clang++-$CLANG
          '-DCMAKE_C_FLAGS=-march=x86-64-v2' '-DCMAKE_CXX_FLAGS=-march=x86-64-v2')

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ISO="$(realpath "${1:-$ISOS/DOAX2.iso}")"
DOAX2_GAME="$ROOT/games/doax2/build/extracted game files here"

require_latest
[[ -f "$DOAX2_GAME/default.xex" ]] || { require_file "$ISO"; require_extract_xiso; }
TAG="$(release_tag)"

# --- 1. Código ---
mkdir -p "$WORK"
log "Copiando el código ($TAG) en work/src"
rsync -a --delete --exclude=/out/ --exclude=/generated/ --exclude=/game/ --exclude=/sdk/ \
    "$LATEST/" "$SRC/"

# --- 2. SDK en el commit del submódulo + parche del proyecto ---
api_auth=()
token="${GITHUB_TOKEN:-$(gh auth token 2>/dev/null || true)}"
[[ -n "$token" ]] && api_auth=(-H "Authorization: Bearer $token")
sdk_commit="$(curl -fsSL "${api_auth[@]}" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/contents/sdk/rexglue-sdk?ref=$TAG" | jq -r .sha)"
[[ "$sdk_commit" =~ ^[0-9a-f]{40}$ ]] || die "No se pudo saber el commit del SDK de $TAG"
patch_file="$SRC/patches/rexglue-sdk/0001-doax2-runtime-changes.patch"
# Parches nuestros (games/doax2-linux/patches/rexglue-sdk), después del del port
our_patches=("$GAME_DIR"/patches/rexglue-sdk/*.patch)
patch_sum="$(cat "$patch_file" "${our_patches[@]}" | sha256sum | cut -d' ' -f1)"
sdk_stamp="$sdk_commit $patch_sum"
if [[ "$(cat "$SDK/.steamdeck-ports-stamp" 2>/dev/null)" != "$sdk_stamp" ]]; then
    if [[ ! -d "$SDK/.git" ]]; then
        log "Clonando el SDK (rexglue/rexglue-sdk)"
        git clone --filter=blob:none https://github.com/rexglue/rexglue-sdk.git "$SDK"
    fi
    log "SDK -> $sdk_commit + parche de doax2"
    git -C "$SDK" reset -q --hard
    git -C "$SDK" clean -qfdx -e /out/
    git -C "$SDK" cat-file -e "$sdk_commit^{commit}" 2>/dev/null || git -C "$SDK" fetch origin
    git -C "$SDK" checkout -q "$sdk_commit"
    git -C "$SDK" submodule update --init --recursive
    git -C "$SDK" apply "$patch_file"
    for p in "${our_patches[@]}"; do
        log "SDK: parche nuestro $(basename "$p")"
        git -C "$SDK" apply "$p"
    done
    echo "$sdk_stamp" > "$SDK/.steamdeck-ports-stamp"
fi

# --- 3. Disco extraído (codegen lee game/default.xex) ---
if [[ ! -f "$SRC/game/default.xex" ]]; then
    rm -rf "$SRC/game"
    if [[ -f "$DOAX2_GAME/default.xex" ]]; then
        log "Copiando el juego extraído de games/doax2/build"
        cp -a --reflink=auto "$DOAX2_GAME" "$SRC/game"
    else
        log "Extrayendo $(basename "$ISO") en work/src/game (unos 6 GB)"
        mkdir -p "$SRC/game"
        "$EXTRACT_XISO" -q -x "$ISO" -d "$SRC/game"
    fi
fi
[[ "$(sha256sum "$SRC/game/default.xex" | cut -d' ' -f1)" == "$XEX_SHA256" ]] \
    || die "default.xex no es el que admite el port (SHA-256 $XEX_SHA256)"
log "SHA-256 de default.xex correcto"

# --- 4 y 5. SDK, codegen y juego (contenedor) ---
# Con otro compilador, las carpetas de CMake se rehacen desde cero.
if [[ "$(cat "$WORK/.compilador" 2>/dev/null)" != "clang-$CLANG" ]]; then
    log "Compilador nuevo (clang-$CLANG): se borran las compilaciones anteriores"
    rm -rf "$SDK/out/build" "$SDK/out/install" "$SRC/out"
fi
log "Compilando SDK, código generado y juego con -j $JOBS"
CONTAINER_WORKDIR="$SRC" run_in_container bash -c "
    set -euo pipefail
    cd '$SDK'
    cmake --preset linux-amd64 -DCMAKE_EXPORT_NO_PACKAGE_REGISTRY=ON ${CC_FLAGS[*]@Q}
    cmake --build out/build/linux-amd64 --config Release --target install --parallel $JOBS
    cd '$SRC'
    '$SDK_INSTALL/bin/rexglue' codegen doax2_manifest.toml --ignore-stamp
    if grep -lE 'FATAL: unresolved|REX_FATAL\\(\"Unresolved' generated/default/*.cpp; then
        echo 'El código generado tiene llamadas sin resolver' >&2; exit 1
    fi
    cmake --preset linux-amd64-release -B out/game -DCMAKE_PREFIX_PATH='$SDK_INSTALL' ${CC_FLAGS[*]@Q}
    cmake --build out/game --config Release --parallel $JOBS"
echo "clang-$CLANG" > "$WORK/.compilador"
BIN="$(find "$OUT" -type f -name doax2 -perm -u+x | head -1)"
[[ -n "$BIN" ]] || die "No está el ejecutable doax2 en work/src/out/game"

# --- build/: solo lo necesario para jugar ---
prepare_build "$FORCE"
log "Dejando en build/ el ejecutable, sus .so y las licencias"
find "$BUILD" -mindepth 1 -maxdepth 1 ! -name game ! -name userdata ! -name photos ! -name logs \
    ! -name .building-tag -exec rm -rf {} +
cp "$BIN" "$BUILD/doax2"
find "$(dirname "$BIN")" "$SDK_INSTALL/lib" -maxdepth 1 -name '*.so*' -exec cp -an {} "$BUILD/" \; 2>/dev/null || true
cp "$SRC/LICENSE" "$SRC/THIRD-PARTY-NOTICES.md" "$SRC/README.md" "$SRC/CHANGELOG.md" "$BUILD/"
if [[ ! -f "$BUILD/game/default.xex" ]]; then
    # latest/ trae una carpeta game/ con solo un README.md del port
    log "Copiando el juego (reflink) en build/game"
    rm -rf "$BUILD/game"
    cp -a --reflink=auto "$SRC/game" "$BUILD/game"
fi

check_absolute_paths
write_steamdeck_launcher doax2
# steamdeck.sh: las opciones que pasaría el lanzador de Windows (que aquí no
# hay), con Vulkan. Se pueden cambiar con variables (ver games/doax2-linux/README.md).
python3 - "$BUILD/steamdeck.sh" "$GAME_DIR/launch-options.sh" <<'PY'
import sys
p, opts = sys.argv[1], open(sys.argv[2]).read()
s = open(p).read()
a = 'exec "$HERE/doax2" "$@"\n'
assert s.count(a) == 1, "steamdeck.sh inesperado"
open(p, "w").write(s.replace(a, opts))
PY
bash -n "$BUILD/steamdeck.sh"
install -m 755 "$GAME_DIR/launcher.py" "$BUILD/launcher.py"   # lanzador de opciones
finish_build
