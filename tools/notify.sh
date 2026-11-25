# Aviso de escritorio (notify-send; GNOME, KDE…) al terminar un build o un
# paquete. Sin escritorio (SSH, cron) o sin notify-send no hace nada.
# STEAMDECK_PORTS_NOTIFY=0 lo desactiva.
#
#   source "$ROOT/tools/notify.sh"
#   notify "Título" "Texto" [icono]

notify() {
    [[ "${STEAMDECK_PORTS_NOTIFY:-1}" != 0 ]] || return 0
    [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] || return 0
    command -v notify-send >/dev/null || return 0
    notify-send -a "steamdeck.ports" -i "${3:-dialog-information}" "$1" "$2" 2>/dev/null || true
}
