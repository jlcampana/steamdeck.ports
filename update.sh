#!/usr/bin/env bash
# Descarga la última release de cada port (ports.tsv) en latest/<id>/ y la
# descomprime en games/<id>/latest/. Si el repo no tiene release "latest" (solo
# prereleases), usa la más reciente. Las versiones se registran en ports.db.
#
# Uso: ./update.sh [-f] [-b] [id ...]
#   -f, --force   fuerza la descarga aunque la versión ya esté instalada
#   -b, --build   después, ejecuta games/<id>/build.sh y tools/package.sh de los
#                 juegos cuyo build/ o paquete no esté en la versión descargada
#   -h, --help    muestra esta ayuda
#   id            limita la actualización a esos juegos (por defecto, todos)
#
# Al final resume qué versiones se han descargado y qué builds y paquetes para
# la Deck (DEST de local.conf o dist/) se han quedado atrás.
#
# GITHUB_TOKEN (opcional) evita el límite de 60 peticiones/hora de la API.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/help.sh
source "$ROOT/tools/help.sh"
show_help_if_asked "$0" "$@"
DB="$ROOT/ports.db"
FORCE=0
BUILD=0
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        -f|--force) FORCE=1 ;;
        -b|--build) BUILD=1 ;;
        *) echo "Opción desconocida: $1 (ver ./update.sh --help)" >&2; exit 2 ;;
    esac
    shift
done
ONLY=("$@")

# Destino de los paquetes (como tools/package.sh)
DEST="$ROOT/dist"
# shellcheck source=/dev/null
[[ -f "$ROOT/local.conf" ]] && source "$ROOT/local.conf"

for cmd in curl jq sqlite3 unzip tar sha256sum; do
    command -v "$cmd" >/dev/null || { echo "Falta '$cmd'. Ejecuta tools/install.sh" >&2; exit 1; }
done

sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS releases (
    game          TEXT NOT NULL,
    tag           TEXT NOT NULL,
    asset         TEXT NOT NULL,
    url           TEXT NOT NULL,
    size          INTEGER,
    sha256        TEXT,
    published_at  TEXT,
    downloaded_at TEXT NOT NULL,
    PRIMARY KEY (game, tag)
);
CREATE TABLE IF NOT EXISTS installed (
    game         TEXT PRIMARY KEY,
    tag          TEXT NOT NULL,
    installed_at TEXT NOT NULL
);
SQL

sql_quote() { printf "'%s'" "${1//\'/\'\'}"; }

