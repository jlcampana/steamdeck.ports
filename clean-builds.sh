#!/usr/bin/env bash
# Borra los builds para liberar espacio en el PC:
#   - games/<id>/build.old/  (el build anterior que deja build.sh)
#   - games/<id>/build/      (el actual), solo si ya está empaquetado: en el
#     destino de los paquetes hay un <id>.tar.zst terminado de la misma
#     versión. Si no, lo salta y avisa (con -f lo borra igualmente).
# Rehacer un build borrado: games/<id>/build.sh (los DOA de NoRain tardan
# 6-12 min en recompilar; los demás, segundos o un par de minutos).
#
# Uso: ./clean-builds.sh [-y] [-n] [-f] [--old-only] [-o destino] [id…]
#   (sin ids: todos los juegos)
#   -y, --yes      no pregunta antes de borrar
#   -n, --dry-run  solo enseña qué borraría y cuánto ocupa
#   -f, --force    borra también los build/ sin paquete al día
#   --old-only     solo los build.old/ (es lo que hace ./clean-old-builds.sh)
#   -o destino     carpeta de los paquetes (por defecto, DEST de local.conf
#                  o dist/, como tools/package.sh)
#   -h, --help     muestra esta ayuda
#
# No toca latest/, art/ ni los paquetes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/help.sh
source "$ROOT/tools/help.sh"
show_help_if_asked "$0" "$@"

DEST="$ROOT/dist"
# shellcheck disable=SC1091
[[ -f "$ROOT/local.conf" ]] && source "$ROOT/local.conf"

YES=0
DRY=0
FORCE=0
OLD_ONLY=0
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        -y|--yes) YES=1 ;;
        -n|--dry-run) DRY=1 ;;
        -f|--force) FORCE=1 ;;
        --old-only) OLD_ONLY=1 ;;
        -o) [[ $# -ge 2 ]] || { echo "Falta la carpeta tras -o" >&2; exit 2; }
            DEST="$2"; shift ;;
        *) echo "Opción desconocida: $1 (ver ./clean-builds.sh --help)" >&2; exit 2 ;;
    esac
    shift
done

ids=()
if (( $# )); then
    for id in "$@"; do
        [[ -d "$ROOT/games/$id" ]] || { echo "No existe el juego: $id" >&2; exit 1; }
        ids+=("$id")
    done
else
    for d in "$ROOT"/games/*/; do ids+=("$(basename "$d")"); done
fi

# Versión del paquete terminado de $1 en DEST, o vacío.
packaged_version() {
    local out="$DEST/$1"
    [[ -f "$out/$1.tar.zst" && -f "$out/$1.tar.zst.sha256" && ! -e "$out/$1.tar.zst.part" ]] || return 0
    sed -n 's/^VERSION=//p' "$out/game.conf" 2>/dev/null || true
}

dirs=()
lines=()
skipped=()
for id in "${ids[@]}"; do
    g="$ROOT/games/$id"
    if [[ -d "$g/build.old" ]]; then
        dirs+=("$g/build.old")
        lines+=("$(printf '%-16s %-8s build.old  %s' "$id" "$(du -sh "$g/build.old" | cut -f1)" \
            "$(cat "$g/build.old/.release-tag" 2>/dev/null || echo "?")")")
    fi
    (( OLD_ONLY )) && continue
    [[ -d "$g/build" ]] || continue
    tag="$(cat "$g/build/.release-tag" 2>/dev/null || true)"
    pkg="$(packaged_version "$id")"
    if [[ -n "$tag" && "$pkg" == "$tag" ]]; then
        note="$tag (empaquetado)"
    elif (( FORCE )); then
        note="${tag:-sin terminar} (SIN paquete al día: ${pkg:-ninguno})"
    else
        skipped+=("$(printf '%-16s %s, paquete: %s' "$id" "${tag:-build sin terminar}" "${pkg:-ninguno}")")
        continue
    fi
    dirs+=("$g/build")
    lines+=("$(printf '%-16s %-8s build      %s' "$id" "$(du -sh "$g/build" | cut -f1)" "$note")")
done

if (( ${#skipped[@]} )); then
    echo "Se quedan (sin paquete de su versión en $DEST; -f para borrarlos):"
    printf '  %s\n' "${skipped[@]}"
fi
if (( ${#dirs[@]} == 0 )); then
    echo "No hay builds que borrar."
    exit 0
fi

echo "Builds a borrar:"
printf '  %s\n' "${lines[@]}"
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
    # Comprobación de seguridad: solo games/<id>/build{,.old} dentro del proyecto
    [[ "$d" == "$ROOT"/games/*/build || "$d" == "$ROOT"/games/*/build.old ]] \
        || { echo "Ruta inesperada: $d" >&2; exit 1; }
    rm -rf -- "$d"
    echo "Borrado ${d#"$ROOT"/}"
done
