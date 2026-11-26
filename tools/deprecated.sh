# Juegos obsoletos: DEPRECATED=1 en games/<id>/game.conf (sustituidos por otra
# variante). Sus archivos se conservan y se pueden compilar y empaquetar
# nombrándolos, pero update.sh, package.sh, fetch-art.sh y serve.sh se los
# saltan cuando recorren todos los juegos.
# Uso: is_deprecated <id>   (necesita ROOT)
is_deprecated() {
    grep -qE '^DEPRECATED=1([[:space:]]|$)' "$ROOT/games/$1/game.conf" 2>/dev/null
}
