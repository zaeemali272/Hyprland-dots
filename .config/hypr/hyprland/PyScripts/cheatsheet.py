#!/usr/bin/env python3
import gi
import re
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk

KEYBINDS_FILE = "/home/zaeem/.config/hypr/hyprland/keybinds.conf"

def parse_keybinds(path):
    """
    Parses keybinds.conf and extracts visible keybinds, sections, and headings.
    - Lines ending with '# [hidden]' are ignored.
    - Lines starting with '#!' are treated as section titles.
    - Lines starting with '##!' are treated as subsection headings.
    """
    keybinds = []
    current_section = "General"
    current_heading = None

    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            # Skip standard comments
            if line.startswith("#") and not line.startswith("#!") and not line.startswith("##!"):
                continue

            # Sub-heading
            if line.startswith("##!"):
                current_heading = line.lstrip("#!").strip()
                continue

            # Section
            if line.startswith("#!") and not line.startswith("##!"):
                current_section = line.lstrip("#!").strip()
                current_heading = None
                continue

            # Parse binds
            if line.startswith(("bind", "bindd", "bindl", "bindld", "bindm", "binde")):
                if "# [hidden]" in line:
                    continue

                comment = ""
                if "#" in line:
                    line_part, comment_part = line.split("#", 1)
                    comment = comment_part.strip()
                else:
                    line_part = line

                match = re.match(r"bind.*?=\s*(.*?),\s*(.*?),", line_part)
                if not match:
                    continue
                mods, key = match.groups()
                combo = f"{mods} {key}".strip()

                keybinds.append((current_section, current_heading, combo, comment))
    return keybinds

class CheatsheetWindow(Gtk.Window):
    def __init__(self, keybinds):
        super().__init__(title="Hyprland Keybinds Cheatsheet")
        self.set_default_size(800, 600)
        self.set_keep_above(True)
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        self.add(scrolled)

        grid = Gtk.Grid(column_spacing=40, row_spacing=10, margin=20)
        scrolled.add(grid)

        last_section = None
        last_heading = None
        col, row = 0, 0
        half = len(keybinds) // 2 + len(keybinds) % 2

        for i, (section, heading, combo, action) in enumerate(keybinds):
            if i == half:
                col = 2
                row = 0
                # Add spacing at top of the second column for visual balance
                grid.attach(Gtk.Label(label=""), col, row, 2, 1)
                row += 1


            # Section label
            if section != last_section:
                label = Gtk.Label()
                label.set_markup(f"<span size='large' weight='bold'>{section}</span>")
                label.set_xalign(0)
                grid.attach(label, col, row, 2, 1)
                row += 1
                last_section = section
                last_heading = None

            # Heading label
            if heading and heading != last_heading:
                sub_label = Gtk.Label()
                sub_label.set_markup(f"<b>{heading}</b>")
                sub_label.set_xalign(0)
                grid.attach(sub_label, col, row, 2, 1)
                row += 1
                last_heading = heading

            # Keybind row
            grid.attach(Gtk.Label(label=combo, xalign=0), col, row, 1, 1)
            grid.attach(Gtk.Label(label=action, xalign=0), col + 1, row, 1, 1)
            row += 1

        self.connect("key-press-event", self.on_key_press)

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()

if __name__ == "__main__":
    keybinds = parse_keybinds(KEYBINDS_FILE)
    if not keybinds:
        print("No keybinds found.")
    else:
        win = CheatsheetWindow(keybinds)
        win.show_all()
        Gtk.main()
