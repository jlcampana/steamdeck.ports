#!/usr/bin/env bash
# Castlevania: Symphony of the Night (XBLA): copia el binario Linux e instala
# los paquetes STFS (World y Japón) en assets/ con scripts/extract_game.py del
# repo, en el mismo tag que la release.
# Resultado: games/castlevania-son/build (ejecutable: nocturnerecomp).
#
# Uso: games/castlevania-son/build.sh [-f] [carpeta]
#   -f       build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   carpeta  por defecto "isos/Castlevania SON" (con "world version/" y
#            "japan version/"; "addon/" se ignora: el title update ya está portado)
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

REPO="birabittoh/NocturneRecomp"
FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
SRC="$(realpath "${1:-$ISOS/Castlevania SON}")"

require_latest
require_file "$SRC"
command -v python3 >/dev/null || die "Falta python3"

prepare_build "$FORCE"

tag="$(release_tag)"
extractor="$GAME_DIR/extract_game-$tag.py"
if [[ ! -f "$extractor" ]]; then
    log "Descargando scripts/extract_game.py ($tag)"
    curl -fsSL -o "$extractor.part" \
        "https://raw.githubusercontent.com/$REPO/$tag/scripts/extract_game.py"
    mv "$extractor.part" "$extractor"
fi

packages=()
for dir in "world version" "japan version"; do
    [[ -d "$SRC/$dir" ]] || { log "No hay '$dir' en $SRC; se omite"; continue; }
    while IFS= read -r -d '' f; do packages+=("$f"); done \
        < <(find "$SRC/$dir" -maxdepth 1 -type f -print0)
done
(( ${#packages[@]} )) || die "No hay paquetes en $SRC/{world,japan} version"

for pkg in "${packages[@]}"; do
    log "Instalando $(basename "$(dirname "$pkg")")/$(basename "$pkg")"
    python3 -I "$extractor" "$pkg" --assets "$BUILD/assets" --force
done

# Partidas, opciones y caché junto al ejecutable (útil para copiarlo a la Deck)
touch "$BUILD/portable.txt"

# Punto de entrada común en la Deck
write_steamdeck_launcher nocturnerecomp

finish_build
log "En la Deck: añade 'steamdeck.sh' a Steam como juego no de Steam."
