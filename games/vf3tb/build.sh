#!/usr/bin/env bash
# Virtua Fighter 3 Team Battle (arcade Model 3, vf3-recomp): copia el paquete
# para Steam Deck de la release (binario Linux listo, con su SDL3 en lib/) y
# pone el set de MAME en roms/vf3tb.zip. El port recompila el programa del
# juego desde el zip en cada arranque; con un vf3tb.zip completo (no "split")
# no hace falta vf3.zip. Si se da también un vf3.zip, va a roms/ y el menú
# Game > Version cambia entre los dos.
# Resultado: games/vf3tb/build (ejecutable: VirtuaFighter3.sh -> vf3).
#
# Uso: games/vf3tb/build.sh [-f] [vf3tb.zip] [vf3.zip]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   vf3tb.zip   por defecto isos/VF33tb.zip (set de MAME "vf3tb")
#   vf3.zip     opcional (set de MAME "vf3", Revision D)
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
TB_ZIP="$(realpath "${1:-$ISOS/VF33tb.zip}")"
VF3_ZIP="${2:-}"

require_latest
require_file "$TB_ZIP"
[[ -z "$VF3_ZIP" ]] || { require_file "$VF3_ZIP"; VF3_ZIP="$(realpath "$VF3_ZIP")"; }
command -v unzip >/dev/null || die "Falta unzip"
# Un set de vf3tb completo trae también las ROM de vf3 (mpr-19xxx).
# (La lista va a una variable: con pipefail, grep -q cortaría a unzip.)
tb_list="$(unzip -l "$TB_ZIP")"
grep -q 'epr-20126' <<<"$tb_list" || die "$TB_ZIP no parece el set de MAME vf3tb"
if [[ -z "$VF3_ZIP" ]] && ! grep -q 'mpr-19197' <<<"$tb_list"; then
    die "$TB_ZIP es un set \"split\" (solo lo de Team Battle): hace falta también vf3.zip"
fi

prepare_build "$FORCE"

log "Copiando $(basename "$TB_ZIP") a roms/vf3tb.zip"
mkdir -p "$BUILD/roms"
cp --reflink=auto "$TB_ZIP" "$BUILD/roms/vf3tb.zip"
if [[ -n "$VF3_ZIP" ]]; then
    log "Copiando $(basename "$VF3_ZIP") a roms/vf3.zip"
    cp --reflink=auto "$VF3_ZIP" "$BUILD/roms/vf3.zip"
fi

# Ajustes, partidas, capturas y log en la carpeta del juego (el paquete de
# Deck ya lo hace; portable.txt lo garantiza).
touch "$BUILD/portable.txt"

check_absolute_paths
# Punto de entrada común en la Deck (VirtuaFighter3.sh hace cd y lanza vf3)
write_steamdeck_launcher VirtuaFighter3.sh

finish_build
log "En la Deck: añade 'steamdeck.sh' a Steam como juego no de Steam (sin Proton)."
