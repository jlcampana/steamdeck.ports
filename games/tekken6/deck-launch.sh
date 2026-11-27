#!/usr/bin/env bash
# Tekken 6: arranque en la Deck (lo llama steamdeck.sh). Antes del juego, el
# menú de opciones (opciones.py, GTK con mando) salvo MENU=0 en
# opciones.conf; las opciones (ESCALA, RES, ANISO, OFFSCREEN) se guardan en
# ese archivo y aquí se pasan a tools/run_linux.sh del port. Los argumentos
# que se den (p. ej. en las Opciones de lanzamiento de Steam) van después y
# mandan; los del juego, tras «--».
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$HERE/opciones.conf"

opt() {  # opt CLAVE defecto (valores con letras, números y «x»)
    local v
    v="$(sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\([0-9A-Za-z]*\).*/\1/p" "$CONF" 2>/dev/null | tail -1)"
    echo "${v:-$2}"
}

if [[ "$(opt MENU 1)" != 0 && -f "$HERE/opciones.py" ]] && command -v python3 >/dev/null; then
    rc=0
    env -u LD_LIBRARY_PATH python3 "$HERE/opciones.py" "$HERE/opciones.json" "$HERE" || rc=$?
    [[ $rc == 1 ]] && exit 0  # Salir: sin jugar (3 = no se pudo mostrar: se juega)
fi

ARGS=(--build-dir bin --fullscreen)
res="$(opt RES 1024x576)"
[[ "$res" =~ ^(640x360|768x432)$ ]] && ARGS+=(--res "$res")
[[ "$(opt OFFSCREEN 1024)" == 512 ]] && ARGS+=(--offscreen 512)

escala="$(opt ESCALA 1)"; [[ "$escala" =~ ^[1-8]$ ]] || escala=1
aniso="$(opt ANISO 0)"; [[ "$aniso" =~ ^[0-5]$ ]] || aniso=0
GAME=(--resolution_scale="$escala" --anisotropic_override="$aniso")

# Lo que llegue de Steam: opciones de run_linux.sh y, tras «--», del juego.
PRE=() POST=()
while [[ $# -gt 0 ]]; do
    if [[ "$1" == -- ]]; then shift; POST=("$@"); break; fi
    PRE+=("$1"); shift
done

exec "$HERE/tools/run_linux.sh" "${ARGS[@]}" "${PRE[@]}" -- "${GAME[@]}" "${POST[@]}"
