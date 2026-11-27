#!/usr/bin/env bash
# Bayonetta 3 (B3-Express / ScarletNX): arranque en la Deck (lo llama
# steamdeck.sh). Lo mismo que Play en el lanzador de Windows: el juego
# (Bayo3_120/Bayo3_120, el runtime de ScarletNX con su código en
# Bayo3_120_code.so) con --game=<su carpeta> y el renderizador rápido
# (SNX_NVN_FRONTEND=2, SNX_NVN_RELEASE_ONLY=1; sin ellas usa el antiguo).
# Antes del juego, el menú de opciones (opciones.py, GTK con mando: escribe
# en Bayo3_120.ini) salvo MENU=0 en opciones.conf. Menú del juego: F2.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="$HERE/Bayo3_120"
menu="$(sed -n 's/^[[:space:]]*MENU[[:space:]]*=[[:space:]]*\([01]\).*/\1/p' "$HERE/opciones.conf" 2>/dev/null | tail -1)"
if [[ "${menu:-1}" != 0 && -f "$HERE/opciones.py" ]] && command -v python3 >/dev/null; then
    rc=0
    env -u LD_LIBRARY_PATH python3 "$HERE/opciones.py" "$HERE/opciones.json" "$HERE" || rc=$?
    [[ $rc == 1 ]] && exit 0  # Salir: sin jugar (3 = no se pudo mostrar: se juega)
fi
export SNX_NVN_FRONTEND=2 SNX_NVN_RELEASE_ONLY=1
cd "$G"
exec "$G/Bayo3_120" --game="$G" "$@"
