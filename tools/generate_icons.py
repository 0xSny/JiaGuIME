#!/usr/bin/env python3
"""
Generate high-resolution modern app icons for JiaGuIME (甲骨输入法)
and populate HostApp/Assets.xcassets/AppIcon.appiconset + docs/icon.png.
"""

import json
import os
from PIL import Image, ImageDraw, ImageFont


def draw_icon(size: int = 1024) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # Smooth vertical-diagonal gradient background: deep indigo -> vibrant royal blue -> cyan accent
    for y in range(size):
        t = y / (size - 1)
        r = int(18 * (1 - t) + 12 * t)
        g = int(42 * (1 - t) + 118 * t)
        b = int(112 * (1 - t) + 235 * t)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # Subtle radial glow in top-right
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    for radius in range(int(size * 0.55), 0, -8):
        alpha = int(18 * (1 - radius / (size * 0.55)))
        cx, cy = int(size * 0.72), int(size * 0.24)
        gdraw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=(120, 220, 255, alpha))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # Crisp white rounded keycap container in center
    margin = int(size * 0.17)
    cap_rect = [margin, margin, size - margin, size - margin]
    cap_radius = int(size * 0.16)

    # Soft shadow under keycap
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle(
        [margin, margin + int(size * 0.025), size - margin, size - margin + int(size * 0.025)],
        radius=cap_radius,
        fill=(5, 16, 48, 95),
    )
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img)

    # Bottom 3D lip
    draw.rounded_rectangle(
        [margin, margin + int(size * 0.016), size - margin, size - margin + int(size * 0.016)],
        radius=cap_radius,
        fill=(196, 212, 236, 255),
    )
    # Main crisp white keycap
    draw.rounded_rectangle(cap_rect, radius=cap_radius, fill=(252, 253, 255, 255))

    # Stylized geometric "甲" / key-grid glyph drawn with crisp vector strokes
    cx = size // 2
    cy = size // 2 - int(size * 0.01)
    stroke = int(size * 0.052)
    box_w = int(size * 0.34)
    box_h = int(size * 0.26)
    x0, x1 = cx - box_w // 2, cx + box_w // 2
    y0, y1 = cy - box_h // 2 - int(size * 0.03), cy + box_h // 2 - int(size * 0.03)
    mid_y = (y0 + y1) // 2
    stem_bottom = cy + int(size * 0.21)

    ink = (20, 68, 168, 255)
    accent = (14, 148, 226, 255)

    # Outer frame of '甲'
    draw.rounded_rectangle([x0, y0, x1, y1], radius=int(size * 0.045), outline=ink, width=stroke)
    # Horizontal cross bar
    draw.line([(x0 + stroke // 2, mid_y), (x1 - stroke // 2, mid_y)], fill=ink, width=stroke)
    # Central vertical stem extending downward
    draw.line([(cx, y0 + stroke // 2), (cx, stem_bottom)], fill=accent, width=stroke)
    # Rounded cap at bottom of stem
    r_cap = stroke // 2
    draw.ellipse([cx - r_cap, stem_bottom - r_cap, cx + r_cap, stem_bottom + r_cap], fill=accent)

    # Subtle Shuangpin dual-dot indicator in bottom-right of keycap
    dot_r = int(size * 0.022)
    dx = x1 - int(size * 0.02)
    dy = stem_bottom - dot_r
    draw.ellipse([dx - dot_r, dy - dot_r, dx + dot_r, dy + dot_r], fill=(56, 189, 248, 255))

    return img.convert("RGB")


def main():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    appicon_dir = os.path.join(base_dir, "HostApp", "Assets.xcassets", "AppIcon.appiconset")
    assets_dir = os.path.join(base_dir, "HostApp", "Assets.xcassets")
    docs_dir = os.path.join(base_dir, "docs")

    os.makedirs(appicon_dir, exist_ok=True)
    os.makedirs(docs_dir, exist_ok=True)

    with open(os.path.join(assets_dir, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

    master = draw_icon(1024)
    master.save(os.path.join(docs_dir, "icon.png"), format="PNG", optimize=True)

    specs = [
        ("iphone", "20x20", 2),
        ("iphone", "20x20", 3),
        ("iphone", "29x29", 2),
        ("iphone", "29x29", 3),
        ("iphone", "40x40", 2),
        ("iphone", "40x40", 3),
        ("iphone", "60x60", 2),
        ("iphone", "60x60", 3),
        ("ipad", "20x20", 1),
        ("ipad", "20x20", 2),
        ("ipad", "29x29", 1),
        ("ipad", "29x29", 2),
        ("ipad", "40x40", 1),
        ("ipad", "40x40", 2),
        ("ipad", "76x76", 1),
        ("ipad", "76x76", 2),
        ("ipad", "83.5x83.5", 2),
        ("ios-marketing", "1024x1024", 1),
    ]

    images_json = []
    for idiom, pt_str, scale in specs:
        pt = float(pt_str.split("x")[0])
        px = int(round(pt * scale))
        filename = f"icon_{idiom}_{pt_str}@{scale}x.png"
        resized = master.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(os.path.join(appicon_dir, filename), format="PNG", optimize=True)
        images_json.append({
            "filename": filename,
            "idiom": idiom,
            "scale": f"{scale}x",
            "size": pt_str,
        })

    contents = {
        "images": images_json,
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(appicon_dir, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump(contents, f, indent=2)

    print(f"[icons] Generated {len(images_json)} AppIcon assets + docs/icon.png")


if __name__ == "__main__":
    main()
