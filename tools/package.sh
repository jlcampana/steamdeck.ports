#!/usr/bin/env bash
# Empaqueta games/<id>/build para la Steam Deck. Por cada juego crea:
#
#   <destino>/<id>/
#     <id>.tar.zst               el juego (carpeta <id>/)
#     <id>.tar.zst.sha256
#     Instalar <Nombre>.desktop  doble clic en el modo escritorio de la Deck
#     instalar.sh                el instalador (tools/deck/instalar.sh)
#     steam-art.py               pone las imágenes en la ficha de Steam
#     game.conf                  id, nombre, ejecutable, Proton, versión, tamaño
#     art/                       imágenes (games/<id>/art, si hay)
#
# Uso: tools/package.sh [-o destino] [id…]   (sin ids: todos los que tienen build/)
# Destino por defecto: DEST de local.conf (no va a git) o dist/.
#
# Fuera del paquete: private/venv (el Python del PC; run_game.sh usa el del
# sistema si no está), logs, __pycache__ y la caché de shaders (es de la GPU).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/dist"
# shellcheck source=/dev/null
[[ -f "$ROOT/local.conf" ]] && source "$ROOT/local.conf"

log() { printf '\e[1;34m[package]\e[0m %s\n' "$*"; }
die() { printf '\e[1;31m[package] %s\e[0m\n' "$*" >&2; exit 1; }

if [[ "${1:-}" == "-o" ]]; then
    [[ $# -ge 2 ]] || die "Falta la carpeta tras -o"
    DEST="$2"; shift 2
fi
command -v zstd >/dev/null || die "Falta zstd"

ids=("$@")
if (( ${#ids[@]} == 0 )); then
    for d in "$ROOT"/games/*/build; do ids+=("$(basename "$(dirname "$d")")"); done
fi
(( ${#ids[@]} )) || die "No hay ningún build"

EXCLUDES=(
    --exclude='build/private/venv'
    --exclude='build/private/*-logs'
    --exclude='build/private/shader-cache'
    --exclude='build/logs'
    --exclude='__pycache__'
)

package() {
    local id="$1" game="$ROOT/games/$1"
    [[ -f "$game/build/.release-tag" ]] || die "$id: no hay build terminado (games/$id/build.sh)"
    [[ -f "$game/game.conf" ]] || die "$id: falta games/$id/game.conf"
    local NAME EXEC PROTON STEAMGRIDDB
    # shellcheck source=/dev/null
    source "$game/game.conf"
    [[ -e "$game/build/$EXEC" ]] || die "$id: no existe build/$EXEC"

    local version out size_kb
    version="$(cat "$game/build/.release-tag")"
    out="$DEST/$id"
    mkdir -p "$out"
    size_kb="$(du -sk "$game/build" | cut -f1)"

    log "$id ($version): comprimiendo $(du -sh "$game/build" | cut -f1) en $out/$id.tar.zst"
    # La carpeta build/ se guarda como <id>/. Los enlaces duros (p. ej.
    # play-disc → imported-disc en doa2u) se conservan.
    tar -C "$game" "${EXCLUDES[@]}" --transform="s|^build|$id|" -cf - build \
        | zstd -T0 -6 -q -f -o "$out/$id.tar.zst.part"
    mv -f "$out/$id.tar.zst.part" "$out/$id.tar.zst"
    (cd "$out" && sha256sum "$id.tar.zst" > "$id.tar.zst.sha256")

    {
        echo "# Generado por tools/package.sh"
        printf 'ID=%q\nNAME=%q\nEXEC=%q\nPROTON=%q\nVERSION=%q\nSIZE_KB=%q\n' \
            "$id" "$NAME" "$EXEC" "${PROTON:-0}" "$version" "$size_kb"
    } > "$out/game.conf"
    install -m 755 "$ROOT/tools/deck/instalar.sh" "$out/instalar.sh"
    install -m 755 "$ROOT/tools/deck/steam-art.py" "$out/steam-art.py"

    # Solo las elegidas (art/<tipo>.png|jpg), no las candidatas.
    rm -rf "$out/art"
    local img chosen=()
    for img in "$game"/art/{cover,header,hero,logo,icon}.{png,jpg}; do
        [[ -f "$img" ]] && chosen+=("$img")
    done
    if (( ${#chosen[@]} )); then
        mkdir -p "$out/art"
        cp "${chosen[@]}" "$out/art/"
    else
        log "$id: sin imágenes (games/$id/art; ver tools/fetch-art.sh)"
    fi

    rm -f "$out"/Instalar*.desktop
    local desktop="$out/Instalar ${NAME//\//-}.desktop"
    {
        echo "[Desktop Entry]"
        echo "Type=Application"
        echo "Name=Instalar $NAME"
        echo "Comment=Instala $NAME ($version) y lo añade a Steam"
        # %k = ruta de este .desktop: el instalador está a su lado. Ejecuta
        #   bash -c 'exec "$(dirname "$1")/instalar.sh"' instalar <ruta>
        # con los escapes de la especificación (\\$ y \\" dentro de comillas).
        cat <<'EOF'
Exec=bash -c "exec \\"\\$(dirname \\"\\$1\\")/instalar.sh\\"" instalar %k
EOF
        echo "Icon=system-software-install"
        echo "Terminal=true"
    } > "$desktop"
    chmod +x "$desktop"
    log "$id: listo ($(du -sh "$out/$id.tar.zst" | cut -f1))"
}

for id in "${ids[@]}"; do package "$id"; done
