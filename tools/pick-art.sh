#!/usr/bin/env bash
# Elige una de las imágenes candidatas que bajó tools/fetch-art.sh.
#
# Uso: tools/pick-art.sh <id> <tipo> <NN>
#   tipo: cover | header | hero | logo | icon
#   NN:   número de la candidata (el de games/<id>/art/candidatas/index.html)
# Ejemplo: tools/pick-art.sh doa3 cover 04
#
# Copia la candidata a games/<id>/art/<tipo>.<ext>, que es la que va al
# paquete, y guarda su id de SteamGridDB en game.conf (ART_<TIPO>=…, va a git)
# para que tools/fetch-art.sh la recupere en otro PC. Después hay que volver a
# empaquetar (tools/package.sh <id>).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=tools/art-lib.sh
source "$ROOT/tools/art-lib.sh"
die() { printf '\e[1;31m[art] %s\e[0m\n' "$*" >&2; exit 1; }

[[ $# -eq 3 ]] || die "Uso: tools/pick-art.sh <id> <tipo> <NN>"
id="$1" kind="$2" nn="$(printf '%02d' "$((10#$3))")"
[[ "$kind" =~ ^(cover|header|hero|logo|icon)$ ]] || die "Tipo no válido: $kind"
art="$ROOT/games/$id/art"
dir="$art/candidatas/$kind"
[[ -d "$dir" ]] || die "No hay candidatas en $dir (tools/fetch-art.sh $id)"

file="$(find "$dir" -maxdepth 1 -name "$nn-*" -printf '%f\n' | head -1)"
[[ -n "$file" ]] || die "No existe la candidata $nn de $kind"

set_art_choice "$ROOT/games/$id" "$kind" "$file"
# Marca la elegida en index.html
sed -i "\\|href=\"$kind/|s|<figure class=\"chosen\">|<figure>|" "$art/candidatas/index.html" 2>/dev/null || true
sed -i "s|<figure><a href=\"$kind/$file\">|<figure class=\"chosen\"><a href=\"$kind/$file\">|" \
    "$art/candidatas/index.html" 2>/dev/null || true
printf '\e[1;34m[art]\e[0m %s: %s = %s\n' "$id" "$kind" "$file"
