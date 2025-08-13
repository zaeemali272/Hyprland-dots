#!/usr/bin/env python3
import os
from PIL import Image

WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")
THUMB_DIR = os.path.expanduser("~/.cache/wallpaper_thumbs")
THUMB_SIZE = 300

os.makedirs(THUMB_DIR, exist_ok=True)

def generate_thumbnail(img_path, thumb_path):
    try:
        with Image.open(img_path) as im:
            im.thumbnail((THUMB_SIZE, THUMB_SIZE), Image.LANCZOS)
            im.save(thumb_path, format="PNG")
            print(f"✓ {thumb_path}")
    except Exception as e:
        print(f"✗ {img_path} → {e}")

def main():
    for file in sorted(os.listdir(WALLPAPER_DIR)):
        if not file.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
            continue

        src_path = os.path.join(WALLPAPER_DIR, file)
        thumb_name = os.path.splitext(file)[0] + ".png"
        thumb_path = os.path.join(THUMB_DIR, thumb_name)

        if not os.path.exists(thumb_path):
            generate_thumbnail(src_path, thumb_path)

if __name__ == "__main__":
    main()

