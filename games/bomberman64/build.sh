#!/usr/bin/env bash
# Bomberman 64 (N64, BM64Recomp; N64: Recompiled + RT64): binario Linux
# listo. Copia el contenido de la release, la ROM ya validada como
# bm64_us.z64 y portable.txt (tools/n64recomp.sh), así el juego no pide la ROM.
# Resultado: games/bomberman64/build (ejecutable: BM64Recompiled).
#
# Uso: games/bomberman64/build.sh [-f] [rom]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   rom         por defecto isos/Bomberman64.z64 (USA 1.0 sin modificar, .z64)
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"
source "$ROOT/tools/n64recomp.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ROM="$(realpath "${1:-$ISOS/Bomberman64.z64}")"

require_latest
require_file "$ROM"
# XXH3 de src/main/main.cpp del port. Sin SHA-1: aún no hay una ROM buena
# comprobada (la de isos/ es una modificada, 10 MB con «Zoinkity» en la
# cabecera); sin xxhsum ni python3-xxhash, el build se para.
n64_check_rom "$ROM" c4c0b74bbb696426

prepare_build "$FORCE"
n64recomp_build BM64Recompiled bm64_us "$ROM"

finish_build
log "En la Deck: añade 'steamdeck.sh' a Steam como juego no de Steam (sin Proton)."
