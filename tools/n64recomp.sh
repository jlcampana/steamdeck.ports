# Funciones para los ports de N64: Recompiled (N64Recomp + RT64), con binario
# Linux listo en la release (zip con un .tar.gz dentro). Se carga desde el
# build.sh del juego, después de tools/lib.sh.
#
# El port pide la ROM en su menú de inicio y la guarda como <game_id>.z64 en
# su carpeta de datos, tras comprobar su XXH3-64 (rom_hash en src/main/main.cpp
# del port). Con portable.txt en la carpeta actual (steamdeck.sh hace cd a la
# suya), esa carpeta es la del juego: el build deja allí la ROM ya validada y
# el juego arranca sin preguntar.

# XXH3-64 de un archivo en hexadecimal (16 cifras), o nada si no hay con qué
# calcularlo (xxhsum >= 0.8, paquete xxhash; o el módulo xxhash de Python).
n64_xxh3() {
    local f="$1" out
    if command -v xxhsum >/dev/null && out="$(xxhsum -H3 "$f" 2>/dev/null)"; then
        out="${out%% *}"; out="${out#XXH3_}"
        printf '%s\n' "${out,,}"
        return
    fi
    python3 -I -c 'import sys, xxhash
print("%016x" % xxhash.xxh3_64_intdigest(open(sys.argv[1], "rb").read()))' "$f" 2>/dev/null || true
}

# n64_check_rom <rom> <xxh3> [sha1…]
# Comprueba que la ROM es la que pide el port: XXH3-64 si se puede calcular;
# si no, SHA-1 contra las de ROM ya comprobadas con XXH3 (las da el build.sh).
n64_check_rom() {
    local rom="$1" want="${2,,}"; shift 2
    want="${want#0x}"
    [[ "$(head -c 4 "$rom" | od -An -tx1 | tr -d ' \n')" == 80371240 ]] \
        || die "$rom no es una ROM .z64 (big-endian). Conviértela antes (.n64/.v64 -> .z64)"
    local h; h="$(n64_xxh3 "$rom")"
    if [[ -n "$h" ]]; then
        [[ "$h" == "$want" ]] || die "$(basename "$rom"): XXH3 $h, el port pide $want (ROM USA 1.0 sin modificar)"
        log "ROM correcta (XXH3 $h)"
        return
    fi
    (( $# )) || die "No hay con qué comprobar el XXH3 de la ROM: instala xxhash (xxhsum) o python3-xxhash"
    local s; s="$(sha1sum "$rom" | cut -d' ' -f1)"
    local ok
    for ok in "$@"; do
        [[ "$s" == "$ok" ]] && { log "ROM correcta (SHA-1 $s)"; return; }
    done
    die "$(basename "$rom"): SHA-1 $s desconocido. El port pide la ROM USA 1.0 sin modificar (XXH3 $want); instala xxhash para comprobarla"
}

# n64recomp_build <ejecutable> <game_id> <rom>  (tras n64_check_rom y prepare_build)
# build/ = contenido del .tar.gz de la release + portable.txt + <game_id>.z64.
n64recomp_build() {
    local exe="$1" game_id="$2" rom="$3"
    local tgz
    tgz="$(find "$LATEST" -maxdepth 1 -name '*.tar.gz' | head -n 1)"
    [[ -n "$tgz" ]] || die "No hay .tar.gz en $LATEST"

    log "Descomprimiendo $(basename "$tgz")"
    tar -xzf "$tgz" -C "$BUILD"
    rm -f "$BUILD/$(basename "$tgz")"  # prepare_build copia latest/ entero
    [[ -x "$BUILD/$exe" ]] || die "La release no trae $exe"

    log "ROM -> $game_id.z64"
    cp --reflink=auto "$rom" "$BUILD/$game_id.z64"
    chmod 644 "$BUILD/$game_id.z64"
    # Partidas, ajustes, mods y la ROM en la carpeta del juego
    touch "$BUILD/portable.txt"

    check_absolute_paths
    write_steamdeck_launcher "$exe"
}
