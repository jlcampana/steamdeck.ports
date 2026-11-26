#!/usr/bin/env python3
"""Lanzador de DOAX2 (Linux): las opciones gráficas del lanzador de Windows.

Lo abre steamdeck.sh antes del juego. Se maneja con el mando (cruceta o
stick: elegir y cambiar; A: jugar o cambiar; Start: jugar; B: salir), con
el teclado (flechas, Enter, Esc) o con la pantalla táctil.

Uso: launcher.py <opciones.conf>
Sale con 0 para jugar (opciones guardadas), 1 si se cancela y 3 si no puede
mostrarse (sin GTK o sin pantalla: steamdeck.sh arranca el juego igual).
"""
import glob
import os
import struct
import sys

try:
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import GLib, Gtk, Gdk
except Exception:  # noqa: BLE001 (sin GTK: el juego arranca sin lanzador)
    sys.exit(3)

# (variable, título, [(valor, texto)], valor por defecto); la resolución
# guarda dos variables (DOAX2_WIDTH y DOAX2_HEIGHT).
OPTIONS = [
    ("DOAX2_FPS", "Fotogramas por segundo", [("60", "60 FPS"), ("30", "30 FPS (el original)")], "60"),
    ("RES", "Resolución", [("1280x720", "1280 × 720"), ("1280x800", "1280 × 800 (pantalla de la Deck)"),
                           ("1920x1080", "1920 × 1080"), ("2560x1440", "2560 × 1440")], "1280x720"),
    ("DOAX2_SCALE", "Escala interna", [("1", "1x (nativa)"), ("2", "2x"), ("3", "3x"), ("4", "4x")], "1"),
    ("DOAX2_MSAA", "Antialiasing MSAA", [("native", "2x nativo"), ("emulated", "2x emulado"),
                                         ("off", "No (el más rápido; mejor con FXAA)")], "native"),
    ("DOAX2_AA", "FXAA", [("0", "No"), ("1", "FXAA"), ("2", "FXAA extremo")], "0"),
    ("DOAX2_ANISO", "Filtro anisótropo", [("-1", "El del juego"), ("0", "No"), ("1", "1x"), ("2", "2x"),
                                          ("3", "4x"), ("4", "8x"), ("5", "16x")], "3"),
    ("DOAX2_SHADOWS", "Sombras dinámicas", [("1", "Sí"), ("0", "No")], "1"),
    ("DOAX2_FULLSCREEN", "Pantalla completa", [("1", "Sí"), ("0", "No")], "1"),
    ("DOAX2_FPS_OVERLAY", "Contador de FPS", [("0", "No"), ("1", "Sí")], "0"),
    ("DOAX2_LAUNCHER", "Mostrar este menú al arrancar",
     [("1", "Sí"), ("0", "No (para volver: DOAX2_LAUNCHER=1 en opciones.conf)")], "1"),
]
MANAGED = {k for k, *_ in OPTIONS if k != "RES"} | {"DOAX2_WIDTH", "DOAX2_HEIGHT"}

CSS = b"""
window { background: #10141c; }
label { color: #d8dee9; font-size: 20px; }
.title { font-size: 30px; font-weight: bold; color: #ffffff; }
.hint { font-size: 15px; color: #8a93a6; }
.row { padding: 6px 16px; border-radius: 8px; }
.row.selected { background: #2e5c9a; }
.value { color: #ffd479; }
.locked { color: #8a93a6; }
.button { font-size: 24px; font-weight: bold; padding: 10px 16px; border-radius: 8px; }
.button.selected { background: #2e9a5c; }
"""


def read_conf(path):
    lines, values = [], {}
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        pass
    for line in lines:
        k, sep, v = line.partition("=")
        k = k.strip()
        if sep and not k.startswith("#"):
            values[k] = v.split("#", 1)[0].strip()
    return lines, values


