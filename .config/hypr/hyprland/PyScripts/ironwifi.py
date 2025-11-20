#!/usr/bin/env python3
# ironwifi_checked.py — IWD Wi-Fi Manager (GTK3)
# Author: Zaeem + ChatGPT (2025)
# Fixes:
#  - use iwctl --passphrase for non-interactive password submission
#  - pause auto-refresh while user interacts / typing password
#  - avoid concurrent scans and ensure periodic timer persists correctly
#  - more robust parsing of iwctl output

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, Gdk
import subprocess, json, re, threading, time, os
from pathlib import Path

# ---------- Configuration ----------
CONFIG_FILE = Path.home() / ".config/hypr/hyprland/data/wifi_saved.json"
CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
if not CONFIG_FILE.exists():
    CONFIG_FILE.write_text("{}")

DEF_REFRESH = 5           # seconds between auto-scans
LEAVE_CLOSE_MS = 200
_saved_lock = threading.Lock()

# ---------- Helpers ----------
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

def detect_station():
    """Detect wireless interface name via `iw dev` (fallback to wlan0)."""
    try:
        out = subprocess.check_output(["iw", "dev"], text=True)
        m = re.search(r"Interface\s+(\w+)", out)
        if m:
            return m.group(1)
    except Exception:
        pass
    return "wlan0"

STATION = detect_station()

# ---------- iwctl wrappers ----------
def get_connected_ssid():
    """
    Parse `iwctl station <dev> show`.
    Looks for lines like:
      State: connected
      Connected network: SSID NAME
    """
    try:
        proc = subprocess.run(
            ["iwctl", "station", STATION, "show"],
            capture_output=True, text=True, timeout=3
        )
        out = proc.stdout or ""
        state = None
        ssid = None
        for line in out.splitlines():
            line = line.strip()
            if re.match(r"(?i)^State\b", line):
                # e.g. "State: connected"
                state = line.split(":", 1)[-1].strip().lower()
            elif re.match(r"(?i)^Connected network\b", line) or "Connected network:" in line:
                # e.g. "Connected network: mySSID"
                parts = line.split(":", 1)
                if len(parts) == 2:
                    ssid = parts[1].strip()
                else:
                    # fallback: last token
                    ssid = line.split()[-1].strip()
        if state == "connected" and ssid:
            log(f"Connected SSID detected: {ssid}")
            return ssid
    except Exception as e:
        log(f"get_connected_ssid error: {e}")
    return None

