#!/usr/bin/env python3
"""Build iOS icon renditions from Nexora's approved, full-resolution artwork.

The artwork is uniformly enlarged and center-cropped to the square icon canvas.
No color matte, rounded-corner mask, logo redraw, or non-uniform scaling is used.
This removes the source tile's outer transparent margin so iOS can apply its own
icon mask. In-app preview images use the same crop as the corresponding icon.

Usage: python Tools/generate_alternate_icons.py [--preview PATH]
Requires Pillow.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
REFERENCE_DIR = ROOT / "Tools" / "logo-references"
ASSET_CATALOG = ROOT / "Nexora" / "Resources" / "Assets.xcassets"
COVER_SCALE = 1.45

ICON_SETS = {
    "AppIcon": ("01_N_degrade_fond_bleu.png", "NexoraLogo"),
    "AppIcon-Gradient": ("02_N_degrade_fond_clair.png", "NexoraLogoGradient"),
    "AppIcon-Minimal": ("03_symbole_progression.png", "NexoraLogoMinimal"),
    "AppIcon-Bold": ("04_etoile.png", "NexoraLogoBold"),
    "AppIcon-Mono": ("05_N_circulaire.png", "NexoraLogoMono"),
}


def pixel_size(image_spec: dict) -> int:
    points = float(image_spec["size"].split("x", maxsplit=1)[0])
    scale = float(image_spec["scale"].removesuffix("x"))
    result = points * scale
    if not result.is_integer():
        raise ValueError(f"Non-integral icon pixel size in {image_spec!r}")
    return int(result)


def render_artwork(source_path: Path, size: int) -> Image.Image:
    source = Image.open(source_path).convert("RGBA")
    if source.width != source.height:
        raise ValueError(f"Icon reference must be square: {source_path}")

    crop_side = round(source.width / COVER_SCALE)
    left = (source.width - crop_side) // 2
    top = (source.height - crop_side) // 2
    image = source.crop((left, top, left + crop_side, top + crop_side))
    image = image.resize((size, size), Image.Resampling.LANCZOS)

    # iOS app-icon renditions must be opaque. The crop retains original artwork
    # colors at the edge; discard only its remaining antialias alpha instead of
    # compositing the mark onto an invented, uniform background.
    image.putalpha(255)
    return image.convert("RGB")


def unique_images(contents: dict):
    seen: dict[str, int] = {}
    for spec in contents.get("images", []):
        filename = spec.get("filename")
        if not filename:
            raise ValueError("An app-icon entry is missing its filename")
        size = pixel_size(spec)
        if filename in seen:
            if seen[filename] != size:
                raise ValueError(f"Conflicting dimensions for {filename!r}")
            continue
        seen[filename] = size
        yield filename, size


def create_preview(path: Path) -> None:
    tile_size = 320
    margin = 30
    label_height = 48
    labels = ["Primary", "Gradient", "Minimal", "Bold", "Mono"]
    width = margin + len(labels) * (tile_size + margin)
    height = tile_size + label_height + margin * 2
    sheet = Image.new("RGB", (width, height), (239, 241, 245))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()

    for index, (set_name, _) in enumerate(ICON_SETS.items()):
        source = ASSET_CATALOG / f"{set_name}.appiconset" / {
            "AppIcon": "AppIcon-1024.png",
            "AppIcon-Gradient": "AppIcon-Gradient-1024.png",
            "AppIcon-Minimal": "AppIcon-Minimal-1024.png",
            "AppIcon-Bold": "AppIcon-Bold-1024.png",
            "AppIcon-Mono": "AppIcon-Mono-1024.png",
        }[set_name]
        with Image.open(source) as icon:
            tile = icon.convert("RGB").resize((tile_size, tile_size), Image.Resampling.LANCZOS)
        x = margin + index * (tile_size + margin)
        y = margin
        sheet.paste(tile, (x, y))
        draw.text((x, y + tile_size + 12), labels[index], fill=(25, 31, 44), font=font)

    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, "PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path, help="Write a comparison sheet of the five generated 1024 px icons")
    args = parser.parse_args()

    total = 0
    for set_name, (reference_name, logo_asset_name) in ICON_SETS.items():
        set_dir = ASSET_CATALOG / f"{set_name}.appiconset"
        contents_path = set_dir / "Contents.json"
        if not contents_path.is_file():
            raise FileNotFoundError(f"Missing icon catalog: {contents_path}")

        source_path = REFERENCE_DIR / reference_name
        if not source_path.is_file():
            raise FileNotFoundError(f"Missing approved artwork: {source_path}")

        contents = json.loads(contents_path.read_text(encoding="utf-8-sig"))
        cache: dict[int, Image.Image] = {}
        for filename, size in unique_images(contents):
            if size not in cache:
                cache[size] = render_artwork(source_path, size)
            destination = set_dir / filename
            cache[size].save(destination, "PNG", optimize=True)
            with Image.open(destination) as check:
                if check.size != (size, size) or check.mode != "RGB":
                    raise ValueError(f"Invalid icon rendition: {destination}")
            total += 1

        logo_dir = ASSET_CATALOG / f"{logo_asset_name}.imageset"
        logo_contents_path = logo_dir / "Contents.json"
        logo_contents = json.loads(logo_contents_path.read_text(encoding="utf-8-sig"))
        for spec in logo_contents.get("images", []):
            filename = spec.get("filename")
            if not filename:
                raise ValueError(f"An image-set entry has no filename in {logo_contents_path}")
            size = int(spec["scale"].removesuffix("x")) * 48
            if size not in cache:
                cache[size] = render_artwork(source_path, size)
            cache[size].save(logo_dir / filename, "PNG", optimize=True)

    if args.preview:
        create_preview(args.preview)
        print(f"Comparison sheet written to {args.preview}")
    print(f"Generated {total} app-icon renditions and five matching in-app previews.")


if __name__ == "__main__":
    main()
