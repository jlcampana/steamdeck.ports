#!/usr/bin/env bash
# Instala lo que necesitan update.sh y los games/<id>/build.sh en el PC:
#   - paquetes del sistema (con dnf, apt o pacman, usando sudo)
#   - extract-xiso en tools/bin (release de XboxDev/extract-xiso)
#
# Uso: tools/install.sh [--print]
#   --print     solo muestra lo que haría con el gestor de paquetes
#   -h, --help  muestra esta ayuda
set -euo pipefail

TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/help.sh
source "$TOOLS/help.sh"
show_help_if_asked "$0" "$@"
BIN="$TOOLS/bin"
PRINT=0
[[ "${1:-}" == "--print" ]] && PRINT=1

# comando -> paquete (igual en dnf, apt y pacman salvo los indicados)
declare -A PKG=(
    [curl]=curl [jq]=jq [sqlite3]=sqlite3 [unzip]=unzip [tar]=tar
    [python3]=python3 [sha256sum]=coreutils [git]=git
)
missing=()
for cmd in "${!PKG[@]}"; do
    command -v "$cmd" >/dev/null || missing+=("${PKG[$cmd]}")
done
# Motor de contenedores para compilar los ports de NoRain211 (Ubuntu 24.04)
if ! command -v podman >/dev/null && ! command -v docker >/dev/null; then
    missing+=(podman)
fi

if (( ${#missing[@]} )); then
    if command -v dnf >/dev/null; then
        pm=(sudo dnf install -y)
        missing=("${missing[@]/sqlite3/sqlite}")
    elif command -v apt-get >/dev/null; then
        pm=(sudo apt-get install -y)
    elif command -v pacman >/dev/null; then
        pm=(sudo pacman -S --needed --noconfirm)
        missing=("${missing[@]/sqlite3/sqlite}")
        missing=("${missing[@]/python3/python}")
    else
        echo "Instala a mano: ${missing[*]}" >&2; exit 1
    fi
    echo "Faltan paquetes: ${missing[*]}"
    if (( PRINT )); then echo "${pm[*]} ${missing[*]}"; else "${pm[@]}" "${missing[@]}"; fi
else
    echo "Paquetes del sistema: OK"
fi

# extract-xiso: binario oficial de Linux, verificado con el digest de GitHub
if [[ -x "$BIN/extract-xiso" ]]; then
    echo "extract-xiso: ya instalado en tools/bin"
elif (( PRINT )); then
    echo "Descargaría extract-xiso_Linux.zip de XboxDev/extract-xiso en tools/bin"
else
    echo "Descargando extract-xiso..."
    json="$(curl -fsSL https://api.github.com/repos/XboxDev/extract-xiso/releases/latest)"
    url="$(jq -r '.assets[] | select(.name=="extract-xiso_Linux.zip") | .browser_download_url' <<<"$json")"
    digest="$(jq -r '.assets[] | select(.name=="extract-xiso_Linux.zip") | .digest // "" | sub("^sha256:"; "")' <<<"$json")"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/x.zip" "$url"
    if [[ -n "$digest" ]] && ! echo "$digest  $tmp/x.zip" | sha256sum -c --quiet -; then
        echo "SHA-256 de extract-xiso no coincide" >&2; exit 1
    fi
    unzip -q "$tmp/x.zip" -d "$tmp/x"
    mkdir -p "$BIN"
    install -m 755 "$(find "$tmp/x" -type f -name extract-xiso | head -1)" "$BIN/extract-xiso"
    echo "extract-xiso $(jq -r .tag_name <<<"$json") instalado en tools/bin"
fi
"$BIN/extract-xiso" 2>&1 | head -1 || true
