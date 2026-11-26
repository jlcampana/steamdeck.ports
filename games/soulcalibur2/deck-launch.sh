#!/usr/bin/env bash
# Soulcalibur II (soulcalibur2-recomp): arranque en la Deck (lo llama
# steamdeck.sh). Con portable.txt, el launcher guarda todo en
# user/Soulcalibur II/ y su launcher.ini recuerda el disco con ruta
# absoluta. Aquí se pone [game] disc= con el disco de esta instalación
# (disc/Soulcalibur2.iso) antes de abrir el launcher, así funciona aunque
# la carpeta del juego se mueva o se instale en otra ruta.
# Argumentos: los del launcher (p. ej. --play: directo al juego, sin menú).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISC="$HERE/disc/Soulcalibur2.iso"
INI="$HERE/user/Soulcalibur II/launcher.ini"

if [[ -f "$DISC" ]]; then
    mkdir -p "$(dirname "$INI")"
    touch "$INI"
    awk -v disc="$DISC" '
        /^\[/ {
            if (in_game && !done) { print "disc=" disc; done = 1 }
            in_game = ($0 == "[game]"); seen = seen || in_game
        }
        in_game && /^disc=/ { if (!done) { print "disc=" disc; done = 1 }; next }
        { print }
        END {
            if (in_game && !done) { print "disc=" disc; done = 1 }
            if (!seen) { print "[game]"; print "disc=" disc }
        }' "$INI" > "$INI.tmp" && mv "$INI.tmp" "$INI"
fi

cd "$HERE"
exec "$HERE/soulcalibur2-launcher" "$@"
