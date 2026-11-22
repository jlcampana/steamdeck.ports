#!/usr/bin/env bash
# Dead or Alive 2 Ultimate: compila el port en Ubuntu 24.04 (contenedor) con la ISO del juego.
# Resultado: games/doa2u/build (se juega con launcher.sh o run_game.sh).
#
# Uso: games/doa2u/build.sh [-f] [ruta.iso]
#   -f        build limpio (el anterior pasa a build.old/)
#   ruta.iso  por defecto isos/DOA2U.iso
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ISO="$(realpath "${1:-$ISOS/DOA2U.iso}")"

require_latest
require_file "$ISO"
require_extract_xiso
[[ "$ISO" == "$ROOT"/* ]] || die "La ISO tiene que estar dentro de $ROOT (se monta en el contenedor)"

prepare_build "$FORCE"
# build_game.py hace "pip install capstone" con el Python con el que se lanza y
# Ubuntu 24.04 lo bloquea fuera de un venv (PEP 668). build_game.sh usa
# private/venv si existe, así que se crea antes.
run_in_container bash -c 'python3 -m venv private/venv && exec ./build_game.sh "$@"' _ \
    "$ISO" --extractor "$EXTRACT_XISO"
check_absolute_paths
write_steamdeck_launcher launcher.sh
finish_build
