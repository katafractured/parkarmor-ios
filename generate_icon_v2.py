#!/usr/bin/env python3
"""
ParkArmor App Icon — v2 (Pillow)
Renders at 4096×4096 then downscales to 1024×1024 for maximum sharpness.
Output: ParkArmor/Assets.xcassets/AppIcon.appiconset/AppIcon.png
"""

import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

# ── Constants ─────────────────────────────────────────────────────────────────
RENDER_SIZE = 4096          # Internal render resolution
EXPORT_SIZE = 1024          # Final PNG size
SCALE = RENDER_SIZE // EXPORT_SIZE  # 4x

S = RENDER_SIZE
H = S // 2                  # Half size (centre)

NAVY_DARK  = (5,   8,  18)        # #050812  — deepest background
NAVY_MID   = (10, 14,  28)        # #0A0E1C
NAVY_LIGHT = (18, 26,  55)        # #121A37  — subtle inner glow
CYAN       = (0, 240, 255)        # #00F0FF
CYAN_DARK  = (0, 160, 195)        # #00A0C3  — shield shadow edge
CYAN_MID   = (0, 210, 240)        # #00D2F0
WHITE      = (255, 255, 255)
BLACK      = (0, 0, 0)

OUTPUT = "ParkArmor/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

# ── Helpers ───────────────────────────────────────────────────────────────────

def lerp_color(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))

def radial_gradient(img, cx, cy, r_inner, r_outer, color_inner, color_outer):
    """Paint a radial gradient onto img (RGBA)."""
    arr = img.load()
    for y in range(S):
        for x in range(S):
            d = math.sqrt((x - cx)**2 + (y - cy)**2)
            t = max(0.0, min(1.0, (d - r_inner) / (r_outer - r_inner)))
            ci = color_inner + (255,) if len(color_inner) == 3 else color_inner
            co = color_outer + (0,)   if len(color_outer) == 3 else color_outer
            r = int(ci[0] + (co[0] - ci[0]) * t)
            g = int(ci[1] + (co[1] - ci[1]) * t)
            b = int(ci[2] + (co[2] - ci[2]) * t)
            a = int(ci[3] + (co[3] - ci[3]) * t)
            # Alpha-composite onto existing pixel
            bg = arr[x, y]
            oa = a / 255.0
            ba = bg[3] / 255.0
            na = oa + ba * (1 - oa)
            if na > 0:
                nr = int((r * oa + bg[0] * ba * (1 - oa)) / na)
                ng = int((g * oa + bg[1] * ba * (1 - oa)) / na)
                nb = int((b * oa + bg[2] * ba * (1 - oa)) / na)
            else:
                nr = ng = nb = 0
            arr[x, y] = (nr, ng, nb, int(na * 255))

def shield_polygon(cx, cy, w, h):
    """Return list of (x,y) points for a clean shield shape."""
    pts = []
    # Top edge — flat with slight curve via many points
    segments = 80
    # Shield: from top-left arc → top-right arc → right side → bottom point → left side
    r = w * 0.11   # corner radius approximated via polygon points

    left   = cx - w * 0.42
    right  = cx + w * 0.42
    top    = cy - h * 0.44
    # Right side curves inward at ~60% down then meets at bottom tip
    mid_y  = cy + h * 0.05
    bot    = cy + h * 0.52

    # Top-left corner arc
    for i in range(9):
        angle = math.pi + (math.pi / 2) * (i / 8)
        pts.append((cx - w * 0.42 + r + r * math.cos(angle),
                    cy - h * 0.44 + r + r * math.sin(angle)))

    # Top edge
    pts.append((cx + w * 0.42 - r, top))

    # Top-right corner arc
    for i in range(9):
        angle = (3 * math.pi / 2) + (math.pi / 2) * (i / 8)
        pts.append((cx + w * 0.42 - r + r * math.cos(angle),
                    cy - h * 0.44 + r + r * math.sin(angle)))

    # Right side: straight then Bezier-like curve to bottom tip
    n = 40
    for i in range(n + 1):
        t = i / n
        # cubic bezier: P0=(right, mid_y), P1=(right, mid_y+h*0.25), P2=(cx+w*0.12, bot+h*0.05), P3=(cx, bot)
        p0x, p0y = right, mid_y
        p1x, p1y = right, cy + h * 0.32
        p2x, p2y = cx + w * 0.12, bot - h * 0.02
        p3x, p3y = cx, bot
        bx = ((1-t)**3 * p0x + 3*(1-t)**2*t * p1x +
               3*(1-t)*t**2 * p2x + t**3 * p3x)
        by = ((1-t)**3 * p0y + 3*(1-t)**2*t * p1y +
               3*(1-t)*t**2 * p2y + t**3 * p3y)
        pts.append((bx, by))

    # Left side: mirror
    n = 40
    for i in range(n + 1):
        t = i / n
        p0x, p0y = cx, bot
        p1x, p1y = cx - w * 0.12, bot - h * 0.02
        p2x, p2y = left, cy + h * 0.32
        p3x, p3y = left, mid_y
        bx = ((1-t)**3 * p0x + 3*(1-t)**2*t * p1x +
               3*(1-t)*t**2 * p2x + t**3 * p3x)
        by = ((1-t)**3 * p0y + 3*(1-t)**2*t * p1y +
               3*(1-t)*t**2 * p2y + t**3 * p3y)
        pts.append((bx, by))

    return pts

