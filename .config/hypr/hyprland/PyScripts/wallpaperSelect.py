#!/usr/bin/env python3
import glob
import os
import gi
import subprocess
import time

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GdkPixbuf, GLib, Gdk

WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")
THUMB_DIR = os.path.expanduser("~/.cache/wallpaper_thumbs")
WALLUST_CONFIG_DIR = os.path.expanduser("~/.config/wallust")
HYPLOCK_CONF = os.path.expanduser("~/.config/hypr/hyprlock.conf")


def update_hyprlock_conf(new_path: str):
    try:
        with open(HYPLOCK_CONF, "r", encoding="utf-8") as f:
            lines = f.readlines()
        updated, replaced, inside_background = [], False, False
        for line in lines:
            stripped = line.strip()
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
            if inside_background and stripped.startswith("path"):
                updated.append(f"    path = {new_path}\n")
                replaced = True
            else:
                updated.append(line)
        if not replaced:
            updated.append("\nbackground {\n")
            updated.append(f"    path = {new_path}\n")
            updated.append("}\n")
        with open(HYPLOCK_CONF, "w", encoding="utf-8") as f:
            f.writelines(updated)
        print(f"✔ hyprlock.conf updated with wallpaper: {new_path}")
    except Exception as e:
        print(f"✗ Failed to update hyprlock.conf: {e}")


