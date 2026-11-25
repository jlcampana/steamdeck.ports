#!/usr/bin/env bash
# Empaqueta games/<id>/build para la Steam Deck. Por cada juego crea:
#
#   <destino>/<id>/
#     <id>.tar.zst               el juego (carpeta <id>/)
#     <id>.tar.zst.sha256
#     Instalar <Nombre>.desktop  doble clic en el modo escritorio de la Deck
#     instalar.sh                el instalador (tools/deck/instalar.sh)
#     steam-art.py               pone las imágenes en la ficha de Steam
#     proton-dpi.sh              (PC, Proton) pone los DPI antes de arrancar
#     post-install.sh            paso propio del juego (games/<id>/deck-post-install.sh), si lo hay
#     game.conf                  id, nombre, ejecutable, Proton, versión, tamaño,
#                                PC_GAMES (de local.conf: dónde instalar en un PC)
#                                y PC_PROTON_DPI (de local.conf: DPI de los juegos
#                                con Proton en un PC; 192 por defecto, 96 = normal)
#     art/                       imágenes (games/<id>/art, si hay)
#
#     README.md                  cómo instalarlo en la Deck (tools/deck/README.md.in)
#
# Uso: tools/package.sh [-o destino] [-m] [id…]   (sin ids: todos los que tienen build/)
#   -o destino  carpeta de los paquetes
#   -h, --help  muestra esta ayuda
#   -m  solo metadatos: README, instalador, game.conf e imágenes, sin volver a
#       comprimir el juego (tiene que haber ya un <id>.tar.zst de esa versión)
# Destino por defecto: DEST de local.conf (no va a git) o dist/.
#
# Fuera del paquete: private/venv (el Python del PC; run_game.sh usa el del
# sistema si no está), logs, __pycache__ y la caché de shaders (es de la GPU).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/help.sh
source "$ROOT/tools/help.sh"
# shellcheck source=tools/notify.sh
source "$ROOT/tools/notify.sh"
show_help_if_asked "$0" "$@"
DEST="$ROOT/dist"
# shellcheck source=/dev/null
[[ -f "$ROOT/local.conf" ]] && source "$ROOT/local.conf"

log() { printf '\e[1;34m[package]\e[0m %s\n' "$*"; }
die() { printf '\e[1;31m[package] %s\e[0m\n' "$*" >&2; exit 1; }

META_ONLY=0
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        -o) [[ $# -ge 2 ]] || die "Falta la carpeta tras -o"; DEST="$2"; shift 2 ;;
        -m) META_ONLY=1; shift ;;
        *)  die "Opción desconocida: $1 (ver tools/package.sh --help)" ;;
    esac
done
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
    --exclude='build/.building-tag'
)

# Imagen de art/ de un tipo (png o jpg), o vacío.
art_file() { local f; for f in "$1/art/$2".{png,jpg}; do [[ -f "$f" ]] && { basename "$f"; return; }; done; return 0; }

# README.md del paquete a partir de tools/deck/README.md.in.
write_readme() {
    local id="$1" out="$2" version="$3" size_kb="$4" t hero logo cover header icon top="" gallery="" proton=""
    hero="$(art_file "$out" hero)"; logo="$(art_file "$out" logo)"
    cover="$(art_file "$out" cover)"; header="$(art_file "$out" header)"; icon="$(art_file "$out" icon)"
    [[ -n "$hero" ]] && top+="![$NAME](art/$hero)"$'\n\n'
    [[ -n "$logo" ]] && top+="<p align=\"center\"><img src=\"art/$logo\" alt=\"$NAME\" width=\"420\"></p>"$'\n\n'
    if [[ -n "$cover$header$icon" ]]; then
        gallery="Así se verá en Steam:"$'\n\n'
        [[ -n "$cover" ]] && gallery+="<img src=\"art/$cover\" alt=\"Portada\" height=\"240\"> "
        [[ -n "$header" ]] && gallery+="<img src=\"art/$header\" alt=\"Cabecera\" height=\"112\"> "
        [[ -n "$icon" ]] && gallery+="<img src=\"art/$icon\" alt=\"Icono\" height=\"64\">"
        gallery+=$'\n'
    fi
    if [[ "${PROTON:-0}" == 1 ]]; then
        proton=$'7. **Este juego es de Windows: hay que activar Proton.** En Steam, en el juego →\n'
        proton+=$'   ⚙ → Propiedades → Compatibilidad → «Forzar el uso de una herramienta de\n'
        proton+=$'   compatibilidad» → Proton (la versión más reciente). El instalador lo recuerda.\n'
    fi
    # Sustituciones literales (sin que & tenga significado especial)
    shopt -u patsub_replacement 2>/dev/null || true
    t="$(<"$ROOT/tools/deck/README.md.in")"
    t="${t//@ART_TOP@/$top}"
    t="${t//@ART_GALLERY@/$gallery}"
    t="${t//@PROTON_STEP@/$proton}"
    local post=""
    [[ -f "$out/post-install.sh" ]] && post="- Ejecuta \`post-install.sh\`, el paso propio de este juego (ver «Notas de este juego»)."$'\n'
    t="${t//@POST_INSTALL@/$post}"
    local notes=""
    if [[ -f "$ROOT/games/$id/deck-notes.md" ]]; then
        notes="## Notas de este juego"$'\n\n'"$(<"$ROOT/games/$id/deck-notes.md")"$'\n\n'
    fi
    t="${t//@NOTES@/$notes}"
    t="${t//@NAME@/$NAME}"
    t="${t//@ID@/$id}"
    t="${t//@EXEC@/$EXEC}"
    t="${t//@VERSION@/$version}"
    t="${t//@SAVES@/$SAVES}"
    t="${t//@SIZE_GB@/$(awk -v k="$size_kb" 'BEGIN { printf "%.1f", k / 1048576 }' | tr . ,)}"
    printf '%s\n' "$t" > "$out/README.md"
}