def pin_polygon(cx, cy, head_r, tail_h):
    """Return list of points for a teardrop map-pin pointing down."""
    pts = []
    tip_y = cy + head_r + tail_h
    # Left side of tail
    tail_w = head_r * 0.48
    n = 32
    for i in range(n + 1):
        t = i / n
        # Bezier from left-attach to tip
        p0x, p0y = cx - tail_w, cy + head_r * 0.35
        p1x, p1y = cx - tail_w * 0.8, tip_y - tail_h * 0.15
        p2x, p2y = cx - tail_w * 0.15, tip_y
        p3x, p3y = cx, tip_y
        bx = ((1-t)**3*p0x + 3*(1-t)**2*t*p1x + 3*(1-t)*t**2*p2x + t**3*p3x)
        by = ((1-t)**3*p0y + 3*(1-t)**2*t*p1y + 3*(1-t)*t**2*p2y + t**3*p3y)
        pts.append((bx, by))
    # Right side
    for i in range(n + 1):
        t = i / n
        p0x, p0y = cx, tip_y
        p1x, p1y = cx + tail_w * 0.15, tip_y
        p2x, p2y = cx + tail_w * 0.8, tip_y - tail_h * 0.15
        p3x, p3y = cx + tail_w, cy + head_r * 0.35
        bx = ((1-t)**3*p0x + 3*(1-t)**2*t*p1x + 3*(1-t)*t**2*p2x + t**3*p3x)
        by = ((1-t)**3*p0y + 3*(1-t)**2*t*p1y + 3*(1-t)*t**2*p2y + t**3*p3y)
        pts.append((bx, by))
    # Circle top
    for i in range(65):
        angle = math.pi * 0.15 + math.pi * 1.7 * (i / 64)
        pts.append((cx + head_r * math.cos(angle), cy + head_r * math.sin(angle)))
    return pts

# ── Build the image ───────────────────────────────────────────────────────────

canvas = Image.new("RGBA", (S, S), NAVY_DARK + (255,))
draw   = ImageDraw.Draw(canvas)

# 1. Background — deep dark gradient
bg_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
# Draw concentric ellipses to fake radial gradient
steps = 120
for i in range(steps, 0, -1):
    t = i / steps
    r_size = int(S * 0.72 * t)
    col = lerp_color(NAVY_LIGHT, NAVY_DARK, t)
    bg_draw = ImageDraw.Draw(bg_layer)
    bg_draw.ellipse(
        [H - r_size, H - r_size, H + r_size, H + r_size],
        fill=col + (255,)
    )
canvas = Image.alpha_composite(canvas, bg_layer)
draw = ImageDraw.Draw(canvas)

# 2. Shield drop shadow (blurred)
shadow_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sh_draw = ImageDraw.Draw(shadow_layer)
sh_poly = shield_polygon(H + S*0.012, H + S*0.025, S*0.62, S*0.72)
sh_draw.polygon(sh_poly, fill=(0, 200, 255, 90))
shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=S*0.038))
canvas = Image.alpha_composite(canvas, shadow_layer)
draw = ImageDraw.Draw(canvas)

