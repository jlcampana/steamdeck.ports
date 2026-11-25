#!/usr/bin/env bash
# Borra los builds anteriores (games/<id>/build.old/) que deja build.sh al
# cambiar de versión. Solo sirven para volver atrás si la versión nueva falla:
# bórralos cuando hayas probado la nueva en la Deck.
#
# Uso: ./clean-old-builds.sh [-y] [-n] [id…]   (sin ids: todos los juegos)
#   -y, --yes      no pregunta antes de borrar
#   -n, --dry-run  solo enseña qué borraría y cuánto ocupa
#   -h, --help     muestra esta ayuda
#
# No toca games/<id>/build/ (el build actual) ni los paquetes para la Deck.
# Es ./clean-builds.sh --old-only; para borrar también los build/ ya
# empaquetados, ./clean-builds.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/help.sh
source "$ROOT/tools/help.sh"
show_help_if_asked "$0" "$@"

exec "$ROOT/clean-builds.sh" --old-only "$@"
