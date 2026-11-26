#!/usr/bin/env bash
# Soulcalibur II (Xbox, soulcalibur2-recomp): copia el binario Linux de la
# release (el programa del juego ya va traducido y compilado; lee el disco al
# jugar), pone la ISO en disc/Soulcalibur2.iso y portable.txt (ajustes y
# partidas en user/, dentro de la carpeta del juego). steamdeck.sh lanza
# deck-launch.sh, que apunta el launcher al disco de la instalación.
# La ISO tiene que ser la USA o la europea: se comprueba el SHA-256 de su
# Default.xbe (el del README del port).
# Resultado: games/soulcalibur2/build (ejecutable: soulcalibur2-launcher).
#
# Uso: games/soulcalibur2/build.sh [-f] [iso]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   iso         por defecto isos/Soulcalibur2.iso
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ISO="$(realpath "${1:-$ISOS/Soulcalibur2.iso}")"

require_latest
require_file "$ISO"
require_extract_xiso

# SHA-256 de Default.xbe (README del port): USA y EUR, tal cual y con el
# parche de medios de extract-xiso.
declare -A XBE_OK=(
    [d7c2e1fc993350821e3f7e13cfd1c9d4ba6a7bf91011005bdd1f843899efb730]="USA"
    [7ce12851850ab46766f77c612b251afe7c8bd81f879e11b4836bdf766be542c6]="USA (parche de medios)"
    [074463537bf0a2753c72aa6ef1b438851b281954a7ec0cc7919f2464477b5292]="Europa"
    [4ad4e124a1773a6f78acf46397073affe9415cde576fe6e242e3260a0e41a1ec]="Europa (parche de medios)"
)
# extract-xiso no saca un solo archivo: se extrae el disco entero (1,3 GB)
# junto al juego (no en /tmp, que puede ser tmpfs) y se borra en seguida.
tmp="$(mktemp -d -p "$GAME_DIR" .xbe-check.XXXXXX)"
log "Comprobando Default.xbe de $(basename "$ISO")"
(cd "$tmp" && "$EXTRACT_XISO" -x "$ISO" -d x >/dev/null 2>&1) || true
sum=""
[[ -f "$tmp/x/Default.xbe" ]] && sum="$(sha256sum "$tmp/x/Default.xbe" | cut -d' ' -f1)"
rm -rf "$tmp"
[[ -n "$sum" ]] || die "No se pudo sacar Default.xbe de $ISO"
[[ -n "${XBE_OK[$sum]:-}" ]] || die "Default.xbe ($sum) no es de Soulcalibur II USA ni europeo"
log "Disco: ${XBE_OK[$sum]}"

prepare_build "$FORCE"

log "Copiando $(basename "$ISO") a disc/Soulcalibur2.iso"
mkdir -p "$BUILD/disc"
cp --reflink=auto "$ISO" "$BUILD/disc/Soulcalibur2.iso"
touch "$BUILD/portable.txt"
install -m 755 "$GAME_DIR/deck-launch.sh" "$BUILD/deck-launch.sh"

check_absolute_paths
write_steamdeck_launcher deck-launch.sh

finish_build
log "En la Deck: añade 'steamdeck.sh' a Steam como juego no de Steam (sin Proton)."
