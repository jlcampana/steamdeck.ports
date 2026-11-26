#!/usr/bin/env bash
# Lollipop Chainsaw Recomp, versión NATIVA de Linux (sin Proton). El port solo
# publica un lanzador de Windows (WPF) que compila el juego en el PC del
# jugador con MSVC/LLVM; no hay versión ni guía de Linux. Aquí se hace lo
# mismo que sus scripts (build-sdk.ps1, build.ps1) en Ubuntu 24.04 + clang 20
# (contenedor, games/lollipop-chainsaw/Dockerfile), con un parche nuestro
# que porta a Linux las partes de Windows del código del juego.
#
#   1. latest/ (código de la última release, @source) -> work/src
#      + games/lollipop-chainsaw/patches/game/*.patch (nuestros: Linux)
#   2. SDK rexglue/rexglue-sdk v0.11.0 en el commit que fija el port
#      (scripts/sdk-package.ps1) + sus 5 parches (patches/*.patch del port)
#      + los nuestros (patches/rexglue-sdk/*.patch: fibras y /dev/shm);
#      cabeceras de Vulkan 1.4.313 y VMA 3.3.0 en los commits del port
#   3. work/game = el disco extraído (default.xex con el SHA-256 del port)
#   4. rexglue codegen -> work/src/out/generated (no va en la release)
#   5. el juego: cmake -> work/src/out/build/linux-release/lollipop
#
# work/ se conserva entre builds (si falla, se sigue donde iba). El código
# generado sale del disco: no se publica nunca.
# Resultado: games/lollipop-chainsaw/build (lollipop, sus .so, game/,
# steamdeck.sh). Partidas y ajustes en user/, cachés en cache/.
#
# Uso: games/lollipop-chainsaw/build.sh [-f] [ruta.iso]
#   -f          build limpio (el anterior pasa a build.old/; work/ se conserva)
#   -h, --help  muestra esta ayuda
#   ruta.iso    por defecto isos/LollipopChainsaw.iso (disco retail, title
#               ID 565707D0)
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

XEX_SHA256="a687f47d537b011600146c665e59f5d2b4d4243284799d84fee7da45cdd2df26"
SDK_URL="https://github.com/rexglue/rexglue-sdk.git"
VULKAN_COMMIT="409c16be502e39fe70dd6fe2d9ad4842ef2c9a53"  # vulkan-sdk-1.4.313.0
VMA_COMMIT="1d8f600fd424278486eade7ed3e877c99f0846b1"     # v3.3.0
JOBS="${LOLLIPOP_JOBS:-4}"
WORK="$GAME_DIR/work"
SRC="$WORK/src"
GAME="$WORK/game"
SDK="$WORK/rexglue-sdk"
SDK_BUILD="$SDK/out/build/linux-release"
SDK_INSTALL="$SDK/out/install/linux-release"
OUT="$SRC/out/build/linux-release"
CLANG=20   # LLVM 20.1.8 es el que usa el port en Windows
CC_FLAGS=(-DCMAKE_C_COMPILER=clang-$CLANG -DCMAKE_CXX_COMPILER=clang++-$CLANG
          '-DCMAKE_C_FLAGS=-march=x86-64-v2' '-DCMAKE_CXX_FLAGS=-march=x86-64-v2')

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ISO="$(realpath "${1:-$ISOS/LollipopChainsaw.iso}")"

require_latest
[[ -f "$GAME/default.xex" ]] || { require_file "$ISO"; require_extract_xiso; }
TAG="$(release_tag)"
mkdir -p "$WORK"

