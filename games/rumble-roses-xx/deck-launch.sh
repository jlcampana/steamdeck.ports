#!/usr/bin/env bash
# Rumble Roses XX: arranque en la Deck (lo llama steamdeck.sh). Antes del
# juego, el menú de opciones (opciones.py, GTK con mando), que cambia
# game/RumbleRosesReX.toml (el mismo archivo que el menú del juego, F4 o
# Back+Start), salvo MENU=0 en opciones.conf.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

menu="$(sed -n 's/^[[:space:]]*MENU[[:space:]]*=[[:space:]]*\([01]\).*/\1/p' "$HERE/opciones.conf" 2>/dev/null | tail -1)"
if [[ "${menu:-1}" != 0 && -f "$HERE/opciones.py" ]] && command -v python3 >/dev/null; then
    rc=0
    env -u LD_LIBRARY_PATH python3 "$HERE/opciones.py" "$HERE/opciones.json" "$HERE" || rc=$?
    [[ $rc == 1 ]] && exit 0  # Salir: sin jugar (3 = no se pudo mostrar: se juega)
fi

cd "$HERE"
exec "$HERE/game/rumble_roses_xx" "$@"
