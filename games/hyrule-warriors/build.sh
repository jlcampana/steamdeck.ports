#!/usr/bin/env bash
# Hyrule Warriors: Definitive Edition (Switch, HWDER): la release de Linux no
# trae el juego; su Setup (tools/linux_setup.py prepare) lo compila a partir
# del .nsp y de prod.keys con herramientas propias (Zig/Clang, CMake, Ninja,
# Python; las descarga y comprueba él), sin contenedor y sin nada del
# sistema. Aquí se ejecuta ese mismo paso con XDG_DATA_HOME en
# games/hyrule-warriors/work/ (toolchain y caché de compilación; se
# conservan entre builds), así la Deck no descarga ni compila nada.
# El juego (hwder) lee el .nsp, prod.keys y la update descomprimida en cada
# arranque, así que van en la carpeta del juego: game/base.nsp,
# keys/prod.keys y update/. deck-launch.sh apunta hwder_settings.ini a esas
# rutas y a save/ y mods/ de la instalación (por defecto irían a
# ~/.local/share/HWDER).
# Resultado: games/hyrule-warriors/build (ejecutable: hwder).
#
# Uso: games/hyrule-warriors/build.sh [-f] [nsp [keys [update]]]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   nsp         por defecto el *[Base].nsp de isos/HyruleWarriors/
#   keys        por defecto isos/HyruleWarriors/prod.keys
#   update      por defecto el *[UPD].nsp de isos/HyruleWarriors/ (1.0.1;
#               "-" = sin update, solo el juego base)
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
SRC="$ISOS/HyruleWarriors"
first() { local f; for f in "$@"; do [[ -e "$f" ]] && { echo "$f"; return; }; done; echo "$1"; }
NSP="$(realpath "${1:-$(first "$SRC"/*\[Base\].nsp)}")"
KEYS="$(realpath "${2:-$SRC/prod.keys}")"
UPDATE="${3:-$(first "$SRC"/*\[UPD\].nsp)}"
[[ "$UPDATE" == "-" ]] && UPDATE="" || UPDATE="$(realpath "$UPDATE")"

require_latest
require_file "$NSP"
require_file "$KEYS"
[[ -z "$UPDATE" ]] || require_file "$UPDATE"
command -v python3 >/dev/null || die "Falta python3"

WORK="$GAME_DIR/work"
DATA="$WORK/HWDER"  # lo que el Setup pone en ~/.local/share/HWDER

prepare_build "$FORCE"

log "Compilando el juego con el Setup de HWDER (la primera vez descarga ~200 MB de herramientas)"
log "Juego: $(basename "$NSP")${UPDATE:+; update: $(basename "$UPDATE")}"
mkdir -p "$WORK"
args=(prepare --nsp "$NSP" --keys "$KEYS")
[[ -n "$UPDATE" ]] && args+=(--update "$UPDATE")
# El Setup busca el juego en $XDG_DATA_HOME/HWDER/build/play.
XDG_DATA_HOME="$WORK" python3 "$LATEST/tools/linux_setup.py" "${args[@]}" 2>&1 \
    | tee "$WORK/prepare.log"
PLAY="$DATA/build/play"
[[ -x "$PLAY/hwder" ]] || die "El Setup no dejó $PLAY/hwder (ver $WORK/prepare.log)"

# --- Carpeta del juego: solo lo que hace falta para jugar ---
log "Montando build/ (sin el código del port)"
find "$BUILD" -mindepth 1 -maxdepth 1 ! -name .building-tag ! -name LICENSE \
    ! -name linux-deps ! -name save ! -name mods ! -name hwder_settings.ini \
    ! -name 'pipeline_*.bin' -exec rm -rf {} +
# Licencias de lo que va enlazado en hwder (SDL3, FFmpeg LGPL, OpenSSL).
find "$BUILD/linux-deps" -mindepth 1 -maxdepth 1 ! -name licenses ! -name sources -exec rm -rf {} + 2>/dev/null || true
install -m 755 "$PLAY/hwder" "$BUILD/hwder"
# Ajustes iniciales del Setup (version, face_labels…); las rutas las pone
# deck-launch.sh al arrancar.
if [[ ! -f "$BUILD/hwder_settings.ini" ]]; then
    grep -vE '^(nsp_path|keys_path|update_path|save_dir|mods_dir)=' "$PLAY/hwder_settings.ini" \
        > "$BUILD/hwder_settings.ini" || true
fi
mkdir -p "$BUILD/game" "$BUILD/keys" "$BUILD/save" "$BUILD/mods"
log "Copiando $(basename "$NSP") a game/base.nsp"
cp --reflink=auto "$NSP" "$BUILD/game/base.nsp"
install -m 600 "$KEYS" "$BUILD/keys/prod.keys"
# hwder lee también title.keys si está junto a prod.keys (opcional).
rm -f "$BUILD/keys/title.keys"
[[ -f "$(dirname "$KEYS")/title.keys" ]] && install -m 600 "$(dirname "$KEYS")/title.keys" "$BUILD/keys/title.keys"
rm -rf "$BUILD/update"
if [[ -n "$UPDATE" ]]; then
    update_dir="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("update_dir") or "")' \
        "$DATA/build/last-success.json")"
    [[ -d "$update_dir" ]] || die "No se encuentra la update descomprimida ($update_dir)"
    log "Copiando la update descomprimida a update/"
    cp -a --reflink=auto "$update_dir" "$BUILD/update"
fi
install -m 755 "$GAME_DIR/deck-launch.sh" "$BUILD/deck-launch.sh"

check_absolute_paths
write_steamdeck_launcher deck-launch.sh

finish_build
log "En la Deck: añade 'steamdeck.sh' a Steam como juego no de Steam (sin Proton)."
