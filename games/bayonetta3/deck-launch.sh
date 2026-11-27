#!/usr/bin/env bash
# Bayonetta 3 (B3-Express / ScarletNX): arranque en la Deck (lo llama
# steamdeck.sh). Lo mismo que Play en el lanzador de Windows: el juego
# (Bayo3_120/Bayo3_120, el runtime de ScarletNX con su código en
# Bayo3_120_code.so) con --game=<su carpeta> y el renderizador rápido
# (SNX_NVN_FRONTEND=2, SNX_NVN_RELEASE_ONLY=1; sin ellas usa el antiguo).
# Ajustes en Bayo3_120/Bayo3_120.ini; menú del juego con F2.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="$HERE/Bayo3_120"
export SNX_NVN_FRONTEND=2 SNX_NVN_RELEASE_ONLY=1
cd "$G"
exec "$G/Bayo3_120" --game="$G" "$@"
