#!/usr/bin/env bash
# Instalador de un juego en la Steam Deck o en un PC con Linux (lo copia
# tools/package.sh junto al paquete). Se lanza con doble clic en
# "Instalar <juego>.desktop" (modo escritorio) o desde una terminal:
#
#   ./instalar.sh [carpeta-base]
#     carpeta-base  dónde instalar (se crea <carpeta-base>/<id>); sin ella,
#                   en la Deck pregunta: ~/Games (interna) o <tarjeta SD>/Games;
#                   en un PC, PC_GAMES de game.conf si existe, o ~/Games
#     -h, --help    muestra esta ayuda
#
# 1. Elige dónde instalar (ver arriba).
# 2. Descomprime <id>.tar.zst en <base>/<id>. Si ya existía, lo mueve antes a
#    <base>/<id>.old y copia de ahí a la nueva las partidas y ajustes (KEEP de
#    game.conf: rutas o patrones relativos a la carpeta del juego; en las
#    carpetas se salta KEEP_EXCLUDE). El .old queda como copia de seguridad.
# 3. Crea <base>/<id>/<id>.desktop y lo añade a Steam (si no estaba ya):
#    en la Deck con steamos-add-to-steam; en un PC, escribiendo shortcuts.vdf
#    (con Steam cerrado) y, si el juego es de Windows, con el Proton más
#    reciente ya elegido. En un PC, los juegos Linux van también al menú de
#    aplicaciones, y los de Windows arrancan con .proton-dpi.sh, que pone en
#    su prefijo de Proton los DPI de PC_PROTON_DPI (game.conf, 192 = doble;
#    0 = no tocar): si no, menús como el de DOA4 salen diminutos.
# 4. Copia las imágenes de art/ a la ficha de Steam (steam-art.py).
# Si el paquete trae post-install.sh (games/<id>/deck-post-install.sh), lo
# ejecuta tras descomprimir con la carpeta del juego como argumento.
#
# Instalación por red (la usa steamdeck-ports.sh, ver tools/serve.sh):
#   PKG_URL=http://<pc>:8765/<id>/<id>.tar.zst ./instalar.sh
# Con PKG_URL, el juego se descarga y se descomprime a la vez, sin guardar el
# .tar.zst; la suma se comprueba con el <id>.tar.zst.sha256 de esta carpeta.
# Si la descarga falla o la suma no coincide, se borra lo descomprimido y la
# instalación anterior (si la había) vuelve a su sitio.
# INSTALAR_SIN_PAUSA=1: no espera a que se pulse Enter al terminar.
set -euo pipefail

case "${1:-}" in
    -h|--help)
        awk 'NR == 1 && /^#!/ { next } !/^#/ { exit } { sub(/^# ?/, ""); print }' "$0"
        exit 0 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
PC_GAMES=""
PC_PROTON_DPI=192
KEEP=""; KEEP_EXCLUDE=""
source "$HERE/game.conf"   # ID, NAME, EXEC, PROTON, VERSION, SIZE_KB, PC_GAMES, KEEP, KEEP_EXCLUDE, PC_PROTON_DPI