class WallpaperSelector(Gtk.Window):
    def __init__(self):
        super().__init__(title="Wallpaper Selector")

        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        try:
            self.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)
        except Exception:
            pass

        self.set_app_paintable(True)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_default_size(1200, 800)
        self.set_keep_above(True)
        self.set_accept_focus(True)

        self.connect("focus-out-event", lambda *_: Gtk.main_quit())
        self.connect("button-press-event", self.on_outer_click)
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key_press)

        # Ensure cache directory exists
        os.makedirs(THUMB_DIR, exist_ok=True)

        subprocess.run(
            [
                "python3",
                os.path.expanduser(
                    "~/.config/hypr/hyprland/PyScripts/generate_thumbnails.py"
                ),
            ]
        )

        css = b"""
        scrollbar slider {
            min-width: 3px;
            min-height: 3px;
            background-color: #000;
        }
        scrollbar {
            background-color: transparent;
        }

        *:focus {
            border: 0.5px solid rgba(0, 0, 0, 0.8);
            background-color: rgba(0, 0, 0, 0.7);
            border-radius: 2px;
            transition: 100ms ease-in-out;
        }

        *:hover {
            border: 2px solid rgba(0, 0, 0, 0.6);
            background-color: rgba(0, 0, 0, 0.15);
            border-radius: 8px;
        }
        """

        style_provider = Gtk.CssProvider()
        style_provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        self.overlay = Gtk.Overlay()
        self.add(self.overlay)

        self.scroll = Gtk.ScrolledWindow()
        self.scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)

        self.grid = Gtk.FlowBox()
        self.grid.set_max_children_per_line(5)
        self.grid.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.grid.set_activate_on_single_click(False)
        self.scroll.add(self.grid)
        self.overlay.add(self.scroll)

        self.loading_label = Gtk.Label()
        self.loading_label.set_markup(
            '<span font="20" foreground="#000">Getting wallpapers...</span>'
        )
        self.loading_label.set_halign(Gtk.Align.CENTER)
        self.loading_label.set_valign(Gtk.Align.CENTER)
        self.overlay.add_overlay(self.loading_label)

        self.show_all()
        GLib.timeout_add(100, self.load_thumbnails)

    # Lightweight compatibility focus helpers (safe no-ops if not used)
    def apply_focus_style(self, widget):
        try:
            widget.grab_focus()
        except Exception:
            pass

    def remove_focus_style(self, widget):
        # styling is handled by CSS :focus; nothing else required here
        return

    # ============================ #
    # Keyboard Handling            #
    # ============================ #
    def on_key_press(self, widget, event):
        key = Gdk.keyval_name(event.keyval)

        if key in ("Escape", "q"):
            Gtk.main_quit()
            return True

        wrappers = self.grid.get_children()
        if not wrappers:
            return False

        focus = self.get_focus()
        node = focus
        while node is not None and not isinstance(node, Gtk.EventBox):
            node = node.get_parent()

        idx = None
        for i, wrap in enumerate(wrappers):
            if wrap is node or wrap is focus:
                idx = i
                break

        # If nothing is focused, set a sensible starting index so arrow keys move on first press
        if idx is None:
            if key in ("Right", "Down", "Tab"):
                idx = 0
            elif key in ("Left", "Up"):
                idx = max(len(wrappers) - 1, 0)
            elif key in ("Return", "KP_Enter", "space"):
                # activate first immediately
                wrap0 = wrappers[0]
                base_name = wrap0.get_tooltip_text()
                path = self.get_original_path(base_name)
                if path:
                    self.set_wallpaper(wrap0, None, path)
                return True
            else:
                idx = 0

        new_idx = idx
        if key == "Right":
            new_idx = min(idx + 1, len(wrappers) - 1)
        elif key == "Left":
            new_idx = max(idx - 1, 0)
        elif key == "Down":
            new_idx = min(idx + 3, len(wrappers) - 1)
        elif key == "Up":
            new_idx = max(idx - 3, 0)
        elif key == "Tab":
            new_idx = (idx + 1) % len(wrappers)
        elif key in ("Return", "KP_Enter", "space"):
            wrap = wrappers[idx]
            child = wrap.get_child() if hasattr(wrap, "get_child") else wrap
            base_name = child.get_tooltip_text()
            path = self.get_original_path(base_name)
            if path:
                self.set_wallpaper(child, None, path)
            return True
        else:
            return False

        # Remove focus style from all (no-op if not implemented)
        for w in wrappers:
            try:
                c = w.get_child() if hasattr(w, "get_child") else w
                self.remove_focus_style(c)
            except Exception:
                pass

        wrap_new = wrappers[new_idx]
        # focus the wrapper (EventBox) itself
        try:
            wrap_new.grab_focus()
        except Exception:
            # fallback: try child
            try:
                child_new = (
                    wrap_new.get_child() if hasattr(wrap_new, "get_child") else wrap_new
                )
                child_new.grab_focus()
            except Exception:
                pass

        try:
            self.apply_focus_style(wrap_new)
        except Exception:
            pass

        return True

    def on_outer_click(self, widget, event):
        x, y = int(event.x_root), int(event.y_root)
        win = self.get_window()
        if not win:
            return
        rect = win.get_frame_extents()
        if not (
            rect.x <= x <= rect.x + rect.width and rect.y <= y <= rect.y + rect.height
        ):
            Gtk.main_quit()

    # ============================ #
    # Core Wallpaper Handling      #
    # ============================ #
    def load_thumbnails(self):
        if not os.path.isdir(THUMB_DIR) or not os.listdir(THUMB_DIR):
            subprocess.run(
                [
                    "python3",
                    os.path.expanduser(
                        "~/.config/hypr/hyprland/PyScripts/generate_thumbnails.py"
                    ),
                ]
            )

        for filename in sorted(os.listdir(THUMB_DIR)):
            if not filename.lower().endswith(".png"):
                continue

            thumb_path = os.path.join(THUMB_DIR, filename)
            base_name = os.path.splitext(filename)[0]
            match = glob.glob(os.path.join(WALLPAPER_DIR, base_name + ".*"))
            if not match:
                continue
            original_path = match[0]

            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file(thumb_path)
                image = Gtk.Image.new_from_pixbuf(pixbuf)
                overlay = Gtk.Overlay()
                overlay.add(image)

                event_box = Gtk.EventBox()
                event_box.set_tooltip_text(base_name)
                event_box.set_can_focus(True)
                event_box.set_visible_window(True)
                event_box.add(overlay)

                event_box.get_style_context().add_class("eventbox")

                event_box.connect(
                    "button-press-event", self.set_wallpaper, original_path
                )
                self.grid.add(event_box)
            except Exception as e:
                print(f"✗ Error loading thumbnail {filename}: {e}")
                continue

        self.show_all()
        GLib.idle_add(self.loading_label.hide)

        children = self.grid.get_children()
        if children:
            # focus the wrapper (EventBox), not the inner overlay, to keep navigation consistent
            GLib.idle_add(lambda: children[0].grab_focus())
        return False

    def get_original_path(self, base_name):
        match = glob.glob(os.path.join(WALLPAPER_DIR, base_name + ".*"))
        return match[0] if match else None

    def set_wallpaper(self, _, __, path):
        Gtk.main_quit()
        subprocess.Popen(
            [
                "swww",
                "img",
                path,
                "--transition-type",
                "fade",
                "--transition-fps",
                "60",
                "--transition-duration",
                "1",
            ]
        )
        with open(
            os.path.expanduser("~/.config/current_wallpaper.txt"), "w", encoding="utf-8"
        ) as f:
            f.write(path)
        update_hyprlock_conf(path.strip())

        try:
            subprocess.run(
                [
                    "wallust",
                    "run",
                    path,
                    "--templates-dir",
                    WALLUST_CONFIG_DIR,
                    "--quiet",
                ],
                check=True,
            )
        except Exception as e:
            print(f"✗ Wallust failed: {e}")

        time.sleep(0.5)
        for service in ("ironbar", "mako"):
            try:
                subprocess.run(["pkill", service])
                subprocess.Popen(
                    [service],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    preexec_fn=os.setpgrp,
                )
                print(f"✔ {service.capitalize()} restarted with new colors")
            except Exception as e:
                print(f"✗ {service} failed to restart: {e}")

        seq = os.path.expanduser("~/.cache/wallust/sequences")
        if os.path.isfile(seq):
            print(
                "Palette updated. Run: cat ~/.cache/wallust/sequences  # in existing terminals"
            )


def main():
    app = WallpaperSelector()
    Gtk.main()


if __name__ == "__main__":
    main()
