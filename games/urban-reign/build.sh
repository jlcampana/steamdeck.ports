#!/usr/bin/env bash
# Urban Reign (PS2, urban-reign-recomp): copia el binario Linux de la release
# y convierte la imagen del disco (USA, SLUS-21209) de .chd a .iso en game/,
# donde el juego la busca. La versión portable guarda ajustes, tarjetas de
# memoria y estados en game/.
# Resultado: games/urban-reign/build (ejecutable: urban-reign --game, sin el
# launcher de Python/GTK/WebKit, que SteamOS no trae).
#
# Uso: games/urban-reign/build.sh [-f] [imagen]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   imagen      .chd o .iso; por defecto isos/UrbanReign.chd
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
SRC="$(realpath "${1:-$ISOS/UrbanReign.chd}")"

require_latest
require_file "$SRC"
[[ "$SRC" != *.chd ]] || command -v chdman >/dev/null || die "Falta chdman (tools/install.sh)"

prepare_build "$FORCE"

ISO="$BUILD/game/UrbanReign.iso"
if [[ -f "$ISO" ]]; then
    log "Ya está game/$(basename "$ISO")"
elif [[ "$SRC" == *.chd ]]; then
    log "Convirtiendo $(basename "$SRC") a game/$(basename "$ISO")"
    chdman extractdvd -i "$SRC" -o "$ISO.part"
    mv "$ISO.part" "$ISO"
else
    log "Copiando $(basename "$SRC") a game/$(basename "$ISO")"
    cp --reflink=auto "$SRC" "$ISO"
fi
# Comprueba que es el disco USA (SYSTEM.CNF: BOOT2 = cdrom0:\SLUS_212.09;1)
grep -a -m1 -q 'SLUS_212\.09' <(head -c 64M "$ISO") \
    || die "$(basename "$ISO") no parece Urban Reign USA (SLUS-21209)"

check_absolute_paths
# Punto de entrada común en la Deck: el juego directamente, sin launcher
write_steamdeck_launcher urban-reign --game

finish_build
log "En la Deck: añade 'steamdeck.sh' a Steam como juego no de Steam (sin Proton)."
