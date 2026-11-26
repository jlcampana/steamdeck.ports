#!/usr/bin/env bash
# Jet Set Radio Future (Xbox, JSRF-PC): copia la release de Linux, extrae el
# disco en game/ y compila aquí el motor (bin/jsrf_recomp) a partir de su
# default.xbe, como haría jsrf-pc en el primer arranque, pero sin preguntas
# y sin que la Deck descargue ni compile nada. Usa el archivo de
# herramientas de la misma release (JSRF-PC-tools-linux-x86_64.tar.gz:
# Python, capstone y Zig propios; se guarda en latest/jsrf/) y
# kit/build_engine.py; no hace falta contenedor (las herramientas no usan
# nada del sistema). Comprueba los SHA-256 del código generado y del motor
# con kit/expected.txt y luego borra herramientas y código generado.
# portable/ guarda ajustes, partidas, logs y caché dentro de la carpeta.
# Resultado: games/jsrf/build (ejecutable: jsrf-pc).
#
# Uso: games/jsrf/build.sh [-f] [iso]
#   -f          build limpio (el anterior pasa a build.old/)
#   -h, --help  muestra esta ayuda
#   iso         por defecto isos/JSRF.iso (el disco USA suelto, no el
#               combinado con Sega GT 2002)
source "$(dirname "${BASH_SOURCE[0]}")/../../tools/lib.sh"

REPO="spriteice/JSRF-PC"
TOOLS_ASSET="JSRF-PC-tools-linux-x86_64.tar.gz"
FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
ISO="$(realpath "${1:-$ISOS/JSRF.iso}")"

require_latest
require_file "$ISO"
require_extract_xiso
command -v curl >/dev/null && command -v jq >/dev/null || die "Faltan curl o jq"

tag="$(release_tag)"

# --- Herramientas de compilación (una vez por versión, fuera de git) ---
tools_tgz="$ROOT/latest/$GAME_ID/tools-$tag.tar.gz"
if [[ ! -f "$tools_tgz" ]]; then
    log "Descargando $TOOLS_ASSET ($tag)"
    digest="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/tags/$tag" \
        | jq -r --arg n "$TOOLS_ASSET" '.assets[] | select(.name == $n) | .digest // empty')"
    mkdir -p "$(dirname "$tools_tgz")"
    curl -fL --progress-bar -o "$tools_tgz.part" \
        "https://github.com/$REPO/releases/download/$tag/$TOOLS_ASSET"
    if [[ "$digest" == sha256:* ]]; then
        echo "${digest#sha256:}  $tools_tgz.part" | sha256sum -c --quiet - \
            || { rm -f "$tools_tgz.part"; die "El SHA-256 de $TOOLS_ASSET no coincide"; }
    else
        log "AVISO: GitHub no da el SHA-256 de $TOOLS_ASSET; sin comprobar"
    fi
    mv "$tools_tgz.part" "$tools_tgz"
fi

prepare_build "$FORCE"

# --- Disco ---
if [[ -f "$BUILD/game/default.xbe" ]]; then
    log "game/ ya está extraído"
else
    log "Extrayendo $(basename "$ISO") en game/"
    rm -rf "$BUILD/game" "$BUILD/game.part"
    mkdir -p "$BUILD/game.part"
    (cd "$BUILD/game.part" && "$EXTRACT_XISO" -x "$ISO" -d game >/dev/null)
    mv "$BUILD/game.part/game" "$BUILD/game"
    rmdir "$BUILD/game.part"
fi

# --- Motor ---
read_expected() { sed -n "s/^$1=//p" "$BUILD/kit/expected.txt"; }
want_engine="$(read_expected engine_sha256)"
if [[ -x "$BUILD/bin/jsrf_recomp" && -n "$want_engine" ]] \
        && [[ "$(sha256sum "$BUILD/bin/jsrf_recomp" | cut -d' ' -f1)" == "$want_engine" ]]; then
    log "bin/jsrf_recomp ya está compilado y coincide con kit/expected.txt"
else
    log "Descomprimiendo las herramientas en tools/"
    rm -rf "$BUILD/tools"
    tar -xzf "$tools_tgz" -C "$BUILD"
    [[ -x "$BUILD/tools/python/bin/python3" ]] || die "El archivo de herramientas no trae tools/python/bin/python3"
    log "Compilando el motor desde game/default.xbe (unos minutos)"
    result="$("$BUILD/tools/python/bin/python3" -E -s "$BUILD/kit/build_engine.py" \
        --root "$BUILD" --xbe "$BUILD/game/default.xbe" 2>&1 \
        | tee "$ROOT/latest/$GAME_ID/build-engine.log" | grep -E '^done ' || true)"
    [[ -n "$result" ]] || die "build_engine.py no terminó bien (ver latest/$GAME_ID/build-engine.log)"
    read -r _ engine_sum engine_ok gen_sum gen_ok <<<"$result"
    log "Motor: $engine_ok ($engine_sum); código generado: $gen_ok ($gen_sum)"
    [[ "$engine_ok" == "match" ]] || log "AVISO: el motor no coincide con el de la release (otra copia del juego). jsrf-pc preguntará si jugar igualmente."
    log "Borrando herramientas y código generado"
    rm -rf "$BUILD/tools" "$BUILD/build"
fi

# Todo (ajustes, partidas, logs, caché) en portable/, junto a jsrf-pc. En
# modo portable, jsrf-pc pregunta dónde está el juego (zenity) si
# settings.cfg no tiene game_dir; una carpeta dentro de la suya la guarda
# relativa, así que game_dir=game vale en cualquier ruta. (JSRF_GAME_DIR no
# sirve para esto: con ella pregunta igual.) El resto de ajustes los pone
# jsrf-pc al arrancar.
mkdir -p "$BUILD/portable"
[[ -f "$BUILD/portable/settings.cfg" ]] || echo "game_dir=game" > "$BUILD/portable/settings.cfg"

check_absolute_paths
write_steamdeck_launcher jsrf-pc
# En el modo Juego de la Deck (gamescope), SDL cree que la ventana no tiene
# el foco y no da al juego los botones del mando (el menú F1 sí los ve: los
# lee de los eventos). Comprobado en la Deck el 2026-11-26.
sed -i 's|^cd "\$HERE"$|export SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS=1\ncd "$HERE"|' "$BUILD/steamdeck.sh"
grep -q SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS "$BUILD/steamdeck.sh" || die "No se pudo poner SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS en steamdeck.sh"

finish_build
log "En la Deck: añade 'steamdeck.sh' a Steam como juego no de Steam (sin Proton)."
