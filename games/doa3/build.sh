#!/usr/bin/env bash
# Dead or Alive 3: compila el port en Ubuntu 24.04 (contenedor) con las ISO del juego.
# Resultado: games/doa3/build (en la Deck se lanza con steamdeck.sh).
#
# El port admite USA 3.0, Japón 3.1 y Europa 3.2 en el mismo build: cada una
# con su ejecutable y su carpeta de disco (partidas aparte), y se elige en el
# launcher. Se compilan todas las ISO dadas; una ISO ya compilada en este
# build (misma release) se salta.
#
# Trajes de mods: solo los de las chicas (costumes.py), que caben todos en los
# 128 huecos del juego.
#
# Uso: games/doa3/build.sh [-f] [ruta.iso…]
#   -f        build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   ruta.iso  por defecto todas las isos/DOA3*.iso (DOA3.iso, USA, la última:
#             es la versión por defecto si el launcher no tiene ninguna elegida)
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi

ISOS_TO_BUILD=()
if (( $# )); then
    for iso in "$@"; do ISOS_TO_BUILD+=("$(realpath "$iso")"); done
else
    for iso in "$ISOS"/DOA3*.iso; do
        [[ -f "$iso" && "$(basename "$iso")" != DOA3.iso ]] && ISOS_TO_BUILD+=("$(realpath "$iso")")
    done
    [[ -f "$ISOS/DOA3.iso" ]] && ISOS_TO_BUILD+=("$(realpath "$ISOS/DOA3.iso")")
    (( ${#ISOS_TO_BUILD[@]} )) || die "No hay ninguna isos/DOA3*.iso"
fi

require_latest
for iso in "${ISOS_TO_BUILD[@]}"; do
    require_file "$iso"
    require_container_path "$iso"
done
require_extract_xiso

# ¿Está ya esta ISO en el build terminado? (el port guarda su SHA-256 en
# private/imported-disc*/receipt.json)
already_built() {
    local sum
    [[ -f "$BUILD/.release-tag" ]] || return 1
    sum="$(sha256sum "$1" | cut -d' ' -f1)"
    grep -lqs "\"iso_sha256\": \"$sum\"" "$BUILD"/private/imported-disc*/receipt.json
}

prepare_build "$FORCE"
BUILT=0
for iso in "${ISOS_TO_BUILD[@]}"; do
    if already_built "$iso"; then
        log "$(basename "$iso"): ya compilada en este build, se salta"
        continue
    fi
    log "Compilando con $(basename "$iso")"
    # La marca de build terminado se quita mientras se añade otra versión.
    rm -f "$BUILD/.release-tag"
    release_tag > "$BUILD/.building-tag"
    # Trajes de mods: los pone costumes.py, solo los de las chicas.
    run_in_container ./build_game.sh "$iso" --extractor "$EXTRACT_XISO" --no-costumes
    BUILT=1
done
log "Trajes de mods (solo chicas)"
run_in_container python3 "$GAME_DIR/costumes.py"
if (( ! BUILT )) && [[ -f "$BUILD/.release-tag" ]]; then
    log "Nada que compilar"
    BUILD_NOTIFIED=1
    exit 0
fi
check_absolute_paths
write_steamdeck_launcher launcher.sh
log "Versiones instaladas: $(jq -r '[.installed[].version] | join(", ")' "$BUILD/private/build.json")"
finish_build
