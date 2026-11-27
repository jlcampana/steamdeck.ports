#!/usr/bin/env bash
# Bomberman Hero (N64, BMHeroRecomp; N64: Recompiled + RT64): binario Linux
# listo. Copia el contenido de la release, la ROM ya validada como bmhero.z64
# y portable.txt (tools/n64recomp.sh), así el juego no pide la ROM.
# Resultado: games/bomberman-hero/build (ejecutable: BMHeroRecompiled).
#
# Uso: games/bomberman-hero/build.sh [-f] [rom]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   rom         por defecto isos/BombermanHero.z64 (USA, .z64)
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"
source "$ROOT/tools/n64recomp.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ROM="$(realpath "${1:-$ISOS/BombermanHero.z64}")"

require_latest
require_file "$ROM"
# XXH3 de src/main/main.cpp del port; SHA-1 de la ROM comprobada con él
n64_check_rom "$ROM" 89134c0e1f16e0f8 a36364b7e59351f7551ab351cb3b41ebc4be285b

prepare_build "$FORCE"
n64recomp_build BMHeroRecompiled bmhero "$ROM"

finish_build
log "En la Deck: añade 'steamdeck.sh' a Steam como juego no de Steam (sin Proton)."
