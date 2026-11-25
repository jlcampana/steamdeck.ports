#!/usr/bin/env bash
# SoulCalibur (Dreamcast, Voldorium): ejecutable Linux listo, pero el código del
# juego (sc_game.so) se genera a partir del disco del usuario. El juego lo hace
# en su primer arranque (descarga Zig y traduce el código); aquí se hace en el
# PC para que la Deck no tenga que compilar nada:
#   1. convierte el CHD (GD-ROM) a disc/SoulCalibur.gdi + pistas (chdman);
#   2. genera sc_game.so en el contenedor con builder/tools/build.py
#      (--only module: el mismo paso que builder/first_run.sh);
#   3. apunta voldorium.ini a disc/SoulCalibur.gdi (relativa: steamdeck.sh
#      hace cd a la carpeta del juego) y borra el compilador descargado.
# Resultado: games/soulcalibur/build (ejecutable: voldorium).
#
# Uso: games/soulcalibur/build.sh [-f] [disco.chd|disco.gdi]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   disco       por defecto isos/SoulCalibur.chd (USA); con un .gdi, se copia
#               con sus pistas
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
DISC="$(realpath "${1:-$ISOS/SoulCalibur.chd}")"

require_latest
require_file "$DISC"

prepare_build "$FORCE"

GDI="$BUILD/disc/SoulCalibur.gdi"
if [[ ! -f "$GDI" ]]; then
    rm -rf "$BUILD/disc.tmp"; mkdir -p "$BUILD/disc.tmp"
    case "$DISC" in
        *.chd)
            command -v chdman >/dev/null || die "Falta chdman (tools/install.sh: mame-tools)"
            log "Convirtiendo $(basename "$DISC") a .gdi (chdman)"
            chdman extractcd -i "$DISC" -o "$BUILD/disc.tmp/SoulCalibur.gdi" ;;
        *.gdi)
            log "Copiando $(basename "$DISC") y sus pistas"
            cp "$DISC" "$BUILD/disc.tmp/SoulCalibur.gdi"
            awk 'NR > 1 && NF >= 5 { print $5 }' "$DISC" | tr -d '"\r' | while read -r track; do
                cp --reflink=auto "$(dirname "$DISC")/$track" "$BUILD/disc.tmp/"
            done ;;
        *) die "Formato no soportado: $DISC (.chd o .gdi)" ;;
    esac
    mv "$BUILD/disc.tmp" "$BUILD/disc"
fi

if [[ ! -f "$BUILD/sc_game.so" ]]; then
    log "Generando sc_game.so desde el disco (contenedor; descarga Zig la primera vez)"
    run_in_container python3 -I builder/tools/build.py --download --only module \
        --gdi "$GDI" --module-dir "$BUILD" --out "$BUILD/builder/work"
    [[ -f "$BUILD/sc_game.so" ]] || die "build.py no ha dejado sc_game.so"
fi
# El compilador (Zig, ~300 MB) y los intermedios (archivos de arranque del
# disco, el código traducido a C) no hacen falta para jugar.
rm -rf "$BUILD/builder/toolchain" "$BUILD/builder/work" "$BUILD/builder/extracted" \
    "$BUILD/builder/port/build"

log "voldorium.ini: disc = disc/SoulCalibur.gdi"
sed -i 's|^disc *=.*|disc = disc/SoulCalibur.gdi|' "$BUILD/voldorium.ini"
grep -q '^disc = disc/SoulCalibur.gdi$' "$BUILD/voldorium.ini" || die "No se ha podido escribir disc en voldorium.ini"

check_absolute_paths
write_steamdeck_launcher voldorium
finish_build
