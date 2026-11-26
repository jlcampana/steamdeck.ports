#!/usr/bin/env bash
# Hyrule Warriors: Definitive Edition (HWDER): arranque en la Deck (lo llama
# steamdeck.sh). hwder lee de hwder_settings.ini (junto al ejecutable) el
# juego, las claves y la update con rutas absolutas, y guarda partidas y
# mods en ~/.local/share/HWDER si el .ini no dice otra cosa. Aquí se ponen
# las de esta instalación (game/base.nsp, keys/prod.keys, update/, save/ y
# mods/) antes de arrancar, así funciona aunque la carpeta se mueva.
# El resto del .ini (los ajustes del menú F1) no se toca.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INI="$HERE/hwder_settings.ini"

mkdir -p "$HERE/save" "$HERE/mods"
touch "$INI"
{
    grep -vE '^(nsp_path|keys_path|update_path|save_dir|mods_dir)=' "$INI" || true
    echo "nsp_path=$HERE/game/base.nsp"
    echo "keys_path=$HERE/keys/prod.keys"
    if [[ -d "$HERE/update" ]]; then echo "update_path=$HERE/update"; else echo "update_path="; fi
    echo "save_dir=$HERE/save"
    echo "mods_dir=$HERE/mods"
} > "$INI.tmp" && mv "$INI.tmp" "$INI"

cd "$HERE"
exec "$HERE/hwder" "$@"
