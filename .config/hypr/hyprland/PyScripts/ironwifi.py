#!/usr/bin/env python3
# ironwifi_full_clean_fixed.py — IWD Wi-Fi Manager (GTK3)
# Author: Zaeem + ChatGPT (2025)

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, Gdk
import subprocess, json, re, threading, time
from pathlib import Path

CONFIG_FILE = Path.home() / ".config/hypr/hyprland/data/wifi_saved.json"
CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
if not CONFIG_FILE.exists():
    CONFIG_FILE.write_text("{}")

DEF_REFRESH = 5
LEAVE_CLOSE_MS = 200
_saved_lock = threading.Lock()


def log(msg):
    print(f"[DEBUG] {msg}", flush=True)


def load_saved():
    try:
        return json.load(open(CONFIG_FILE))
    except Exception:
        return {}


def save_saved(data):
    try:
        with _saved_lock:
            json.dump(data, open(CONFIG_FILE, "w"), indent=2)
    except Exception as e:
        log(f"Failed to save config: {e}")


saved_networks = load_saved()


def get_station():
    try:
        out = subprocess.check_output("iw dev", shell=True, text=True)
        m = re.search(r"Interface\s+(\w+)", out)
        if m:
            return m.group(1)
    except Exception:
        pass
    return "wlan0"


STATION = get_station()


def get_connected_ssid():
    try:
        out = subprocess.check_output(
            ["iwctl", "station", STATION, "show"], text=True, stderr=subprocess.DEVNULL
        )
        ssid = None
        state = None

        for line in out.splitlines():
            line = line.strip()
            # Match "State" and "Connected network" even if spacing is weird
            if re.search(r"^State\s", line, re.IGNORECASE):
                state = line.split()[-1].lower()
            elif re.search(r"^Connected\s+network\s", line, re.IGNORECASE):
                parts = line.split()
                if len(parts) >= 3:
                    ssid = parts[-1].strip()

        if state == "connected" and ssid:
            log(f"Connected SSID detected: {ssid}")
            return ssid
    except Exception as e:
        log(f"get_connected_ssid error: {e}")
    return None


def scan_networks_blocking():
    try:
        subprocess.run(
            ["iwctl", "station", STATION, "scan"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=6,
        )
    except Exception:
        pass

    try:
        raw = subprocess.check_output(
            ["iwctl", "station", STATION, "get-networks"], text=True, timeout=6
        )
    except Exception:
        return []

    raw = re.sub(r"\x1B\[[0-9;]*[mK]", "", raw)
    nets = []

    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith(("Available", "Network name", "----")):
            continue
        parts = line.rsplit(None, 2)
        if len(parts) != 3:
            continue
        ssid, sig, sec = parts
        nets.append((ssid.strip(), sec.strip()))

    conn = get_connected_ssid()
    if conn:
        conn = conn.strip().lower()

    result = []
    for s, sec in nets:
        result.append((s, sec, s.strip().lower() == conn))
    return result


def connect_network_blocking(ssid, password=None):
    cmd = ["iwctl", "station", STATION, "connect", ssid]
    try:
        if password:
            proc = subprocess.run(
                cmd, input=password + "\n", text=True, capture_output=True, timeout=25
            )
        else:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=25)
    except Exception as e:
        return False, str(e)
    out, err = (proc.stdout or "").strip(), (proc.stderr or "").strip()
    if proc.returncode == 0:
        with _saved_lock:
            saved_networks[ssid] = password or ""
            save_saved(saved_networks)
        return True, out or "Connected"
    return False, err or out or "Connect failed"


def disconnect_blocking():
    try:
        proc = subprocess.run(
            ["iwctl", "station", STATION, "disconnect"],
            capture_output=True,
            text=True,
            timeout=8,
        )
    except Exception as e:
        return False, str(e)
    if proc.returncode == 0:
        return True, (proc.stdout or "Disconnected").strip()
    return False, (proc.stderr or proc.stdout or "Disconnect failed").strip()


def forget_blocking(ssid):
    try:
        proc = subprocess.run(
            ["iwctl", "known-networks", ssid, "forget"],
            capture_output=True,
            text=True,
            timeout=8,
        )
    except Exception as e:
        return False, str(e)
    if proc.returncode == 0:
        with _saved_lock:
            saved_networks.pop(ssid, None)
            save_saved(saved_networks)
        return True, (proc.stdout or "Forgot").strip()
    return False, (proc.stderr or proc.stdout or "Forget failed").strip()


