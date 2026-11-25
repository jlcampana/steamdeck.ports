# Funciones comunes para games/<id>/build.sh. Se carga con:
#   source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"
# Define ROOT, GAME_DIR, GAME_ID, LATEST, BUILD, ISOS, EXTRACT_XISO.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
GAME_ID="$(basename "$GAME_DIR")"
LATEST="$GAME_DIR/latest"
BUILD="$GAME_DIR/build"
ISOS="$ROOT/isos"
EXTRACT_XISO="$ROOT/tools/bin/extract-xiso"

# -h / --help: la cabecera del build.sh es su ayuda. Al cargar lib.sh con
# source y sin argumentos, "$@" son los del build.sh.
# shellcheck source=tools/help.sh
source "$ROOT/tools/help.sh"
show_help_if_asked "${BASH_SOURCE[1]}" "$@"

log()  { printf '\e[1;34m[%s]\e[0m %s\n' "$GAME_ID" "$*"; }
die()  { printf '\e[1;31m[%s] %s\e[0m\n' "$GAME_ID" "$*" >&2; exit 1; }

release_tag() { cat "$LATEST/.release-tag" 2>/dev/null || echo "?"; }

require_latest() {
    [[ -d "$LATEST" ]] || die "No existe $LATEST. Ejecuta ./update.sh $GAME_ID"
}

require_file() {
    [[ -e "$1" ]] || die "No existe $1"
}

require_extract_xiso() {
    [[ -x "$EXTRACT_XISO" ]] || die "Falta tools/bin/extract-xiso. Ejecuta tools/install.sh"
}

# Copia latest/ en build/. Si build/ es de otra versión (o se pasa -f), el
# build anterior se mueve a build.old/ (se pierde el build.old previo) para no
# perder partidas ni ajustes. Con la misma versión, se reutiliza build/.
# $1 = 1 para forzar un build limpio.
prepare_build() {
    local force="${1:-0}" tag old_tag
    tag="$(release_tag)"
    if [[ -d "$BUILD" ]]; then
        old_tag="$(cat "$BUILD/.release-tag" 2>/dev/null || echo "?")"
        if [[ "$old_tag" == "$tag" && "$force" -eq 0 ]]; then
            log "Reutilizando build/ ($tag)"
            return
        fi
        # Un build de esta versión que no terminó: se continúa (los scripts
        # de los ports reaprovechan lo hecho) sin tocar build.old/.
        if [[ "$old_tag" == "?" && "$(cat "$BUILD/.building-tag" 2>/dev/null)" == "$tag" && "$force" -eq 0 ]]; then
            log "Continuando el build sin terminar de $tag"
            return
        fi
        if [[ "$old_tag" == "?" ]]; then
            log "Borrando un build sin terminar ($(cat "$BUILD/.building-tag" 2>/dev/null || echo "?"))"
            rm -rf "$BUILD"
        else
            log "Moviendo el build anterior ($old_tag) a build.old/"
            rm -rf "$GAME_DIR/build.old"
            mv "$BUILD" "$GAME_DIR/build.old"
        fi
    fi
    log "Copiando latest/ ($tag) en build/"
    cp -a --reflink=auto "$LATEST" "$BUILD"
    # .release-tag (versión de un build terminado) solo lo pone finish_build:
    # un build a medias o fallido no debe parecer listo (update.sh y
    # package.sh lo miran). Mientras tanto, .building-tag.
    rm -f "$BUILD/.release-tag"
    echo "$tag" > "$BUILD/.building-tag"
}

# Motor de contenedores: podman (rootless) o docker con el daemon activo.
container_engine() {
    if command -v podman >/dev/null; then echo podman
    elif command -v docker >/dev/null && docker info >/dev/null 2>&1; then echo docker
    else die "Hace falta podman o docker (tools/install.sh)"
    fi
}

# Imagen común de compilación (Dockerfile en tools/docker/).
BUILD_IMAGE="steamdeck-ports/ubuntu-build:24.04"
BUILD_DOCKERFILE="$ROOT/tools/docker/ubuntu-build.Dockerfile"

# Carpeta real de isos/ (puede ser un enlace a otro disco).
ISOS_REAL="$(realpath "$ISOS" 2>/dev/null || echo "$ISOS")"

