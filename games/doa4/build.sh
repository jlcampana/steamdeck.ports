#!/usr/bin/env bash
# Dead or Alive 4 Online (Windows, se juega con Proton): copia la release y
# extrae en game/ la ISO de Xbox 360 (default.xex en la raíz).
# Resultado: games/doa4/build (ejecutable: dead_or_alive_4.exe).
#
# Las rutas de game/ y de las partidas van en dead_or_alive_4.toml como rutas
# de Windows (Z:/…), que dependen de dónde se instale: las escribe en la Deck
# deck-post-install.sh, que el instalador ejecuta tras descomprimir.
#
# Uso: games/doa4/build.sh [-f] [ruta.iso]
#   -f        build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   ruta.iso  por defecto isos/DOA4.iso (Dead or Alive 4 (USA, Europe) (Rev 1))
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ISO="$(realpath "${1:-$ISOS/DOA4.iso}")"

require_latest
require_file "$ISO"
require_extract_xiso

prepare_build "$FORCE"

if [[ -f "$BUILD/game/default.xex" ]]; then
    log "game/ ya contiene default.xex; no se vuelve a extraer la ISO"
else
    log "Extrayendo $(basename "$ISO") en game/ (unos 7 GB)"
    rm -rf "$BUILD/game"
    mkdir -p "$BUILD/game"
    "$EXTRACT_XISO" -q -x "$ISO" -d "$BUILD/game"
    [[ -f "$BUILD/game/default.xex" ]] || die "La ISO no contiene default.xex en la raíz"
fi

# Comprueba los tres archivos del port con el SHA256SUMS.txt de la release.
if [[ -f "$BUILD/SHA256SUMS.txt" ]]; then
    (cd "$BUILD" && sha256sum --quiet -c SHA256SUMS.txt) || die "SHA256SUMS.txt no cuadra"
    log "SHA-256 de dead_or_alive_4.exe y sus DLL correctos"
fi

finish_build
log "En la Deck: instálalo con tools/package.sh (fuerza Proton en Steam)."