def write_conf(path, lines, values):
    out = [l for l in lines if l.partition("=")[0].strip() not in MANAGED]
    if not out:
        out = ["# Ajustes de DOAX2 (Linux); los cambia el lanzador (launcher.py).",
               "# Las Opciones de lanzamiento de Steam mandan sobre este archivo."]
    out += [f"{k}={values[k]}" for k in sorted(values) if k in MANAGED]
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
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


class Launcher(Gtk.Window):
    def __init__(self, conf):
        super().__init__(title="Dead or Alive Xtreme 2 (Linux)")
        self.conf = conf
        self.lines, values = read_conf(conf)
        self.choice = {}
        for key, _title, choices, default in OPTIONS:
            if key == "RES":
                cur = f"{values.get('DOAX2_WIDTH', '1280')}x{values.get('DOAX2_HEIGHT', '720')}"
            else:
                cur = values.get(key, default)
            vals = [v for v, _ in choices]
            if cur not in vals:  # valor a mano fuera de la lista: se añade
                choices.append((cur, cur))
                vals.append(cur)
            self.choice[key] = vals.index(cur)
        self.result = 1
        self.sel = len(OPTIONS)  # empieza en «Jugar»

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider,
                                                 Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4, margin=28)
        title = Gtk.Label(label="Dead or Alive Xtreme 2 (Linux)", xalign=0)
        title.get_style_context().add_class("title")
        box.pack_start(title, False, False, 8)
        self.rows = []
        for i, (key, text, _choices, _default) in enumerate(OPTIONS):
            ev = Gtk.EventBox()
            row = Gtk.Box(spacing=12)
            row.get_style_context().add_class("row")
            name = Gtk.Label(label=text, xalign=0)
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

    def refresh(self):
        for i, (key, _t, choices, _d) in enumerate(OPTIONS):
            row, value = self.rows[i]
            text = choices[self.choice[key]][1]
            env_key = None if key == "RES" else key
            if env_key and env_key in os.environ:  # fijada en las Opciones de lanzamiento de Steam
                text = f"{os.environ[env_key]} (fijado en Steam)"
                value.get_style_context().add_class("locked")
            value.set_text(text)
            ctx = row.get_style_context()
            (ctx.add_class if self.sel == i else ctx.remove_class)("selected")
        for i, lab in enumerate(self.buttons):
            ctx = lab.get_style_context()
            (ctx.add_class if self.sel == len(OPTIONS) + i else ctx.remove_class)("selected")

    def change(self, step):
        if self.sel < len(OPTIONS):
            key, _t, choices, _d = OPTIONS[self.sel]
            self.choice[key] = (self.choice[key] + step) % len(choices)
        elif step:
            self.sel = len(OPTIONS) + (1 - (self.sel - len(OPTIONS)))  # Jugar <-> Salir
        self.refresh()

    def action(self, what):
        last = len(OPTIONS) + 1
        if what == "up":
            self.sel = min(self.sel, len(OPTIONS)) - 1 if self.sel > 0 else last - 1
        elif what == "down":
            self.sel = 0 if self.sel >= len(OPTIONS) else self.sel + 1
        elif what in ("left", "right"):
            self.change(-1 if what == "left" else 1)
            return
        elif what == "accept":
            if self.sel < len(OPTIONS):
                self.change(1)
                return
            self.finish(self.sel == len(OPTIONS))
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
            values = {}
            for key, _t, choices, _d in OPTIONS:
                v = choices[self.choice[key]][0]
                if key == "RES":
                    values["DOAX2_WIDTH"], values["DOAX2_HEIGHT"] = v.split("x")
                else:
                    values[key] = v
            write_conf(self.conf, self.lines, values)
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
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        if not Gtk.init_check(sys.argv)[0]:
            return 3
        win = Launcher(sys.argv[1])
        win.show_all()
        Gtk.main()
        return win.result
    except Exception as e:  # noqa: BLE001 (cualquier fallo: el juego arranca igual)
        print(f"launcher.py: {e}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())
