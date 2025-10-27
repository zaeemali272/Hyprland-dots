#!/usr/bin/env python3
import gi, os, json, sys
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gio, GdkPixbuf, Gdk, GLib

# ---------------- SINGLE INSTANCE CHECK ---------------- #
LOCK_FILE = "/tmp/pylauncher.lock"

if os.path.exists(LOCK_FILE):
    # If already running, close existing instance
    try:
        with open(LOCK_FILE) as f:
            pid = int(f.read().strip())
        os.kill(pid, 9)
    except Exception:
        pass
    os.remove(LOCK_FILE)
    sys.exit(0)

# Write our PID
with open(LOCK_FILE, "w") as f:
    f.write(str(os.getpid()))

# ---------------- CONFIG ---------------- #
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(SCRIPT_DIR, "config.json")
HIDE_APPS_FILE = os.path.join(SCRIPT_DIR, "hide_apps.txt")
CSS_FILE = os.path.join(SCRIPT_DIR, "style.css")

if os.path.exists(CONFIG_FILE):
    with open(CONFIG_FILE) as f:
        CONFIG = json.load(f)
else:
    print(f"[WARN] Config not found at {CONFIG_FILE}, using defaults.")
    CONFIG = {}

HIDE_NO_ICON_APPS = CONFIG.get("hide_no_icon_apps", True)
WINDOW_WIDTH = CONFIG.get("window_width", 900)
WINDOW_HEIGHT = CONFIG.get("window_height", 600)

if os.path.exists(HIDE_APPS_FILE):
    with open(HIDE_APPS_FILE) as f:
        HIDDEN_APPS = {line.strip().lower() for line in f if line.strip()}
else:
    HIDDEN_APPS = set()


