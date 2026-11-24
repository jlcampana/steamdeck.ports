#!/usr/bin/env bash
# DOA4: paso propio del instalador de la Deck (tools/deck/instalar.sh lo
# ejecuta tras descomprimir, con la carpeta del juego como $1 y VERSION en el
# entorno). tools/package.sh lo copia al paquete como post-install.sh.
#
# 1. dead_or_alive_4.toml: doa4_game_files = game/ y doa4_user_data =
#    user_data/, como rutas de Windows (Z: = / en Proton) con barras normales,
#    para que el juego arranque sin la pantalla de configuración y guarde las
#    partidas dentro de su carpeta (y no en el prefijo de Proton).
# 2. Hasta alpha-v0.3.7, el juego se congela al arrancar en Proton: abre el
#    puerto UDP 1000 y en Linux solo root puede abrir puertos < 1024
#    (dwreckgg/doa4-online#12, arreglado para la 0.3.8). Se permite con
#    net.ipv4.ip_unprivileged_port_start=1000 (pide la contraseña de sudo).
set -euo pipefail

DEST="$1"
VERSION="${VERSION:-}"
say()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[aviso]\e[0m %s\n' "$*"; }

# --- 1. Rutas en dead_or_alive_4.toml ---------------------------------------
toml="$DEST/dead_or_alive_4.toml"
mkdir -p "$DEST/user_data"
toml_string() { local s="${1//\\/\\\\}"; printf '"%s"' "${s//\"/\\\"}"; }
# Pone `clave = valor` como clave de primer nivel (antes de cualquier [tabla]).
upsert() {
    local key="$1" value="$2" tmp
    tmp="$(mktemp "$toml.XXXXXX")"
    {
        printf '%s = %s\n' "$key" "$value"
        [[ -f "$toml" ]] && grep -v -E "^[[:space:]]*$key[[:space:]]*=" "$toml" || true
    } > "$tmp"
    mv "$tmp" "$toml"
}
upsert doa4_user_data  "$(toml_string "Z:$DEST/user_data")"
upsert doa4_game_files "$(toml_string "Z:$DEST/game")"
say "Rutas del juego y de las partidas en dead_or_alive_4.toml"

# --- 2. Puerto 1000 (solo hasta alpha-v0.3.7) -------------------------------
needs_port_fix() {
    [[ "$VERSION" =~ ^alpha-v0\.([0-9]+)\.([0-9]+)$ ]] || return 1
    local minor="${BASH_REMATCH[1]}" patch="${BASH_REMATCH[2]}"
    (( minor < 3 || (minor == 3 && patch <= 7) ))
}
if needs_port_fix; then
    current="$(sysctl -n net.ipv4.ip_unprivileged_port_start 2>/dev/null || echo 1024)"
    if (( current <= 1000 )); then
        say "El puerto 1000 ya está permitido (ip_unprivileged_port_start=$current)"
    else
        echo
        warn "Esta versión ($VERSION) se queda congelada al arrancar en Proton si no se"
        echo "    permite a los usuarios abrir el puerto 1000. El arreglo (se mantiene al reiniciar):"
        echo "      net.ipv4.ip_unprivileged_port_start=1000  en /etc/sysctl.d/99-doa4.conf"
        echo "    Hace falta la contraseña de sudo (si no tienes, créala con «passwd»)."
        read -rp "¿Aplicarlo ahora? [S/n] " a || a=n
        if [[ ! "$a" =~ ^[nN] ]]; then
            if echo 'net.ipv4.ip_unprivileged_port_start=1000' | sudo tee /etc/sysctl.d/99-doa4.conf >/dev/null \
                && sudo sysctl -q -w net.ipv4.ip_unprivileged_port_start=1000; then
                say "Puerto 1000 permitido"
            else
                warn "No se pudo aplicar. Hazlo a mano en una terminal:"
                echo "      echo 'net.ipv4.ip_unprivileged_port_start=1000' | sudo tee /etc/sysctl.d/99-doa4.conf"
                echo "      sudo sysctl -w net.ipv4.ip_unprivileged_port_start=1000"
            fi
        else
            warn "Sin esto el juego se congelará al arrancar (hasta la 0.3.8)."
        fi
    fi
fi
