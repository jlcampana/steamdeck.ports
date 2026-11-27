#!/usr/bin/env python3
"""Menú de opciones de un juego antes de jugar (común; modelo: el de DOAX2).

Lo abre el deck-launch.sh del juego. Se maneja con el mando (cruceta o stick:
elegir y cambiar; A: cambiar o jugar; Start: jugar; B: salir), con el
teclado (flechas, Enter, Esc) o con la pantalla táctil. Escribe cada opción
en el archivo y la clave que dice <opciones.json>, cambiando solo el valor
(los comentarios y el resto del archivo quedan igual; una clave que falta se
añade al final).

<opciones.json>:
  {"titulo": "…",
   "opciones": [{"archivo": "config/graphics.ini", "clave": "resolution_scale",
                 "titulo": "…", "valores": [["1.0", "texto"], …], "defecto": "1.0"}, …]}
Los archivos son relativos a <carpeta del juego>. La opción con
"archivo": "opciones.conf" y "clave": "MENU" decide si el menú sale al
arrancar (deck-launch.sh la lee).

Uso: opciones.py <opciones.json> <carpeta del juego>
Sale con 0 para jugar (opciones guardadas), 1 si se cancela y 3 si no puede
mostrarse (sin GTK o sin pantalla: el juego arranca igual).
"""
import glob
import json
import os
import re
import struct
import sys

try:
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import GLib, Gtk, Gdk
except Exception:  # noqa: BLE001 (sin GTK: el juego arranca sin menú)
    sys.exit(3)

CSS = b"""
window { background: #10141c; }
label { color: #d8dee9; font-size: 20px; }
.title { font-size: 30px; font-weight: bold; color: #ffffff; }
.hint { font-size: 15px; color: #8a93a6; }
.row { padding: 6px 16px; border-radius: 8px; }
.row.selected { background: #2e5c9a; }
.value { color: #ffd479; }
.button { font-size: 24px; font-weight: bold; padding: 10px 16px; border-radius: 8px; }
.button.selected { background: #2e9a5c; }
"""


def key_re(key):
    # «clave = valor», «clave=valor»; no las líneas comentadas
    return re.compile(r"^(\s*" + re.escape(key) + r"\s*=\s*)([^;#\r\n]*?)(\s*([;#].*)?)$")


def read_value(path, key):
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                m = key_re(key).match(line.rstrip("\n"))
                if m:
                    return m.group(2).strip()
    except OSError:
        pass
    return None


def write_values(path, values):
    """values: {clave: valor}. Cambia el valor de la primera línea de cada clave."""
    try:
        with open(path, encoding="utf-8", newline="") as f:
            lines = f.read().split("\n")
    except OSError:
        lines = []
    pending = dict(values)
    for i, line in enumerate(lines):
        for key in list(pending):
            m = key_re(key).match(line.rstrip("\r"))
            if m:
                end = "\r" if line.endswith("\r") else ""
                lines[i] = m.group(1) + pending.pop(key) + m.group(3) + end
                break
    while lines and lines[-1] == "":
        lines.pop()
    sep = " = " if any(re.match(r"^\s*\w+ = ", l) for l in lines) else "="
    lines += [f"{k}{sep}{v}" for k, v in pending.items()]
    tmp = path + ".tmp"
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(tmp, "w", encoding="utf-8", newline="") as f:
        f.write("\n".join(lines) + "\n")
    os.replace(tmp, path)


class Joysticks:
    """Mandos por la interfaz /dev/input/js* (eventos de 8 bytes)."""
    EVENT = struct.Struct("IhBB")  # tiempo, valor, tipo, número
    BUTTON, AXIS, INIT = 0x01, 0x02, 0x80

    def __init__(self, on_action):
        self.on_action = on_action
        self.stick = {}
        devices = sorted(glob.glob("/dev/input/js*"))
        names = {d: self._name(d) for d in devices}
        # Con Steam Input, los mandos son «Microsoft X-Box 360 pad» virtuales;
        # leer también el físico duplicaría cada pulsación.
        virtual = [d for d in devices if "X-Box 360 pad" in names[d]]
        for dev in virtual or devices:
            try:
                fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
            except OSError:
                continue
            GLib.io_add_watch(fd, GLib.IO_IN, self._read)

    @staticmethod
    def _name(dev):
        try:
            with open(f"/sys/class/input/{os.path.basename(dev)}/device/name") as f:
                return f.read().strip()
        except OSError:
            return ""

    def _read(self, fd, _cond):
        try:
            data = os.read(fd, self.EVENT.size * 32)
        except BlockingIOError:
            return True
        except OSError:
            return False
        for i in range(0, len(data) - self.EVENT.size + 1, self.EVENT.size):
            _, value, kind, number = self.EVENT.unpack_from(data, i)
            if kind & self.INIT:
                continue
            if kind == self.BUTTON and value:
                action = {0: "accept", 1: "back", 7: "play", 11: "left", 12: "right", 13: "up", 14: "down"}.get(number)
                if action:
                    self.on_action(action)
            elif kind == self.AXIS:
                self._axis(fd, number, value)
        return True

    def _axis(self, fd, number, value):
        # 0/1: stick izquierdo, 6/7: cruceta (xpad). Un paso al pasar el umbral.
        if number not in (0, 1, 6, 7):
            return
        pos = -1 if value < -20000 else 1 if value > 20000 else 0
        key = (fd, number)
        if pos and self.stick.get(key) != pos:
            horizontal = number in (0, 6)
            self.on_action(("left" if pos < 0 else "right") if horizontal else ("up" if pos < 0 else "down"))
        self.stick[key] = pos


