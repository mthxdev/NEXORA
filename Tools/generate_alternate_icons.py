#!/usr/bin/env python3
"""Regenerate all Nexora app icon catalogs from the approved artwork references.

The transparent exterior of the reference artwork is composited onto an opaque,
style-matched background before resizing. This avoids white matte corners and
keeps all app icon renditions consistent with the 1024 px source artwork.

Usage: python Tools/generate_alternate_icons.py
Requires Pillow.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
REFERENCE_DIR = ROOT / "Tools" / "logo-references"
ASSET_CATALOG = ROOT / "Nexora" / "Resources" / "Assets.xcassets"

# Keep the existing Nexora artwork and distinguish its intentionally light
# Gradient style from the dark styles. The Classic fill samples the blue already
# present in its artwork; the dark fills match the other dark references.
ICON_SETS = {
    "AppIcon": ("01_N_degrade_fond_bleu.png", (7, 54, 108)),
    "AppIcon-Classic": ("01_N_degrade_fond_bleu.png", (7, 54, 108)),
    "AppIcon-Gradient": ("02_N_degrade_fond_clair.png", (242, 247, 255)),
    "AppIcon-Minimal": ("03_symbole_progression.png", (9, 22, 39)),
    "AppIcon-Bold": ("04_etoile.png", (9, 22, 39)),
    "AppIcon-Mono": ("05_N_circulaire.png", (9, 22, 39)),
}


def pixel_size(image_spec: dict) -> int:
    """Return the exact pixel dimension required by an appiconset entry."""
    point_size = float(image_spec["size"].split("x", maxsplit=1)[0])
    scale = float(image_spec["scale"].removesuffix("x"))
    result = point_size * scale
    if not result.is_integer():
        raise ValueError(f"Non-integral icon pixel size in {image_spec!r}")
    return int(result)


def make_opaque_icon(source_path: Path, background: tuple[int, int, int], size: int) -> Image.Image:
    source = Image.open(source_path).convert("RGBA")
    if source.width != source.height:
        raise ValueError(f"Icon reference must be square: {source_path}")

    canvas = Image.new("RGBA", source.size, background + (255,))
    canvas.alpha_composite(source)
    return canvas.convert("RGB").resize((size, size), Image.Resampling.LANCZOS)


def main() -> None:
    generated = 0
    for set_name, (reference_name, background) in ICON_SETS.items():
        set_dir = ASSET_CATALOG / f"{set_name}.appiconset"
        contents_path = set_dir / "Contents.json"
        if not contents_path.is_file():
            raise FileNotFoundError(f"Missing app icon catalog: {contents_path}")

        source_path = REFERENCE_DIR / reference_name
        if not source_path.is_file():
            raise FileNotFoundError(f"Missing icon artwork: {source_path}")

        contents = json.loads(contents_path.read_text(encoding="utf-8-sig"))
        seen: dict[str, int] = {}
        for image_spec in contents.get("images", []):
            filename = image_spec.get("filename")
            if not filename:
                raise ValueError(f"Image entry has no filename in {contents_path}")
            size = pixel_size(image_spec)
            if filename in seen:
                if seen[filename] != size:
                    raise ValueError(f"Conflicting dimensions for {filename!r} in {contents_path}")
                continue
            seen[filename] = size

            destination = set_dir / filename
            icon = make_opaque_icon(source_path, background, size)
            icon.save(destination, "PNG", optimize=True)

            with Image.open(destination) as written:
                if written.size != (size, size) or written.mode != "RGB":
                    raise ValueError(f"Invalid generated icon: {destination}")
            generated += 1
            print(f"{set_name}/{filename}: {size}x{size}, opaque RGB")

    print(f"Generated {generated} renditions across {len(ICON_SETS)} icon catalogs.")


if __name__ == "__main__":
    main()
