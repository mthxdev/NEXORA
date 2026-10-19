#!/usr/bin/env python3
"""
Génère l'identité visuelle Nexora (icône App Store + 5 logos in-app).

5 concepts distincts basés sur les références :
1. N géométrique dégradé bleu/cyan/violet sur fond bleu nuit
2. N géométrique dégradé sur fond clair
3. Symbole angulaire "progression" cyan/violet sur fond sombre
3. Étoile 4 branches dégradé cyan/violet sur fond sombre
5. N stylisé dans cercle dynamique cyan/violet sur fond sombre

Contraintes Apple :
- PNG 1024x1024 sans alpha (icône opaque)
- Pas de corner radius pré-dessiné
- Supersampling 4x + Lanczos

Usage: python Tools/generate_app_icon.py
"""

from __future__ import annotations

import os
import math

from PIL import Image, ImageDraw

# --- Configuration ---------------------------------------------------------

SUPERSAMPLE = 4

# Tailles icône App Store (classic uniquement)
ICON_SIZES = [
    ("AppIcon-20@2x.png", 40),
    ("AppIcon-20@3x.png", 60),
    ("AppIcon-29@2x.png", 58),
    ("AppIcon-29@3x.png", 87),
    ("AppIcon-40@2x.png", 80),
    ("AppIcon-40@3x.png", 120),
    ("AppIcon-60@2x.png", 120),
    ("AppIcon-60@3x.png", 180),
    ("AppIcon-20~ipad.png", 20),
    ("AppIcon-20~ipad@2x.png", 40),
    ("AppIcon-29@1x.png", 29),
    ("AppIcon-40@1x.png", 40),
    ("AppIcon-76@1x.png", 76),
    ("AppIcon-76@2x.png", 152),
    ("AppIcon-83.5@2x.png", 167),
    ("AppIcon-1024.png", 1024),
]

# Tailles logos in-app : 48 pt = 48 / 96 / 144 px
LOGO_SIZES = {
    "1x": 48,
    "2x": 96,
    "3x": 144,
}

# Concepts : (dossier, nom_fichier_base, fonc_rendu)
CONCEPTS = [
    # 1. N géométrique dégradé sur fond bleu nuit
    ("NexoraLogo.imageset", "NexoraLogo", "concept_1_n_geometric_night"),
    # 2. N géométrique dégradé sur fond clair
    ("NexoraLogoGradient.imageset", "NexoraLogoGradient", "concept_2_n_geometric_light"),
    # 3. Symbole angulaire progression
    ("NexoraLogoMinimal.imageset", "NexoraLogoMinimal", "concept_3_angular_progression"),
    # 4. Étoile 4 branches
    ("NexoraLogoBold.imageset", "NexoraLogoBold", "concept_4_star"),
    # 5. N dans cercle dynamique
    ("NexoraLogoMono.imageset", "NexoraLogoMono", "concept_5_n_circle"),
]

# Couleurs
NIGHT_BG_TOP = (10, 12, 28)
NIGHT_BG_MID = (8, 10, 24)
NIGHT_BG_BOT = (6, 8, 20)

LIGHT_BG_TOP = (240, 245, 255)
LIGHT_BG_MID = (225, 235, 250)
LIGHT_BG_BOT = (210, 225, 245)

CYAN = (0, 220, 255)
VIOLET = (140, 80, 255)
BLUE = (30, 100, 255)
WHITE = (255, 255, 255)
DARK_TEXT = (20, 25, 45)
LIGHT_TEXT = (245, 250, 255)

def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t

def _mix(c1, c2, t: float):
    return tuple(int(round(_lerp(c1[i], c2[i], t))) for i in range(3))

def _vertical_gradient(size: int, top, mid, bot) -> Image.Image:
    img = Image.new("RGB", (1, size))
    px = img.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        if t < 0.5:
            colour = _mix(top, mid, t / 0.5)
        else:
            colour = _mix(mid, bot, (t - 0.5) / 0.5)
        px[0, y] = colour
    return img.resize((size, size), Image.NEAREST)

