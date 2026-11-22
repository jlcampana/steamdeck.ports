#!/usr/bin/env bash
# Descarga la última release de cada port (ports.tsv) en latest/<id>/ y la
# descomprime en games/<id>/latest/. Las versiones se registran en ports.db.
#
# Uso: ./update.sh [-f] [id ...]
#   -f   fuerza la descarga aunque la versión ya esté instalada
#   id   limita la actualización a esos juegos (por defecto, todos)
#
# GITHUB_TOKEN (opcional) evita el límite de 60 peticiones/hora de la API.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB="$ROOT/ports.db"
FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ONLY=("$@")

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
while IFS=$'\t' read -r id repo regex; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    if (( ${#ONLY[@]} )) && [[ ! " ${ONLY[*]} " == *" $id "* ]]; then continue; fi

    echo "== $id ($repo)"
    json="$(api "repos/$repo/releases/latest")" || { echo "  No se pudo consultar la release" >&2; continue; }
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
done < "$ROOT/ports.tsv"

echo
echo "Actualizados: $updated. Ejecuta games/<id>/build.sh para generar el build."
