#!/usr/bin/env python3
"""
Génère l'identité visuelle Nexora (icône App Store + logo in-app).

Le monogramme « N » est construit géométriquement : deux montants verticaux
blancs reliés par une diagonale en dégradé cyan → indigo. Le fond est un
dégradé bleu nuit avec un halo central, sans coins arrondis (iOS les applique).

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

# --- Palette Nexora -------------------------------------------------------
NAVY_TOP = (22, 31, 68)
NAVY_MID = (16, 22, 50)
NAVY_BOTTOM = (13, 17, 40)
HALO = (74, 62, 190)
GLYPH_WHITE = (255, 255, 255)
DIAGONAL_TOP = (58, 226, 201)
DIAGONAL_BOTTOM = (122, 107, 255)

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


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _mix(c1, c2, t: float):
    return tuple(int(round(_lerp(c1[i], c2[i], t))) for i in range(3))


def _vertical_gradient(size: int) -> Image.Image:
    """Dégradé vertical à trois arrêts, du navy clair au presque noir."""
    img = Image.new("RGB", (1, size))
    px = img.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        if t < 0.55:
            colour = _mix(NAVY_TOP, NAVY_MID, t / 0.55)
        else:
            colour = _mix(NAVY_MID, NAVY_BOTTOM, (t - 0.55) / 0.45)
        px[0, y] = colour
    return img.resize((size, size), Image.NEAREST)


def _draw_background(size: int) -> Image.Image:
    """Fond navy + halo radial doux, pour éviter un aplat parfaitement plat."""
    base = _vertical_gradient(size).convert("RGB")

    mask = Image.radial_gradient("L").resize((size, size), Image.LANCZOS)
    mask = mask.point(lambda v: int(v * 0.42))

    halo_layer = Image.new("RGB", (size, size), HALO)
    return Image.composite(halo_layer, base, mask)


def _glyph_geometry(size: int):
    """Coordonnées du monogramme N, exprimées en fraction du canevas."""
    s = size
    stem = 0.130 * s           # largeur d'un montant
    left_x = 0.215 * s
    right_x = 0.655 * s
    top = 0.272 * s            # centré verticalement sur 0.5
    bottom = 0.728 * s
    return stem, left_x, right_x, top, bottom
def _draw_glyph(size: int) -> Image.Image:
    """Dessine le monogramme N : deux montants blancs et une diagonale effilée.

    La diagonale se resserre du haut vers le bas : cela donne du mouvement et
    distingue le monogramme d'un N à largeur constante.
    """
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    stem, left_x, right_x, top, bottom = _glyph_geometry(size)
    inner_left = left_x + stem
    right_end = right_x + stem

    wide = 0.150 * size       # épaisseur de la diagonale en haut
    narrow = 0.118 * size     # épaisseur de la diagonale en bas

    # La diagonale part du montant gauche et se glisse sous le montant droit :
    # les deux extrémités sont ainsi parfaitement raccordées.
    diagonal = [
        (inner_left, top),
        (inner_left + wide, top),
        (right_end, bottom),
        (right_end - narrow, bottom),
    ]

    # Dégradé vertical cyan → indigo, appliqué via un masque.
    diag_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(diag_mask).polygon(diagonal, fill=255)

    gradient = Image.new("RGB", (1, size))
    gpx = gradient.load()
    for y in range(size):
        t = min(max((y - top) / max(bottom - top, 1), 0.0), 1.0)
        gpx[0, y] = _mix(DIAGONAL_TOP, DIAGONAL_BOTTOM, t)
    gradient = gradient.resize((size, size), Image.NEAREST)

    layer.paste(gradient, (0, 0), diag_mask)

    # Montants blancs, dessinés par-dessus pour des jonctions nettes.
    draw = ImageDraw.Draw(layer)
    draw.rectangle([left_x, top, inner_left, bottom], fill=GLYPH_WHITE + (255,))
    draw.rectangle([right_x, top, right_x + stem, bottom], fill=GLYPH_WHITE + (255,))

    return layer


def render_icon(size: int) -> Image.Image:
    """Rend une icône carrée, totalement opaque, sans canal alpha."""
    hi = size * SUPERSAMPLE

    canvas = _draw_background(hi).convert("RGBA")
    canvas.alpha_composite(_draw_glyph(hi))

    # Aucun corner radius : iOS applique son propre masque.
    # convert("RGB") supprime le canal alpha du PNG final.
    img = canvas.convert("RGB").resize((size, size), Image.LANCZOS)
    assert img.mode == "RGB", img.mode
    return img


def main() -> None:
    here = os.path.dirname(os.path.abspath(__file__))
    assets = os.path.join(os.path.dirname(here), "Nexora", "Resources", "Assets.xcassets")
    icon_dir = os.path.join(assets, "AppIcon.appiconset")
    logo_dir = os.path.join(assets, "NexoraLogo.imageset")

    os.makedirs(icon_dir, exist_ok=True)
    os.makedirs(logo_dir, exist_ok=True)

    # Une seule passe de rendu par taille distincte.
    cache: dict[int, Image.Image] = {}

    def icon_for(size: int) -> Image.Image:
        if size not in cache:
            cache[size] = render_icon(size)
        return cache[size]

    for filename, size in ICON_SIZES:
        icon_for(size).save(os.path.join(icon_dir, filename), "PNG", optimize=True)
        print(f"icon  {filename:<26} {size}x{size}")

    for filename, size in LOGO_SIZES.items():
        icon_for(size).save(os.path.join(logo_dir, filename), "PNG", optimize=True)
        print(f"logo  {filename:<26} {size}x{size}")


if __name__ == "__main__":
    main()

