#!/usr/bin/env bash
# Descarga de SteamGridDB varias imágenes candidatas de cada tipo (cover,
# header, hero, logo, icon) para elegir las de la ficha de Steam.
#
# Uso: tools/fetch-art.sh [-n N] [id…]   (sin ids: todos; N por defecto 10)
#
#   games/<id>/art/candidatas/<tipo>/NN-<idsgdb>.<ext>   ordenadas por votos
#   games/<id>/art/candidatas/index.html                  para verlas todas
#   games/<id>/art/<tipo>.<ext>                           la elegida (va al paquete)
#
# La elegida de cada tipo se guarda en game.conf (ART_COVER=<id en SteamGridDB>…,
# va a git) y se descarga aunque no esté entre las N primeras. Si un tipo no
# tiene elegida, se usa la más votada (01) y se anota. Para cambiarla:
# tools/pick-art.sh <id> <tipo> <NN>. Lo ya descargado no se vuelve a bajar.
#
# El juego se toma de STEAMGRIDDB en games/<id>/game.conf
# (https://www.steamgriddb.com/game/<n>). Hace falta una API key (gratis, en
# https://www.steamgriddb.com/profile/preferences/api) en STEAMGRIDDB_API_KEY
# o en local.conf.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
[[ -f "$ROOT/local.conf" ]] && source "$ROOT/local.conf"

# shellcheck source=tools/art-lib.sh
source "$ROOT/tools/art-lib.sh"

log() { printf '\e[1;34m[art]\e[0m %s\n' "$*"; }
die() { printf '\e[1;31m[art] %s\e[0m\n' "$*" >&2; exit 1; }

COUNT=10
if [[ "${1:-}" == "-n" ]]; then
    [[ "${2:-}" =~ ^[0-9]+$ ]] && (( $2 >= 1 && $2 <= 50 )) || die "-n entre 1 y 50"
    COUNT="$2"; shift 2
fi
[[ -n "${STEAMGRIDDB_API_KEY:-}" ]] || die "Falta STEAMGRIDDB_API_KEY (env o local.conf)"
command -v jq >/dev/null || die "Falta jq"

API="https://www.steamgriddb.com/api/v2"
KINDS=("${ART_KINDS[@]}")
declare -A ENDPOINT=([cover]=grids [header]=grids [hero]=heroes [logo]=logos [icon]=icons)
declare -A QUERY=(
    [cover]="dimensions=600x900&types=static"
    [header]="dimensions=920x430,460x215&types=static"
    [hero]="types=static"
    [logo]="types=static"
    [icon]="types=static"
)
declare -A HINT=(
    [cover]="portada vertical 600x900"
    [header]="cabecera horizontal 920x430"
    [hero]="fondo de la ficha"
    [logo]="logo sobre el fondo"
    [icon]="icono"
)

api() { curl -fsS -H "Authorization: Bearer $STEAMGRIDDB_API_KEY" "$API/$1"; }

