#!/usr/bin/env bash
# Bañadores de DOAX2 para DOA4: el port (doa4-online) construye 34 trajes
# de Dead or Alive Xtreme 2 a partir del disco USA de DOAX2 (los deja en
# <partidas>/doax2_suits, ~300 MB). Normalmente se hace desde el juego (menú
# Esc, Extras, «Import DOAX2 swimsuits...»); aquí se hace una vez en el PC
# para meterlos en los paquetes de doa4 y doa4-linux (sus build.sh copian la
# caché a build/user_data/doax2_suits).
#
# Cómo: arranca el build de doa4-linux (copia reflink en work/suits-run) con
# la importación pendiente (--doa4_suits_import_pending=true) y el interruptor
# de pruebas del port DOA4_SETUP_TEST="doax2=<disco>", que elige el disco sin
# diálogos. Abre la ventana del juego ~40 s (hace falta sesión gráfica).
# Resultado: games/doa4-linux/work/doax2_suits (+ .release-tag con la versión
# de DOA4 con que se hicieron; los build.sh solo la copian si coincide).
#
# Uso: games/doa4-linux/doax2-suits.sh [-f] [disco]
#   -f          rehace los trajes aunque la caché sea de esta versión
#   -h, --help  muestra esta ayuda
#   disco       carpeta extraída o .iso del DOAX2 USA; por defecto la carpeta
#               extraída de games/doax2/build, o isos/DOAX2.iso
set -euo pipefail
case "${1:-}" in
    -h|--help)
        awk 'NR == 1 && /^#!/ { next } !/^#/ { exit } { sub(/^# ?/, ""); print }' "$0"
        exit 0 ;;
esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="$HERE/build"
RUN="$HERE/work/suits-run"
CACHE="$HERE/work/doax2_suits"
log() { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
die() { printf '\e[1;31m[error]\e[0m %s\n' "$*" >&2; exit 1; }

FORCE=0
if [[ "${1:-}" == "-f" ]]; then FORCE=1; shift; fi
DISC="${1:-}"
if [[ -z "$DISC" ]]; then
    DISC="$ROOT/games/doax2/build/extracted game files here"
    [[ -f "$DISC/default.xex" ]] || DISC="$ROOT/isos/DOAX2.iso"
fi
[[ -e "$DISC" ]] || die "No encuentro el disco de DOAX2: $DISC"
DISC="$(realpath "$DISC")"

[[ -f "$BUILD/.release-tag" && -x "$BUILD/steamdeck.sh" ]] \
    || die "Falta games/doa4-linux/build terminado (games/doa4-linux/build.sh)"
TAG="$(cat "$BUILD/.release-tag")"
if (( ! FORCE )) && [[ -f "$CACHE/manifest.txt" && "$(cat "$CACHE/.release-tag" 2>/dev/null)" == "$TAG" ]]; then
    log "Los trajes de DOAX2 ya están hechos con DOA4 $TAG ($CACHE)"
    exit 0
fi
[[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]] || die "Hace falta una sesión gráfica (el juego abre su ventana)"
pgrep -x dead_or_alive_4 >/dev/null && die "Hay un DOA4 abierto: ciérralo antes"

log "Copia de doa4-linux ($TAG) en work/suits-run (reflink)"
rm -rf "$RUN"
cp -a --reflink=auto "$BUILD" "$RUN"
rm -rf "$RUN/user_data/doax2_suits" "$RUN/logs"

log "Importando los trajes de $DISC (se abre la ventana del juego)"
DOA4_SETUP_TEST="doax2=$DISC" setsid "$RUN/steamdeck.sh" --doa4_suits_import_pending=true \
    >/dev/null 2>&1 </dev/null &
pid=$!
result=""
for _ in $(seq 300); do
    sleep 1
    log_file="$(ls -t "$RUN"/logs/*.log 2>/dev/null | head -1)"
    if [[ -n "$log_file" ]]; then
        result="$(grep -oP '\[doa4\]\[SETUP\] import: result \K\S+' "$log_file" | tail -1 || true)"
        [[ -n "$result" ]] && break
    fi
    kill -0 "$pid" 2>/dev/null || break
done
# Tras importar, el juego sigue arrancando: se cierra (SIGTERM, como Steam).
pkill -TERM -f "^$RUN/dead_or_alive_4" 2>/dev/null || true
for _ in $(seq 20); do pgrep -f "^$RUN/dead_or_alive_4" >/dev/null || break; sleep 1; done
pkill -KILL -f "^$RUN/dead_or_alive_4" 2>/dev/null || true

[[ "$result" == kImported ]] || die "La importación no terminó bien (resultado: ${result:-ninguno}); mira $RUN/logs"
n="$(find "$RUN/user_data/doax2_suits" -name '*.tpr' | wc -l)"
[[ -f "$RUN/user_data/doax2_suits/manifest.txt" && "$n" -gt 0 ]] || die "No hay trajes en $RUN/user_data/doax2_suits"

rm -rf "$CACHE"
mv "$RUN/user_data/doax2_suits" "$CACHE"
echo "$TAG" > "$CACHE/.release-tag"
rm -rf "$RUN"
log "$n trajes de DOAX2 en $CACHE ($(du -sh "$CACHE" | cut -f1)); los build.sh de doa4 y doa4-linux los copian"
