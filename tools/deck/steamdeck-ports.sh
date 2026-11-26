#!/usr/bin/env bash
# «Ports por red»: instala y actualiza en la Steam Deck los juegos que sirve
# el PC con tools/serve.sh, sin copiar carpetas. El juego se descarga y se
# descomprime a la vez (instalar.sh con PKG_URL): en la Deck solo hace falta
# el espacio del juego instalado.
#
# Uso: steamdeck-ports.sh [URL]
#      steamdeck-ports.sh --instalar URL
#   URL         el servidor, p. ej. http://192.168.1.64:8765 (sin ella lo
#               busca por mDNS y, si no, usa el último que funcionó)
#   --instalar  se instala en la Deck (una vez): queda en
#               ~/.local/share/steamdeck-ports/ con «Ports por red» en el menú
#               de aplicaciones y en el escritorio
#   -h, --help  muestra esta ayuda
#
# Cada vez que arranca se actualiza solo con la copia del servidor.
# Enseña los juegos con la versión instalada (en ~/Games o <tarjeta SD>/Games)
# y la del PC; se eligen por número (varios separados por espacios, o «a»
# para todos los que tienen versión nueva). Cada juego lo instala su propio
# instalar.sh: pregunta el destino y guarda las partidas al actualizar.
set -euo pipefail

APP_DIR="$HOME/.local/share/steamdeck-ports"
APP="$APP_DIR/steamdeck-ports.sh"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/steamdeck-ports"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/steamdeck-ports"
SERVICE=_steamdeck-ports._tcp

say()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[aviso]\e[0m %s\n' "$*"; }
pause() { [[ -t 0 ]] && read -rp "Pulsa Enter para cerrar…" _ || true; }
fail() { printf '\e[1;31m[error]\e[0m %s\n' "$*" >&2; pause; exit 1; }

case "${1:-}" in
    -h|--help)
        [[ -f "$0" ]] && awk 'NR == 1 && /^#!/ { next } !/^#/ { exit } { sub(/^# ?/, ""); print }' "$0"
        exit 0 ;;
esac
command -v curl >/dev/null || fail "Falta curl"

# --- Instalación del propio cliente ------------------------------------------
self_install() {
    local url="${1%/}" desktop
    [[ -n "$url" ]] || fail "Uso: steamdeck-ports.sh --instalar http://<pc>:8765"
    mkdir -p "$APP_DIR" "$CONF_DIR"
    # Se descarga otra vez: con «curl … | bash» no hay archivo que copiar.
    curl -fsS -m 10 -o "$APP.new" "$url/steamdeck-ports.sh" || fail "No se puede descargar de $url"
    chmod +x "$APP.new"
    mv -f "$APP.new" "$APP"
    printf '%s\n' "$url" > "$CONF_DIR/servidor"
    desktop="[Desktop Entry]
Type=Application
Name=Ports por red
Comment=Instala y actualiza los ports que sirve el PC (tools/serve.sh)
Exec=\"$APP\"
Icon=folder-download
Terminal=true
Categories=Game;"
    mkdir -p "$HOME/.local/share/applications"
    printf '%s\n' "$desktop" > "$HOME/.local/share/applications/steamdeck-ports.desktop"
    if [[ -d "$HOME/Desktop" ]]; then
        printf '%s\n' "$desktop" > "$HOME/Desktop/Ports por red.desktop"
        chmod +x "$HOME/Desktop/Ports por red.desktop"
    fi
    say "Instalado: $APP"
    echo "    Ábrelo con «Ports por red» (escritorio o menú de aplicaciones, en Juegos)."
}

if [[ "${1:-}" == --instalar ]]; then
    self_install "${2:-}"
    exit 0
fi

# --- Servidor -----------------------------------------------------------------
reachable() { curl -fsS -m 3 -o /dev/null "${1%/}/index.tsv" 2>/dev/null; }

# URLs anunciadas por mDNS; primero las de cable (la Wi-Fi es más lenta).
mdns_urls() {
    command -v avahi-browse >/dev/null || return 0
    timeout 6 avahi-browse -rpt "$SERVICE" 2>/dev/null \
        | awk -F';' '$1 == "=" && $3 == "IPv4" { print ($2 ~ /^wl/ ? 1 : 0) "\thttp://" $8 ":" $9 }' \
        | sort -u | sort -n -k1,1 | cut -f2
}

find_server() {
    local u
    if [[ -n "${1:-}" ]]; then
        reachable "$1" || fail "No responde $1 (¿está en marcha tools/serve.sh en el PC?)"
        printf '%s' "${1%/}"; return
    fi
    say "Buscando el PC en la red…" >&2
    while IFS= read -r u; do
        reachable "$u" && { printf '%s' "$u"; return; }
    done < <(mdns_urls)
    if [[ -f "$CONF_DIR/servidor" ]]; then
        u="$(<"$CONF_DIR/servidor")"
        reachable "$u" && { printf '%s' "$u"; return; }
    fi
    warn "No encuentro el PC. ¿Está en marcha tools/serve.sh?" >&2
    read -rp "Escribe su dirección (p. ej. http://192.168.1.64:8765) o Intro para salir: " u
    [[ -n "$u" ]] || exit 0
    [[ "$u" == http* ]] || u="http://$u"
    [[ "$u" =~ :[0-9]+/?$ ]] || u="${u%/}:8765"
    reachable "$u" || fail "No responde $u"
    printf '%s' "${u%/}"
}