api() {
    local auth=()
    [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    curl -fsSL "${auth[@]}" -H "Accept: application/vnd.github+json" "https://api.github.com/$1"
}

# JSON de la release a descargar: la marcada como "latest" si tiene un archivo
# que cumpla la regex; si no (p. ej. un repo que solo publica prereleases, como
# doa4), la más reciente, sin contar borradores, que lo tenga.
release_json() {
    local repo="$1" regex="$2" json
    if json="$(api "repos/$repo/releases/latest" 2>/dev/null)" \
        && jq -e --arg re "$regex" 'any(.assets[]; .name | test($re))' <<<"$json" >/dev/null; then
        echo "$json"
        return
    fi
    api "repos/$repo/releases?per_page=30" | jq -e --arg re "$regex" '
        [.[] | select(.draft | not) | select(any(.assets[]; .name | test($re)))]
        | sort_by(.published_at) | last'
}

# Descomprime $1 en $2. Si el archivo tiene una única carpeta raíz, la aplana.
extract() {
    local archive="$1" dest="$2" tmp
    tmp="$(mktemp -d "$ROOT/.extract.XXXXXX")"
    case "$archive" in
        *.zip)            unzip -q "$archive" -d "$tmp" ;;
        *.tar.gz|*.tgz)   tar -xzf "$archive" -C "$tmp" ;;
        *.tar.xz)         tar -xJf "$archive" -C "$tmp" ;;
        *.tar.zst)        tar --zstd -xf "$archive" -C "$tmp" ;;
        *.7z)             7z x -y -o"$tmp" "$archive" >/dev/null ;;
        *) echo "  Formato no soportado: $archive" >&2; rm -rf "$tmp"; return 1 ;;
    esac
    local entries=("$tmp"/* "$tmp"/.[!.]*)
    local real=()
    for e in "${entries[@]}"; do [[ -e "$e" ]] && real+=("$e"); done
    local src="$tmp"
    if (( ${#real[@]} == 1 )) && [[ -d "${real[0]}" ]]; then src="${real[0]}"; fi
    rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    mv "$src" "$dest"
    rm -rf "$tmp"
}

updated=0
new_versions=()   # "id (antes -> ahora)"
ids=()            # juegos revisados
while IFS=$'\t' read -r id repo regex; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    if (( ${#ONLY[@]} )) && [[ ! " ${ONLY[*]} " == *" $id "* ]]; then continue; fi

    echo "== $id ($repo)"
    ids+=("$id")
    json="$(release_json "$repo" "$regex")" || { echo "  No hay ninguna release con un archivo que cumpla /$regex/" >&2; continue; }
    tag="$(jq -r .tag_name <<<"$json")"
    published="$(jq -r .published_at <<<"$json")"
    asset_json="$(jq -c --arg re "$regex" '[.assets[] | select(.name | test($re))] | first // empty' <<<"$json")"
    if [[ -z "$asset_json" ]]; then echo "  Ningún archivo coincide con /$regex/ en $tag" >&2; continue; fi
    name="$(jq -r .name <<<"$asset_json")"
    url="$(jq -r .browser_download_url <<<"$asset_json")"
    size="$(jq -r .size <<<"$asset_json")"
    digest="$(jq -r '.digest // "" | sub("^sha256:"; "")' <<<"$asset_json")"

    current="$(sqlite3 "$DB" "SELECT tag FROM installed WHERE game=$(sql_quote "$id");")"
    if [[ "$current" == "$tag" && -d "$ROOT/games/$id/latest" && $FORCE -eq 0 ]]; then
        echo "  Al día ($tag)"
        continue
    fi
    echo "  ${current:-(ninguna)} -> $tag  [$name, $((size / 1024 / 1024)) MB]"

    dldir="$ROOT/latest/$id"
    mkdir -p "$dldir"
    file="$dldir/$name"
    if [[ ! -f "$file" || "$(stat -c %s "$file")" != "$size" ]]; then
        curl -fL --progress-bar -o "$file.part" "$url"
        mv "$file.part" "$file"
    fi
    sha="$(sha256sum "$file" | cut -d' ' -f1)"
    if [[ -n "$digest" && "$sha" != "$digest" ]]; then
        echo "  SHA-256 no coincide (esperado $digest, obtenido $sha)" >&2
        rm -f "$file"; continue
    fi
    # Borra descargas antiguas de este juego
    find "$dldir" -maxdepth 1 -type f ! -name "$name" -delete

    extract "$file" "$ROOT/games/$id/latest"
    echo "$tag" > "$ROOT/games/$id/latest/.release-tag"

    now="$(date -u +%FT%TZ)"
    sqlite3 "$DB" <<SQL
INSERT OR REPLACE INTO releases VALUES ($(sql_quote "$id"), $(sql_quote "$tag"), $(sql_quote "$name"),
    $(sql_quote "$url"), $size, $(sql_quote "$sha"), $(sql_quote "$published"), $(sql_quote "$now"));
INSERT OR REPLACE INTO installed VALUES ($(sql_quote "$id"), $(sql_quote "$tag"), $(sql_quote "$now"));
SQL
    echo "  Descomprimido en games/$id/latest"
    updated=$((updated + 1))
    new_versions+=("$id (${current:-nada} -> $tag)")
done < "$ROOT/ports.tsv"

tag_of() { cat "$1" 2>/dev/null || true; }
pkg_tag_of() {   # VERSION del game.conf de un paquete (escrito con printf %q)
    local v
    v="$(sed -n 's/^VERSION=//p' "$1" 2>/dev/null)"
    [[ -n "$v" ]] && eval "printf '%s' $v"
}

# Qué builds y paquetes no están en la versión de latest/
stale_builds=(); stale_packages=()
check_stale() {
    stale_builds=(); stale_packages=()
    local id latest built packaged
    for id in "${ids[@]}"; do
        latest="$(tag_of "$ROOT/games/$id/latest/.release-tag")"
        [[ -n "$latest" ]] || continue
        built="$(tag_of "$ROOT/games/$id/build/.release-tag")"
        packaged="$(pkg_tag_of "$DEST/$id/game.conf")"
        [[ "$built" == "$latest" ]] || stale_builds+=("$id (${built:-sin build} -> $latest)")
        [[ "$packaged" == "$latest" ]] || stale_packages+=("$id (${packaged:-sin paquete} -> $latest)")
    done
}
join_by() { local IFS=","; local out="${*:2}"; echo "${out//,/$1}"; }

summary() {
    echo
    if (( ${#new_versions[@]} )); then
        echo "Versiones nuevas: $(join_by ', ' "${new_versions[@]}")"
    else
        echo "Versiones nuevas: ninguna"
    fi
    check_stale
    (( ${#stale_builds[@]} )) && echo "Builds atrasados: $(join_by ', ' "${stale_builds[@]}")"
    (( ${#stale_packages[@]} )) && echo "Paquetes atrasados ($DEST): $(join_by ', ' "${stale_packages[@]}")"
    if (( ${#stale_builds[@]} + ${#stale_packages[@]} == 0 )); then
        echo "Builds y paquetes al día."
    elif (( ! BUILD )); then
        echo "Para generarlos: ./update.sh --build [id …]  (o games/<id>/build.sh y tools/package.sh <id>)"
    fi
    return 0
}

summary

# --- --build: compila y empaqueta lo atrasado -------------------------------
if (( BUILD )); then
    failed=()
    for entry in "${stale_builds[@]}"; do
        id="${entry%% *}"
        echo
        echo "== Build de $id"
        "$ROOT/games/$id/build.sh" || { failed+=("$id (build)"); continue; }
    done
    check_stale
    for entry in "${stale_packages[@]}"; do
        id="${entry%% *}"
        # Sin build terminado de esa versión no se empaqueta
        [[ " ${failed[*]} " == *" $id (build)"* ]] && continue
        [[ -f "$ROOT/games/$id/build/.release-tag" ]] || continue
        echo
        echo "== Paquete de $id"
        "$ROOT/tools/package.sh" "$id" || failed+=("$id (paquete)")
    done
    new_versions=()
    summary
    if (( ${#failed[@]} )); then
        echo "Fallos: $(join_by ', ' "${failed[@]}")" >&2
        exit 1
    fi
fi
