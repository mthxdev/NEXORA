#!/usr/bin/env python3
"""Verify the built IPA's primary icon pixels and compiled AppIcon catalog.

The verifier normalizes Apple's CgBI PNG rendition for a visual proof artifact,
checks the four rendered corners against the approved opaque background, and
queries the built Assets.car with Xcode's assetutil.

Usage:
    python Tools/verify_ipa_icon.py Nexora.ipa Payload/Nexora.app --proof-dir icon-proof
"""

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import shutil
import struct
import subprocess
import sys
import zipfile
import zlib
from pathlib import Path


EXPECTED_RENDITIONS = {
    "AppIcon60x60@2x.png": (120, 120),
    "AppIcon60x60@3x.png": (180, 180),
}
EXPECTED_BACKGROUND = (7, 54, 108)
CORNER_TOLERANCE = 16
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    distances = (abs(estimate - left), abs(estimate - above), abs(estimate - upper_left))
    return (left, above, upper_left)[distances.index(min(distances))]


def decode_png(data: bytes) -> tuple[int, int, bytes, bool]:
    """Decode non-interlaced 8-bit RGB/RGBA PNG, including Apple's CgBI variant."""
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("not a PNG file")

    offset = len(PNG_SIGNATURE)
    cgbi = False
    header: bytes | None = None
    compressed = bytearray()
    while offset + 12 <= len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        chunk_type = data[offset + 4:offset + 8]
        start = offset + 8
        end = start + length
        if end + 4 > len(data):
            raise ValueError("truncated PNG chunk")
        chunk = data[start:end]
        if chunk_type == b"CgBI":
            cgbi = True
        elif chunk_type == b"IHDR":
            header = chunk
        elif chunk_type == b"IDAT":
            compressed.extend(chunk)
        elif chunk_type == b"IEND":
            break
        offset = end + 4

    if header is None or len(header) != 13:
        raise ValueError("PNG is missing a valid IHDR")
    width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(
        ">IIBBBBB", header
    )
    if not width or not height or bit_depth != 8 or color_type not in (2, 6):
        raise ValueError(f"unsupported PNG format: {width}x{height}, depth={bit_depth}, type={color_type}")
    if compression != 0 or filtering != 0 or interlace != 0:
        raise ValueError("unsupported PNG compression, filter method, or interlacing")
    if cgbi and color_type != 6:
        raise ValueError("Apple CgBI PNG must use RGBA color type")

    bytes_per_pixel = 4 if color_type == 6 else 3
    stride = width * bytes_per_pixel
    try:
        raw = zlib.decompress(bytes(compressed), -15 if cgbi else zlib.MAX_WBITS)
    except zlib.error as exc:
        raise ValueError(f"invalid PNG image data: {exc}") from exc
    if len(raw) != height * (stride + 1):
        raise ValueError("PNG decompressed data has an unexpected size")

    rgba = bytearray(width * height * 4)
    previous = bytearray(stride)
    cursor = 0
    for y in range(height):
        filter_type = raw[cursor]
        cursor += 1
        row = bytearray(raw[cursor:cursor + stride])
        cursor += stride
        for x in range(stride):
            left = row[x - bytes_per_pixel] if x >= bytes_per_pixel else 0
            above = previous[x]
            upper_left = previous[x - bytes_per_pixel] if x >= bytes_per_pixel else 0
            if filter_type == 1:
                row[x] = (row[x] + left) & 0xFF
            elif filter_type == 2:
                row[x] = (row[x] + above) & 0xFF
            elif filter_type == 3:
                row[x] = (row[x] + ((left + above) // 2)) & 0xFF
            elif filter_type == 4:
                row[x] = (row[x] + _paeth(left, above, upper_left)) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"unsupported PNG filter {filter_type}")

        for x in range(width):
            source_index = x * bytes_per_pixel
            target_index = (y * width + x) * 4
            if color_type == 2:
                red, green, blue = row[source_index:source_index + 3]
                alpha = 255
            elif cgbi:
                blue, green, red, alpha = row[source_index:source_index + 4]
                if alpha == 0:
                    red = green = blue = 0
                elif alpha < 255:
                    red = min(255, (red * 255 + alpha // 2) // alpha)
                    green = min(255, (green * 255 + alpha // 2) // alpha)
                    blue = min(255, (blue * 255 + alpha // 2) // alpha)
            else:
                red, green, blue, alpha = row[source_index:source_index + 4]
            rgba[target_index:target_index + 4] = bytes((red, green, blue, alpha))
        previous = row

    return width, height, bytes(rgba), cgbi


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
    body = kind + payload
    return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def write_rgba_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    rows = b"".join(b"\0" + rgba[y * width * 4:(y + 1) * width * 4] for y in range(height))
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        PNG_SIGNATURE
        + _png_chunk(b"IHDR", header)
        + _png_chunk(b"IDAT", zlib.compress(rows, level=9))
        + _png_chunk(b"IEND", b"")
    )


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_bundle_icon(data: bytes, filename: str, expected_size: tuple[int, int]) -> dict:
    width, height, rgba, was_cgbi = decode_png(data)
    if (width, height) != expected_size:
        raise ValueError(f"{filename}: {width}x{height}, expected {expected_size[0]}x{expected_size[1]}")

    alpha_values = rgba[3::4]
    if any(alpha != 255 for alpha in alpha_values):
        raise ValueError(f"{filename}: rendered icon contains transparent pixels")

    corners = []
    for x, y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        index = (y * width + x) * 4
        rgb = tuple(rgba[index:index + 3])
        corners.append(rgb)
        if max(rgb) > 220:
            raise ValueError(f"{filename}: white/light matte at corner ({x},{y}): {rgb}")
        if any(abs(rgb[channel] - EXPECTED_BACKGROUND[channel]) > CORNER_TOLERANCE for channel in range(3)):
            raise ValueError(f"{filename}: unexpected corner color at ({x},{y}): {rgb}")

    return {
        "filename": filename,
        "width": width,
        "height": height,
        "sourceWasAppleCgBI": was_cgbi,
        "alphaOpaque": True,
        "cornerRGB": corners,
        "sha256": sha256(rgba),
        "rgba": rgba,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", nargs="?", default="Nexora.ipa")
    parser.add_argument("app_dir", nargs="?", default="Payload/Nexora.app")
    parser.add_argument("--proof-dir", default="icon-proof")
    args = parser.parse_args()

    ipa = Path(args.ipa)
    app_dir = Path(args.app_dir)
    proof_dir = Path(args.proof_dir)
    errors: list[str] = []
    if not ipa.is_file():
        print(f"::error::IPA introuvable : {ipa}")
        return 1
    if not app_dir.is_dir():
        print(f"::error::Dossier .app introuvable : {app_dir}")
        return 1

    plist_path = app_dir / "Info.plist"
    if not plist_path.is_file():
        print(f"::error::Info.plist introuvable dans {app_dir}")
        return 1
    with plist_path.open("rb") as file:
        plist = plistlib.load(file)

    primary = plist.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
    icon_name = primary.get("CFBundleIconName")
    icon_files = primary.get("CFBundleIconFiles", [])
    print(f"CFBundleIdentifier    : {plist.get('CFBundleIdentifier')}")
    print(f"CFBundleShortVersion  : {plist.get('CFBundleShortVersionString')}")
    print(f"CFBundleVersion       : {plist.get('CFBundleVersion')}")
    print(f"CFBundleIconName      : {icon_name}")
    print(f"CFBundleIconFiles     : {icon_files}")
    if icon_name != "AppIcon":
        errors.append(f"Primary CFBundleIconName = {icon_name!r}, expected 'AppIcon'")
    if "AppIcon60x60" not in icon_files:
        errors.append("CFBundleIconFiles does not name the expected iPhone home screen icon")

    app_icons: dict[str, dict] = {}
    for filename, expected_size in EXPECTED_RENDITIONS.items():
        path = app_dir / filename
        if not path.is_file():
            errors.append(f"Built app is missing required rendered icon {filename}")
            continue
        try:
            with path.open("rb") as file:
                data = file.read()
            icon = read_bundle_icon(data, filename, expected_size)
            app_icons[filename] = icon
            print(f"{filename:<26} {icon['width']}x{icon['height']} opaque; corners={icon['cornerRGB']}")
            if filename.endswith("@2x.png"):
                write_rgba_png(proof_dir / "AppIcon60x60-120.png", icon["width"], icon["height"], icon["rgba"])
        except (OSError, ValueError) as exc:
            errors.append(str(exc))

    assets_car = app_dir / "Assets.car"
    if not assets_car.is_file():
        errors.append("Assets.car absent from the built app")
        car_data = b""
    else:
        car_data = assets_car.read_bytes()
        print(f"Assets.car            : {len(car_data)} bytes, sha256={sha256(car_data)}")

    try:
        with zipfile.ZipFile(ipa) as archive:
            app_prefix = "Payload/Nexora.app/"
            car_names = [name for name in archive.namelist() if name.endswith("/Assets.car")]
            if len(car_names) != 1:
                errors.append(f"Expected exactly one Assets.car in IPA; found {len(car_names)}")
            elif archive.read(car_names[0]) != car_data:
                errors.append("Assets.car inside the IPA differs from the verified built app")
            if app_prefix + "Info.plist" not in archive.namelist():
                errors.append("IPA is missing Payload/Nexora.app/Info.plist")
    except (OSError, zipfile.BadZipFile, KeyError) as exc:
        errors.append(f"Unable to verify IPA archive: {exc}")

    assetutil = shutil.which("xcrun")
    asset_records: list[dict] = []
    if not assetutil:
        errors.append("xcrun is unavailable; cannot inspect the compiled Assets.car AppIcon entry")
    elif assets_car.is_file():
        command = [assetutil, "--sdk", "iphoneos", "assetutil", "--info=AppIcon", str(assets_car)]
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        if result.returncode != 0:
            errors.append(f"assetutil could not find/read AppIcon (exit {result.returncode}): {result.stderr.strip()}")
        else:
            try:
                asset_records = json.loads(result.stdout)
                if not isinstance(asset_records, list) or not asset_records:
                    errors.append("assetutil returned no AppIcon renditions")
                else:
                    icon_records = [
                        record for record in asset_records
                        if "icon" in str(record.get("AssetType", "")).lower()
                        or "appicon" in str(record.get("RenditionName", "")).lower()
                        or "appicon" in str(record.get("Name", "")).lower()
                    ]
                    sizes = {
                        (record.get("PixelWidth"), record.get("PixelHeight"))
                        for record in icon_records
                    }
                    if not icon_records:
                        errors.append("assetutil found AppIcon but exposed no icon rendition metadata")
                    if (120, 120) not in sizes:
                        errors.append(f"AppIcon in Assets.car has no 120x120 rendition; reported sizes: {sorted(map(str, sizes))}")
                    print(f"assetutil AppIcon renditions: {len(icon_records)}; pixel sizes={sorted(map(str, sizes))}")
            except (json.JSONDecodeError, AttributeError, TypeError) as exc:
                errors.append(f"Invalid assetutil JSON for AppIcon: {exc}")
            proof_dir.mkdir(parents=True, exist_ok=True)
            (proof_dir / "Assets-car-AppIcon.json").write_text(result.stdout, encoding="utf-8")

    manifest = {
        "bundleIdentifier": plist.get("CFBundleIdentifier"),
        "version": plist.get("CFBundleShortVersionString"),
        "build": plist.get("CFBundleVersion"),
        "primaryIconName": icon_name,
        "assetsCarSHA256": sha256(car_data) if car_data else None,
        "iconRenditions": [
            {key: value for key, value in icon.items() if key != "rgba"}
            for icon in app_icons.values()
        ],
        "assetutilIconRenditionCount": len(asset_records),
    }
    proof_dir.mkdir(parents=True, exist_ok=True)
    (proof_dir / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    if errors:
        for message in errors:
            print(f"::error::{message}")
        return 1
    print(f"Icon proof artifacts written to: {proof_dir}")
    print("Validated the primary icon pixels and the AppIcon rendition in Assets.car.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
