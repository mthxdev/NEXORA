#!/usr/bin/env python3
"""Verify Nexora's primary and alternate icons in an IPA and its Assets.car.

This checks the generated Info.plist declarations, opaque source renditions,
the catalog names and iPhone sizes compiled into Assets.car, and byte-for-byte
identity of Assets.car inside the IPA. The uploaded PNG previews are copies of
the exact 1024 px source renditions compiled during this workflow run.
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


ICON_SETS = {
    "AppIcon": "Icon-Primary.png",
    "AppIcon-Gradient": "Icon-Gradient.png",
    "AppIcon-Minimal": "Icon-Minimal.png",
    "AppIcon-Bold": "Icon-Bold.png",
    "AppIcon-Mono": "Icon-Mono.png",
}
LOGO_ASSETS = {
    "AppIcon": "NexoraLogo",
    "AppIcon-Gradient": "NexoraLogoGradient",
    "AppIcon-Minimal": "NexoraLogoMinimal",
    "AppIcon-Bold": "NexoraLogoBold",
    "AppIcon-Mono": "NexoraLogoMono",
}
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    distances = (abs(estimate - left), abs(estimate - above), abs(estimate - upper_left))
    return (left, above, upper_left)[distances.index(min(distances))]


def decode_png(data: bytes) -> tuple[int, int, bytes]:
    """Decode a non-interlaced 8-bit RGB/RGBA PNG (including Apple CgBI)."""
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("not a PNG file")
    offset = len(PNG_SIGNATURE)
    cgbi = False
    header = None
    compressed = bytearray()
    while offset + 12 <= len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        start, end = offset + 8, offset + 8 + length
        if end + 4 > len(data):
            raise ValueError("truncated PNG chunk")
        chunk = data[start:end]
        if kind == b"CgBI":
            cgbi = True
        elif kind == b"IHDR":
            header = chunk
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            break
        offset = end + 4

    if header is None or len(header) != 13:
        raise ValueError("PNG is missing a valid IHDR")
    width, height, depth, color_type, compression, filtering, interlace = struct.unpack(
        ">IIBBBBB", header
    )
    if not width or not height or depth != 8 or color_type not in (2, 6):
        raise ValueError(f"unsupported PNG format: {width}x{height}, depth={depth}, type={color_type}")
    if compression or filtering or interlace:
        raise ValueError("unsupported PNG compression/filter/interlace mode")
    if cgbi and color_type != 6:
        raise ValueError("Apple CgBI image must use RGBA")

    bpp = 4 if color_type == 6 else 3
    stride = width * bpp
    try:
        raw = zlib.decompress(bytes(compressed), -15 if cgbi else zlib.MAX_WBITS)
    except zlib.error as exc:
        raise ValueError(f"invalid PNG data: {exc}") from exc
    if len(raw) != height * (stride + 1):
        raise ValueError("PNG decompressed size does not match dimensions")

    rgba = bytearray(width * height * 4)
    previous = bytearray(stride)
    cursor = 0
    for y in range(height):
        filter_type = raw[cursor]
        cursor += 1
        row = bytearray(raw[cursor:cursor + stride])
        cursor += stride
        for x in range(stride):
            left = row[x - bpp] if x >= bpp else 0
            above = previous[x]
            upper_left = previous[x - bpp] if x >= bpp else 0
            if filter_type == 1:
                row[x] = (row[x] + left) & 255
            elif filter_type == 2:
                row[x] = (row[x] + above) & 255
            elif filter_type == 3:
                row[x] = (row[x] + (left + above) // 2) & 255
            elif filter_type == 4:
                row[x] = (row[x] + _paeth(left, above, upper_left)) & 255
            elif filter_type != 0:
                raise ValueError(f"unsupported PNG filter {filter_type}")
        for x in range(width):
            source, target = x * bpp, (y * width + x) * 4
            if color_type == 2:
                red, green, blue = row[source:source + 3]
                alpha = 255
            elif cgbi:
                blue, green, red, alpha = row[source:source + 4]
                if alpha == 0:
                    red = green = blue = 0
                elif alpha < 255:
                    red = min(255, (red * 255 + alpha // 2) // alpha)
                    green = min(255, (green * 255 + alpha // 2) // alpha)
                    blue = min(255, (blue * 255 + alpha // 2) // alpha)
            else:
                red, green, blue, alpha = row[source:source + 4]
            rgba[target:target + 4] = bytes((red, green, blue, alpha))
        previous = row
    return width, height, bytes(rgba)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def inspect_catalog(catalog: Path, proof_dir: Path, errors: list[str]) -> list[dict]:
    manifest = []
    for set_name, preview_filename in ICON_SETS.items():
        set_dir = catalog / f"{set_name}.appiconset"
        contents_path = set_dir / "Contents.json"
        if not contents_path.is_file():
            errors.append(f"Missing icon catalog {contents_path}")
            continue
        try:
            contents = json.loads(contents_path.read_text(encoding="utf-8-sig"))
            entries = contents.get("images", [])
            if not entries:
                errors.append(f"No renditions declared in {contents_path}")
                continue
            names = set()
            sizes = set()
            for entry in entries:
                filename = entry.get("filename")
                if not filename:
                    errors.append(f"Filename missing in {contents_path}")
                    continue
                path = set_dir / filename
                if not path.is_file():
                    errors.append(f"Missing rendition {path}")
                    continue
                width, height, rgba = decode_png(path.read_bytes())
                point_size = float(entry["size"].split("x", maxsplit=1)[0])
                scale = float(entry["scale"].removesuffix("x"))
                expected = round(point_size * scale)
                if (width, height) != (expected, expected):
                    errors.append(f"{path}: {width}x{height}, expected {expected}x{expected}")
                if any(alpha != 255 for alpha in rgba[3::4]):
                    errors.append(f"{path}: icon rendition is not fully opaque")
                names.add(filename)
                sizes.add((width, height))
            full_size_filename = next((name for name in names if name.endswith("1024.png")), None)
            if full_size_filename is None:
                errors.append(f"{set_name} has no 1024 px marketing rendition")
                continue
            full_path = set_dir / full_size_filename
            full_bytes = full_path.read_bytes()
            expected_preview = proof_dir / preview_filename
            expected_preview.parent.mkdir(parents=True, exist_ok=True)
            expected_preview.write_bytes(full_bytes)
            logo_dir = catalog / f"{LOGO_ASSETS[set_name]}.imageset"
            logo_3x = logo_dir / f"{LOGO_ASSETS[set_name]}@3x.png"
            if not logo_3x.is_file():
                errors.append(f"Missing in-app preview {logo_3x}")
            else:
                _, _, logo_rgba = decode_png(logo_3x.read_bytes())
                if any(alpha != 255 for alpha in logo_rgba[3::4]):
                    errors.append(f"{logo_3x}: preview image is not opaque")
            manifest.append({
                "assetCatalogName": set_name,
                "inAppPreviewAsset": LOGO_ASSETS[set_name],
                "renditionCount": len(names),
                "pixelSizes": [list(size) for size in sorted(sizes)],
                "1024PreviewFile": preview_filename,
                "1024PreviewSHA256": sha256(full_bytes),
            })
        except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
            errors.append(f"Invalid icon catalog {set_name}: {exc}")
    return manifest


def run_assetutil(assets_car: Path, name: str) -> tuple[list[dict] | None, str]:
    xcrun = shutil.which("xcrun")
    if not xcrun:
        raise RuntimeError("xcrun is unavailable; cannot inspect compiled Assets.car")
    command = [xcrun, "--sdk", "iphoneos", "assetutil", f"--info={name}", str(assets_car)]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError(f"assetutil failed for {name} (exit {result.returncode}): {result.stderr.strip()}")
    return json.loads(result.stdout), result.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", nargs="?", default="Nexora.ipa")
    parser.add_argument("app_dir", nargs="?", default="Payload/Nexora.app")
    parser.add_argument("--catalog", default="Nexora/Resources/Assets.xcassets")
    parser.add_argument("--proof-dir", default="icon-proof")
    args = parser.parse_args()

    ipa, app_dir = Path(args.ipa), Path(args.app_dir)
    catalog, proof_dir = Path(args.catalog), Path(args.proof_dir)
    errors: list[str] = []
    if not ipa.is_file() or not app_dir.is_dir():
        print(f"::error::IPA or built .app is missing: {ipa}, {app_dir}")
        return 1
    plist_path = app_dir / "Info.plist"
    if not plist_path.is_file():
        print(f"::error::Info.plist missing in {app_dir}")
        return 1

    plist = plistlib.loads(plist_path.read_bytes())
    bundle_identifier = plist.get("CFBundleIdentifier")
    version = plist.get("CFBundleShortVersionString")
    build = plist.get("CFBundleVersion")
    icon_root = plist.get("CFBundleIcons", {})
    primary = icon_root.get("CFBundlePrimaryIcon", {})
    alternate_icons = icon_root.get("CFBundleAlternateIcons", {})
    primary_name = primary.get("CFBundleIconName")
    print(f"Bundle ID             : {bundle_identifier}")
    print(f"Version / build       : {version} ({build})")
    print(f"Primary icon catalog  : {primary_name}")
    print(f"Alternate icons       : {sorted(alternate_icons)}")
    if bundle_identifier != "com.mathieu.musculog":
        errors.append(f"Unexpected Bundle ID {bundle_identifier!r}")
    if primary_name != "AppIcon":
        errors.append(f"Primary icon name is {primary_name!r}, expected AppIcon")
    expected_alternates = set(ICON_SETS) - {"AppIcon"}
    if set(alternate_icons) != expected_alternates:
        errors.append(f"Info.plist alternate icon names {sorted(alternate_icons)} do not match {sorted(expected_alternates)}")
    for name in expected_alternates:
        entry = alternate_icons.get(name, {})
        if entry.get("CFBundleIconName") != name:
            errors.append(f"Info.plist entry {name} points to {entry.get('CFBundleIconName')!r}")

    source_manifest = inspect_catalog(catalog, proof_dir, errors)
    assets_car = app_dir / "Assets.car"
    if not assets_car.is_file():
        errors.append("Assets.car is missing from the built app")
        car_data = b""
    else:
        car_data = assets_car.read_bytes()
        print(f"Assets.car SHA-256    : {sha256(car_data)} ({len(car_data)} bytes)")

    try:
        with zipfile.ZipFile(ipa) as archive:
            names = archive.namelist()
            app_prefix = "Payload/Nexora.app/"
            car_names = [name for name in names if name.endswith("/Assets.car")]
            if len(car_names) != 1:
                errors.append(f"IPA must contain exactly one Assets.car; found {len(car_names)}")
            elif archive.read(car_names[0]) != car_data:
                errors.append("Assets.car inside IPA differs from the inspected app bundle")
            zip_plist = app_prefix + "Info.plist"
            if zip_plist not in names:
                errors.append(f"IPA is missing {zip_plist}")
            elif archive.read(zip_plist) != plist_path.read_bytes():
                errors.append("Info.plist inside IPA differs from the inspected app bundle")
            if "Payload/Nexora.app/Info.plist" not in names:
                errors.append("IPA does not contain Payload/Nexora.app/Info.plist")
    except (OSError, zipfile.BadZipFile, KeyError) as exc:
        errors.append(f"Unable to inspect IPA archive: {exc}")

    asset_metadata = {}
    if assets_car.is_file():
        for name in ICON_SETS:
            try:
                records, raw = run_assetutil(assets_car, name)
                records = records or []
                icon_records = [
                    record for record in records
                    if record.get("AssetType") == "Icon Image"
                    or record.get("Name") == name
                    or record.get("RenditionName") == name
                ]
                sized_icon_records = [
                    record for record in icon_records
                    if type(record.get("PixelWidth")) is int
                    and type(record.get("PixelHeight")) is int
                ]
                sizes = {
                    (record["PixelWidth"], record["PixelHeight"])
                    for record in sized_icon_records
                }
                if not sized_icon_records:
                    errors.append(f"Assets.car has no icon renditions named {name}")
                for required in ((120, 120), (180, 180)):
                    if required not in sizes:
                        errors.append(f"Assets.car {name} is missing {required[0]}x{required[1]} iPhone rendition; saw {sorted(map(str, sizes))}")
                asset_metadata[name] = {
                    "renditionCount": len(sized_icon_records),
                    "pixelSizes": [list(size) for size in sorted(sizes)],
                }
                (proof_dir / f"Assets-car-{name}.json").write_text(raw, encoding="utf-8")
                print(f"Assets.car {name:<20}: {len(sized_icon_records)} icon renditions; {sorted(sizes)}")
            except (OSError, RuntimeError, json.JSONDecodeError, TypeError, AttributeError) as exc:
                errors.append(str(exc))

    proof_dir.mkdir(parents=True, exist_ok=True)
    proof = {
        "bundleIdentifier": bundle_identifier,
        "version": version,
        "build": build,
        "primaryIcon": primary_name,
        "alternateIcons": sorted(alternate_icons),
        "assetsCarSHA256": sha256(car_data) if car_data else None,
        "catalogSourceRenditions": source_manifest,
        "compiledAssetsCarIcons": asset_metadata,
        "comparisonSheet": "Comparison.png",
        "verificationScope": "Info.plist declaration, source icon pixels, assetutil catalog metadata, and byte-identical Assets.car in IPA",
    }
    (proof_dir / "manifest.json").write_text(json.dumps(proof, indent=2), encoding="utf-8")
    if not (proof_dir / "Comparison.png").is_file():
        errors.append("Icon comparison sheet is missing from proof artifacts")

    if errors:
        for error in errors:
            print(f"::error::{error}")
        return 1
    print(f"Icon verification proof written to {proof_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
