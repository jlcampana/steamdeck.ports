#!/bin/bash
# Lanzador previo de los juegos con Proton en un PC (no en la Deck). El
# instalador lo pone en las opciones de lanzamiento de Steam:
#     "<juego>/.proton-dpi.sh" %command%
# Antes de arrancar, pone en el prefijo de Proton los DPI de .proton-dpi
# (192 = doble): los menús que se dibujan según los DPI de Windows (el de
# DOA4, por ejemplo) se ven muy pequeños en pantallas grandes con los 96 de
# Wine. La primera vez el prefijo aún no existe: vale a partir del segundo
# arranque. Si algo falla, el juego arranca igual.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dpi="$(cat "$here/.proton-dpi" 2>/dev/null)"
if [[ "$dpi" =~ ^[0-9]+$ && -n "${STEAM_COMPAT_DATA_PATH:-}" ]]; then
    python3 -I "$here/.steam-art.py" dpi-reg "$STEAM_COMPAT_DATA_PATH/pfx/user.reg" "$dpi" >/dev/null 2>&1 || true
fi
exec "$@"
