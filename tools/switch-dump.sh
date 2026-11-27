#!/usr/bin/env bash
# Saca de un juego de Switch (.nsp o .xci, y su update .nsp) el exefs/, la
# romfs/ con la update aplicada y el control/ (icono, control.nacp), que es
# lo que piden los ports que no descifran nada (B2recomp, B3-Express).
# Con hactool (tools/install.sh) y las claves de la Switch del usuario:
#   - HOME temporal para hactool con un prod.keys filtrado (hactool se para
#     en claves de longitud rara) y un title.keys hecho de los tickets
#     (clave en 0x180, tipo en 0x281: solo tickets comunes; rights ID en
#     0x2a0), sin líneas repetidas (hactool se para en ellas).
#   - .xci: los .nca de la partición «secure», leída aquí (las cabeceras
#     HFS0), porque hactool rechaza los .xci convertidos de .nsp («XCI
#     partition is corrupt»: el hash de la partición raíz no coincide).
#   - El Program de la update es el que tiene el Title ID del Program base
#     (una update puede traer otros programas: la de Bayonetta 3 trae dos).
# Los .nca intermedios van a <tmp> y se borran al terminar. hactool escribe
# valores de claves en sus avisos: su salida se filtra.
#
# Uso: tools/switch-dump.sh <salida> <tmp> <prod.keys> <base.nsp|.xci> [update.nsp]
#   -h, --help  muestra esta ayuda
# <salida> no debe existir; se crea <salida> con exefs/, romfs/ y control/.
set -euo pipefail
TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/help.sh
source "$TOOLS/help.sh"
show_help_if_asked "$0" "$@"
(( $# >= 4 )) || { echo "Uso: $0 <salida> <tmp> <prod.keys> <base.nsp|.xci> [update.nsp]" >&2; exit 2; }
OUT="$1" TMPD="$2" KEYS="$3" BASE="$4" UPD="${5:-}"
HACTOOL="$TOOLS/bin/hactool"
[[ -x "$HACTOOL" ]] || { echo "Falta hactool: tools/install.sh" >&2; exit 1; }
[[ ! -e "$OUT" ]] || { echo "$OUT ya existe" >&2; exit 1; }

W="$TMPD/steamdeck-ports-switch-dump.$$"
mkdir -p "$W"
trap 'rm -rf "$W"' EXIT
HH="$W/home"
(umask 077; mkdir -p "$HH/.switch"
 awk -F'[ =]+' 'NF>=2 && (length($2)==32 || length($2)==64)' "$KEYS" > "$HH/.switch/prod.keys")
hac() { HOME="$HH" "$HACTOOL" --disablekeywarns --suppresskeys "$@" 2>&1 | sed -E 's/[0-9a-fA-F]{24,}/<hex>/g'; }

unpack() {  # contenedor carpeta
    mkdir -p "$2"
    case "${1,,}" in
        *.xci) python3 - "$1" "$2" <<'EOF'
import os, struct, sys
f = open(sys.argv[1], 'rb')
def hfs0(off):
    f.seek(off)
    h = f.read(16)
    if h[:4] != b'HFS0':
        sys.exit('%s: no hay HFS0 en 0x%x' % (sys.argv[1], off))
    n, strsz = struct.unpack('<II', h[4:12])
    ents = [struct.unpack('<QQIIQ32s', f.read(0x40)) for _ in range(n)]
    strs = f.read(strsz)
    hdr = 16 + n * 0x40 + strsz
    return [(strs[no:strs.index(b'\0', no)].decode(), off + hdr + o, s) for o, s, no, *_ in ents]
f.seek(0x100)
if f.read(4) != b'HEAD':
    sys.exit('%s: no es un .xci (sin HEAD en 0x100)' % sys.argv[1])
f.seek(0x130)
secure = [e for e in hfs0(struct.unpack('<Q', f.read(8))[0]) if e[0] == 'secure']
if not secure:
    sys.exit('%s: sin partición secure' % sys.argv[1])
for name, off, size in hfs0(secure[0][1]):
    with open(os.path.join(sys.argv[2], name), 'wb') as o:
        f.seek(off)
        left = size
        while left:
            b = f.read(min(left, 64 << 20))
            if not b:
                sys.exit('%s: se acaba antes de tiempo' % sys.argv[1])
            o.write(b)
            left -= len(b)
EOF
        ;;
        *) hac -t pfs0 --outdir="$2" "$1" >/dev/null ;;
    esac
}
echo "Desempaquetando $(basename "$BASE")"
unpack "$BASE" "$W/base"
[[ -n "$UPD" ]] && { echo "Desempaquetando $(basename "$UPD")"; unpack "$UPD" "$W/upd"; }
(umask 077
 shopt -s nullglob
 tiks=("$W"/base/*.tik "$W"/upd/*.tik)
 (( ${#tiks[@]} )) || exit 0
 python3 - "${tiks[@]}" <<'EOF' | sort -u > "$HH/.switch/title.keys"
import sys
for p in sys.argv[1:]:
    t = open(p, 'rb').read()
    if t[0:4] != b'\x04\x00\x01\x00' or t[0x281] != 0:
        sys.exit('%s: ticket no común o de formato inesperado' % p)
    print('%s = %s' % (t[0x2a0:0x2b0].hex(), t[0x180:0x190].hex()))
EOF
)

# "tipo título" de cada .nca de una carpeta
nca_info() {
    local n
    for n in "$1"/*.nca; do
        [[ "$n" == *.cnmt.nca ]] && continue
        hac -i "$n" | awk -v f="$n" '/^Title ID:/ {t=$3} /Content Type:/ {c=$3} END {print c, t, f}'
    done
}
base_prog="$(nca_info "$W/base" | awk '$1=="Program" {print $2, $3; exit}')"
[[ -n "$base_prog" ]] || { echo "No hay .nca Program en $(basename "$BASE") (¿claves?)" >&2; exit 1; }
tid="${base_prog%% *}" base_nca="${base_prog#* }"
src=(--exefsdir="$OUT.part/exefs" --romfsdir="$OUT.part/romfs")
rm -rf "$OUT.part"
mkdir -p "$OUT.part"  # hactool no crea la carpeta padre de --exefsdir/--romfsdir
if [[ -n "$UPD" ]]; then
    upd_info="$(nca_info "$W/upd")"
    upd_nca="$(awk -v t="$tid" '$1=="Program" && $2==t {print $3; exit}' <<<"$upd_info")"
    ctl_nca="$(awk -v t="$tid" '$1=="Control" && $2==t {print $3; exit}' <<<"$upd_info")"
    [[ -n "$upd_nca" ]] || { echo "La update no trae el Program de $tid" >&2; exit 1; }
    echo "Extrayendo exefs/ y romfs/ con la update aplicada"
    hac --basenca="$base_nca" "${src[@]}" "$upd_nca" | grep -i -E 'error|fail|corrupt|unable|invalid|\[WARN\]' >&2 || true
else
    ctl_nca="$(nca_info "$W/base" | awk -v t="$tid" '$1=="Control" && $2==t {print $3; exit}')"
    echo "Extrayendo exefs/ y romfs/"
    hac "${src[@]}" "$base_nca" | grep -i -E 'error|fail|corrupt|unable|invalid|\[WARN\]' >&2 || true
fi
[[ -n "$ctl_nca" ]] && hac --romfsdir="$OUT.part/control" "$ctl_nca" >/dev/null
[[ -f "$OUT.part/exefs/main" && -d "$OUT.part/romfs" ]] \
    || { echo "La extracción no dejó exefs/main y romfs/ (¿claves?)" >&2; exit 1; }
mv "$OUT.part" "$OUT"
echo "Listo: $OUT (Title ID $tid)"