def scan_networks_blocking():
    """
    Run `iwctl station <dev> scan` then `iwctl station <dev> get-networks`.
    Returns list of tuples: (ssid, security)
    The raw 'get-networks' output has columns; we rsplit to keep SSIDs that contain spaces.
    """
    try:
        subprocess.run(
            ["iwctl", "station", STATION, "scan"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=6
        )
    except Exception:
        pass

    try:
        proc = subprocess.run(
            ["iwctl", "station", STATION, "get-networks"],
            capture_output=True, text=True, timeout=6
        )
        raw = proc.stdout or ""
    except Exception:
        return []

    # remove terminal color sequences
    raw = re.sub(r"\x1B\[[0-9;]*[mK]", "", raw)
    nets = []
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith(("Available", "Network name", "----")):
            continue
        # rsplit into 3 pieces from right: (ssid maybe with spaces), signal, security
        parts = line.rsplit(None, 2)
        if len(parts) == 3:
            ssid, sig, sec = parts
            nets.append((ssid.strip(), sec.strip()))
        else:
            # fallback: entire line as ssid (unknown sec)
            nets.append((line, ""))
    # mark connected later in UI code
    return nets

def connect_network_blocking(ssid, password=None):
    """
    Use iwctl --passphrase when password is provided.
    Use argument list (no shell) so SSIDs with spaces are passed intact.
    Returns (success_bool, message)
    """
    try:
        if password:
            # According to iwctl manpage, use --passphrase (or -P) for non-interactive passphrase
            cmd = ["iwctl", "--passphrase", password, "station", STATION, "connect", ssid]
        else:
            cmd = ["iwctl", "station", STATION, "connect", ssid]

        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    except Exception as e:
        return False, str(e)

    out = (proc.stdout or "").strip()
    err = (proc.stderr or "").strip()
    log(f"connect_network_blocking: cmd={' '.join(cmd)}; rc={proc.returncode}; out={out!r}; err={err!r}")
    if proc.returncode == 0:
        with _saved_lock:
            saved_networks[ssid] = password or ""
            save_saved(saved_networks)
        return True, out or "Connected"
    # Some errors are printed to stdout; combine both
    return False, (err or out or "Connect failed")

def disconnect_blocking():
    try:
        proc = subprocess.run(
            ["iwctl", "station", STATION, "disconnect"],
            capture_output=True, text=True, timeout=8
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
            capture_output=True, text=True, timeout=8
        )
    except Exception as e:
        return False, str(e)
    if proc.returncode == 0:
        with _saved_lock:
            saved_networks.pop(ssid, None)
            save_saved(saved_networks)
        return True, (proc.stdout or "Forgot").strip()
    return False, (proc.stderr or proc.stdout or "Forget failed").strip()

# ---------- GTK UI ----------
class IronWiFi(Gtk.Window):
    def __init__(self):
        super().__init__(title="IronWiFi")
        # popup-style window
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
        # Deprecation warning is OK; keep position logic for now
        try:
            width = screen.get_width()
        except Exception:
            width = 800
        self._popup_x = max(0, width - 470)
        self._popup_y = 35
        self.move(self._popup_x, self._popup_y)

        # minimal css (avoid invalid properties)
        css = b"""
        window { background: #1e1e1e; color: #f2f2f2; border-radius: 8px; }
        label, treeview { color: #ddd; font-size: 12px; }
        button { background: #2b2b2b; color: #fff; padding: 4px 8px; border-radius: 6px; }
        """
        prov = Gtk.CssProvider()
        prov.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            screen, prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self._action_bar = None
        self._connect_lock = threading.Lock()
        self._refresh_enabled = True   # <<-- NEW: pause auto-refresh while interacting
        self._scanning = False

        # layout
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        vbox.set_margin_top(8); vbox.set_margin_bottom(8); vbox.set_margin_start(8); vbox.set_margin_end(8)
        self.add(vbox)

        header = Gtk.Box(spacing=8)
        self.iface_label = Gtk.Label()
        self.iface_label.set_xalign(0)
        self.refresh_btn = Gtk.Button(label="⟳ Refresh")
        self.refresh_btn.connect("clicked", lambda *_: self.start_scan())
        header.pack_start(self.iface_label, True, True, 0)
        header.pack_end(self.refresh_btn, False, False, 0)
        vbox.pack_start(header, False, False, 0)

        # list
        self.store = Gtk.ListStore(str, str)  # display name, icon/flag
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

        # initial scan + periodic timer (use wrapper that returns True so the timer repeats)
        self.start_scan()
        GLib.timeout_add_seconds(DEF_REFRESH, self._timeout_wrapper)

    def _timeout_wrapper(self):
        # called by GLib periodically — only trigger scan when allowed
        if self._refresh_enabled:
            self.start_scan()
        return True

    def start_scan(self, *_):
        # do nothing if a scan is already running or refresh disabled
        if self._scanning:
            return
        self._scanning = True
        self.refresh_btn.set_sensitive(False)
        threading.Thread(target=self._scan_worker, daemon=True).start()

    def _scan_worker(self):
        nets = scan_networks_blocking()
        # nets is list of (ssid, sec)
        # compute list for UI (include connected info)
        current = get_connected_ssid() or ""
        result = []
        for s, sec in nets:
            result.append((s, sec, s.strip().lower() == (current or "").strip().lower()))
        GLib.idle_add(self._on_scan_done, result)

    def _on_scan_done(self, nets):
        self.store.clear()
        current_ssid = get_connected_ssid() or ""
        for s, sec, _ in nets:
            is_connected = s.strip() == (current_ssid or "").strip()
            is_known = s in saved_networks
            if is_connected and is_known:
                icon = "󰤨"
                display_name = f"● {s} (Known)"
            elif is_connected and not is_known:
                icon = "󰤪"
                display_name = f"● {s} (Temp)"
            elif not is_connected and is_known:
                icon = ""
                display_name = f"{s} (Saved)"
            else:
                icon = ""
                display_name = s
            self.store.append([display_name, icon])

        if current_ssid:
            self.iface_label.set_text(f"Interface: {STATION}   |   Connected: {current_ssid}")
        else:
            self.iface_label.set_text(f"Interface: {STATION}   |   Connected: (none)")

        self.refresh_btn.set_sensitive(True)
        self._scanning = False

        # if user was interacting, don't auto-destroy action bar here; we rely on _refresh_enabled outside
        if self._action_bar:
            try:
                self._action_bar.destroy()
            except Exception:
                pass
            self._action_bar = None
        return False

    def on_selection_changed(self, selection):
        model, it = selection.get_selected()
        if not it:
            return
        ssid = model[it][0].replace("●", "").split("(")[0].strip()
        if not ssid:
            return

        # Pause auto-refresh while user interacts
        self._refresh_enabled = False

        current_conn = get_connected_ssid()
        is_connected = current_conn == ssid
        is_known = ssid in saved_networks

        if self._action_bar:
            self._action_bar.destroy()
            self._action_bar = None
        parent = self.get_children()[0]

        if is_connected:
            self._action_bar = Gtk.Box(spacing=6)
            buttons = [
                ("Disconnect", self.disconnect_selected),
                ("Forget", self.forget_selected),
                ("Show Password", self.show_password),
            ]
        elif is_known:
            self._action_bar = Gtk.Box(spacing=6)
            buttons = [
                ("Connect", self.connect_selected),
                ("Forget", self.forget_selected),
                ("Show Password", self.show_password),
            ]
        else:
            # new network: prompt password inline
            self._action_bar = Gtk.Box(spacing=6)
            entry = Gtk.Entry()
            entry.set_placeholder_text(f"Password for {ssid}")
            entry.set_visibility(False)
            show_btn = Gtk.Button(label="👁")
            show_btn.connect("clicked", lambda *_: entry.set_visibility(not entry.get_visibility()))
            connect_btn = Gtk.Button(label="Connect")
            connect_btn.connect("clicked", lambda *_: self._on_connect_click(ssid, entry))
            entry.connect("activate", lambda *_: self._on_connect_click(ssid, entry))
            self._action_bar.pack_start(entry, True, True, 0)
            self._action_bar.pack_start(show_btn, False, False, 0)
            self._action_bar.pack_start(connect_btn, False, False, 0)
            parent.pack_end(self._action_bar, False, False, 4)
            self._action_bar.show_all()
            GLib.idle_add(entry.grab_focus)
            return

        for text, cb in buttons:
            b = Gtk.Button(label=text)
            b.connect("clicked", lambda w, cb=cb, s=ssid: cb(s))
            self._action_bar.pack_start(b, False, False, 2)
        parent.pack_end(self._action_bar, False, False, 4)
        self._action_bar.show_all()

    def connect_selected(self, ssid):
        # connect using saved password if present
        threading.Thread(
            target=lambda: self._connect_with_lock(ssid, saved_networks.get(ssid)),
            daemon=True
        ).start()

    def disconnect_selected(self, ssid):
        threading.Thread(target=self._disconnect_with_lock, daemon=True).start()

    def forget_selected(self, ssid):
        threading.Thread(
            target=lambda: (forget_blocking(ssid), GLib.idle_add(self.start_scan)),
            daemon=True
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
            # if user pressed connect with empty pwd, treat as cancel for open networks
            self._refresh_enabled = True
            return
        # start connect; action bar removed to avoid GUI race, refresh re-enabled after result
        if self._action_bar:
            try:
                self._action_bar.destroy()
            except Exception:
                pass
            self._action_bar = None
        threading.Thread(target=lambda: self._connect_with_lock(ssid, pwd), daemon=True).start()

    def _connect_with_lock(self, ssid, password=None):
        with self._connect_lock:
            # disable scanning while connecting
            self._refresh_enabled = False
            disconnect_blocking()
            time.sleep(0.3)
            success, msg = connect_network_blocking(ssid, password)
            log(f"Connect result: {success}, {msg}")
            # re-enable refresh and schedule a scan (update UI)
            self._refresh_enabled = True
            GLib.idle_add(self.start_scan)

    def _disconnect_with_lock(self):
        with self._connect_lock:
            self._refresh_enabled = False
            disconnect_blocking()
            self._refresh_enabled = True
            GLib.idle_add(self.start_scan)

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

# ---------- Entrypoint ----------
if __name__ == "__main__":
    print("⚙️ Starting IronWiFi — interface:", STATION, flush=True)
    win = IronWiFi()
    win.show_all()
    Gtk.main()
