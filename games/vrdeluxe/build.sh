#!/usr/bin/env bash
# Virtua Racing Deluxe (32X) Enhanced: compila el emulador (PicoDrive + gráficos
# mejorados, SDL2 + OpenGL) en Ubuntu 24.04 (contenedor) desde el código de la
# release (no publica binario de Linux) y pone la ROM junto al ejecutable: sin
# argumentos, vrde juega el primer .32x de su carpeta.
# Resultado: games/vrdeluxe/build (vrde, la ROM, steamdeck.sh y licencias).
#
# Uso: games/vrdeluxe/build.sh [-f] [rom.32x]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   rom.32x     por defecto isos/VirtuaRacingDeluxe.32x (USA, SHA-1 abajo)
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

ROM_SHA1="18dfdeb50780c2623e60a6587d7ed701a1cf81f1"   # la que pide el README del port

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ROM="$(realpath "${1:-$ISOS/VirtuaRacingDeluxe.32x}")"

require_latest
require_file "$ROM"
[[ "$(sha1sum "$ROM" | cut -d' ' -f1)" == "$ROM_SHA1" ]] \
    || die "$ROM no es Virtua Racing Deluxe (USA) (SHA-1 distinto de $ROM_SHA1)"

prepare_build "$FORCE"
if [[ ! -x "$BUILD/vrde" ]]; then
    run_in_container make -j"$(nproc)" build/vrde
    # Solo lo necesario para jugar: el ejecutable y las licencias.
    log "Dejando solo el ejecutable y las licencias"
    mv "$BUILD/build/vrde" "$BUILD/vrde.new"
    cp "$BUILD/third_party/picodrive/COPYING" "$BUILD/COPYING.picodrive"
    find "$BUILD" -mindepth 1 -maxdepth 1 ! -name vrde.new ! -name LICENSE ! -name README.md \
        ! -name COPYING.picodrive ! -name .building-tag -exec rm -rf {} +
    mv "$BUILD/vrde.new" "$BUILD/vrde"
fi

log "Copiando la ROM ($(basename "$ROM"))"
cp --reflink=auto "$ROM" "$BUILD/VirtuaRacingDeluxe.32x"

check_absolute_paths
# vrde.ini (ajustes) y vrde.mds (estado guardado) van a la carpeta actual:
# steamdeck.sh hace cd a la del juego.
write_steamdeck_launcher vrde
finish_build