# 3. Shield body — solid dark-cyan base
shield_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
s_draw = ImageDraw.Draw(shield_layer)
shield_pts = shield_polygon(H, H, S*0.60, S*0.70)
s_draw.polygon(shield_pts, fill=CYAN_DARK + (255,))
canvas = Image.alpha_composite(canvas, shield_layer)
draw = ImageDraw.Draw(canvas)

# 4. Shield gradient — lighter cyan on top, darker at bottom
shield_grad = Image.new("RGBA", (S, S), (0, 0, 0, 0))
grad_draw = ImageDraw.Draw(shield_grad)

# Clip to shield shape mask
shield_mask = Image.new("L", (S, S), 0)
m_draw = ImageDraw.Draw(shield_mask)
m_draw.polygon(shield_pts, fill=255)

top_y  = int(H - S*0.70*0.44)
bot_y  = int(H + S*0.70*0.52)
height = bot_y - top_y

# Draw gradient scanlines
for row in range(top_y, bot_y):
    t = (row - top_y) / height
    t_ease = t * t * (3 - 2 * t)     # smoothstep
    col = lerp_color(CYAN, CYAN_DARK, t_ease)
    grad_draw.line([(0, row), (S, row)], fill=col + (255,))

shield_grad.putalpha(shield_mask)
canvas = Image.alpha_composite(canvas, shield_grad)
draw = ImageDraw.Draw(canvas)

# 5. Shield specular highlight (top-left glossy streak)
gloss_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
g_draw = ImageDraw.Draw(gloss_layer)

# Elliptical gloss highlight, top portion of shield
for i in range(60, 0, -1):
    alpha = int(55 * (i / 60))
    ew = int(S * 0.30 * (i / 60))
    eh = int(S * 0.14 * (i / 60))
    cx_g = int(H - S * 0.08)
    cy_g = int(H - S * 0.22)
    g_draw.ellipse([cx_g - ew, cy_g - eh, cx_g + ew, cy_g + eh],
                   fill=(255, 255, 255, alpha))

gloss_layer.putalpha(gloss_layer.getchannel("A").filter(ImageFilter.GaussianBlur(S*0.025)))
gloss_clipped = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gloss_clipped.paste(gloss_layer, mask=shield_mask)
canvas = Image.alpha_composite(canvas, gloss_clipped)
draw = ImageDraw.Draw(canvas)

# 6. Shield inner edge highlight — thin bright line around top of shield
edge_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
e_draw = ImageDraw.Draw(edge_layer)
# Draw a slightly smaller shield in very light cyan for an inner glow rim
inner_pts = shield_polygon(H, H, S*0.576, S*0.672)
e_draw.polygon(inner_pts, outline=(180, 255, 255, 90), width=int(S*0.006))
edge_layer = edge_layer.filter(ImageFilter.GaussianBlur(radius=S*0.004))
canvas = Image.alpha_composite(canvas, edge_layer)
draw = ImageDraw.Draw(canvas)

# 7. Map pin — shadow
PIN_CX   = int(H)
PIN_CY   = int(H - S * 0.035)
HEAD_R   = int(S * 0.115)
TAIL_H   = int(S * 0.158)

pin_shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ps_draw = ImageDraw.Draw(pin_shadow)
pin_pts = pin_polygon(PIN_CX + int(S*0.012), PIN_CY + int(S*0.018), HEAD_R, TAIL_H)
circle_pts = [(PIN_CX + int(S*0.012) + HEAD_R * math.cos(a * math.pi/180),
               PIN_CY + int(S*0.018) + HEAD_R * math.sin(a * math.pi/180))
              for a in range(360)]
ps_draw.polygon(list(pin_pts) + circle_pts, fill=(0, 0, 0, 180))
pin_shadow = pin_shadow.filter(ImageFilter.GaussianBlur(S*0.022))
# Clip shadow to shield
pin_shadow_clipped = Image.new("RGBA", (S, S), (0, 0, 0, 0))
pin_shadow_clipped.paste(pin_shadow, mask=shield_mask)
canvas = Image.alpha_composite(canvas, pin_shadow_clipped)
draw = ImageDraw.Draw(canvas)