say()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[aviso]\e[0m %s\n' "$*"; }
fail() { printf '\e[1;31m[error]\e[0m %s\n' "$*" >&2; pause; exit 1; }
# Con doble clic se abre una terminal: que no se cierre sin dejar leer.
pause() { [[ -t 0 && "${INSTALAR_SIN_PAUSA:-0}" != 1 ]] && read -rp "Pulsa Enter para cerrar…" _ || true; }
ask_yes() { local a; read -rp "$1 [s/N] " a; [[ "$a" =~ ^[sSyY] ]]; }

PKG="$HERE/$ID.tar.zst"
PKG_URL="${PKG_URL:-}"
if [[ -n "$PKG_URL" ]]; then
    command -v curl >/dev/null || fail "Falta curl"
    [[ -f "$PKG.sha256" ]] || fail "No encuentro $PKG.sha256"
else
    [[ -f "$PKG" ]] || fail "No encuentro $PKG"
fi
command -v zstd >/dev/null || fail "Falta zstd"

# En la Deck (SteamOS) o en un PC
ON_DECK=0
if grep -qi '^ID=steamos' /etc/os-release 2>/dev/null || command -v steamos-add-to-steam >/dev/null; then
    ON_DECK=1
fi
FLATPAK_STEAM=com.valvesoftware.Steam

say "Instalador de $NAME ($VERSION)"
[[ -n "$PKG_URL" ]] && say "Origen: $PKG_URL"

# --- 1. Destino -------------------------------------------------------------
if [[ $# -ge 1 ]]; then
    BASE="$1"
elif (( ! ON_DECK )); then
    if [[ -n "$PC_GAMES" && -d "$PC_GAMES" ]]; then BASE="$PC_GAMES"; else BASE="$HOME/Games"; fi
else
    options=("$HOME/Games")
    while IFS= read -r mnt; do
        [[ -w "$mnt" && "$mnt" != "$HERE"* ]] && options+=("$mnt/Games")
    done < <(findmnt -rn -o TARGET 2>/dev/null | grep '^/run/media/' || true)
    if (( ${#options[@]} == 1 )); then
        BASE="${options[0]}"
    else
        echo "¿Dónde lo instalo?"
        for i in "${!options[@]}"; do
            free="$(df -h --output=avail "$(dirname "${options[$i]}")" 2>/dev/null | tail -1 | tr -d ' ')"
            printf '  %d) %s  (libres: %s)\n' "$((i + 1))" "${options[$i]}" "$free"
        done
        read -rp "Opción [1]: " n
        n="${n:-1}"
        [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#options[@]} )) || fail "Opción no válida"
        BASE="${options[$((n - 1))]}"
    fi
fi
DEST="$BASE/$ID"
mkdir -p "$BASE"
BASE="$(cd "$BASE" && pwd)"
DEST="$BASE/$ID"

# --- 2. Descomprimir --------------------------------------------------------
free_kb="$(df -k --output=avail "$BASE" | tail -1 | tr -d ' ')"
if (( free_kb < SIZE_KB )); then
    fail "No hay espacio en $BASE: hacen falta $((SIZE_KB / 1024 / 1024 + 1)) GB y hay $((free_kb / 1024 / 1024)) GB"
fi

moved_old=0
if [[ -e "$DEST" ]]; then
    old="$(cat "$DEST/.release-tag" 2>/dev/null || echo "?")"
    warn "Ya está instalado en $DEST (versión $old)."
    echo "    Se moverá a $DEST.old (se borra el .old anterior) y sus partidas y ajustes"
    echo "    se copiarán a la nueva instalación."
    ask_yes "¿Continuar?" || { echo "Cancelado."; pause; exit 0; }
    rm -rf "$DEST.old"
    mv "$DEST" "$DEST.old"
    moved_old=1
fi

# Por red: curl | tee (al fifo, del que lee sha256sum) | zstd | tar. Sin
# --retry: curl repetiría la descarga por la salida y se mezclarían los datos.
unpack() {
    if [[ -z "$PKG_URL" ]]; then
        zstd -dc --progress "$PKG" | tar -x -C "$tmp"
        return
    fi
    local want got sp fifo="$BASE/.$ID.sha256-fifo" sumf="$BASE/.$ID.sha256-got"
    want="$(cut -d' ' -f1 "$PKG.sha256")"
    rm -f "$fifo" "$sumf"
    mkfifo "$fifo" || return 1
    sha256sum <"$fifo" >"$sumf" &
    sp=$!
    if ! curl -fL --progress-bar "$PKG_URL" | tee "$fifo" | zstd -dcq | tar -x -C "$tmp"; then
        wait "$sp" || true
        rm -f "$fifo" "$sumf"
        warn "La descarga o la descompresión ha fallado"
        return 1
    fi
    wait "$sp" || true
    got="$(cut -d' ' -f1 "$sumf" 2>/dev/null)"
    rm -f "$fifo" "$sumf"
    if [[ "$got" != "$want" ]]; then
        warn "La suma SHA-256 no coincide (esperada $want, recibida ${got:-ninguna})"
        return 1
    fi
    say "Suma SHA-256 comprobada."
}

if [[ -n "$PKG_URL" ]]; then
    say "Descargando y descomprimiendo en $DEST (puede tardar unos minutos)…"
else
    say "Descomprimiendo en $DEST (puede tardar unos minutos)…"
fi
tmp="$BASE/.$ID.partial"
rm -rf "$tmp"
mkdir -p "$tmp"
if ! unpack || [[ ! -d "$tmp/$ID" ]]; then
    rm -rf "$tmp"
    if (( moved_old )); then
        mv "$DEST.old" "$DEST"
        warn "Se deja como estaba la instalación anterior ($DEST)."
    fi
    fail "No se ha instalado $NAME"
fi
mv "$tmp/$ID" "$DEST"
rmdir "$tmp"

# Partidas y ajustes de la instalación anterior (KEEP de game.conf)
keep_saves() {
    local old="$DEST.old" pattern path n=0 f skip x pats excl
    [[ -d "$old" && -n "$KEEP" ]] || return 0
    read -r -a pats <<<"$KEEP"           # read no expande los patrones
    read -r -a excl <<<"$KEEP_EXCLUDE"
    shopt -s nullglob globstar
    for pattern in "${pats[@]}"; do
        for path in "$old"/$pattern; do
            path="${path#"$old"/}"
            if [[ -d "$old/$path" ]]; then
                while IFS= read -r -d '' f; do
                    skip=0
                    for x in "${excl[@]}"; do
                        # shellcheck disable=SC2053
                        [[ "${f##*/}" == $x ]] && skip=1
                    done
                    (( skip )) && continue
                    (cd "$old" && cp -a --parents "$f" "$DEST/") && n=$((n + 1))
                done < <(cd "$old" && find "$path" -type f -print0)
            elif [[ -f "$old/$path" ]]; then
                (cd "$old" && cp -a --parents "$path" "$DEST/") && n=$((n + 1))
            fi
        done
    done
    shopt -u nullglob globstar
    if (( n )); then
        say "Copiados $n archivos de partidas y ajustes de la instalación anterior."
    else
        say "La instalación anterior no tenía partidas ni ajustes que copiar."
    fi
}
keep_saves || warn "No se han podido copiar todas las partidas; siguen en $DEST.old"

# Paso propio del juego, si lo hay (games/<id>/deck-post-install.sh)
if [[ -f "$HERE/post-install.sh" ]]; then
    VERSION="$VERSION" bash "$HERE/post-install.sh" "$DEST" \
        || warn "El paso propio del juego (post-install.sh) ha fallado; revisa los mensajes"
fi

# --- 3. Acceso directo en Steam ---------------------------------------------
ICON=""
if [[ -d "$HERE/art" ]]; then
    mkdir -p "$DEST/.steam-art"
    cp -a "$HERE/art/." "$DEST/.steam-art/"
    for ext in png jpg; do
        [[ -f "$DEST/.steam-art/icon.$ext" ]] && { ICON="$DEST/.steam-art/icon.$ext"; break; }
    done
fi
cp "$HERE/steam-art.py" "$DEST/.steam-art.py"

# PC + Proton: DPI del prefijo (el menú del juego sale a escala)
PROTON_DPI=0
if (( ! ON_DECK )) && [[ "$PROTON" == 1 && "$PC_PROTON_DPI" =~ ^[0-9]+$ && "$PC_PROTON_DPI" != 0 \
      && -f "$HERE/proton-dpi.sh" ]]; then
    PROTON_DPI="$PC_PROTON_DPI"
    cp "$HERE/proton-dpi.sh" "$DEST/.proton-dpi.sh"
    chmod +x "$DEST/.proton-dpi.sh"
    echo "$PROTON_DPI" > "$DEST/.proton-dpi"
fi

# Exec del .desktop: rutas entre comillas (puede haber espacios).
quote() {   # especificación de .desktop: escapar \ " ` $ y doblar %
    local s="${1//\\/\\\\}"
    s="${s//\"/\\\"}"; s="${s//\`/\\\`}"; s="${s//\$/\\\$}"; s="${s//%/%%}"
    printf '"%s"' "$s"
}
DESKTOP="$DEST/$ID.desktop"
{
    echo "[Desktop Entry]"
    echo "Type=Application"
    echo "Name=$NAME"
    echo "Exec=$(quote "$DEST/$EXEC")"
    echo "Path=$DEST"
    [[ -n "$ICON" ]] && echo "Icon=$ICON"
    echo "Terminal=false"
    echo "Categories=Game;"
} > "$DESKTOP"
chmod +x "$DESKTOP" "$DEST/$EXEC"

# ¿Ve el Steam de Flatpak la carpeta? (permiso filesystems=)
flatpak_sees() {
    local fs p path
    path="$(realpath -m "$1")"
    fs="$(flatpak info --show-permissions "$FLATPAK_STEAM" 2>/dev/null | sed -n 's/^filesystems=//p')"
    local IFS=';'
    for p in $fs; do
        p="${p%%:*}"
        case "$p" in
            host) return 0 ;;
            home) p="$HOME" ;;
            "~/"*) p="$HOME/${p#\~/}" ;;
            /*) ;;
            *) continue ;;   # xdg-…, !… (quitados)
        esac
        p="$(realpath -m "$p")"
        [[ "$path" == "$p" || "$path" == "$p"/* ]] && return 0
    done
    return 1
}

ART_PY=(python3 -I "$DEST/.steam-art.py")
ADDED_PROTON=0
if "${ART_PY[@]}" find "$DEST" >/dev/null 2>&1; then
    say "Ya estaba en Steam (misma carpeta): no se añade otra vez."
    # Accesos de antes de .proton-dpi.sh: los DPI, directamente en el prefijo.
    if (( PROTON_DPI )); then
        "${ART_PY[@]}" dpi "$DEST" "$PROTON_DPI" \
            || warn "Sin DPI en el prefijo de Proton (¿aún no has arrancado el juego?). Luego: python3 \"$DEST/.steam-art.py\" dpi \"$DEST\" $PROTON_DPI"
    fi
elif (( ! ON_DECK )); then
    # PC: shortcuts.vdf a mano. Steam lo reescribe al salir, así que tiene que estar cerrado.
    add_args=(add "$DEST/$EXEC" "$NAME")
    [[ -n "$ICON" ]] && add_args+=(--icon "$ICON")
    [[ "$PROTON" == 1 ]] && add_args+=(--proton)
    (( PROTON_DPI )) && add_args+=(--launch-options "\"$DEST/.proton-dpi.sh\" %command%")
    while pgrep -x steam >/dev/null; do
        warn "Steam está abierto. Para añadir el juego hay que cerrarlo (Steam → Salir)."
        read -rp "Ciérralo y pulsa Enter (o escribe «n» para no añadirlo a Steam): " a || a=n
        [[ "$a" =~ ^[nN] ]] && break
    done
    if pgrep -x steam >/dev/null; then
        warn "No se añade a Steam. Luego, con Steam cerrado: python3 \"$DEST/.steam-art.py\" ${add_args[*]@Q}"
    elif "${ART_PY[@]}" "${add_args[@]}"; then
        say "Añadido «$NAME» a Steam."
        [[ "$PROTON" == 1 ]] && ADDED_PROTON=1
    else
        warn "No se ha podido añadir a Steam"
    fi
    if flatpak info "$FLATPAK_STEAM" >/dev/null 2>&1 && ! flatpak_sees "$DEST"; then
        warn "El Steam de Flatpak no tiene permiso para ver $BASE. Dáselo con:"
        echo "    flatpak override --user --filesystem=${BASE@Q} $FLATPAK_STEAM"
    fi
    # Menú de aplicaciones (solo los de Linux; los de Windows van con Proton desde Steam)
    if [[ "$PROTON" != 1 ]]; then
        apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
        mkdir -p "$apps"
        cp "$DESKTOP" "$apps/steamdeck-ports-$ID.desktop"
        say "Añadido al menú de aplicaciones."
    fi
elif command -v steamos-add-to-steam >/dev/null; then
    say "Añadiendo «$NAME» a Steam…"
    steamos-add-to-steam "$DESKTOP" || warn "steamos-add-to-steam ha fallado"
    # Steam escribe shortcuts.vdf al cabo de unos segundos.
    for _ in $(seq 20); do
        "${ART_PY[@]}" find "$DEST" >/dev/null 2>&1 && break
        sleep 1
    done
else
    warn "No es SteamOS (no hay steamos-add-to-steam): añade $DESKTOP a Steam a mano."
fi

# --- 4. Imágenes ------------------------------------------------------------
if [[ -d "$DEST/.steam-art" ]]; then
    "${ART_PY[@]}" art "$DEST" "$DEST/.steam-art" \
        || warn "No se han podido poner las imágenes (¿Steam no ha guardado aún el acceso?). Reinténtalo con: python3 \"$DEST/.steam-art.py\" art \"$DEST\" \"$DEST/.steam-art\""
fi

echo
say "Instalado: $DEST"
if (( ADDED_PROTON )); then
    echo "    Es de Windows: en Steam queda elegido Proton (el GE-Proton más reciente que tengas)."
elif [[ "$PROTON" == 1 ]]; then
    warn "Este juego es de Windows: en Steam, Propiedades → Compatibilidad →"
    echo "    «Forzar el uso de una herramienta de compatibilidad» → Proton (la más reciente)."
fi
[[ -d "$DEST.old" ]] && echo "    La instalación anterior está en $DEST.old (bórrala cuando compruebes que todo va bien)."
echo "    Si Steam ya estaba abierto y no ves las imágenes, reinícialo."
pause
