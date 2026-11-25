#!/usr/bin/env bash
# Descarga la última release de cada port (ports.tsv) en latest/<id>/ y la
# descomprime en games/<id>/latest/. Si el repo no tiene release "latest" (solo
# prereleases), usa la más reciente. Las versiones se registran en ports.db.
#
# Uso: ./update.sh [-f] [-b | -m | -M] [id ...]
#   -f, --force    fuerza la descarga aunque la versión ya esté instalada
#   -b, --build    después, ejecuta games/<id>/build.sh y tools/package.sh de los
#                  juegos cuyo build/ o paquete no esté en la versión descargada
#   -m, --menu     menú de builds aunque no haya terminal (por defecto sale
#                  solo si stdin y stdout son una terminal)
#   -M, --no-menu  sin menú de builds
#   -h, --help     muestra esta ayuda
#   id             limita la actualización a esos juegos (por defecto, todos)
#
# Al final resume qué versiones se han descargado y qué builds y paquetes para
# la Deck (DEST de local.conf o dist/) se han quedado atrás. También avisa si
# una release trae un archivo específico para Steam Deck / SteamOS (podría
# servir en vez de la versión de Linux o de Windows que se usa ahora).
#
# Menú de builds (desde una terminal, sin --build): lista todos los juegos con
# su nombre, versión y estado, con los que tienen un UPDATE ya marcados. De cada juego
# elegido compila lo que haga falta (build.sh si build/ no es de esa versión)
# y lo empaqueta siempre: sirve también para regenerar paquetes perdidos.
# Usa whiptail si está; si no (o con UPDATE_MENU=text), una lista numerada.
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
MENU=auto
while [[ "${1:-}" == -* ]]; do
    case "$1" in
        -f|--force) FORCE=1 ;;
        -b|--build) BUILD=1 ;;
        -m|--menu) MENU=1 ;;
        -M|--no-menu) MENU=0 ;;
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
deck_assets=()    # "id: archivo" de releases con algo para Steam Deck
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
    while IFS= read -r deck; do
        [[ -n "$deck" ]] || continue
        echo "  AVISO: esta release trae un archivo para Steam Deck: $deck"
        deck_assets+=("$id: $deck ($tag)")
    done < <(jq -r '.assets[].name | select(test("steam.?deck|steamos|[-_.]deck[-_.]"; "i"))' <<<"$json")
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
    return 0   # sin paquete: vacío (con set -e, un [[ ]] falso al final cortaría)
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
        # Con el paquete al día, el build/ no hace falta (clean-builds.sh lo borra)
        [[ "$packaged" == "$latest" ]] && continue
        [[ "$built" == "$latest" ]] || stale_builds+=("$id (${built:-sin build} -> $latest)")
        stale_packages+=("$id (${packaged:-sin paquete} -> $latest)")
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
    if (( ${#deck_assets[@]} )); then
        echo "Archivos para Steam Deck en las releases (revisar si sustituyen a lo que usamos):"
        printf '  %s\n' "${deck_assets[@]}"
    fi
    check_stale
    (( ${#stale_builds[@]} )) && echo "Builds atrasados: $(join_by ', ' "${stale_builds[@]}")"
    (( ${#stale_packages[@]} )) && echo "Paquetes atrasados ($DEST): $(join_by ', ' "${stale_packages[@]}")"
    if (( ${#stale_builds[@]} + ${#stale_packages[@]} == 0 )); then
        echo "Builds y paquetes al día."
    elif (( ! BUILD )) && [[ "$MENU" != 1 ]]; then
        echo "Para generarlos: ./update.sh --build [id …]  (o games/<id>/build.sh y tools/package.sh <id>)"
    fi
    return 0
}

summary

# --- Build y paquete de una lista de juegos ---------------------------------
# build.sh solo si build/ no es de la versión de latest/; paquete si está
# atrasado o, con $1 = 1, siempre (regenerar uno perdido).
failed=()
build_and_package() {
    local always="$1" id latest built packaged
    shift
    for id in "$@"; do
        latest="$(tag_of "$ROOT/games/$id/latest/.release-tag")"
        built="$(tag_of "$ROOT/games/$id/build/.release-tag")"
        if [[ -z "$latest" ]]; then
            echo "== $id: no hay games/$id/latest (./update.sh $id)" >&2
            failed+=("$id (sin descarga)"); continue
        fi
        if [[ "$built" != "$latest" ]]; then
            echo
            echo "== Build de $id ($latest)"
            "$ROOT/games/$id/build.sh" || { failed+=("$id (build)"); continue; }
        fi
        packaged="$(pkg_tag_of "$DEST/$id/game.conf")"
        if (( always )) || [[ "$packaged" != "$latest" ]]; then
            echo
            echo "== Paquete de $id ($latest)"
            "$ROOT/tools/package.sh" "$id" || failed+=("$id (paquete)")
        fi
    done
}

# Nombre del juego (NAME de games/<id>/game.conf) o el id.
game_name() {
    local n
    n="$( [[ -f "$ROOT/games/$1/game.conf" ]] && source "$ROOT/games/$1/game.conf" && echo "${NAME:-}")" || true
    echo "${n:-$1}"
}

# Menú: elige juegos (todos los de ports.tsv con descarga). Deja los ids en
# $chosen. Devuelve 1 si se cancela.
chosen=()
choose_games() {
    local id latest built packaged old state mark all=() names=() states=() marks=()
    while IFS=$'\t' read -r id _; do
        [[ -z "$id" || "$id" == \#* ]] && continue
        latest="$(tag_of "$ROOT/games/$id/latest/.release-tag")"
        [[ -n "$latest" ]] || continue
        built="$(tag_of "$ROOT/games/$id/build/.release-tag")"
        packaged="$(pkg_tag_of "$DEST/$id/game.conf")"
        # Estado: al día (paquete de la versión descargada; el build/ no hace
        # falta), UPDATE (hay una versión anterior empaquetada o compilada),
        # falta el paquete (build al día) o nuevo (ni build ni paquete).
        # Marcados por defecto: solo los UPDATE.
        mark=0
        old="${packaged:-$built}"
        if [[ "$packaged" == "$latest" ]]; then
            state="al día"
        elif [[ -n "$old" && "$old" != "$latest" ]]; then
            mark=1; state="UPDATE desde $old"
        elif [[ "$built" == "$latest" ]]; then
            state="falta el paquete"
        else
            state="nuevo: sin build ni paquete"
        fi
        all+=("$id"); names+=("$(game_name "$id")"); states+=("$state"); marks+=("$mark")
    done < "$ROOT/ports.tsv"
    (( ${#all[@]} )) || return 1

    # Columnas al ancho del contenido: nombre, versión, estado
    local i rows=() wn=0 wv=0 wid=0 wrow=0 v
    for i in "${!all[@]}"; do
        (( ${#names[$i]} > wn )) && wn=${#names[$i]}
        v="$(tag_of "$ROOT/games/${all[$i]}/latest/.release-tag")"
        (( ${#v} > wv )) && wv=${#v}
        (( ${#all[$i]} > wid )) && wid=${#all[$i]}
    done
    for i in "${!all[@]}"; do
        rows+=("$(printf "%-${wn}s  %-${wv}s  %s" "${names[$i]}" \
            "$(tag_of "$ROOT/games/${all[$i]}/latest/.release-tag")" "${states[$i]}")")
        (( ${#rows[$i]} > wrow )) && wrow=${#rows[$i]}
    done

    if [[ "${UPDATE_MENU:-}" != text ]] && command -v whiptail >/dev/null; then
        local items=() out cols width text pad
        text="Espacio marca/desmarca, Intro acepta. Paquetes en: $DEST"
        # Ancho del cuadro: id + fila + casilla y márgenes de whiptail, con
        # holgura; no más que la terminal
        cols="$(tput cols 2>/dev/null || echo 80)"
        width=$(( wid + wrow + 26 ))
        (( width < ${#text} + 6 )) && width=$(( ${#text} + 6 ))
        (( width > cols - 2 )) && width=$(( cols - 2 ))
        # La lista (zona azul) mide lo que su texto: «[ ] » + id + 2 + fila.
        # Se rellenan las filas con espacios para que llegue hasta dejar a la
        # derecha el mismo margen que a la izquierda (borde + 2 espacios).
        pad=$(( width - wid - 12 ))
        for i in "${!all[@]}"; do
            items+=("${all[$i]}" "$(printf "%-${pad}s" "${rows[$i]}")")
            (( marks[i] )) && items+=(ON) || items+=(OFF)
        done
        out="$(whiptail --title "Build y paquete para la Deck" --separate-output \
            --checklist "$text" \
            $(( ${#all[@]} + 8 )) "$width" "${#all[@]}" "${items[@]}" 3>&1 1>&2 2>&3)" || return 1
        mapfile -t chosen <<<"$out"
        [[ -n "${chosen[0]:-}" ]] || chosen=()
        return 0
    fi

    echo
    echo "Build y paquete para la Deck (paquetes en $DEST):"
    for i in "${!all[@]}"; do
        printf '  %2d) [%s] %s\n' $((i + 1)) "$( (( marks[i] )) && echo x || echo ' ')" "${rows[$i]}"
    done
    local answer n
    read -rp "Números separados por espacios, 'a' = todos, Intro = los marcados [x], 'n' = ninguno: " answer || return 1
    chosen=()
    case "$answer" in
        "") for i in "${!all[@]}"; do (( marks[i] )) && chosen+=("${all[$i]}"); done ;;
        n|N) ;;
        a|A) chosen=("${all[@]}") ;;
        *) for n in $answer; do
               [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#all[@]} )) \
                   || { echo "Número no válido: $n" >&2; return 1; }
               chosen+=("${all[$((n - 1))]}")
           done ;;
    esac
    return 0
}

# --- --build: compila y empaqueta lo atrasado -------------------------------
if (( BUILD )); then
    todo=()
    for entry in "${stale_builds[@]}" "${stale_packages[@]}"; do
        id="${entry%% *}"
        [[ " ${todo[*]} " == *" $id "* ]] || todo+=("$id")
    done
    build_and_package 0 "${todo[@]}"
elif [[ "$MENU" == 1 || ( "$MENU" == auto && -t 0 && -t 1 ) ]]; then
    if choose_games && (( ${#chosen[@]} )); then
        echo "Elegidos: ${chosen[*]}"
        build_and_package 1 "${chosen[@]}"
    else
        echo "Sin builds."
        exit 0
    fi
else
    exit 0
fi

# Resumen después de compilar y empaquetar
ids=(); while IFS=$'\t' read -r id _; do [[ -z "$id" || "$id" == \#* ]] || ids+=("$id"); done < "$ROOT/ports.tsv"
new_versions=(); deck_assets=()
summary
if (( ${#failed[@]} )); then
    echo "Fallos: $(join_by ', ' "${failed[@]}")" >&2
    exit 1
fi
