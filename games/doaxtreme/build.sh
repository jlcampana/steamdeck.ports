#!/usr/bin/env bash
# Dead or Alive Xtreme Beach Volleyball: compila el port en Ubuntu 24.04 (contenedor) con la ISO del juego.
# Resultado: games/doaxtreme/build (se juega con launcher.sh o run_game.sh).
#
# Uso: games/doaxtreme/build.sh [-f] [ruta.iso]
#   -f        build limpio (el anterior pasa a build.old/)
#   ruta.iso  por defecto isos/DOAXtreme.iso
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ISO="$(realpath "${1:-$ISOS/DOAXtreme.iso}")"

require_latest
require_file "$ISO"
require_extract_xiso
[[ "$ISO" == "$ROOT"/* ]] || die "La ISO tiene que estar dentro de $ROOT (se monta en el contenedor)"

prepare_build "$FORCE"
run_in_container ./build_game.sh "$ISO" --extractor "$EXTRACT_XISO"
check_absolute_paths
write_steamdeck_launcher launcher.sh
finish_build
