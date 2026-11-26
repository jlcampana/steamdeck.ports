#!/usr/bin/env bash
# Sirve por HTTP los paquetes de tools/package.sh para instalarlos en la
# Steam Deck por red, sin copiar carpetas (en la Deck: «Ports por red»,
# tools/deck/steamdeck-ports.sh).
#
# Uso: tools/serve.sh [-p puerto] [-o carpeta]
#   -p puerto   puerto HTTP (por defecto 8765)
#   -o carpeta  carpeta de los paquetes (por defecto DEST de local.conf o dist/)
#   -h, --help  muestra esta ayuda
#
# Se para con Ctrl+C. Mientras está en marcha:
# - Anuncia el servicio por mDNS (_steamdeck-ports._tcp, con avahi-publish)
#   para que la Deck encuentre el PC sin escribir la IP.
# - Sirve, desde una carpeta temporal en $XDG_RUNTIME_DIR (la de los paquetes
#   no se toca):
#     index.tsv            un juego por línea: id, nombre, versión, KB
#                          instalado, Proton (0/1) y bytes del .tar.zst
#     listas/<id>.lst      archivos pequeños del paquete que descarga la Deck
#                          (game.conf, .sha256, art/…)
#     comun/               instalar.sh, steam-art.py y proton-dpi.sh del repo
#                          (tools/deck): la Deck usa siempre estos y no los
#                          del paquete, que pueden ser de antes de PKG_URL
#     steamdeck-ports.sh   el cliente de la Deck (se actualiza solo desde aquí)
#     <id>/                enlace a la carpeta del paquete
# El índice se hace al arrancar: si empaquetas algo nuevo, reinicia serve.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/help.sh
source "$ROOT/tools/help.sh"
# shellcheck source=tools/deprecated.sh
source "$ROOT/tools/deprecated.sh"
show_help_if_asked "$0" "$@"
DEST="$ROOT/dist"
# shellcheck source=/dev/null
[[ -f "$ROOT/local.conf" ]] && source "$ROOT/local.conf"

log() { printf '\e[1;34m[serve]\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[serve]\e[0m %s\n' "$*"; }
die() { printf '\e[1;31m[serve] %s\e[0m\n' "$*" >&2; exit 1; }

PORT=8765
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        -p) [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || die "Falta el puerto tras -p"; PORT="$2"; shift 2 ;;
        -o) [[ $# -ge 2 ]] || die "Falta la carpeta tras -o"; DEST="$2"; shift 2 ;;
        *)  die "Opción desconocida: $1 (ver tools/serve.sh --help)" ;;
    esac
done
[[ -d "$DEST" ]] || die "No existe la carpeta de paquetes: $DEST"
DEST="$(cd "$DEST" && pwd)"
command -v python3 >/dev/null || die "Falta python3"

# Valor de una variable de un game.conf (escrito con printf %q)
pkg_value() {
    local v
    v="$(sed -n "s/^$2=//p" "$1")"
    eval "printf '%s' $v"
}

SERVE="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/steamdeck-ports-serve.XXXXXX")"
AVAHI_PID=""
cleanup() {
    [[ -n "$AVAHI_PID" ]] && kill "$AVAHI_PID" 2>/dev/null || true
    rm -rf "$SERVE"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# --- Índice -------------------------------------------------------------------
mkdir -p "$SERVE/listas"
install -m 644 "$ROOT/tools/deck/steamdeck-ports.sh" "$SERVE/steamdeck-ports.sh"
COMMON=(instalar.sh steam-art.py proton-dpi.sh)
mkdir -p "$SERVE/comun"
for f in "${COMMON[@]}"; do install -m 644 "$ROOT/tools/deck/$f" "$SERVE/comun/$f"; done
n=0
for conf in "$DEST"/*/game.conf; do
    [[ -f "$conf" ]] || continue
    dir="$(dirname "$conf")"
    id="$(pkg_value "$conf" ID)"
    [[ "$id" == "$(basename "$dir")" ]] || { warn "$dir: el ID de game.conf ($id) no es el de la carpeta; se salta"; continue; }
    if is_deprecated "$id"; then log "$id: obsoleto (DEPRECATED en games/$id/game.conf), no se ofrece"; continue; fi
    pkg="$dir/$id.tar.zst"
    if [[ ! -f "$pkg" || ! -f "$pkg.sha256" ]]; then
        warn "$id: falta $id.tar.zst o su .sha256; se salta"
        continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$(pkg_value "$conf" NAME)" "$(pkg_value "$conf" VERSION)" \
        "$(pkg_value "$conf" SIZE_KB)" "$(pkg_value "$conf" PROTON)" "$(stat -c %s "$pkg")" >> "$SERVE/index.tsv"
    # Todo menos el juego, el lanzador .desktop (la Deck usa instalar.sh) y
    # los scripts comunes (van en comun/)
    (cd "$dir" && find . -type f ! -name "$id.tar.zst" ! -name '*.desktop' ! -name '*.part' \
        ! -path './__pycache__/*' -printf '%P\n' | grep -vxF -e "${COMMON[0]}" -e "${COMMON[1]}" -e "${COMMON[2]}" \
        | sort) > "$SERVE/listas/$id.lst"
    ln -s "$dir" "$SERVE/$id"
    n=$((n + 1))
done
(( n )) || die "No hay paquetes en $DEST (tools/package.sh)"
log "$n juegos en $DEST"

# --- mDNS ---------------------------------------------------------------------
if command -v avahi-publish >/dev/null; then
    avahi-publish -s "steamdeck.ports en $(hostname -s)" _steamdeck-ports._tcp "$PORT" "path=/" >/dev/null 2>&1 &
    AVAHI_PID=$!
    log "Anunciado por mDNS como _steamdeck-ports._tcp"
else
    warn "Sin avahi-publish (paquete avahi-tools): la Deck no encontrará el PC sola; dale la URL"
fi

# --- HTTP ---------------------------------------------------------------------
ips=()
read -r -a ips <<<"$(hostname -I 2>/dev/null || true)"
echo
log "Sirviendo en el puerto $PORT. Desde la Deck:"
for ip in "${ips[@]}"; do
    [[ "$ip" == *:* ]] && continue   # solo IPv4
    echo "    http://$ip:$PORT/"
done
echo
echo "  Para instalar «Ports por red» en la Deck (una vez), en Konsole:"
for ip in "${ips[@]}"; do
    [[ "$ip" == *:* ]] && continue
    echo "    curl -fsSL http://$ip:$PORT/steamdeck-ports.sh | bash -s -- --instalar http://$ip:$PORT"
    break
done
echo
log "Ctrl+C para parar."
python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$SERVE"