SERVER="$(find_server "${1:-}")"
[[ -n "$SERVER" ]] || exit 0
mkdir -p "$CONF_DIR"
printf '%s\n' "$SERVER" > "$CONF_DIR/servidor"

# Actualización del propio cliente (solo la copia instalada)
if [[ "$(readlink -f "$0" 2>/dev/null)" == "$APP" && -z "${STEAMDECK_PORTS_UPDATED:-}" ]]; then
    if curl -fsS -m 10 -o "$APP.new" "$SERVER/steamdeck-ports.sh" && ! cmp -s "$APP.new" "$APP"; then
        chmod +x "$APP.new"
        mv -f "$APP.new" "$APP"
        say "«Ports por red» actualizado."
        STEAMDECK_PORTS_UPDATED=1 exec "$APP" "$SERVER"
    fi
    rm -f "$APP.new"
fi

# --- Juegos -------------------------------------------------------------------
INDEX="$(curl -fsS -m 10 "$SERVER/index.tsv")" || fail "No se puede leer $SERVER/index.tsv"

# Carpetas donde puede haber juegos instalados: ~/Games y <tarjeta>/Games
bases=("$HOME/Games")
while IFS= read -r mnt; do bases+=("$mnt/Games"); done \
    < <(findmnt -rn -o TARGET 2>/dev/null | grep '^/run/media/' || true)

installed_version() {   # versión instalada de un id, o vacío
    local b
    for b in "${bases[@]}"; do
        [[ -f "$b/$1/.release-tag" ]] && { cat "$b/$1/.release-tag"; return; }
        [[ -d "$b/$1" ]] && { echo "?"; return; }
    done
    return 0
}

human_gb() { awk -v k="$1" 'BEGIN { printf "%.1f GB", k / 1048576 }' | tr . ,; }

ids=(); names=(); versions=(); sizes=(); have=()
while IFS=$'\t' read -r id name version size_kb proton _bytes; do
    [[ -n "$id" ]] || continue
    ids+=("$id"); names+=("$name"); versions+=("$version"); sizes+=("$size_kb")
    have+=("$(installed_version "$id")")
    [[ "$proton" == 1 ]] && names[-1]+=" (Proton)"
done <<<"$INDEX"
(( ${#ids[@]} )) || fail "El servidor no tiene juegos"

echo
say "Juegos en $SERVER"
printf '\n  %3s  %-40s %-19s %-19s %s\n' "nº" "juego" "en el PC" "instalado" "tamaño"
for i in "${!ids[@]}"; do
    state="${have[$i]:--}"
    mark=" "
    [[ -n "${have[$i]}" && "${have[$i]}" != "${versions[$i]}" ]] && mark="*"
    printf '  %3d%s %-40s %-19s %-19s %s\n' "$((i + 1))" "$mark" "${names[$i]:0:40}" \
        "${versions[$i]}" "$state" "$(human_gb "${sizes[$i]}")"
done
echo
echo "  * = hay versión nueva en el PC"
echo
read -rp "Números a instalar (separados por espacios), «a» = actualizar los marcados, Intro = salir: " choice
[[ -n "$choice" ]] || exit 0

sel=()
if [[ "$choice" =~ ^[aA]$ ]]; then
    for i in "${!ids[@]}"; do
        [[ -n "${have[$i]}" && "${have[$i]}" != "${versions[$i]}" ]] && sel+=("$i")
    done
    (( ${#sel[@]} )) || { say "No hay nada que actualizar."; pause; exit 0; }
else
    for n in $choice; do
        [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#ids[@]} )) || fail "Número no válido: $n"
        sel+=("$((n - 1))")
    done
fi

# URL de una ruta relativa (espacios y caracteres raros, codificados)
urlpath() { python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$1"; }

ok=(); bad=()
for i in "${sel[@]}"; do
    id="${ids[$i]}"
    echo
    say "─── ${names[$i]} (${versions[$i]}) ───"
    work="$CACHE/$id"
    rm -rf "$work"
    mkdir -p "$work"
    lst="$(curl -fsS -m 10 "$SERVER/listas/$id.lst")" || { warn "No se puede leer la lista de $id"; bad+=("$id"); continue; }
    fetched=1
    # Archivos del paquete (lista del servidor) y scripts comunes del repo
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        mkdir -p "$work/$(dirname "$f")"
        curl -fsS -m 60 -o "$work/$f" "$SERVER/$id/$(urlpath "$f")" || { warn "No se puede descargar $f"; fetched=0; break; }
    done <<<"$lst"
    for f in instalar.sh steam-art.py proton-dpi.sh; do
        (( fetched )) || break
        curl -fsS -m 60 -o "$work/$f" "$SERVER/comun/$f" || { warn "No se puede descargar $f"; fetched=0; }
    done
    if (( ! fetched )) || [[ ! -f "$work/instalar.sh" ]]; then
        bad+=("$id"); rm -rf "$work"; continue
    fi
    chmod +x "$work/instalar.sh"
    if PKG_URL="$SERVER/$id/$(urlpath "$id.tar.zst")" INSTALAR_SIN_PAUSA=1 bash "$work/instalar.sh"; then
        ok+=("${names[$i]}")
    else
        bad+=("${names[$i]}")
    fi
    rm -rf "$work"
done

echo
(( ${#ok[@]} )) && say "Instalados: $(IFS=,; echo "${ok[*]}" | sed 's/,/, /g')"
(( ${#bad[@]} )) && warn "Con errores: $(IFS=,; echo "${bad[*]}" | sed 's/,/, /g')"
pause
