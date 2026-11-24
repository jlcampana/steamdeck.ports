# Ayuda común de los scripts: la cabecera de comentarios del propio script
# (desde la línea 2 hasta la primera que no es comentario) es su ayuda.
#
#   source "$ROOT/tools/help.sh"
#   show_help_if_asked "$0" "$@"     # sale con 0 si hay -h o --help
#
# Los games/<id>/build.sh la reciben a través de tools/lib.sh.

print_help() {
    awk 'NR == 1 && /^#!/ { next } !/^#/ { exit } { sub(/^# ?/, ""); print }' "$1"
}

show_help_if_asked() {
    local script="$1" arg
    shift
    for arg in "$@"; do
        case "$arg" in
            -h|--help) print_help "$script"; exit 0 ;;
        esac
    done
}