# 8. Pin teardrop body (white)
pin_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
p_draw = ImageDraw.Draw(pin_layer)
pin_pts_full = pin_polygon(PIN_CX, PIN_CY, HEAD_R, TAIL_H)
# Circle top of pin
for i in range(361):
    a = math.radians(i)
    pin_pts_full.append((PIN_CX + HEAD_R * math.cos(a),
                         PIN_CY + HEAD_R * math.sin(a)))
p_draw.polygon(pin_pts_full, fill=WHITE + (255,))
# Clean teardrop: draw filled circle on top
p_draw.ellipse([PIN_CX - HEAD_R, PIN_CY - HEAD_R,
                PIN_CX + HEAD_R, PIN_CY + HEAD_R],
               fill=WHITE + (255,))
canvas = Image.alpha_composite(canvas, pin_layer)
draw = ImageDraw.Draw(canvas)

# 9. Inner circle (dark navy "hole") — creates ring/donut effect
INNER_R = int(HEAD_R * 0.52)
draw.ellipse([PIN_CX - INNER_R, PIN_CY - INNER_R,
              PIN_CX + INNER_R, PIN_CY + INNER_R],
             fill=NAVY_DARK + (255,))

# 10. Car icon inside the pin hole (3 simple Pillow-drawn rectangles = car silhouette)
car_w  = int(INNER_R * 1.35)
car_h  = int(INNER_R * 0.62)
car_x  = PIN_CX - car_w // 2
car_y  = PIN_CY - car_h // 2 + int(INNER_R * 0.05)

# Car body — main rectangle
draw.rounded_rectangle(
    [car_x, car_y + car_h//3, car_x + car_w, car_y + car_h],
    radius=int(car_h * 0.22),
    fill=WHITE + (255,)
)
# Car cabin — upper trapezoidal shape as a polygon
cabin_margin_x = int(car_w * 0.16)
cabin_h = int(car_h * 0.50)
cabin_pts = [
    (car_x + cabin_margin_x + int(car_w*0.06),  car_y),
    (car_x + car_w - cabin_margin_x - int(car_w*0.06), car_y),
    (car_x + car_w - cabin_margin_x//2, car_y + cabin_h),
    (car_x + cabin_margin_x//2,         car_y + cabin_h),
]
draw.polygon(cabin_pts, fill=WHITE + (255,))

# Wheels (dark circles)
wheel_r = int(car_h * 0.22)
wheel_y = car_y + car_h
draw.ellipse([car_x + int(car_w*0.18) - wheel_r, wheel_y - wheel_r,
              car_x + int(car_w*0.18) + wheel_r, wheel_y + wheel_r],
             fill=NAVY_DARK + (255,))
draw.ellipse([car_x + int(car_w*0.82) - wheel_r, wheel_y - wheel_r,
              car_x + int(car_w*0.82) + wheel_r, wheel_y + wheel_r],
             fill=NAVY_DARK + (255,))

# 11. Pin tip highlight — tiny specular dot
draw.ellipse([PIN_CX - int(HEAD_R*0.28), PIN_CY - int(HEAD_R*0.62),
              PIN_CX + int(HEAD_R*0.05), PIN_CY - int(HEAD_R*0.28)],
             fill=(255, 255, 255, 160))

# 12. Subtle outer glow around whole icon (cyan bloom)
glow_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
g2_draw = ImageDraw.Draw(glow_layer)
for i in range(30, 0, -1):
    alpha = int(12 * (i / 30))
    r = int(S * 0.44 * (i / 30) + S * 0.02)
    g2_draw.ellipse([H - r, H - r, H + r, H + r], fill=CYAN + (alpha,))
glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(S * 0.04))
canvas = Image.alpha_composite(canvas, glow_layer)

# 13. Rounded rect mask (iOS icon corners)
corner_r = int(S * 0.2237)      # iOS standard ≈ 22.37% of size
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S-1, S-1], radius=corner_r, fill=255)
canvas.putalpha(mask)

# ── Export ────────────────────────────────────────────────────────────────────
final = canvas.resize((EXPORT_SIZE, EXPORT_SIZE), Image.LANCZOS)

# Flatten onto white background isn't needed — keep alpha for Xcode
os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
final.save(OUTPUT, "PNG", optimize=True)
print(f"✓ Icon written → {OUTPUT}")

# Also save a preview at 512 for quick inspection
preview_path = "/tmp/parkarmor_icon_preview.png"
final.save(preview_path)
print(f"✓ Preview saved → {preview_path}")
