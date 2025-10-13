#!/usr/bin/env python3
# ironwifi_final.py — Bulletproof IWD Wi-Fi Manager (GTK3 + Debug)
# Author: Zaeem + ChatGPT (2025)

import gi, subprocess, json, os, re
from pathlib import Path

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib

CONFIG_FILE = Path.home() / ".config/hypr/hyprland/data/wifi_saved.json"
CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
if not CONFIG_FILE.exists():
    CONFIG_FILE.write_text("{}")


def log(msg):
    print(f"[DEBUG] {msg}", flush=True)


# ---------------- Device Detection ----------------
def get_station():
    """
    Extract WiFi interface name cleanly from `iw dev` or `iwctl device list`,
    stripping ANSI color codes, headers, and junk.
    """
    print("\n========== [DEBUG] get_station() ==========")
    try:
        # 1️⃣ Try `iw dev` (most reliable)
        iw_output = subprocess.check_output("iw dev", shell=True, text=True)
        match = re.search(r"Interface\s+(\w+)", iw_output)
        if match:
            iface = match.group(1)
            print(f"✅ Found via iw dev: {iface}")
            return iface

        # 2️⃣ Fallback to iwctl device list
        out = subprocess.check_output("iwctl device list", shell=True, text=True)
        out = re.sub(r"\x1B\[[0-9;]*[mK]", "", out)  # strip ANSI codes

        lines = [l.strip() for l in out.splitlines() if l.strip()]
        print("iwctl raw cleaned lines:")
        for l in lines:
            print("   ", l)

        iface = None
        for line in lines:
            if re.match(r"^[a-zA-Z0-9_-]+\s", line):
                parts = line.split()
                if len(parts) >= 1 and parts[0].lower() != "devices":
                    iface = parts[0]
                    break

        if iface:
            print(f"✅ Found via iwctl: {iface}")
            return iface

    except Exception as e:
        print(f"❌ get_station() exception: {e}")

    print("⚠️  Fallback to wlan0\n")
    return "wlan0"


STATION = get_station()


# ---------------- Config Handling ----------------
def load_saved():
    try:
        with CONFIG_FILE.open() as f:
            return json.load(f)
    except Exception:
        return {}


def save_saved(data):
    with CONFIG_FILE.open("w") as f:
        json.dump(data, f, indent=2)


saved_networks = load_saved()


# ---------------- IWD Actions ----------------
def get_connected_ssid():
    log("Checking current connection...")
    try:
        out = subprocess.check_output(["iwctl", "station", STATION, "show"], text=True)
        for line in out.splitlines():
            if "Connected network" in line:
                ssid = line.split(":")[1].strip()
                log(f"Connected SSID: {ssid}")
                return ssid
    except subprocess.CalledProcessError:
        pass
    return None


def scan_networks():
    log(f"Scanning on {STATION}...")
    try:
        subprocess.run(
            ["iwctl", "station", STATION, "scan"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        out = subprocess.check_output(
            ["iwctl", "station", STATION, "get-networks"], text=True
        )
    except subprocess.CalledProcessError:
        return []

    out = re.sub(r"\x1B\[[0-9;]*[mK]", "", out)
    nets = []
    for line in out.splitlines():
        if not line.strip() or line.startswith(("Available", "Network name", "----")):
            continue
        parts = line.split()
        if len(parts) >= 3:
            ssid = " ".join(parts[:-2]).replace("*", "").strip()
            signal = 0
            try:
                signal = int(parts[-2].strip("*"))
            except ValueError:
                pass
            sec = parts[-1]
            nets.append((ssid, signal, sec, False))

    connected = get_connected_ssid()
    nets = [(s, sig, sec, s == connected) for s, sig, sec, _ in nets]
    return sorted(nets, key=lambda n: n[1], reverse=True)


def connect_network(ssid, password=None):
    log(f"Connecting to {ssid} (password={'yes' if password else 'no'})")
    cmd = ["iwctl", "station", STATION, "connect", ssid]
    try:
        if password:
            proc = subprocess.run(
                cmd, input=password + "\n", text=True, capture_output=True
            )
        else:
            proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode == 0:
            subprocess.run(["notify-send", "IronWiFi", f"Connected to {ssid}"])
            saved_networks[ssid] = password or ""
            save_saved(saved_networks)
        else:
            msg = proc.stderr.strip() or proc.stdout.strip() or "Connection failed"
            subprocess.run(["notify-send", "IronWiFi Error", msg])
    except Exception as e:
        subprocess.run(["notify-send", "IronWiFi Error", str(e)])


def disconnect_device():
    log(f"Disconnecting from {STATION}...")
    connected = get_connected_ssid()
    if not connected:
        subprocess.run(["notify-send", "IronWiFi", "No active connection"])
        return
    subprocess.run(["iwctl", "station", STATION, "disconnect"])
    subprocess.run(["notify-send", "IronWiFi", f"Disconnected from {connected}"])


def signal_bars(signal):
    return (
        "▂▄▆█"
        if signal >= 80
        else (
            "▂▄▆▁"
            if signal >= 60
            else "▂▄▁▁" if signal >= 40 else "▂▁▁▁" if signal >= 20 else "▁▁▁▁"
        )
    )


# ---------------- GTK UI ----------------
class IronWiFi(Gtk.Window):
    REFRESH = 5

    def __init__(self):
        super().__init__(title="IronWiFi")
        self.set_default_size(520, 420)
        self.set_border_width(8)
        self.set_resizable(False)
        self.set_position(Gtk.WindowPosition.CENTER)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.add(vbox)

        self.status = Gtk.Label(label="Status: Loading...")
        vbox.pack_start(self.status, False, False, 0)

        self.store = Gtk.ListStore(str, str, str, str)
        self.tree = Gtk.TreeView(model=self.store)
        for i, title in enumerate(["SSID", "Security", "Signal", "Connected"]):
            col = Gtk.TreeViewColumn(title, Gtk.CellRendererText(), text=i)
            self.tree.append_column(col)

        scroll = Gtk.ScrolledWindow()
        scroll.add(self.tree)
        vbox.pack_start(scroll, True, True, 0)

        hbox = Gtk.Box(spacing=6)
        refresh = Gtk.Button(label="Refresh")
        refresh.connect("clicked", lambda *_: self.refresh())
        disc = Gtk.Button(label="Disconnect")
        disc.connect("clicked", lambda *_: disconnect_device())
        hbox.pack_start(refresh, True, True, 0)
        hbox.pack_start(disc, True, True, 0)
        vbox.pack_start(hbox, False, False, 0)

        self.show_all()
        self.refresh()
        GLib.timeout_add_seconds(self.REFRESH, self.auto_refresh)

    def refresh(self):
        self.store.clear()
        connected = get_connected_ssid()
        self.status.set_text(
            f"Connected to {connected}" if connected else "Not connected"
        )
        for ssid, sig, sec, conn in scan_networks():
            self.store.append(
                [ssid, sec, signal_bars(sig), "Connected" if conn else ""]
            )

    def auto_refresh(self):
        self.refresh()
        return True


# ---------------- Entry ----------------
if __name__ == "__main__":
    print("⚙️ Starting IronWiFi GTK")
    print("====================================")
    print(f"STATION DETECTED = {STATION}")
    print("====================================")
    app = IronWiFi()
    app.connect("destroy", Gtk.main_quit)
    Gtk.main()