# Página para comparar las candidatas (rutas relativas; se abre en el navegador).
write_index() {
    local id="$1" art="$2" kind f name chosen
    {
        cat <<EOF
<!doctype html><html lang="es"><head><meta charset="utf-8">
<title>Imágenes de $id</title>
<style>
body{font-family:sans-serif;background:#1b2838;color:#c7d5e0;margin:16px}
h2{margin-top:32px} .grid{display:flex;flex-wrap:wrap;gap:12px}
figure{margin:0;padding:6px;background:#2a475e;border:3px solid transparent;border-radius:6px}
figure.chosen{border-color:#66c0f4} figcaption{font-size:13px;margin-top:4px;text-align:center}
img{display:block;max-height:220px;max-width:420px;background:repeating-conic-gradient(#555 0 25%,#333 0 50%) 0 0/16px 16px}
code{background:#0e1a26;padding:2px 6px}
</style></head><body>
<h1>$id</h1>
<p>Para elegir: <code>tools/pick-art.sh $id &lt;tipo&gt; &lt;NN&gt;</code>. Borde azul = elegida ahora.</p>
EOF
        for kind in "${KINDS[@]}"; do
            [[ -d "$art/candidatas/$kind" ]] || continue
            chosen="$(cat "$art/candidatas/$kind/.elegida" 2>/dev/null || true)"
            echo "<h2>$kind <small>(${HINT[$kind]})</small></h2><div class=\"grid\">"
            for f in "$art/candidatas/$kind"/*; do
                [[ -f "$f" ]] || continue
                name="$(basename "$f")"
                printf '<figure%s><a href="%s/%s"><img src="%s/%s" loading="lazy"></a><figcaption>%s %s</figcaption></figure>\n' \
                    "$([[ "$name" == "$chosen" ]] && echo ' class="chosen"')" \
                    "$kind" "$name" "$kind" "$name" "$kind" "${name%%-*}"
            done
            echo "</div>"
        done
        echo "</body></html>"
    } > "$art/candidatas/index.html"
}

fetch() {
    local id="$1" game="$ROOT/games/$1" STEAMGRIDDB=""
    [[ -f "$game/game.conf" ]] || die "$id: falta games/$id/game.conf"
    # shellcheck source=/dev/null
    source "$game/game.conf"
    local sgid
    sgid="$(grep -oE '/game/[0-9]+' <<<"$STEAMGRIDDB" | grep -oE '[0-9]+' || true)"
    if [[ -z "$sgid" ]]; then
        log "$id: sin STEAMGRIDDB en game.conf; se omite"
        return
    fi
    local art="$game/art" kind dir n imgid url ext file got first want var
    for kind in "${KINDS[@]}"; do
        dir="$art/candidatas/$kind"
        mkdir -p "$dir"
        var="$(art_var "$kind")"
        want="${!var:-}"   # elegida guardada en game.conf
        # Más votadas primero; solo png/jpg (lo que acepta Steam). Pasadas las
        # N primeras, solo se baja la elegida si está más abajo.
        n=0; got=0
        while IFS=$'\t' read -r imgid url; do
            ext="${url##*.}"; ext="${ext,,}"; [[ "$ext" == jpeg ]] && ext=jpg
            [[ "$ext" == png || "$ext" == jpg ]] || continue
            n=$((n + 1))
            (( n > COUNT )) && [[ "$imgid" != "$want" ]] && continue
            file="$(printf '%02d-%s.%s' "$n" "$imgid" "$ext")"
            if [[ ! -f "$dir/$file" ]]; then
                rm -f "$dir"/[0-9][0-9]-"$imgid".*   # misma imagen con otro puesto
                curl -fsSL -o "$dir/$file.part" "$url" && mv "$dir/$file.part" "$dir/$file" \
                    || { rm -f "$dir/$file.part"; log "$id: no se pudo bajar $url"; continue; }
                got=$((got + 1))
            fi
        done < <(api "${ENDPOINT[$kind]}/game/$sgid?${QUERY[$kind]}&nsfw=false" \
                 | jq -r '.data | sort_by(-(.score // 0)) | .[] | "\(.id)\t\(.url)"')
        log "$id: $kind: $(( n < COUNT ? n : COUNT )) candidatas ($got nuevas)"
        # La elegida en game.conf o, si no hay, la más votada.
        first=""
        if [[ -n "$want" ]]; then
            first="$(find "$dir" -maxdepth 1 -name "[0-9][0-9]-$want.*" -printf '%f\n' | head -1)"
            [[ -n "$first" ]] || log "$id: AVISO: la $kind elegida ($var=$want) ya no está en SteamGridDB"
        fi
        if [[ -z "$first" ]] && ! compgen -G "$art/$kind.*" >/dev/null; then
            first="$(find "$dir" -maxdepth 1 -name '01-*' -printf '%f\n' | head -1)"
        fi
        [[ -n "$first" ]] && set_art_choice "$game" "$kind" "$first"
    done
    write_index "$id" "$art"
    log "$id: compáralas en $art/candidatas/index.html"
}

ids=("$@")
if (( ${#ids[@]} == 0 )); then
    for c in "$ROOT"/games/*/game.conf; do ids+=("$(basename "$(dirname "$c")")"); done
fi
for id in "${ids[@]}"; do fetch "$id"; done
