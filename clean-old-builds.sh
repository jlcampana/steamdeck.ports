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
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/help.sh
source "$ROOT/tools/help.sh"
show_help_if_asked "$0" "$@"

YES=0
DRY=0
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        -y|--yes) YES=1 ;;
        -n|--dry-run) DRY=1 ;;
        *) echo "Opción desconocida: $1 (ver ./clean-old-builds.sh --help)" >&2; exit 2 ;;
    esac
    shift
done

dirs=()
if (( $# )); then
    for id in "$@"; do
        [[ -d "$ROOT/games/$id" ]] || { echo "No existe el juego: $id" >&2; exit 1; }
        [[ -d "$ROOT/games/$id/build.old" ]] && dirs+=("$ROOT/games/$id/build.old")
    done
else
    for d in "$ROOT"/games/*/build.old; do
        [[ -d "$d" ]] && dirs+=("$d")
    done
fi

if (( ${#dirs[@]} == 0 )); then
    echo "No hay builds anteriores que borrar."
    exit 0
fi

echo "Builds anteriores:"
for d in "${dirs[@]}"; do
    id="$(basename "$(dirname "$d")")"
    tag="$(cat "$d/.release-tag" 2>/dev/null || echo "?")"
    now="$(cat "$ROOT/games/$id/build/.release-tag" 2>/dev/null || echo "sin build")"
    printf '  %-16s %-8s %s (actual: %s)\n' "$id" "$(du -sh "$d" | cut -f1)" "$tag" "$now"
done
echo "  Total: $(du -shc "${dirs[@]}" | tail -1 | cut -f1)"

if (( DRY )); then
    echo "(--dry-run: no se borra nada)"
    exit 0
fi
if (( ! YES )); then
    read -rp "¿Borrarlos? [s/N] " answer || answer=""
    [[ "$answer" =~ ^[sSyY] ]] || { echo "Cancelado."; exit 0; }
fi

for d in "${dirs[@]}"; do
    # Comprobación de seguridad: solo games/<id>/build.old dentro del proyecto
    [[ "$d" == "$ROOT"/games/*/build.old ]] || { echo "Ruta inesperada: $d" >&2; exit 1; }
    rm -rf -- "$d"
    echo "Borrado games/$(basename "$(dirname "$d")")/build.old"
done