# ---------------- MAIN CLASS ---------------- #
class AppLauncher(Gtk.Window):
    def __init__(self):
        super().__init__(title="Launcher")

        # --- set WM_CLASS for Hyprland ---
        self.set_wmclass("launcher", "launcher")

        # --- window setup ---
        self.set_default_size(WINDOW_WIDTH, WINDOW_HEIGHT)
        self.set_border_width(0)
        self.set_focus_on_map(False)
        self.set_name("launcher-window")

        # --- auto-close when focus lost ---
        self.connect("focus-out-event", self.on_focus_out)

        # --- layout setup ---
        self.main_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.add(self.main_box)

        self.content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=CONFIG.get("apps_spacing", 8))
        for side in ("start", "end", "top", "bottom"):
            getattr(self.content_box, f"set_margin_{side}")(10)
        self.main_box.pack_start(self.content_box, True, True, 0)

        # --- favorites ---
        self.fav_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=CONFIG.get("apps_spacing", 8))
        self.content_box.pack_start(self.fav_box, False, False, 0)
        self.load_favorites()

        # --- search bar ---
        self.search_visible_setting = CONFIG.get("show_search", True)
        self.search = Gtk.SearchEntry()
        self.search.set_size_request(-1, CONFIG.get("search_height", 36))
        self.search.connect("search-changed", self.on_search)
        self.search.connect("focus-out-event", self.on_search_focus_out)
        self.search.set_visible(True)
        self.content_box.pack_start(self.search, False, False, 0)

        # --- app grid ---
        self.scrolled = Gtk.ScrolledWindow()
        self.scrolled.set_shadow_type(Gtk.ShadowType.NONE)
        self.scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.content_box.pack_start(self.scrolled, True, True, 0)

        self.flow = Gtk.FlowBox()
        self.flow.set_valign(Gtk.Align.START)
        self.flow.set_max_children_per_line(100)
        self.flow.set_selection_mode(Gtk.SelectionMode.NONE)
        self.flow.set_homogeneous(False)
        self.flow.set_row_spacing(CONFIG.get("apps_spacing", 8))
        self.flow.set_column_spacing(CONFIG.get("apps_spacing", 8))
        self.scrolled.add(self.flow)

        # --- load apps ---
        self.app_buttons = []
        self.first_visible_app = None
        self.load_apps()

        # --- signals ---
        self.connect("map-event", self.on_window_mapped)
        self.connect("key-press-event", self.on_window_key_press)
        self.connect("destroy", self.cleanup)

        if not self.search_visible_setting:
            GLib.idle_add(self.search.hide)

    # ---------------- CLEANUP ---------------- #
    def cleanup(self, *args):
        try:
            os.remove(LOCK_FILE)
        except Exception:
            pass

    # ---------------- CLOSE ON FOCUS LOST ---------------- #
    def on_focus_out(self, *args):
        Gtk.main_quit()
        return True

    # ---------------- WINDOW FOCUS FIX ---------------- #
    def on_window_mapped(self, *args):
        GLib.idle_add(self.force_focus_clear)
        return False

    def force_focus_clear(self):
        self.set_focus(None)
        self.search.set_can_focus(True)
        return False

    # ---------------- LOAD APPS ---------------- #
    def load_apps(self):
        theme = Gtk.IconTheme.get_default()
        seen_ids = set()
        kdeconnect_main = False

        for app in Gio.AppInfo.get_all():
            label = app.get_name()
            exe = (app.get_executable() or "").lower()
            app_id = app.get_id()

            if not label or label.lower() in HIDDEN_APPS:
                continue

            # KDE Connect filter
            if "kdeconnect" in exe or "kde connect" in (label.lower()):
                if "sms" in exe or "indicator" in exe:
                    continue
                if kdeconnect_main:
                    continue
                kdeconnect_main = True

            if app_id in seen_ids:
                continue
            seen_ids.add(app_id)

            img = self.get_app_icon(app, theme)
            if HIDE_NO_ICON_APPS and img is None:
                continue
            btn = self.add_app_button(app, label, img)
            self.app_buttons.append((label.lower(), btn))

    # ---------------- FAVORITES ---------------- #
    def load_favorites(self):
        theme = Gtk.IconTheme.get_default()
        seen = set()
        kdeconnect_main = False

        for f in CONFIG.get("favorites", []):
            paths = [
                os.path.join("/usr/share/applications", f),
                os.path.join(os.path.expanduser("~/.local/share/applications"), f),
            ]
            app = None
            for p in paths:
                if os.path.exists(p):
                    app = Gio.DesktopAppInfo.new_from_filename(p)
                    break
            if not app:
                continue

            label = app.get_name()
            exe = (app.get_executable() or "").lower()
            if label.lower() in HIDDEN_APPS:
                continue
            if "kdeconnect" in exe or "kde connect" in (label.lower()):
                if "sms" in exe or "indicator" in exe:
                    continue
                if kdeconnect_main:
                    continue
                kdeconnect_main = True
            if label in seen:
                continue
            seen.add(label)
            img = self.get_app_icon(app, theme)
            if HIDE_NO_ICON_APPS and img is None:
                continue
            btn = self.create_app_button(app, label, img)
            self.fav_box.pack_start(btn, False, False, 0)

    # ---------------- BUTTON CREATION ---------------- #
    def create_app_button(self, app, label, img):
        btn = Gtk.Button()
        btn.set_relief(Gtk.ReliefStyle.NONE)
        btn.set_size_request(
            CONFIG.get("icon_size", 64) + CONFIG.get("apps_padding", 8) * 2,
            CONFIG.get("icon_size", 64) + CONFIG.get("apps_padding", 8) * 2 +
            (CONFIG.get("font_size", 12) if CONFIG.get("show_labels", True) else 0)
        )
        btn.connect("clicked", lambda w, a=app: self.launch_and_close(a))
        btn.app_ref = app

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        if img:
            box.pack_start(img, True, True, 0)
        if CONFIG.get("show_labels", True):
            lbl = Gtk.Label(label=label)
            lbl.set_justify(Gtk.Justification.CENTER)
            box.pack_start(lbl, False, False, 0)
        btn.add(box)
        return btn

    def launch_and_close(self, app):
        app.launch([], None)
        Gtk.main_quit()

    def add_app_button(self, app, label, img):
        btn = self.create_app_button(app, label, img)
        self.flow.add(btn)
        return btn

    # ---------------- ICON HANDLING ---------------- #
    def get_app_icon(self, app, theme):
        icon = app.get_icon()
        if isinstance(icon, Gio.ThemedIcon):
            for name in icon.get_names():
                if theme.has_icon(name):
                    try:
                        pixbuf = theme.load_icon(name, CONFIG.get("icon_size", 64), 0)
                        return Gtk.Image.new_from_pixbuf(pixbuf)
                    except Exception:
                        continue
        elif isinstance(icon, Gio.FileIcon):
            path = icon.get_file().get_path()
            if path and os.path.exists(path):
                try:
                    pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_size(
                        path, CONFIG.get("icon_size", 64), CONFIG.get("icon_size", 64)
                    )
                    return Gtk.Image.new_from_pixbuf(pixbuf)
                except Exception:
                    pass
        return None

    # ---------------- SEARCH ---------------- #
    def clear_search_and_reset(self):
        self.search.set_text("")
        self.on_search(self.search)

    def clear_and_hide_search(self):
        self.clear_search_and_reset()
        self.search.hide()
        self.set_focus(None)

    def on_search(self, widget):
        query = widget.get_text().lower()
        self.first_visible_app = None
        if query == "":
            for _, btn in self.app_buttons:
                btn.show()
            return
        for label, btn in self.app_buttons:
            visible = query in label
            btn.set_visible(visible)
            if visible and self.first_visible_app is None:
                self.first_visible_app = btn

    def on_search_focus_out(self, widget, event):
        Gtk.main_quit()
        return False

    # ---------------- KEY EVENTS ---------------- #
    def on_window_key_press(self, widget, event):
        keyname = Gdk.keyval_name(event.keyval)
        if not keyname:
            return False
        if keyname == "Escape":
            Gtk.main_quit()
            return True
        if keyname == "Return":
            if self.first_visible_app and self.first_visible_app.get_visible():
                self.first_visible_app.app_ref.launch([], None)
                Gtk.main_quit()
                return True
        if len(keyname) == 1 and keyname.isprintable():
            if not self.search_visible_setting and not self.search.get_visible():
                self.search.show()
            self.search.grab_focus()
            current = self.search.get_text()
            self.search.set_text(current + keyname)
            self.search.set_position(len(current) + 1)
            self.on_search(self.search)
            return True
        return False


# ---------------- LOAD CSS ---------------- #
if os.path.exists(CSS_FILE):
    provider = Gtk.CssProvider()
    provider.load_from_path(CSS_FILE)
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)

# ---------------- RUN ---------------- #
win = AppLauncher()
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
