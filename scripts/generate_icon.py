#!/usr/bin/env python3
"""Generate LabelYourWindow app icon - 1024x1024 master, then resize to all required sizes."""

import math
import os
import subprocess
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
ICON_DIR = os.path.join(os.path.dirname(__file__), "..", "LabelYourWindow", "Resources", "Assets.xcassets", "AppIcon.appiconset")

def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(len(c1)))

def draw_rounded_rect(draw, rect, radius, fill, outline=None, outline_width=0):
    x0, y0, x1, y1 = rect
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill, outline=outline, width=outline_width)

def make_icon(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    s = size
    # --- Background: dark gradient via layered rects ---
    bg = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    c_top = (28, 28, 52)
    c_bot = (10, 14, 38)
    for y in range(s):
        t = y / s
        color = lerp_color(c_top, c_bot, t)
        bg_draw.line([(0, y), (s, y)], fill=color + (255,))
    corner = int(s * 0.22)
    mask = Image.new("L", (s, s), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, s - 1, s - 1], radius=corner, fill=255)
    img.paste(bg, (0, 0), mask)

    # --- Subtle inner glow at top ---
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for r in range(80, 0, -1):
        alpha = int(18 * (1 - r / 80))
        glow_draw.ellipse([s // 2 - r * 4, -r * 2, s // 2 + r * 4, r * 2], fill=(120, 120, 220, alpha))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # --- Window frame (representing target app window) ---
    wm = int(s * 0.13)
    wx0, wy0, wx1, wy1 = wm, int(s * 0.20), s - wm, int(s * 0.72)
    wr = int(s * 0.055)
    # Window shadow
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(shadow)
    sh_draw.rounded_rectangle([wx0 + 8, wy0 + 14, wx1 + 8, wy1 + 14], radius=wr, fill=(0, 0, 0, 80))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=18))
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img)

    # Title bar
    draw_rounded_rect(draw, [wx0, wy0, wx1, wy0 + int(s * 0.08)], wr, fill=(55, 55, 75, 230))
    # Body
    draw.rectangle([wx0, wy0 + int(s * 0.06), wx1, wy1], fill=(40, 40, 60, 210))
    draw_rounded_rect(draw, [wx0, wy0, wx1, wy1], wr, fill=None, outline=(90, 90, 120, 80), outline_width=2)

    # Traffic lights
    dot_y = wy0 + int(s * 0.04)
    dot_r = int(s * 0.018)
    for i, color in enumerate([(255, 95, 87), (255, 189, 46), (40, 200, 64)]):
        cx = wx0 + int(s * 0.045) + i * int(s * 0.038)
        draw.ellipse([cx - dot_r, dot_y - dot_r, cx + dot_r, dot_y + dot_r], fill=color + (220,))

    # Window content lines (simulated text/content)
    line_x0 = wx0 + int(s * 0.06)
    line_x1 = wx1 - int(s * 0.06)
    content_y = wy0 + int(s * 0.13)
    for i in range(5):
        lw = int((0.6 + (i % 3) * 0.15) * (line_x1 - line_x0))
        draw.rounded_rectangle(
            [line_x0, content_y + i * int(s * 0.07), line_x0 + lw, content_y + i * int(s * 0.07) + int(s * 0.025)],
            radius=4, fill=(80, 80, 110, 120)
        )

    # --- Floating label overlay (the app's UI element) ---
    lw_half = int(s * 0.20)
    lh_half = int(s * 0.050)
    lx0 = wx1 - int(s * 0.05) - lw_half * 2
    ly0 = wy0 + int(s * 0.025)
    lx1 = lx0 + lw_half * 2
    ly1 = ly0 + lh_half * 2

    # Label shadow
    lshadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ls_draw = ImageDraw.Draw(lshadow)
    ls_draw.rounded_rectangle([lx0 + 4, ly0 + 6, lx1 + 4, ly1 + 6], radius=lh_half, fill=(0, 0, 0, 100))
    lshadow = lshadow.filter(ImageFilter.GaussianBlur(radius=12))
    img = Image.alpha_composite(img, lshadow)
    draw = ImageDraw.Draw(img)

    # Label glass background (translucent, like the app's overlay)
    draw.rounded_rectangle([lx0, ly0, lx1, ly1], radius=lh_half, fill=(200, 210, 255, 55))
    draw.rounded_rectangle([lx0, ly0, lx1, ly1], radius=lh_half, fill=None, outline=(255, 255, 255, 80), width=2)

    # Label text dots (simulating label text)
    tx = lx0 + int(s * 0.04)
    ty_mid = (ly0 + ly1) // 2
    dot_h = int(s * 0.020)
    dot_gap = int(s * 0.014)
    for i, width_frac in enumerate([0.06, 0.10, 0.07]):
        dw = int(s * width_frac)
        draw.rounded_rectangle(
            [tx, ty_mid - dot_h // 2, tx + dw, ty_mid + dot_h // 2],
            radius=dot_h // 2, fill=(255, 255, 255, 210)
        )
        tx += dw + dot_gap

    # --- Tag icon (bottom right, branded element) ---
    ti = int(s * 0.58)
    ts = int(s * 0.30)
    tag_x0, tag_y0 = ti, ti
    tag_x1, tag_y1 = ti + ts, ti + ts
    tag_r = int(ts * 0.22)

    # Tag shape shadow
    tshadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    tsh_draw = ImageDraw.Draw(tshadow)
    tsh_draw.rounded_rectangle([tag_x0 + 6, tag_y0 + 10, tag_x1 + 6, tag_y1 + 10], radius=tag_r, fill=(0, 0, 0, 90))
    tshadow = tshadow.filter(ImageFilter.GaussianBlur(radius=16))
    img = Image.alpha_composite(img, tshadow)
    draw = ImageDraw.Draw(img)

    # Tag background gradient (blue-violet)
    tag_img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    tag_draw = ImageDraw.Draw(tag_img)
    c_tl = (90, 110, 240)
    c_br = (160, 80, 220)
    for y in range(tag_y0, tag_y1):
        t = (y - tag_y0) / ts
        color = lerp_color(c_tl, c_br, t)
        tag_draw.line([(tag_x0, y), (tag_x1, y)], fill=color + (255,))
    tag_mask = Image.new("L", (s, s), 0)
    tm_draw = ImageDraw.Draw(tag_mask)
    tm_draw.rounded_rectangle([tag_x0, tag_y0, tag_x1, tag_y1], radius=tag_r, fill=255)
    img.paste(tag_img, (0, 0), tag_mask)
    draw = ImageDraw.Draw(img)

    # Tag border
    draw.rounded_rectangle([tag_x0, tag_y0, tag_x1, tag_y1], radius=tag_r, fill=None,
                            outline=(255, 255, 255, 40), width=2)

    # Tag dot (top-left, like a physical tag hole)
    td = int(ts * 0.12)
    tcx = tag_x0 + int(ts * 0.25)
    tcy = tag_y0 + int(ts * 0.28)
    draw.ellipse([tcx - td // 2, tcy - td // 2, tcx + td // 2, tcy + td // 2], fill=(255, 255, 255, 80))
    draw.ellipse([tcx - td // 4, tcy - td // 4, tcx + td // 4, tcy + td // 4], fill=(30, 30, 50, 180))

    # Tag label lines
    ll_x0 = tag_x0 + int(ts * 0.18)
    ll_y = tag_y0 + int(ts * 0.52)
    ll_h = int(ts * 0.09)
    for i, fw in enumerate([0.58, 0.42]):
        ll_w = int(ts * fw)
        draw.rounded_rectangle([ll_x0, ll_y + i * int(ts * 0.18), ll_x0 + ll_w, ll_y + i * int(ts * 0.18) + ll_h],
                                radius=ll_h // 2, fill=(255, 255, 255, 200))

    return img


def resize_icon(master, size, output_path):
    resized = master.resize((size, size), Image.LANCZOS)
    resized.save(output_path, "PNG")
    print(f"  {size}x{size} → {os.path.basename(output_path)}")


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    print("Generating 1024x1024 master icon...")
    master = make_icon(SIZE)

    sizes = [
        (16,   "icon_16x16.png"),
        (32,   "icon_16x16@2x.png"),
        (32,   "icon_32x32.png"),
        (64,   "icon_32x32@2x.png"),
        (128,  "icon_128x128.png"),
        (256,  "icon_128x128@2x.png"),
        (256,  "icon_256x256.png"),
        (512,  "icon_256x256@2x.png"),
        (512,  "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    print("Resizing to all required sizes...")
    for px, filename in sizes:
        path = os.path.join(ICON_DIR, filename)
        resize_icon(master, px, path)

    print("Done.")


if __name__ == "__main__":
    main()
