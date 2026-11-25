#!/usr/bin/env bash
# Drakengard 3 (PS3, dod3-recomp): copia el binario Linux de la release e
# instala el juego con su propio instalador sin interfaz
# (dod3 --install <disco> <update> [DLC…]), que lo deja en game/ junto al
# ejecutable: descifra el EBOOT de la 1.01, copia el disco a game/disc y
# enlaza (enlaces relativos) los datos que el juego copiaría al arrancar.
# Pide el disco USA (BLUS31197) en una ISO *descifrada* y la actualización
# 1.01; los DLC son opcionales.
# Resultado: games/drakengard3/build (ejecutable: dod3; ~16 GB).
#
# Uso: games/drakengard3/build.sh [-f] [disco [update.pkg [dlc.pkg…]]]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   disco       ISO descifrada o carpeta con PS3_GAME; por defecto
#               isos/Drakengard3.iso
#   update.pkg  UP0082-BLUS31197_00-DOD3PATCH0000000-A0101-V0101-PE.pkg;
#               por defecto se busca en isos/ (y una subcarpeta)
#   dlc.pkg     por defecto, los UP0082-NPUB31251_00-*.pkg de isos/
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
DISC="$(realpath "${1:-$ISOS/Drakengard3.iso}")"
shift || true

find_pkgs() {  # $1 = patrón; isos/ y una subcarpeta, sin repetir
    find -L "$ISOS" -maxdepth 2 -type f -iname "$1" -print0 2>/dev/null | sort -z
}

if (( $# )); then
    UPDATE="$(realpath "$1")"; shift
    DLC=(); for f in "$@"; do DLC+=("$(realpath "$f")"); done
else
    UPDATE=""
    while IFS= read -r -d '' f; do UPDATE="$f"; done < <(find_pkgs '*BLUS31197*DOD3PATCH*.pkg')
    DLC=()
    while IFS= read -r -d '' f; do DLC+=("$f"); done < <(find_pkgs 'UP0082-NPUB31251_00-*.pkg')
fi

require_latest
require_file "$DISC"
[[ -n "$UPDATE" ]] || die "Falta la actualización 1.01 (UP0082-BLUS31197_00-DOD3PATCH0000000-A0101-V0101-PE.pkg) en isos/"
require_file "$UPDATE"
for f in "${DLC[@]}"; do require_file "$f"; done

prepare_build "$FORCE"

if [[ -f "$BUILD/game/disc/PS3_GAME/PARAM.SFO" && -d "$BUILD/game/disc/game/BLES00000" ]]; then
    log "El juego ya está instalado en game/ (para reinstalar: -f)"
else
    log "Instalando: $(basename "$DISC"), $(basename "$UPDATE") y ${#DLC[@]} DLC (unos minutos)"
    # Sin DOD3_INSTALL_BASE instala junto al ejecutable (build/)
    "$BUILD/dod3" --install "$DISC" "$UPDATE" "${DLC[@]}"
fi
[[ -f "$BUILD/game/disc/PS3_GAME/PARAM.SFO" ]] || die "El instalador no ha dejado game/disc"

# Los enlaces que crea el instalador tienen que ser relativos (se mueve a la Deck)
abs_links="$(find "$BUILD" -type l -lname '/*' -print)"
[[ -z "$abs_links" ]] || die "Enlaces absolutos en el build: $abs_links"

check_absolute_paths
# Punto de entrada común en la Deck
write_steamdeck_launcher dod3

finish_build
log "En la Deck: añade 'steamdeck.sh' a Steam como juego no de Steam (sin Proton)."
