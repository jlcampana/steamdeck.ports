#!/usr/bin/env bash
# Bayonetta 2 (B2recomp): arranque en la Deck (lo llama steamdeck.sh). Lo
# mismo que scripts/play.sh y el botón Play del lanzador del port: el juego
# (build-linux/game_native) con la romfs, los ajustes de config/ y las
# partidas en build-linux/play/userdata; log en build-linux/play/stdout.txt.
#   --opciones   abre el lanzador del port (ajustes de gráficos y mandos,
#                con ratón o pantalla táctil; Play arranca el juego)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/build-linux"

if [[ "${1:-}" == "--opciones" ]]; then
    shift
    exec sh "$HERE/B2recomp" "$@"
fi

for f in "$HERE"/config/defaults/*.ini; do  # ajustes del port si faltan los del jugador
    [[ -f "$f" && ! -f "$HERE/config/$(basename "$f")" ]] && cp "$f" "$HERE/config/"
done
mkdir -p "$OUT/play/userdata"
export SSBU_ROMFS="$HERE/targets/romfs" SSBU_USERDATA="$OUT/play/userdata" SSBU_SHOW=1 \
    SSBU_VOLUME=100 SSBU_FOCUS_NOTIFY=0 \
    SSBU_GRAPHICS_CONFIG="$HERE/config/graphics.ini" SSBU_CONFIG="$HERE/config/controllers.ini"
if [[ -d "$HERE/targets/sysdata/fonts" ]]; then export SSBU_FONTS="$HERE/targets/sysdata/fonts"; fi
cd "$OUT"
exec ./game_native "$HERE/targets/exefs/main.elf" "$@" > "$OUT/play/stdout.txt" 2>&1