class Menu(Gtk.Window):
    def __init__(self, spec, game_dir):
        super().__init__(title=spec.get("titulo", "Opciones"))
        self.game_dir = game_dir
        self.options = spec["opciones"]
        self.choice = []
        for o in self.options:
            cur = read_value(self.path(o), o["clave"])
            vals = [v for v, _ in o["valores"]]
            if cur is None:
                cur = o.get("defecto", vals[0])
            if cur not in vals:  # valor a mano fuera de la lista: se añade
                o["valores"].append([cur, f"{cur} (a mano)"])
                vals.append(cur)
            self.choice.append(vals.index(cur))
        self.result = 1
        self.sel = len(self.options)  # empieza en «Jugar»

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider,
                                                 Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4, margin=28)
        title = Gtk.Label(label=spec.get("titulo", "Opciones"), xalign=0)
        title.get_style_context().add_class("title")
        box.pack_start(title, False, False, 8)
        self.rows = []
        for i, o in enumerate(self.options):
            ev = Gtk.EventBox()
            row = Gtk.Box(spacing=12)
            row.get_style_context().add_class("row")
            name = Gtk.Label(label=o["titulo"], xalign=0)
            value = Gtk.Label(xalign=1)
            value.get_style_context().add_class("value")
            row.pack_start(name, True, True, 0)
            row.pack_end(value, False, False, 0)
            ev.add(row)
            ev.connect("button-press-event", self._click_row, i)
            box.pack_start(ev, False, False, 0)
            self.rows.append((row, value))
        buttons = Gtk.Box(spacing=16)
        self.buttons = []
        for i, text in enumerate(("▶  Jugar", "Salir")):
            ev = Gtk.EventBox()
            lab = Gtk.Label(label=text)
            lab.get_style_context().add_class("button")
            ev.add(lab)
            ev.connect("button-press-event", self._click_button, i)
            buttons.pack_start(ev, i == 0, True, 0)
            self.buttons.append(lab)
        box.pack_start(buttons, False, False, 14)
        if spec.get("nota"):
            note = Gtk.Label(xalign=0, label=spec["nota"])
            note.set_line_wrap(True)
            note.get_style_context().add_class("hint")
            box.pack_start(note, False, False, 0)
        hint = Gtk.Label(xalign=0, label="Cruceta o stick: elegir y cambiar · A: cambiar / jugar · "
                                          "Start: jugar · B: salir   (también teclado o pantalla táctil)")
        hint.get_style_context().add_class("hint")
        box.pack_end(hint, False, False, 0)
        self.add(box)

        self.connect("key-press-event", self._key)
        self.connect("destroy", Gtk.main_quit)
        self.set_default_size(1280, 800)
        self.fullscreen()
        Joysticks(self.action)
        self.refresh()

    def path(self, o):
        return os.path.join(self.game_dir, o["archivo"])

    def refresh(self):
        for i, o in enumerate(self.options):
            row, value = self.rows[i]
            value.set_text(o["valores"][self.choice[i]][1])
            ctx = row.get_style_context()
            (ctx.add_class if self.sel == i else ctx.remove_class)("selected")
        n = len(self.options)
        for i, lab in enumerate(self.buttons):
            ctx = lab.get_style_context()
            (ctx.add_class if self.sel == n + i else ctx.remove_class)("selected")

    def change(self, step):
        n = len(self.options)
        if self.sel < n:
            self.choice[self.sel] = (self.choice[self.sel] + step) % len(self.options[self.sel]["valores"])
        elif step:
            self.sel = n + (1 - (self.sel - n))  # Jugar <-> Salir
        self.refresh()

    def action(self, what):
        n = len(self.options)
        if what == "up":
            self.sel = min(self.sel, n) - 1 if self.sel > 0 else n
        elif what == "down":
            self.sel = 0 if self.sel >= n else self.sel + 1
        elif what in ("left", "right"):
            self.change(-1 if what == "left" else 1)
            return
        elif what == "accept":
            if self.sel < n:
                self.change(1)
                return
            self.finish(self.sel == n)
            return
        elif what == "play":
            self.finish(True)
            return
        elif what == "back":
            self.finish(False)
            return
        self.refresh()

    def finish(self, play):
        if play:
            by_file = {}
            for i, o in enumerate(self.options):
                by_file.setdefault(self.path(o), {})[o["clave"]] = o["valores"][self.choice[i]][0]
            for path, values in by_file.items():
                write_values(path, values)
        self.result = 0 if play else 1
        self.destroy()

    def _key(self, _w, event):
        name = Gdk.keyval_name(event.keyval)
        action = {"Up": "up", "Down": "down", "Left": "left", "Right": "right", "Return": "accept",
                  "KP_Enter": "accept", "space": "accept", "Escape": "back"}.get(name)
        if action:
            self.action(action)
        return True

    def _click_row(self, _w, _e, i):
        self.sel = i
        self.change(1)

    def _click_button(self, _w, _e, i):
        self.finish(i == 0)


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        with open(sys.argv[1], encoding="utf-8") as f:
            spec = json.load(f)
        if not Gtk.init_check(sys.argv)[0]:
            return 3
        win = Menu(spec, sys.argv[2])
        win.show_all()
        Gtk.main()
        return win.result
    except Exception as e:  # noqa: BLE001 (cualquier fallo: el juego arranca igual)
        print(f"opciones.py: {e}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())
