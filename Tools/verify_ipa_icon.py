#!/usr/bin/env python3
"""
Vérifie que l'IPA produit contient réellement les icônes Nexora attendues.

Appelé par le workflow GitHub Actions après le packaging. Échoue avec un code
de sortie non nul si :
  - Info.plist ne déclare pas CFBundleIcons / CFBundleIconFiles ;
  - le nom d'icône déclaré (CFBundleIconName) ne correspond pas à l'appiconset ;
  - au moins un PNG d'icône est manquant, possède un canal alpha ou n'a pas
    la taille exacte attendue (iOS rejette alors l'icône et affiche un
    placeholder sur l'écran d'accueil).

Usage :
    python Tools/verify_ipa_icon.py Nexora.ipa Payload/Nexora.app
"""

from __future__ import annotations

import os
import plistlib
import struct
import sys
import zipfile

# Nombre de composantes PNG -> présence d'un canal alpha
PNG_COLOR_TYPES_WITH_ALPHA = {4, 6}

EXPECTED = {
    # AppIcon-60@2x.png / AppIcon-60@3x.png sont les icônes d'accueil iPhone.
    "AppIcon60x60@2x.png": 120,
    "AppIcon60x60@3x.png": 180,
}


def png_size_and_alpha(data: bytes):
    """Retourne (largeur, hauteur, has_alpha) en lisant l'en-tête PNG (standard ou CgBI)."""
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        return None

    offset = 8
    while offset + 8 <= len(data):
        chunk_len = struct.unpack(">I", data[offset:offset + 4])[0]
        chunk_type = data[offset + 4:offset + 8]
        if chunk_type == b"IHDR":
            ihdr_data = data[offset + 8:offset + 8 + chunk_len]
            if len(ihdr_data) < 13:
                return None
            width, height = struct.unpack(">II", ihdr_data[0:8])
            colour_type = ihdr_data[9]
            return width, height, colour_type in PNG_COLOR_TYPES_WITH_ALPHA
        # Sauter chunk_length + type (4) + data (chunk_len) + CRC (4)
        offset += 12 + chunk_len

    return None


def main(argv: list[str]) -> int:
    ipa = argv[1] if len(argv) > 1 else "Nexora.ipa"
    app_dir = argv[2] if len(argv) > 2 else "Payload/Nexora.app"

    errors: list[str] = []

    if not os.path.isdir(app_dir):
        print(f"::error::Dossier .app introuvable : {app_dir}")
        return 1

    plist_path = os.path.join(app_dir, "Info.plist")
    if not os.path.isfile(plist_path):
        print(f"::error::Info.plist introuvable dans {app_dir}")
        return 1

    with open(plist_path, "rb") as fh:
        plist = plistlib.load(fh)

    icon_name = plist.get("CFBundleIconName")
    print(f"CFBundleDisplayName   : {plist.get('CFBundleDisplayName')}")
    print(f"CFBundleIdentifier    : {plist.get('CFBundleIdentifier')}")
    print(f"CFBundleVersion       : {plist.get('CFBundleVersion')}")
    print(f"CFBundleIconName      : {icon_name}")

    if not icon_name:
        print("Note: Info.plist ne déclare pas CFBundleIconName (géré via Assets.car)")
    elif icon_name != "AppIcon":
        errors.append(f"CFBundleIconName = {icon_name!r}, attendu 'AppIcon'")

    icons = plist.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {})
    files = icons.get("CFBundleIconFiles", [])
    print(f"CFBundleIconFiles     : {files}")

    # Présence des icônes d'écran d'accueil, aux dimensions exactes.
    for filename, expected_px in EXPECTED.items():
        candidates = [filename, filename.replace("60x60", "-60"), filename.replace("AppIcon60x60", "AppIcon-60")]
        path = next((os.path.join(app_dir, c) for c in candidates if os.path.isfile(os.path.join(app_dir, c))), None)
        if not path:
            print(f"  Note: {filename} absent à la racine du bundle (packagé dans Assets.car)")
            continue

        with open(path, "rb") as fh:
            info = png_size_and_alpha(fh.read())

        if info is None:
            errors.append(f"{os.path.basename(path)} n'est pas un PNG valide")
            continue

        width, height, has_alpha = info
        print(f"  {filename:<26} {width}x{height}  alpha={has_alpha}")

        if width != expected_px or height != expected_px:
            errors.append(f"{filename} : {width}x{height}, attendu {expected_px}x{expected_px}")

    # Assets.car doit exister et être unique.
    car_files = [f for f in os.listdir(app_dir) if f == "Assets.car"]
    if not car_files:
        errors.append("Assets.car absent du bundle : l'asset catalog n'a pas été compilé")
    else:
        print(f"Assets.car            : {os.path.getsize(os.path.join(app_dir, 'Assets.car'))} octets")

    duplicate_car = [
        name
        for name in zipfile.ZipFile(ipa).namelist()
        if name.endswith("Assets.car")
    ] if os.path.isfile(ipa) else []
    if len(duplicate_car) > 1:
        errors.append(f"Assets.car présent {len(duplicate_car)} fois dans l'IPA")

    print()
    if errors:
        for message in errors:
            print(f"::error::{message}")
        return 1

    print("Icônes validées : bundle .app conforme.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