# El contenedor solo ve el proyecto y la carpeta real de isos/ (solo lectura):
# $1 tiene que estar en uno de los dos.
require_container_path() {
    [[ "$1" == "$ROOT"/* || "$1" == "$ISOS_REAL"/* ]] \
        || die "$1 tiene que estar dentro de $ROOT o de isos/ ($ISOS_REAL): es lo que se monta en el contenedor"
}

# Construye (o reutiliza de la caché) la imagen común y ejecuta un comando
# dentro. El proyecto se monta en la misma ruta que en el host, con el usuario
# del host, para que los archivos generados sean tuyos y las rutas coincidan.
# Si isos/ es un enlace a otro disco, su carpeta real se monta también, en solo
# lectura y en la misma ruta.
run_in_container() {
    local engine image="$BUILD_IMAGE"
    engine="$(container_engine)"
    log "Construyendo la imagen $image ($engine)"
    # Contexto = tools/docker (solo contiene Dockerfiles)
    "$engine" build -t "$image" -f "$BUILD_DOCKERFILE" "$(dirname "$BUILD_DOCKERFILE")"
    local user_args=(--user "$(id -u):$(id -g)")
    [[ "$engine" == podman ]] && user_args=(--userns=keep-id)
    log "Ejecutando en el contenedor: $*"
    local tty=(-i); [[ -t 0 && -t 1 ]] && tty=(-it)
    local isos_mount=()
    [[ -d "$ISOS_REAL" && "$ISOS_REAL" != "$ROOT"/* ]] && isos_mount=(-v "$ISOS_REAL:$ISOS_REAL:ro")
    "$engine" run --rm "${tty[@]}" \
        "${user_args[@]}" \
        --security-opt label=disable \
        -v "$ROOT:$ROOT" \
        "${isos_mount[@]}" \
        -w "$BUILD" \
        -e HOME=/tmp \
        "$image" "$@"
}

# Avisa si los ficheros de configuración del build guardan rutas absolutas
# del PC: en la Deck la carpeta estará en otra ruta.
check_absolute_paths() {
    local hits
    hits="$(find "$BUILD" -path "$BUILD/private/venv" -prune -o -type f -size -1M \
                \( -name '*.json' -o -name '*.txt' -o -name '*.toml' -o -name '*.cfg' \) -print0 \
            | xargs -0 -r grep -l -F "$ROOT" 2>/dev/null || true)"
    if [[ -n "$hits" ]]; then
        log "AVISO: estos ficheros contienen rutas absolutas de este PC ($ROOT):"
        sed "s|^$BUILD/|  build/|" <<<"$hits"
    else
        log "Sin rutas absolutas del PC en la configuración del build"
    fi
    local elf rp
    while IFS= read -r -d '' elf; do
        rp="$(readelf -d "$elf" 2>/dev/null | grep -E 'RPATH|RUNPATH' | grep -oE '\[.*\]' || true)"
        if [[ "$rp" == *"$ROOT"* ]]; then
            log "RUNPATH absoluto (lo cubre steamdeck.sh): ${elf#"$BUILD"/} $rp"
        fi
    done < <(find "$BUILD" -path "$BUILD/private/venv" -prune -o -type f -perm -u+x -size +100k -print0)
}

# Crea build/steamdeck.sh, el punto de entrada común de todos los juegos
# Linux en la Deck: arranca $1 (launcher.sh, nocturnerecomp…) añadiendo a
# LD_LIBRARY_PATH, con rutas relativas a la carpeta del juego, las carpetas
# donde el build dejó sus .so (SDL3). Los argumentos tras $1 se pasan siempre
# al ejecutable (p. ej. urban-reign --game). Los ejecutables compilados en el
# contenedor tienen RUNPATH absoluto a la ruta de este PC; LD_LIBRARY_PATH se
# consulta antes que RUNPATH, así que el juego funciona desde cualquier ruta.
# No se parchean los binarios porque run_game.py comprueba su SHA-256.
write_steamdeck_launcher() {
    local entry="$1" dirs=() d args=""
    shift
    if (( $# )); then args="$(printf ' %q' "$@")"; fi
    while IFS= read -r d; do dirs+=("$d"); done < <(
        find "$BUILD" -path "$BUILD/private/venv" -prune -o -type f -regextype posix-extended \
                -regex '.*/[^/]+\.so(\.[0-9]+)*' -print \
            | grep -v '/CMakeFiles/' | xargs -r -n1 dirname | sort -u \
            | xargs -r -n1 realpath --relative-to="$BUILD")
    {
        echo '#!/usr/bin/env bash'
        echo "# Generado por games/$GAME_ID/build.sh. Punto de entrada en la Steam Deck."
        echo 'HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
        echo 'LIBS=('
        for d in "${dirs[@]}"; do printf '    "$HERE/%s"\n' "$d"; done
        echo ')'
        echo 'export LD_LIBRARY_PATH="$(IFS=:; echo "${LIBS[*]}")${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"'
        echo 'cd "$HERE"'
        printf 'exec "$HERE/%s"%s "$@"\n' "$entry" "$args"
    } > "$BUILD/steamdeck.sh"
    chmod +x "$BUILD/steamdeck.sh"
    log "Creado build/steamdeck.sh -> $entry$args (${#dirs[@]} carpetas de librerías)"
}

finish_build() {
    release_tag > "$BUILD/.release-tag"
    rm -f "$BUILD/.building-tag"
    log "Build listo en $BUILD ($(du -sh "$BUILD" | cut -f1))"
}