# Valor de una variable del game.conf de un paquete (escrito con printf %q)
pkg_value() {
    local v
    v="$(sed -n "s/^$2=//p" "$1")"
    eval "printf '%s' $v"
}

package() {
    local id="$1" game="$ROOT/games/$1"
    [[ -f "$game/build/.release-tag" ]] || (( META_ONLY )) \
        || die "$id: no hay build terminado (games/$id/build.sh)"
    [[ -f "$game/game.conf" ]] || die "$id: falta games/$id/game.conf"
    local NAME EXEC PROTON STEAMGRIDDB SAVES="la carpeta del juego" KEEP="" KEEP_EXCLUDE=""
    # shellcheck source=/dev/null
    source "$game/game.conf"
    local version out size_kb
    out="$DEST/$id"
    if [[ -f "$game/build/.release-tag" ]]; then
        [[ -e "$game/build/$EXEC" ]] || die "$id: no existe build/$EXEC"
        version="$(cat "$game/build/.release-tag")"
        size_kb="$(du -sk "$game/build" | cut -f1)"
    else
        # -m sin build/ (p. ej. tras clean-builds.sh): versión y tamaño del paquete
        [[ -f "$out/game.conf" ]] || die "$id: -m sin build/ ni paquete previo en $out"
        version="$(pkg_value "$out/game.conf" VERSION)"
        size_kb="$(pkg_value "$out/game.conf" SIZE_KB)"
    fi
    mkdir -p "$out"

    if (( META_ONLY )); then
        [[ -f "$out/$id.tar.zst" ]] || die "$id: -m sin paquete previo en $out"
        local packaged
        packaged="$(sed -n 's/^VERSION=//p' "$out/game.conf" 2>/dev/null)"
        [[ "$(eval "echo $packaged")" == "$version" ]] \
            || die "$id: el paquete de $out es de otra versión (${packaged:-?}); empaqueta sin -m"
        log "$id ($version): solo metadatos"
    else
        log "$id ($version): comprimiendo $(du -sh "$game/build" | cut -f1) en $out/$id.tar.zst"
        # La carpeta build/ se guarda como <id>/. Los enlaces duros (p. ej.
        # play-disc → imported-disc en doa2u) se conservan.
        tar -C "$game" "${EXCLUDES[@]}" --transform="s|^build|$id|" -cf - build \
            | zstd -T0 -6 -q -f -o "$out/$id.tar.zst.part"
        mv -f "$out/$id.tar.zst.part" "$out/$id.tar.zst"
        (cd "$out" && sha256sum "$id.tar.zst" > "$id.tar.zst.sha256")
    fi

    {
        echo "# Generado por tools/package.sh"
        printf 'ID=%q\nNAME=%q\nEXEC=%q\nPROTON=%q\nVERSION=%q\nSIZE_KB=%q\nPC_GAMES=%q\nKEEP=%q\nKEEP_EXCLUDE=%q\nPC_PROTON_DPI=%q\n' \
            "$id" "$NAME" "$EXEC" "${PROTON:-0}" "$version" "$size_kb" "${PC_GAMES:-}" "$KEEP" "$KEEP_EXCLUDE" \
            "${PC_PROTON_DPI:-192}"
    } > "$out/game.conf"
    install -m 755 "$ROOT/tools/deck/instalar.sh" "$out/instalar.sh"
    install -m 755 "$ROOT/tools/deck/steam-art.py" "$out/steam-art.py"
    install -m 755 "$ROOT/tools/deck/proton-dpi.sh" "$out/proton-dpi.sh"
    if [[ -f "$game/deck-post-install.sh" ]]; then
        install -m 755 "$game/deck-post-install.sh" "$out/post-install.sh"
    else
        rm -f "$out/post-install.sh"
    fi

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
    write_readme "$id" "$out" "$version" "$size_kb"
    log "$id: listo ($(du -sh "$out/$id.tar.zst" | cut -f1))"
    notify "Paquete de $id listo" "$version, $(du -sh "$out/$id.tar.zst" | cut -f1) en $out"
}

for id in "${ids[@]}"; do package "$id"; done
