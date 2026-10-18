#!/usr/bin/env python3
"""
Génère l'identité visuelle Nexora (icône App Store + 5 logos in-app).

Le monogramme « N » est construit géométriquement : deux montants verticaux
blancs reliés par une diagonale en dégradé. Chaque variante a sa propre
palette et son propre style.

Contraintes Apple respectées :
  - PNG 1024x1024 sans canal alpha (icône opaque obligatoire) ;
  - aucune transparence, aucun corner radius pré-dessiné ;
  - rendu en supersampling 4x puis réduction Lanczos pour rester net à 20 px.

Usage :
    python Tools/generate_app_icon.py
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

# --- Palettes par variante --------------------------------------------------

PALETTES = {
    "classic": {
        "name": "Classic",
        "navy_top": (22, 31, 68),
        "navy_mid": (16, 22, 50),
        "navy_bottom": (13, 17, 40),
        "halo": (74, 62, 190),
        "diag_top": (58, 226, 201),
        "diag_bottom": (122, 107, 255),
        "glyph": (255, 255, 255),
        "stem_factor": 0.130,
        "diag_wide": 0.150,
        "diag_narrow": 0.118,
    },
    "gradient": {
        "name": "Gradient",
        "navy_top": (30, 25, 75),
        "navy_mid": (18, 15, 55),
        "navy_bottom": (10, 8, 35),
        "halo": (100, 50, 200),
        "diag_top": (255, 100, 150),
        "diag_bottom": (100, 50, 255),
        "glyph": (255, 255, 255),
        "stem_factor": 0.125,
        "diag_wide": 0.160,
        "diag_narrow": 0.120,
    },
    "minimal": {
        "name": "Minimal",
        "navy_top": (35, 40, 85),
        "navy_mid": (25, 30, 65),
        "navy_bottom": (18, 22, 50),
        "halo": (60, 80, 160),
        "diag_top": (100, 200, 255),
        "diag_bottom": (140, 120, 220),
        "glyph": (240, 240, 255),
        "stem_factor": 0.110,
        "diag_wide": 0.130,
        "diag_narrow": 0.100,
    },
    "bold": {
        "name": "Bold",
        "navy_top": (15, 20, 55),
        "navy_mid": (10, 14, 40),
        "navy_bottom": (6, 9, 30),
        "halo": (140, 40, 180),
        "diag_top": (255, 80, 120),
        "diag_bottom": (180, 60, 255),
        "glyph": (255, 255, 255),
        "stem_factor": 0.150,
        "diag_wide": 0.180,
        "diag_narrow": 0.140,
    },
    "mono": {
        "name": "Mono",
        "navy_top": (28, 35, 75),
        "navy_mid": (20, 26, 55),
        "navy_bottom": (14, 18, 42),
        "halo": (80, 80, 180),
        "diag_top": (180, 180, 255),
        "diag_bottom": (120, 120, 220),
        "glyph": (230, 230, 240),
        "stem_factor": 0.140,
        "diag_wide": 0.140,
        "diag_narrow": 0.110,
    },
}

SUPERSAMPLE = 4

# Tailles réellement déclarées dans AppIcon.appiconset/Contents.json
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

# Logo affiché dans l'interface : 48 pt, donc 48 / 96 / 144 px
LOGO_SIZES = {
    "NexoraLogo.png": 48,
    "NexoraLogo@2x.png": 96,
    "NexoraLogo@3x.png": 144,
}

VARIANT_LOGO_SIZES = {
    "classic": {
        "NexoraLogo.png": 48,
        "NexoraLogo@2x.png": 96,
        "NexoraLogo@3x.png": 144,
    },
    "gradient": {
        "NexoraLogoGradient.png": 48,
        "NexoraLogoGradient@2x.png": 96,
        "NexoraLogoGradient@3x.png": 144,
    },
    "minimal": {
        "NexoraLogoMinimal.png": 48,
        "NexoraLogoMinimal@2x.png": 96,
        "NexoraLogoMinimal@3x.png": 144,
    },
    "bold": {
        "NexoraLogoBold.png": 48,
        "NexoraLogoBold@2x.png": 96,
        "NexoraLogoBold@3x.png": 144,
    },
    "mono": {
        "NexoraLogoMono.png": 48,
        "NexoraLogoMono@2x.png": 96,
        "NexoraLogoMono@3x.png": 144,
    },
}


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _mix(c1, c2, t: float):
    return tuple(int(round(_lerp(c1[i], c2[i], t))) for i in range(3))


def _vertical_gradient(size: int, palette: dict) -> Image.Image:
    """Dégradé vertical à trois arrêts."""
    img = Image.new("RGB", (1, size))
    px = img.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        if t < 0.55:
            colour = _mix(palette["navy_top"], palette["navy_mid"], t / 0.55)
        else:
            colour = _mix(palette["navy_mid"], palette["navy_bottom"], (t - 0.55) / 0.45)
        px[0, y] = colour
    return img.resize((size, size), Image.NEAREST)


def _draw_background(size: int, palette: dict) -> Image.Image:
    """Fond navy + halo radial doux."""
    base = _vertical_gradient(size, palette).convert("RGB")

    mask = Image.radial_gradient("L").resize((size, size), Image.LANCZOS)
    mask = mask.point(lambda v: int(v * 0.42))

    halo_layer = Image.new("RGB", (size, size), palette["halo"])
    return Image.composite(halo_layer, base, mask)


def _glyph_geometry(size: int, palette: dict):
    """Coordonnées du monogramme N, exprimées en fraction du canevas."""
    s = size
    stem = palette["stem_factor"] * s
    left_x = 0.215 * s
    right_x = 0.655 * s
    top = 0.272 * s
    bottom = 0.728 * s
    return stem, left_x, right_x, top, bottom


def _draw_glyph(size: int, palette: dict) -> Image.Image:
    """Dessine le monogramme N : deux montants et une diagonale effilée."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    stem, left_x, right_x, top, bottom = _glyph_geometry(size, palette)
    inner_left = left_x + stem
    right_end = right_x + stem

    wide = palette["diag_wide"] * size
    narrow = palette["diag_narrow"] * size

    diagonal = [
        (inner_left, top),
        (inner_left + wide, top),
        (right_end, bottom),
        (right_end - narrow, bottom),
    ]

    diag_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(diag_mask).polygon(diagonal, fill=255)

    gradient = Image.new("RGB", (1, size))
    gpx = gradient.load()
    for y in range(size):
        t = min(max((y - top) / max(bottom - top, 1), 0.0), 1.0)
        gpx[0, y] = _mix(palette["diag_top"], palette["diag_bottom"], t)
    gradient = gradient.resize((size, size), Image.NEAREST)

    layer.paste(gradient, (0, 0), diag_mask)

    draw = ImageDraw.Draw(layer)
    glyph_color = palette["glyph"] + (255,)
    draw.rectangle([left_x, top, inner_left, bottom], fill=glyph_color)
    draw.rectangle([right_x, top, right_x + stem, bottom], fill=glyph_color)

    return layer


