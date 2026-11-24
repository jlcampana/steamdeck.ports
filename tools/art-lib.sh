# Funciones comunes de tools/fetch-art.sh y tools/pick-art.sh.
#
# La elección de cada tipo se guarda en games/<id>/game.conf como el id de la
# imagen en SteamGridDB (ART_COVER=389967…), que sí va a git: las imágenes
# no, pero con esos ids fetch-art.sh vuelve a bajar exactamente las mismas.

ART_KINDS=(cover header hero logo icon)

# Variable de game.conf para un tipo: cover -> ART_COVER
art_var() { echo "ART_${1^^}"; }

# Id de SteamGridDB de un archivo candidato: 04-389967.png -> 389967
art_imgid() { local f="${1#*-}"; echo "${f%.*}"; }

# Escribe (o cambia) VAR=valor en game.conf, sin tocar el resto.
set_conf_var() {
    local conf="$1" var="$2" value="$3"
    if grep -q "^$var=" "$conf"; then
        sed -i "s|^$var=.*|$var=$value|" "$conf"
    else
        grep -q '^# Imágenes elegidas' "$conf" \
            || printf '# Imágenes elegidas: id en SteamGridDB (tools/pick-art.sh)\n' >> "$conf"
        echo "$var=$value" >> "$conf"
    fi
}

# Elige la candidata <archivo> de <tipo>: art/<tipo>.<ext>, .elegida y game.conf.
set_art_choice() {
    local game="$1" kind="$2" file="$3"
    local art="$game/art" dir="$game/art/candidatas/$kind"
    rm -f "$art/$kind".*
    cp "$dir/$file" "$art/$kind.${file##*.}"
    echo "$file" > "$dir/.elegida"
    set_conf_var "$game/game.conf" "$(art_var "$kind")" "$(art_imgid "$file")"
}
