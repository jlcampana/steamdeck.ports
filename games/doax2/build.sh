#!/usr/bin/env bash
# Dead or Alive Xtreme 2 Recomp (Windows, se juega con Proton): copia la
# release y extrae la ISO de Xbox 360 en «extracted game files here» (la
# carpeta donde la busca el lanzador; default.xex en la raíz).
# Resultado: games/doax2/build (ejecutable: «DOAX2 Recomp Launcher.exe», que
# arranca out/game/doax2.exe con las opciones elegidas; todas las rutas son
# relativas a su carpeta, así que no hace falta post-install.sh).
#
# Uso: games/doax2/build.sh [-f] [ruta.iso]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   ruta.iso    por defecto isos/DOAX2.iso (disco retail, title ID 544307D2)
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

# SHA-256 del default.xex que admite el port (README del repo).
XEX_SHA256="c4a14853e1f7af951be34f380604113703638780b36d5e74e674fe7431992870"
GAME_SUBDIR="extracted game files here"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ISO="$(realpath "${1:-$ISOS/DOAX2.iso}")"

require_latest
require_file "$ISO"
require_extract_xiso

prepare_build "$FORCE"

GAME="$BUILD/$GAME_SUBDIR"
if [[ -f "$GAME/default.xex" ]]; then
    log "«$GAME_SUBDIR» ya contiene default.xex; no se vuelve a extraer la ISO"
else
    log "Extrayendo $(basename "$ISO") en «$GAME_SUBDIR» (unos 6 GB)"
    mkdir -p "$GAME"
    "$EXTRACT_XISO" -q -x "$ISO" -d "$GAME"
fi
[[ "$(sha256sum "$GAME/default.xex" | cut -d' ' -f1)" == "$XEX_SHA256" ]] \
    || die "default.xex no es el que admite el port (SHA-256 $XEX_SHA256)"
log "SHA-256 de default.xex correcto"
rm -f "$GAME/PUT YOUR GAME FILES HERE.txt"

finish_build
log "En la Deck: instálalo con tools/package.sh (fuerza Proton en Steam)."
