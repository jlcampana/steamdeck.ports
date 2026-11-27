#!/usr/bin/env bash
# Bayonetta 2 (B2recomp): arranque en la Deck (lo llama steamdeck.sh). Lo
# mismo que scripts/play.sh y el botón Play del lanzador del port: el juego
# (build-linux/game_native) con la romfs, los ajustes de config/ y las
# partidas en build-linux/play/userdata; log en build-linux/play/stdout.txt.
# Antes del juego, el menú de opciones (opciones.py, GTK con mando) salvo
# MENU=0 en opciones.conf.
#   --opciones   abre el lanzador del port (más ajustes: mapear el mando,
#                teclado, mods; con ratón o pantalla táctil)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/build-linux"

if [[ "${1:-}" == "--opciones" ]]; then
    shift
    exec sh "$HERE/B2recomp" "$@"
fi

menu="$(sed -n 's/^[[:space:]]*MENU[[:space:]]*=[[:space:]]*\([01]\).*/\1/p' "$HERE/opciones.conf" 2>/dev/null | tail -1)"
if [[ "${menu:-1}" != 0 && -f "$HERE/opciones.py" ]] && command -v python3 >/dev/null; then
    rc=0
    env -u LD_LIBRARY_PATH python3 "$HERE/opciones.py" "$HERE/opciones.json" "$HERE" || rc=$?
    [[ $rc == 1 ]] && exit 0  # Salir: sin jugar (3 = no se pudo mostrar: se juega)
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
