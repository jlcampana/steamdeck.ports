#!/usr/bin/env bash
# Dead or Alive 4 Online, versión NATIVA de Linux (sin Proton): compila el
# código de la release (no publica binario de Linux) con el ReXGlue SDK en el
# commit de netplay_sdk.txt, en Ubuntu 24.04 + clang 23 (contenedor,
# games/doa4-linux/Dockerfile), y pone al lado el juego extraído en game/.
# Resultado: games/doa4-linux/build (dead_or_alive_4, librexruntime.so,
# game/ y steamdeck.sh).
#
# La compilación se hace en games/doa4-linux/work/ (src/ = copia de latest/,
# rexglue-sdk/ y los objetos), que se conserva: si falla o se corta, se sigue
# donde iba, y una versión nueva solo recompila lo que cambie. La primera vez
# tarda ~40 min aquí con -j 2 (upstream da hasta 4 h en su CI) y cada archivo
# grande del código recompilado pide varios GB de RAM: DOA4_JOBS (2 por defecto).
#
# Un build propio se identifica como «dev»: online solo juega con este mismo
# build, no con la release de Windows (para eso, el juego doa4 con Proton).
#
# Uso: games/doa4-linux/build.sh [-f] [ruta.iso]
#   -f          build limpio (el anterior pasa a build.old/; work/ se conserva)
#   -h, --help  muestra esta ayuda
#   ruta.iso    por defecto isos/DOA4.iso (Dead or Alive 4 (USA, Europe) (Rev 1));
#               si games/doa4/build/game ya tiene el juego, se copia de ahí
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

XEX_SHA1="af8011945037b37c98fb8a78d5a4e844dd56c33f"   # docs/BUILDING.md, sección 1
JOBS="${DOA4_JOBS:-2}"
WORK="$GAME_DIR/work"
SRC="$WORK/src"
SDK="$WORK/rexglue-sdk"
OUT="$SRC/out/build/linux-amd64-release"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ISO="$(realpath "${1:-$ISOS/DOA4.iso}")"
DOA4_GAME="$ROOT/games/doa4/build/game"   # el juego ya extraído por games/doa4

require_latest
[[ -f "$DOA4_GAME/default.xex" ]] || { require_file "$ISO"; require_extract_xiso; }

# --- Código: latest/ -> work/src (rsync conserva las fechas: ninja solo
# recompila lo que cambia entre versiones) ---
mkdir -p "$WORK"
log "Copiando el código ($(release_tag)) en work/src"
rsync -a --delete --exclude=/out/ "$LATEST/" "$SRC/"

# --- SDK en el commit de netplay_sdk.txt ---
sdk_repo="$(sed -n 's/^repo=//p' "$SRC/netplay_sdk.txt" | tr -d '[:space:]')"
sdk_commit="$(sed -n 's/^commit=//p' "$SRC/netplay_sdk.txt" | tr -d '[:space:]')"
[[ -n "$sdk_repo" && -n "$sdk_commit" ]] || die "netplay_sdk.txt sin repo o commit"
if [[ ! -d "$SDK/.git" ]]; then
    log "Clonando el SDK ($sdk_repo)"
    git clone --filter=blob:none "$sdk_repo" "$SDK"
fi
if [[ "$(git -C "$SDK" rev-parse HEAD)" != "$sdk_commit" ]]; then
    log "SDK -> $sdk_commit"
    git -C "$SDK" cat-file -e "$sdk_commit^{commit}" 2>/dev/null || git -C "$SDK" fetch origin
    git -C "$SDK" checkout -q "$sdk_commit"
fi
git -C "$SDK" submodule update --init --recursive

# --- Compilación (contenedor) ---
# Mismos parámetros que el job de CI de Linux del port.
log "Compilando con -j $JOBS (la primera vez, ~40 min)"
CONTAINER_WORKDIR="$SRC" run_in_container bash -c "
    set -euo pipefail
    cmake --preset linux-amd64-release -DCMAKE_C_COMPILER=clang-23 -DCMAKE_CXX_COMPILER=clang++-23 \
        '-DCMAKE_C_FLAGS=-march=x86-64-v2' '-DCMAKE_CXX_FLAGS=-march=x86-64-v2' -DREXSDK_DIR='$SDK'
    cmake --build --preset linux-amd64-release -- -j $JOBS"
[[ -x "$OUT/dead_or_alive_4" && -f "$OUT/librexruntime.so" ]] \
    || die "No están out/.../dead_or_alive_4 y librexruntime.so"

# --- build/: solo lo necesario para jugar ---
prepare_build "$FORCE"
log "Dejando en build/ el ejecutable, sus .so y las licencias"
find "$BUILD" -mindepth 1 -maxdepth 1 ! -name game ! -name user_data ! -name logs \
    ! -name dead_or_alive_4.toml ! -name .building-tag -exec rm -rf {} +
cp "$OUT/dead_or_alive_4" "$BUILD/"
find "$OUT" -maxdepth 1 -name '*.so*' -exec cp -a {} "$BUILD/" \;
cp "$SRC/LICENSE" "$SRC/THIRD_PARTY_NOTICES.md" "$SRC/README.md" "$SRC/CHANGELOG.md" "$BUILD/"

if [[ -f "$BUILD/game/default.xex" ]]; then
    log "game/ ya contiene default.xex"
elif [[ -f "$DOA4_GAME/default.xex" ]]; then
    log "Copiando el juego extraído de games/doa4/build/game"
    cp -a --reflink=auto "$DOA4_GAME" "$BUILD/game"
else
    log "Extrayendo $(basename "$ISO") en game/ (unos 7 GB)"
    mkdir -p "$BUILD/game"
    "$EXTRACT_XISO" -q -x "$ISO" -d "$BUILD/game"
fi
[[ "$(sha1sum "$BUILD/game/default.xex" | cut -d' ' -f1)" == "$XEX_SHA1" ]] \
    || die "game/default.xex no es el de DOA4 (USA, Europe) (Rev 1) (SHA-1 $XEX_SHA1)"
log "SHA-1 de default.xex correcto"

# Bañadores de DOAX2 (games/doa4-linux/doax2-suits.sh): la caché solo vale
# con la misma versión de DOA4 con que se hicieron.
SUITS="$ROOT/games/doa4-linux/work/doax2_suits"
if [[ -f "$SUITS/manifest.txt" && "$(cat "$SUITS/.release-tag" 2>/dev/null)" == "$(release_tag)" ]]; then
    log "Copiando los trajes de DOAX2 en user_data/doax2_suits"
    rm -rf "$BUILD/user_data/doax2_suits"
    mkdir -p "$BUILD/user_data"
    cp -a --reflink=auto "$SUITS" "$BUILD/user_data/doax2_suits"
    rm -f "$BUILD/user_data/doax2_suits/.release-tag"
else
    log "Sin trajes de DOAX2 de esta versión (games/doa4-linux/doax2-suits.sh y otro build)"
fi

check_absolute_paths
# Ajustes (dead_or_alive_4.toml) y logs/ van junto al ejecutable; partidas y
# caché de shaders, a user_data/ (si no, a ~/.local/share/dead_or_alive_4).
# Con --game_data_root no sale la pantalla de configuración.
write_steamdeck_launcher dead_or_alive_4
sed -i 's|^exec "$HERE/dead_or_alive_4"|exec "$HERE/dead_or_alive_4" --game_data_root="$HERE/game" --user_data_root="$HERE/user_data"|' \
    "$BUILD/steamdeck.sh"
grep -q -- '--game_data_root' "$BUILD/steamdeck.sh" || die "No se pudo añadir --game_data_root a steamdeck.sh"
finish_build