def render_icon(size: int, palette: dict) -> Image.Image:
    """Rend une icône carrée, totalement opaque, sans canal alpha."""
    hi = size * SUPERSAMPLE

    canvas = _draw_background(hi, palette).convert("RGBA")
    canvas.alpha_composite(_draw_glyph(hi, palette))

    img = canvas.convert("RGB").resize((size, size), Image.LANCZOS)
    assert img.mode == "RGB", img.mode
    return img


def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    assets = os.path.join(os.path.dirname(here), "Nexora", "Resources", "Assets.xcassets")
    icon_dir = os.path.join(assets, "AppIcon.appiconset")

    os.makedirs(icon_dir, exist_ok=True)

    # Une seule passe de rendu par taille distincte pour l'icône App Store (classic)
    cache: dict[int, Image.Image] = {}

    def icon_for(size: int) -> Image.Image:
        if size not in cache:
            cache[size] = render_icon(size, PALETTES["classic"])
        return cache[size]

    for filename, size in ICON_SIZES:
        icon_for(size).save(os.path.join(icon_dir, filename), "PNG", optimize=True)
        print(f"icon  {filename:<26} {size}x{size}")

    # Générer les 5 variantes de logo in-app
    for variant_key, palette in PALETTES.items():
        if variant_key == "classic":
            variant_assets = os.path.join(assets, "NexoraLogo.imageset")
        else:
            variant_assets = os.path.join(assets, f"NexoraLogo{palette['name']}.imageset")
        
        os.makedirs(variant_assets, exist_ok=True)
        
        logo_sizes = VARIANT_LOGO_SIZES[variant_key]
        variant_cache: dict[int, Image.Image] = {}

        def logo_for(size: int) -> Image.Image:
            if size not in variant_cache:
                variant_cache[size] = render_icon(size, palette)
            return variant_cache[size]

        for filename, size in logo_sizes.items():
            logo_for(size).save(os.path.join(variant_assets, filename), "PNG", optimize=True)
            print(f"logo  {variant_key:<10} {filename:<30} {size}x{size}")

        # Générer Contents.json pour chaque variante
        contents = {
            "images": [
                {"filename": f, "idiom": "universal", "scale": s}
                for f, s in [
                    (list(logo_sizes.keys())[0], "1x"),
                    (list(logo_sizes.keys())[1], "2x"),
                    (list(logo_sizes.keys())[2], "3x"),
                ]
            ],
            "info": {"author": "xcode", "version": 1}
        }
        import json
        with open(os.path.join(variant_assets, "Contents.json"), "w") as f:
            json.dump(contents, f, indent=2)


if __name__ == "__main__":
    main()