def _radial_gradient(size: int, center_color, edge_color) -> Image.Image:
    """Gradient radial du centre vers les bords."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    cx = cy = size // 2
    max_dist = math.hypot(cx, cy)
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy) / max_dist
            px[x, y] = _mix(center_color, edge_color, d)
    return img

def _draw_background_night(size: int) -> Image.Image:
    base = _vertical_gradient(size, NIGHT_BG_TOP, NIGHT_BG_MID, NIGHT_BG_BOT)
    halo = _radial_gradient(size, (30, 40, 80), (5, 6, 15))
    return Image.blend(base, halo, 0.35).convert("RGB")

def _draw_background_light(size: int) -> Image.Image:
    base = _vertical_gradient(size, LIGHT_BG_TOP, LIGHT_BG_MID, LIGHT_BG_BOT)
    halo = _radial_gradient(size, (255, 255, 255), (200, 220, 245))
    return Image.blend(base, halo, 0.25).convert("RGB")

def _draw_background_dark_vibrant(size: int) -> Image.Image:
    """Fond sombre vibrant pour concepts 3, 4, 5."""
    base = _vertical_gradient(size, (15, 10, 35), (10, 8, 30), (6, 5, 22))
    halo = _radial_gradient(size, (40, 20, 70), (5, 3, 15))
    return Image.blend(base, halo, 0.4).convert("RGB")

def render_concept_1_n_geometric_night(size: int) -> Image.Image:
    """Concept 1: N géométrique dégradé bleu/cyan/violet sur fond bleu nuit."""
    hi = size * SUPERSAMPLE
    canvas = _draw_background_night(hi).convert("RGBA")
    
    # Glyph N
    glyph = Image.new("RGBA", (hi, hi), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glyph)
    
    s = hi
    stem_w = int(0.125 * s)
    left_x = int(0.215 * s)
    right_x = int(0.655 * s)
    top = int(0.25 * s)
    bottom = int(0.75 * s)
    inner_left = left_x + stem_w
    right_end = right_x + stem_w
    
    # Diagonale dégradée
    diag_wide = int(0.15 * s)
    diag_narrow = int(0.11 * s)
    
    diagonal = [
        (inner_left, top),
        (inner_left + diag_wide, top),
        (right_end, bottom),
        (right_end - diag_narrow, bottom),
    ]
    
    diag_mask = Image.new("L", (hi, hi), 0)
    ImageDraw.Draw(diag_mask).polygon(diagonal, fill=255)
    
    grad = Image.new("RGB", (1, hi))
    gpx = grad.load()
    for y in range(hi):
        t = min(max((y - top) / max(bottom - top, 1), 0.0), 1.0)
        gpx[0, y] = _mix(CYAN, VIOLET, t)
    grad = grad.resize((hi, hi), Image.NEAREST)
    
    glyph.paste(grad, (0, 0), diag_mask)
    
    # Montants blancs
    draw.rectangle([left_x, top, inner_left, bottom], fill=WHITE)
    draw.rectangle([right_x, top, right_end, bottom], fill=WHITE)
    
    canvas.alpha_composite(glyph)
    return canvas.convert("RGB").resize((size, size), Image.LANCZOS)

def render_concept_2_n_geometric_light(size: int) -> Image.Image:
    """Concept 2: N géométrique sur fond clair."""
    hi = size * SUPERSAMPLE
    canvas = _draw_background_light(hi).convert("RGBA")
    
    glyph = Image.new("RGBA", (hi, hi), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glyph)
    
    s = hi
    stem_w = int(0.125 * s)
    left_x = int(0.215 * s)
    right_x = int(0.655 * s)
    top = int(0.25 * s)
    bottom = int(0.75 * s)
    inner_left = left_x + stem_w
    right_end = right_x + stem_w
    
    diag_wide = int(0.15 * s)
    diag_narrow = int(0.11 * s)
    
    diagonal = [
        (inner_left, top),
        (inner_left + diag_wide, top),
        (right_end, bottom),
        (right_end - diag_narrow, bottom),
    ]
    
    diag_mask = Image.new("L", (hi, hi), 0)
    ImageDraw.Draw(diag_mask).polygon(diagonal, fill=255)
    
    grad = Image.new("RGB", (1, hi))
    gpx = grad.load()
    for y in range(hi):
        t = min(max((y - top) / max(bottom - top, 1), 0.0), 1.0)
        gpx[0, y] = _mix(BLUE, VIOLET, t)
    grad = grad.resize((hi, hi), Image.NEAREST)
    
    glyph.paste(grad, (0, 0), diag_mask)
    
    # Montants en bleu nuit
    dark_blue = DARK_TEXT + (255,)
    draw.rectangle([left_x, top, inner_left, bottom], fill=dark_blue)
    draw.rectangle([right_x, top, right_end, bottom], fill=dark_blue)
    
    canvas.alpha_composite(glyph)
    return canvas.convert("RGB").resize((size, size), Image.LANCZOS)

def render_concept_3_angular_progression(size: int) -> Image.Image:
    """Concept 3: Symbole angulaire "progression" - flèche montante stylisée."""
    hi = size * SUPERSAMPLE
    canvas = _draw_background_dark_vibrant(hi).convert("RGBA")
    
    glyph = Image.new("RGBA", (hi, hi), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glyph)
    
    s = hi
    cx = s // 2
    cy = s // 2
    
    # Flèche montante angulaire
    stem_w = int(0.08 * s)
    head_h = int(0.25 * s)
    shaft_h = int(0.4 * s)
    
    # Corps de la flèche (trapèze)
    arrow_body = [
        (cx - stem_w, cy + shaft_h),      # bas gauche
        (cx + stem_w, cy + shaft_h),      # bas droit
        (cx + stem_w * 3, cy - head_h),   # pointe droite
        (cx, cy - head_h * 1.5),          # pointe centrale
        (cx - stem_w * 3, cy - head_h),   # pointe gauche
    ]
    
    draw.polygon(arrow_body, fill=WHITE)
    
    # Ligne d'accélération sous la flèche
    for i in range(3):
        y = cy + shaft_h + int(0.08 * s) * (i + 1)
        w = int(0.15 * s) - i * int(0.03 * s)
        if w > 0:
            draw.line([(cx - w, y), (cx + w, y)], fill=CYAN, width=int(0.015 * s))
    
    # Particules d'énergie
    for i in range(8):
        angle = (i / 8) * 2 * math.pi - math.pi / 2
        r = int(0.35 * s) + int(0.05 * s) * (i % 3)
        px = cx + int(r * math.cos(angle))
        py = cy + int(r * math.sin(angle))
        rad = int(0.015 * s) + (i % 3) * int(0.005 * s)
        color = _mix(CYAN, VIOLET, (i / 8))
        draw.ellipse([px - rad, py - rad, px + rad, py + rad], fill=color + (255,))
    
    canvas.alpha_composite(glyph)
    return canvas.convert("RGB").resize((size, size), Image.LANCZOS)

def render_concept_4_star(size: int) -> Image.Image:
    """Concept 4: Étoile 4 branches dégradé cyan/violet."""
    hi = size * SUPERSAMPLE
    canvas = _draw_background_dark_vibrant(hi).convert("RGBA")
    
    glyph = Image.new("RGBA", (hi, hi), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glyph)
    
    s = hi
    cx = s // 2
    cy = s // 2
    
    outer_r = int(0.38 * s)
    inner_r = int(0.14 * s)
    
    # Étoile 4 branches (losanges allongés)
    for i in range(4):
        angle = (i / 4) * 2 * math.pi - math.pi / 2
        
        # Branch principale
        pts = []
        # Pointe externe
        px = cx + int(outer_r * math.cos(angle))
        py = cy + int(outer_r * math.sin(angle))
        pts.append((px, py))
        
        # Côtés
        side_angle = angle + 0.4  # ~23°
        sx = cx + int(inner_r * math.cos(side_angle))
        sy = cy + int(inner_r * math.sin(side_angle))
        pts.append((sx, sy))
        
        # Centre
        pts.append((cx, cy))
        
        side_angle2 = angle - 0.4
        sx2 = cx + int(inner_r * math.cos(side_angle2))
        sy2 = cy + int(inner_r * math.sin(side_angle2))
        pts.append((sx2, sy2))
        
        # Dégradé par branche
        t = i / 4
        color = _mix(CYAN, VIOLET, t) + (255,)
        draw.polygon(pts, fill=color)
    
    # Cercle central
    center_r = int(0.06 * s)
    grad = Image.new("RGBA", (center_r * 2, center_r * 2), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(grad)
    for r in range(center_r, 0, -1):
        t = r / center_r
        color = _mix(CYAN, VIOLET, t) + (255,)
        gdraw.ellipse([center_r - r, center_r - r, center_r + r, center_r + r], fill=color)
    canvas.alpha_composite(grad, (cx - center_r, cy - center_r))
    
    # Halo externe
    for i in range(8):
        angle = (i / 8) * 2 * math.pi
        r = int(0.45 * s)
        px = cx + int(r * math.cos(angle))
        py = cy + int(r * math.sin(angle))
        rad = int(0.01 * s)
        color = _mix(CYAN, VIOLET, (i / 8)) + (180,)
        draw.ellipse([px - rad, py - rad, px + rad, py + rad], fill=color)
    
    canvas.alpha_composite(glyph)
    return canvas.convert("RGB").resize((size, size), Image.LANCZOS)

def render_concept_5_n_circle(size: int) -> Image.Image:
    """Concept 5: N stylisé dans cercle dynamique."""
    hi = size * SUPERSAMPLE
    canvas = _draw_background_dark_vibrant(hi).convert("RGBA")
    
    glyph = Image.new("RGBA", (hi, hi), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glyph)
    
    s = hi
    cx = s // 2
    cy = s // 2
    
    # Cercle extérieur animé (plusieurs anneaux)
    for ring in range(3):
        r = int(0.38 * s) - ring * int(0.05 * s)
        alpha = 80 - ring * 20
        color = _mix(CYAN, VIOLET, ring / 3) + (alpha,)
        draw.ellipse([cx - r, cy - r, cx + r, cx + r], outline=color, width=int(0.01 * s))
    
    # N au centre
    stem_w = int(0.11 * s)
    left_x = cx - int(0.22 * s)
    right_x = cx + int(0.10 * s)
    top = cy - int(0.22 * s)
    bottom = cy + int(0.22 * s)
    inner_left = left_x + stem_w
    right_end = right_x + stem_w
    
    diag_wide = int(0.13 * s)
    diag_narrow = int(0.10 * s)
    
    diagonal = [
        (inner_left, top),
        (inner_left + diag_wide, top),
        (right_end, bottom),
        (right_end - diag_narrow, bottom),
    ]
    
    diag_mask = Image.new("L", (hi, hi), 0)
    ImageDraw.Draw(diag_mask).polygon(diagonal, fill=255)
    
    grad = Image.new("RGB", (1, hi))
    gpx = grad.load()
    for y in range(hi):
        t = min(max((y - top) / max(bottom - top, 1), 0.0), 1.0)
        gpx[0, y] = _mix(CYAN, VIOLET, t)
    grad = grad.resize((hi, hi), Image.NEAREST)
    
    glyph.paste(grad, (0, 0), diag_mask)
    
    draw.rectangle([left_x, top, inner_left, bottom], fill=WHITE)
    draw.rectangle([right_x, top, right_end, bottom], fill=WHITE)
    
    # Points d'énergie sur le cercle
    for i in range(12):
        angle = (i / 12) * 2 * math.pi
        r = int(0.38 * s)
        px = cx + int(r * math.cos(angle))
        py = cy + int(r * math.sin(angle))
        rad = int(0.012 * s)
        color = _mix(CYAN, VIOLET, (i / 12)) + (255,)
        draw.ellipse([px - rad, py - rad, px + rad, py + rad], fill=color)
    
    canvas.alpha_composite(glyph)
    return canvas.convert("RGB").resize((size, size), Image.LANCZOS)

RENDER_FUNCS = {
    "concept_1_n_geometric_night": render_concept_1_n_geometric_night,
    "concept_2_n_geometric_light": render_concept_2_n_geometric_light,
    "concept_3_angular_progression": render_concept_3_angular_progression,
    "concept_4_star": render_concept_4_star,
    "concept_5_n_circle": render_concept_5_n_circle,
}

def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    assets = os.path.join(os.path.dirname(here), "Nexora", "Resources", "Assets.xcassets")
    icon_dir = os.path.join(assets, "AppIcon.appiconset")
    os.makedirs(icon_dir, exist_ok=True)
    
    # 1. Icône App Store (concept 1 seulement)
    cache: dict[int, Image.Image] = {}
    def icon_for(size: int) -> Image.Image:
        if size not in cache:
            cache[size] = render_concept_1_n_geometric_night(size)
        return cache[size]
    
    for filename, size in ICON_SIZES:
        icon_for(size).save(os.path.join(icon_dir, filename), "PNG", optimize=True)
        print(f"icon  {filename:<26} {size}x{size}")
    
    # 2. Les 5 logos in-app
    for folder, base_name, func_name in CONCEPTS:
        func = RENDER_FUNCS[func_name]
        variant_assets = os.path.join(assets, folder)
        os.makedirs(variant_assets, exist_ok=True)
        
        cache: dict[int, Image.Image] = {}
        def logo_for(size: int) -> Image.Image:
            if size not in cache:
                cache[size] = func(size)
            return cache[size]
        
        for scale, size in LOGO_SIZES.items():
            filename = f"{base_name}@{scale}.png" if scale != "1x" else f"{base_name}.png"
            logo_for(size).save(os.path.join(variant_assets, filename), "PNG", optimize=True)
            print(f"logo  {folder:<28} {filename:<30} {size}x{size}")
        
        # Contents.json
        import json
        contents = {
            "images": [
                {"filename": f"{base_name}.png", "idiom": "universal", "scale": "1x"},
                {"filename": f"{base_name}@2x.png", "idiom": "universal", "scale": "2x"},
                {"filename": f"{base_name}@3x.png", "idiom": "universal", "scale": "3x"},
            ],
            "info": {"author": "xcode", "version": 1}
        }
        with open(os.path.join(variant_assets, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)

if __name__ == "__main__":
    main()