class IronWiFi(Gtk.Window):
    def __init__(self):
        super().__init__(title="IronWiFi")
        self.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)
        self.set_keep_above(True)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_accept_focus(True)
        self.set_default_size(460, 420)
        self.connect("key-press-event", self.on_key_press)

        screen = Gdk.Screen.get_default()
        self._popup_x = max(0, screen.get_width() - 470)
        self._popup_y = 35
        self.move(self._popup_x, self._popup_y)

        css = b"""
        window{background:#1e1e1e;color:#f2f2f2;border-radius:12px;border:1px solid #333;}
        label,treeview{color:#ddd;font-size:12px;}
        button{background:#2b2b2b;color:#fff;border-radius:8px;padding:4px 8px;}
        button:hover{background:#444;}
        """
        prov = Gtk.CssProvider()
        prov.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            screen, prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self._action_bar = None
        self._connect_lock = threading.Lock()

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        vbox.set_margin_top(8)
        vbox.set_margin_bottom(8)
        vbox.set_margin_start(8)
        vbox.set_margin_end(8)
        self.add(vbox)

        # Header — Interface + Connected SSID
        header = Gtk.Box(spacing=8)
        self.iface_label = Gtk.Label()
        self.iface_label.set_xalign(0)
        self.refresh_btn = Gtk.Button(label="⟳ Refresh")
        self.refresh_btn.connect("clicked", lambda *_: self.start_scan())
        header.pack_start(self.iface_label, True, True, 0)
        header.pack_end(self.refresh_btn, False, False, 0)
        vbox.pack_start(header, False, False, 0)

        # Tree
        self.store = Gtk.ListStore(str, str)
        self.tree = Gtk.TreeView(model=self.store)
        self.tree.set_headers_visible(False)
        for i, min_w in enumerate([0, 80]):
            r = Gtk.CellRendererText()
            col = Gtk.TreeViewColumn("", r, text=i)
            if i > 0:
                col.set_min_width(min_w)
            if i == 0:
                col.set_expand(True)
            self.tree.append_column(col)
        sel = self.tree.get_selection()
        sel.set_mode(Gtk.SelectionMode.SINGLE)
        sel.connect("changed", self.on_selection_changed)
        scroll = Gtk.ScrolledWindow()
        scroll.set_vexpand(True)
        scroll.add(self.tree)
        vbox.pack_start(scroll, True, True, 0)

        self._leave_close_id = None
        self.connect("enter-notify-event", self._on_enter)
        self.connect("leave-notify-event", self._on_leave)
        self.connect("focus-out-event", lambda *_: self.close_popup())

        self._scanning = False
        self.start_scan()
        GLib.timeout_add_seconds(DEF_REFRESH, self.start_scan)

    # --- Main scanning ---
    def start_scan(self, *_):
        if self._scanning:
            return
        self._scanning = True
        self.refresh_btn.set_sensitive(False)
        threading.Thread(target=self._scan_worker, daemon=True).start()

    def _scan_worker(self):
        nets = scan_networks_blocking()
        GLib.idle_add(self._on_scan_done, nets)

    def _on_scan_done(self, nets):
        self.store.clear()
        current_ssid = get_connected_ssid() or ""
        for s, sec, _ in nets:
            is_connected = s.strip() == current_ssid.strip()
            icon = "" if is_connected or s in saved_networks else ""
            display_name = f"● {s}" if is_connected else s
            # keep order same, just append
            self.store.append([display_name, icon])

        # ✅ Fix: Show connected SSID inline in header (always refreshed)
        if current_ssid:
            self.iface_label.set_text(
                f"Interface: {STATION}   |   Connected: {current_ssid}"
            )
        else:
            self.iface_label.set_text(f"Interface: {STATION}   |   Connected: (none)")

        self.refresh_btn.set_sensitive(True)
        self._scanning = False

        if self._action_bar:
            self._action_bar.destroy()
            self._action_bar = None
        return False

    # --- Selection & Action Bar ---
    def on_selection_changed(self, selection):
        model, it = selection.get_selected()
        if not it:
            return
        ssid = model[it][0].replace("●", "").strip()
        if not ssid:
            return

        current_conn = get_connected_ssid()
        is_connected = current_conn == ssid
        is_known = ssid in saved_networks

        if self._action_bar:
            self._action_bar.destroy()
            self._action_bar = None
        parent = self.get_children()[0]

        if is_connected:
            # Connected network — show Disconnect, Forget, Show Password
            self._action_bar = Gtk.Box(spacing=6)
            buttons = [
                ("Disconnect", self.disconnect_selected),
                ("Forget", self.forget_selected),
                ("Show Password", self.show_password),
            ]
        elif is_known:
            # Known but not connected — show Connect, Forget, Show Password
            self._action_bar = Gtk.Box(spacing=6)
            buttons = [
                ("Connect", self.connect_selected),
                ("Forget", self.forget_selected),
                ("Show Password", self.show_password),
            ]
        else:
            # Unknown — password entry + connect
            self._action_bar = Gtk.Box(spacing=6)
            entry = Gtk.Entry()
            entry.set_placeholder_text(f"Password for {ssid}")
            entry.set_visibility(False)
            show_btn = Gtk.Button(label="👁")
            show_btn.connect(
                "clicked", lambda *_: entry.set_visibility(not entry.get_visibility())
            )
            connect_btn = Gtk.Button(label="Connect")
            connect_btn.connect(
                "clicked", lambda *_: self._on_connect_click(ssid, entry)
            )
            entry.connect("activate", lambda *_: self._on_connect_click(ssid, entry))
            self._action_bar.pack_start(entry, True, True, 0)
            self._action_bar.pack_start(show_btn, False, False, 0)
            self._action_bar.pack_start(connect_btn, False, False, 0)
            parent.pack_end(self._action_bar, False, False, 4)
            self._action_bar.show_all()
            GLib.idle_add(entry.grab_focus)
            return

        # Shared button logic for connected/known
        for text, cb in buttons:
            b = Gtk.Button(label=text)
            b.connect("clicked", lambda w, cb=cb, s=ssid: cb(s))
            self._action_bar.pack_start(b, False, False, 2)
        parent.pack_end(self._action_bar, False, False, 4)
        self._action_bar.show_all()

    # --- Connect / Disconnect ---
    def connect_selected(self, ssid):
        threading.Thread(
            target=lambda: self._connect_with_lock(ssid, saved_networks.get(ssid)),
            daemon=True,
        ).start()

    def disconnect_selected(self, ssid):
        threading.Thread(target=self._disconnect_with_lock, daemon=True).start()

    def forget_selected(self, ssid):
        threading.Thread(
            target=lambda: (forget_blocking(ssid), GLib.idle_add(self.start_scan)),
            daemon=True,
        ).start()

    def show_password(self, ssid):
        pwd_txt = saved_networks.get(ssid, "")
        dlg = Gtk.MessageDialog(
            transient_for=self,
            flags=0,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.CLOSE,
            text=f"Password for {ssid}:",
        )
        dlg.format_secondary_text(pwd_txt or "(empty)")
        dlg.run()
        dlg.destroy()

    def _on_connect_click(self, ssid, entry):
        pwd = entry.get_text().strip()
        if not pwd:
            return
        threading.Thread(
            target=lambda: self._connect_with_lock(ssid, pwd), daemon=True
        ).start()
        if self._action_bar:
            self._action_bar.destroy()
            self._action_bar = None

    def _connect_with_lock(self, ssid, password=None):
        with self._connect_lock:
            disconnect_blocking()
            time.sleep(0.3)
            success, msg = connect_network_blocking(ssid, password)
            log(f"Connect result: {success}, {msg}")
            GLib.idle_add(self.start_scan)

    def _disconnect_with_lock(self):
        with self._connect_lock:
            disconnect_blocking()
            GLib.idle_add(self.start_scan)

    # --- Window behavior ---
    def _on_enter(self, *_):
        if self._leave_close_id:
            GLib.source_remove(self._leave_close_id)
            self._leave_close_id = None
        return False

    def _on_leave(self, widget, event):
        if event.detail in (Gdk.NotifyType.INFERIOR, Gdk.NotifyType.VIRTUAL):
            return False
        self._leave_close_id = GLib.timeout_add(LEAVE_CLOSE_MS, self.close_popup)
        return False

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.close_popup()
        return False

    def close_popup(self, *_):
        if self._leave_close_id:
            GLib.source_remove(self._leave_close_id)
            self._leave_close_id = None
        Gtk.main_quit()
        return False


if __name__ == "__main__":
    print("⚙️ Starting IronWiFi — interface:", STATION, flush=True)
    app = IronWiFi()
    app.show_all()
    Gtk.main()