# --- 1. Código del juego + parches nuestros ---
shopt -s nullglob
game_patches=("$GAME_DIR"/patches/game/*.patch)
src_stamp="$TAG $(cat /dev/null "${game_patches[@]}" | sha256sum | cut -d' ' -f1)"
if [[ "$(cat "$SRC/.steamdeck-ports-stamp" 2>/dev/null)" != "$src_stamp" ]]; then
    log "Copiando el código ($TAG) en work/src y aplicando nuestros parches"
    rsync -a --delete --exclude=/out/ --exclude=/.git/ "$LATEST/" "$SRC/"
    for p in "${game_patches[@]}"; do
        log "Juego: parche $(basename "$p")"
        git -C "$SRC" apply "$p"
    done
    echo "$src_stamp" > "$SRC/.steamdeck-ports-stamp"
fi

# --- 2. SDK en el commit del port + sus parches + los nuestros ---
sdk_commit="$(sed -n "/function Get-SdkCommit/,/}/s/.*'\([0-9a-f]\{40\}\)'.*/\1/p" "$SRC/scripts/sdk-package.ps1")"
[[ "$sdk_commit" =~ ^[0-9a-f]{40}$ ]] || die "No se encuentra el commit del SDK en scripts/sdk-package.ps1"
mapfile -t port_patches < <(sed -n "/function Get-SdkPatches/,/}/p" "$SRC/scripts/sdk-package.ps1" \
    | grep -o "'[^']*\.patch'" | tr -d "'")
(( ${#port_patches[@]} )) || die "No se encuentran los parches del SDK en scripts/sdk-package.ps1"
our_patches=("$GAME_DIR"/patches/rexglue-sdk/*.patch)
patch_sum="$(cd "$SRC/patches" && cat /dev/null "${port_patches[@]}" "${our_patches[@]}" | sha256sum | cut -d' ' -f1)"
sdk_stamp="$sdk_commit $patch_sum"
if [[ "$(cat "$SDK/.steamdeck-ports-stamp" 2>/dev/null)" != "$sdk_stamp" ]]; then
    if [[ ! -d "$SDK/.git" ]]; then
        log "Clonando el SDK (rexglue/rexglue-sdk)"
        git clone --filter=blob:none "$SDK_URL" "$SDK"
    fi
    log "SDK -> $sdk_commit + ${#port_patches[@]} parches del port + ${#our_patches[@]} nuestros"
    git -C "$SDK" reset -q --hard
    git -C "$SDK" clean -qfdx -e /out/
    git -C "$SDK" cat-file -e "$sdk_commit^{commit}" 2>/dev/null || git -C "$SDK" fetch origin
    git -C "$SDK" checkout -q "$sdk_commit"
    git -C "$SDK" submodule foreach -q --recursive 'git reset -q --hard; git clean -qfdx'
    # Los submódulos que baja build-sdk.ps1
    git -C "$SDK" submodule update --init --depth 1 --jobs 8 \
        thirdparty/cli11 thirdparty/libmspack thirdparty/FFmpeg thirdparty/tomlplusplus \
        thirdparty/simde thirdparty/xxHash thirdparty/spdlog thirdparty/imgui thirdparty/sdl3 \
        thirdparty/tlsf thirdparty/excrypt thirdparty/glslang thirdparty/inja
    for p in "${port_patches[@]}"; do git -C "$SDK" apply "$SRC/patches/$p"; done
    for p in "${our_patches[@]}"; do
        log "SDK: parche nuestro $(basename "$p")"
        git -C "$SDK" apply "$p"
    done
    echo "$sdk_stamp" > "$SDK/.steamdeck-ports-stamp"
fi
pinned_repo() {  # carpeta url commit
    if [[ "$(git -C "$1" rev-parse HEAD 2>/dev/null)" != "$3" ]]; then
        rm -rf "$1"
        git init -q "$1"
        git -C "$1" fetch -q --depth 1 "$2" "$3"
        git -C "$1" checkout -q FETCH_HEAD
    fi
}
pinned_repo "$WORK/vulkan-headers" https://github.com/KhronosGroup/Vulkan-Headers.git "$VULKAN_COMMIT"
pinned_repo "$WORK/vma" https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator.git "$VMA_COMMIT"

# --- 3. Disco extraído ---
if [[ ! -f "$GAME/default.xex" ]]; then
    log "Extrayendo $(basename "$ISO") en work/game (unos 8 GB)"
    rm -rf "$GAME" "$GAME.part"
    mkdir -p "$GAME.part"
    "$EXTRACT_XISO" -q -x "$ISO" -d "$GAME.part"
    mv "$GAME.part" "$GAME"
fi
[[ "$(sha256sum "$GAME/default.xex" | cut -d' ' -f1)" == "$XEX_SHA256" ]] \
    || die "default.xex no es el que admite el port (SHA-256 $XEX_SHA256)"
log "SHA-256 de default.xex correcto"

# Manifiesto de codegen con las rutas de aquí (Write-CodegenManifest de build.ps1)
mkdir -p "$OUT"
sed -e "s|^game_root *=.*|game_root = \"$GAME\"|" \
    -e "s|^file_path *=.*|file_path = \"$GAME/default.xex\"|" \
    -e "s|^out_directory_path *=.*|out_directory_path = \"$SRC/out/generated\"|" \
    "$SRC/lollipop_manifest.toml" > "$OUT/codegen.toml.new"
cmp -s "$OUT/codegen.toml.new" "$OUT/codegen.toml" 2>/dev/null \
    && rm "$OUT/codegen.toml.new" || mv "$OUT/codegen.toml.new" "$OUT/codegen.toml"

# --- 4 y 5. SDK, codegen y juego (contenedor) ---
log "Compilando SDK, código generado y juego con -j $JOBS"
CONTAINER_WORKDIR="$SRC" run_in_container bash -c "
    set -euo pipefail
    cmake -S '$SDK' -B '$SDK_BUILD' -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX='$SDK_INSTALL' ${CC_FLAGS[*]@Q} -DCMAKE_CXX_STANDARD=23 \
        -DREXGLUE_ENABLE_TRACY=OFF -DREXGLUE_BUILD_TESTS=OFF -DREXGLUE_REGISTER_PACKAGE=OFF \
        -DCMAKE_EXPORT_NO_PACKAGE_REGISTRY=ON \
        -DVulkan_INCLUDE_DIR='$WORK/vulkan-headers/include' \
        -DREXGLUE_VMA_INCLUDE_DIR='$WORK/vma/include'
    cmake --build '$SDK_BUILD' --target install --parallel $JOBS
    '$SDK_INSTALL/bin/rexglue' codegen '$OUT/codegen.toml'
    cmake -S '$SRC' -B '$OUT' -G Ninja -DCMAKE_BUILD_TYPE=Release ${CC_FLAGS[*]@Q} \
        -DCMAKE_PREFIX_PATH='$SDK_INSTALL' -Drexglue_DIR='$SDK_INSTALL/lib/cmake/rexglue' \
        -DLOLLIPOP_GAME_DIR='$GAME' -DLOLLIPOP_GENERATED_DIR='$SRC/out/generated' \
        -DLOLLIPOP_MANIFEST='$OUT/codegen.toml' -DBUILD_TESTING=OFF \
        -DVulkan_INCLUDE_DIR='$WORK/vulkan-headers/include'
    cmake --build '$OUT' --parallel $JOBS"
BIN="$OUT/lollipop"
[[ -x "$BIN" ]] || die "No está el ejecutable lollipop en work/src/out/build/linux-release"

# --- build/: solo lo necesario para jugar ---
prepare_build "$FORCE"
log "Dejando en build/ el ejecutable, sus .so y las licencias"
find "$BUILD" -mindepth 1 -maxdepth 1 ! -name game ! -name user ! -name cache \
    ! -name .building-tag -exec rm -rf {} +
cp "$BIN" "$BUILD/lollipop"
find "$OUT" "$SDK_INSTALL/lib" -maxdepth 1 -name '*.so*' -exec cp -an {} "$BUILD/" \; 2>/dev/null || true
for f in shader-precompile-v1.ready recomp-version.txt; do
    [[ -f "$OUT/$f" ]] && cp "$OUT/$f" "$BUILD/"
done
cp "$SRC/LICENSE" "$SRC/THIRD_PARTY.md" "$SRC/README.md" "$BUILD/"
# Licencias del SDK y sus dependencias (lo que copia build-sdk.ps1 a licenses/)
mkdir -p "$BUILD/licenses/rexglue" "$BUILD/licenses/lollipop-patches"
cp "$SDK/LICENSE" "$BUILD/licenses/rexglue/"
for dep in "$SDK"/thirdparty/*/; do
    files=("$dep"LICENSE* "$dep"COPYING* "$dep"COPYRIGHT* "$dep"UNLICENSE*)
    (( ${#files[@]} )) || continue
    mkdir -p "$BUILD/licenses/$(basename "$dep")"
    cp "${files[@]}" "$BUILD/licenses/$(basename "$dep")/"
done
for dep in vulkan-headers vma; do
    mkdir -p "$BUILD/licenses/$dep"
    cp "$WORK/$dep"/LICENSE* "$BUILD/licenses/$dep/" 2>/dev/null || true
done
cp "$SRC"/patches/LICENSE.* "$SRC"/patches/*LICENSE*.txt "$BUILD/licenses/lollipop-patches/" 2>/dev/null || true
cp "$GAME_DIR"/patches/game/*.patch "$GAME_DIR"/patches/rexglue-sdk/*.patch "$BUILD/licenses/lollipop-patches/"
if [[ ! -f "$BUILD/game/default.xex" ]]; then
    log "Copiando el juego (reflink) en build/game"
    rm -rf "$BUILD/game"
    cp -a --reflink=auto "$GAME" "$BUILD/game"
fi
mkdir -p "$BUILD/user" "$BUILD/cache"
# Fuente del menú de ajustes (en Windows, Arial Bold): Liberation Sans Bold
# (SIL OFL 1.1, mismas medidas), la del PC; platform::menu_font() la busca
# en fonts/ antes que en el sistema.
font=/usr/share/fonts/liberation-sans-fonts/LiberationSans-Bold.ttf
if [[ -f "$font" ]]; then
    mkdir -p "$BUILD/fonts"
    cp "$font" "$BUILD/fonts/"
    cp /usr/share/licenses/liberation-sans-fonts/LICENSE "$BUILD/fonts/LICENSE-LiberationSans" 2>/dev/null || true
else
    log "AVISO: no está $font; el menú de ajustes usará una fuente del sistema"
fi

check_absolute_paths
write_steamdeck_launcher lollipop
# Las rutas que pasa el lanzador de Windows (Installer.cs), con las de esta
# instalación: disco, partidas y ajustes (user/), cachés (cache/). Vulkan
# (en Linux no hay D3D12).
python3 - "$BUILD/steamdeck.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
a = 'exec "$HERE/lollipop" "$@"\n'
assert s.count(a) == 1, "steamdeck.sh inesperado"
open(p, "w").write(s.replace(a, 'exec "$HERE/lollipop" --game_data_root="$HERE/game" '
    '--user_data_root="$HERE/user" --cache_root="$HERE/cache" --lollipop_gpu_backend=vulkan "$@"\n'))
PY
bash -n "$BUILD/steamdeck.sh"
finish_build
log "En la Deck: añade 'steamdeck.sh' a Steam como juego no de Steam (sin Proton)."
