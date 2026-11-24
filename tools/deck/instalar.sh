#!/usr/bin/env bash
# Instalador de un juego en la Steam Deck (lo copia tools/package.sh junto al
# paquete). Se lanza con doble clic en "Instalar <juego>.desktop" (modo
# escritorio) o desde una terminal: ./instalar.sh [carpeta-base]
#
# 1. Elige dónde instalar: ~/Games (interna) o <tarjeta SD>/Games.
# 2. Descomprime <id>.tar.zst en <base>/<id>. Si ya existía, lo mueve antes a
#    <base>/<id>.old (ahí quedan las partidas y ajustes anteriores).
# 3. Crea <base>/<id>/<id>.desktop y lo añade a Steam con
#    steamos-add-to-steam (si no estaba ya).
# 4. Copia las imágenes de art/ a la ficha de Steam (steam-art.py).
# Si el paquete trae post-install.sh (games/<id>/deck-post-install.sh), lo
# ejecuta tras descomprimir con la carpeta del juego como argumento.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/game.conf"   # ID, NAME, EXEC, PROTON, VERSION, SIZE_KB

say()  { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m[aviso]\e[0m %s\n' "$*"; }
fail() { printf '\e[1;31m[error]\e[0m %s\n' "$*" >&2; pause; exit 1; }
# Con doble clic se abre una terminal: que no se cierre sin dejar leer.
pause() { [[ -t 0 ]] && read -rp "Pulsa Enter para cerrar…" _ || true; }
ask_yes() { local a; read -rp "$1 [s/N] " a; [[ "$a" =~ ^[sSyY] ]]; }

PKG="$HERE/$ID.tar.zst"
[[ -f "$PKG" ]] || fail "No encuentro $PKG"
command -v zstd >/dev/null || fail "Falta zstd"

say "Instalador de $NAME ($VERSION)"

# --- 1. Destino -------------------------------------------------------------
if [[ $# -ge 1 ]]; then
    BASE="$1"
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

if [[ -e "$DEST" ]]; then
    old="$(cat "$DEST/.release-tag" 2>/dev/null || echo "?")"
    warn "Ya está instalado en $DEST (versión $old)."
    echo "    Se moverá a $DEST.old (con sus partidas y ajustes; se borra el .old anterior)."
    ask_yes "¿Continuar?" || { echo "Cancelado."; pause; exit 0; }
    rm -rf "$DEST.old"
    mv "$DEST" "$DEST.old"
fi

say "Descomprimiendo en $DEST (puede tardar unos minutos)…"
tmp="$BASE/.$ID.partial"
rm -rf "$tmp"
mkdir -p "$tmp"
zstd -dc --progress "$PKG" | tar -x -C "$tmp"
mv "$tmp/$ID" "$DEST"
rmdir "$tmp"

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

ART_PY=(python3 -I "$DEST/.steam-art.py")
if "${ART_PY[@]}" find "$DEST" >/dev/null 2>&1; then
    say "Ya estaba en Steam (misma carpeta): no se añade otra vez."
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
if [[ "$PROTON" == 1 ]]; then
    warn "Este juego es de Windows: en Steam, Propiedades → Compatibilidad →"
    echo "    «Forzar el uso de una herramienta de compatibilidad» → Proton (la más reciente)."
fi
[[ -d "$DEST.old" ]] && echo "    La instalación anterior está en $DEST.old (bórrala cuando compruebes que todo va bien)."
echo "    Si Steam ya estaba abierto y no ves las imágenes, reinícialo."
pause
