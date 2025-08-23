#!/usr/bin/env python3
import glob
import os, gi, subprocess, re
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GdkPixbuf, GLib, Gdk

WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")
THUMB_DIR = os.path.expanduser("~/.cache/wallpaper_thumbs")
WALLUST_CONFIG_DIR = os.path.expanduser("~/.config/wallust")  # contains ironbar.template.toml
HYPLOCK_CONF = os.path.expanduser("~/.config/hypr/hyprlock.conf")

def update_hyprlock_conf(new_path: str):
    """Replace or insert wallpaper path in hyprlock.conf"""
    try:
        with open(HYPLOCK_CONF, "r") as f:
            lines = f.readlines()

        updated = []
        replaced = False
        inside_background = False

        for line in lines:
            stripped = line.strip()

            # Detect background block
            if stripped.startswith("background"):
                inside_background = True
                updated.append(line)
                continue
            if inside_background and stripped.startswith("}"):
                if not replaced:
                    updated.append(f"    path = {new_path}\n")
                    replaced = True
                inside_background = False
                updated.append(line)
                continue

            # Replace path if inside background block
            if inside_background and stripped.startswith("path"):
                updated.append(f"    path = {new_path}\n")
                replaced = True
            else:
                updated.append(line)

        # If no background block found, append at end
        if not replaced:
            updated.append("\nbackground {\n")
            updated.append(f"    path = {new_path}\n")
            updated.append("}\n")

        with open(HYPLOCK_CONF, "w") as f:
            f.writelines(updated)

        print(f"✔ hyprlock.conf updated with wallpaper: {new_path}")
    except Exception as e:
        print(f"✗ Failed to update hyprlock.conf: {e}")

class WallpaperSelector(Gtk.Window):
    def __init__(self):
        super().__init__(title="Wallpaper Selector")
        self.set_decorated(False)
        self.set_app_paintable(True)
        self.connect("key-press-event", self.on_key_press)
        self.connect("button-press-event", self.on_outer_click)

        # Run thumbnail generator script
        subprocess.run([
            "python3",
            os.path.expanduser("~/.config/hypr/hyprland/PyScripts/generate_thumbnails.py")
        ])

        # Minimal scrollbar styling
        css = b"""
        scrollbar slider {
            min-width: 3px;
            min-height: 3px;
            background-color: #000;
        }
        scrollbar {
            background-color: transparent;
        }
        """
        style_provider = Gtk.CssProvider()
        style_provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.overlay = Gtk.Overlay()
        self.add(self.overlay)

        self.scroll = Gtk.ScrolledWindow()
        self.scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)

        self.grid = Gtk.FlowBox()
        self.grid.set_max_children_per_line(5)
        self.grid.set_selection_mode(Gtk.SelectionMode.NONE)
        self.scroll.add(self.grid)

        self.overlay.add(self.scroll)

        self.loading_label = Gtk.Label()
        self.loading_label.set_markup('<span font="20" foreground="#000">Getting wallpapers...</span>')
        self.loading_label.set_halign(Gtk.Align.CENTER)
        self.loading_label.set_valign(Gtk.Align.CENTER)
        self.overlay.add_overlay(self.loading_label)

        self.show_all()
        GLib.timeout_add(100, self.load_thumbnails)

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()

    def on_outer_click(self, widget, event):
        x, y = event.x_root, event.y_root
        alloc = self.grid.get_allocation()
        gx, gy = self.grid.translate_coordinates(self, 0, 0)
        if not (gx <= x <= gx + alloc.width and gy <= y <= gy + alloc.height):
            Gtk.main_quit()

    def load_thumbnails(self):
        for filename in sorted(os.listdir(THUMB_DIR)):
            if not filename.lower().endswith(".png"):
                continue

            thumb_path = os.path.join(THUMB_DIR, filename)
            base_name = os.path.splitext(filename)[0]

            match = glob.glob(os.path.join(WALLPAPER_DIR, base_name + ".*"))
            if not match:
                print(f"✗ No original image found for: {base_name}")
                continue

            original_path = match[0]

            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file(thumb_path)
                image = Gtk.Image.new_from_pixbuf(pixbuf)

                overlay = Gtk.Overlay()
                overlay.add(image)

                button = Gtk.Button(label="Set as wallpaper")
                button.set_halign(Gtk.Align.CENTER)
                button.set_valign(Gtk.Align.END)
                button.set_opacity(0.0)
                overlay.add_overlay(button)

                def on_hover(_, event, btn=button): btn.set_opacity(1.0)
                def on_leave(_, event, btn=button): btn.set_opacity(0.0)

                event_box = Gtk.EventBox()
                event_box.set_tooltip_text(base_name)
                event_box.add(overlay)
                event_box.connect("enter-notify-event", on_hover)
                event_box.connect("leave-notify-event", on_leave)
                event_box.connect("button-press-event", self.set_wallpaper, original_path)
                self.grid.add(event_box)

            except Exception as e:
                print(f"✗ Error loading thumbnail {filename}: {e}")
                continue

        self.show_all()
        GLib.idle_add(self.loading_label.hide)
        return False

    def set_wallpaper(self, _, event, path):
        # Quit GTK main loop immediately
        Gtk.main_quit()

        # Set wallpaper using swww
        subprocess.Popen([
            "swww", "img", path,
            "--transition-type", "any",
            "--transition-fps", "60",
            "--transition-duration", "1"
        ])

        # Save current wallpaper path
        wallpaper_file = os.path.expanduser("~/.config/current_wallpaper.txt")
        with open(wallpaper_file, "w") as f:
            f.write(path)

        # Update hyprlock.conf
        update_hyprlock_conf(path.strip())

        # Generate Wallust palette
        wallust_cmd = [
            "wallust", "run", path,
            "--templates-dir", WALLUST_CONFIG_DIR,
            "--quiet"
        ]
        try:
            subprocess.run(wallust_cmd, check=True)
        except Exception as e:
            print(f"✗ Wallust failed: {e}")

        # Full Ironbar restart
        try:
            subprocess.run(["pkill", "ironbar"])  # stop current
            subprocess.Popen(
                ["ironbar"],  # start new detached
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                preexec_fn=os.setpgrp
            )
        except Exception as e:
            print(f"✗ Ironbar failed to restart: {e}")


def main():
    app = WallpaperSelector()
    app.connect("destroy", Gtk.main_quit)
    Gtk.main()


if __name__ == "__main__":
    main()

