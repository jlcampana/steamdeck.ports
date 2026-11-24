#!/usr/bin/env bash
# Dead or Alive 1 Ultimate (Windows, se juega con Proton): copia la release y
# extrae en assets/ el disco de DOA2U, que contiene Doa1.xbe.
# Resultado: games/doa1u/build (ejecutable: DOA1U.exe).
#
# Uso: games/doa1u/build.sh [-f] [ruta.iso]
#   -f        build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   ruta.iso  por defecto isos/DOA2U.iso
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ISO="$(realpath "${1:-$ISOS/DOA2U.iso}")"

require_latest
require_file "$ISO"
require_extract_xiso

prepare_build "$FORCE"

if [[ -f "$BUILD/assets/Doa1.xbe" ]]; then
    log "assets/ ya contiene Doa1.xbe; no se vuelve a extraer la ISO"
else
    log "Extrayendo $(basename "$ISO") en assets/ (unos 4 GB)"
    find "$BUILD/assets" -mindepth 1 -delete 2>/dev/null || true
    mkdir -p "$BUILD/assets"
    "$EXTRACT_XISO" -q -x "$ISO" -d "$BUILD/assets"
    [[ -f "$BUILD/assets/Doa1.xbe" ]] || die "La ISO no contiene Doa1.xbe en la raíz"
fi

finish_build
log "En la Deck: añade DOA1U.exe a Steam y fuerza Proton. El primer arranque compila el juego."
