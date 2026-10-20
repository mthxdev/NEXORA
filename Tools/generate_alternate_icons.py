from PIL import Image
import os
import json

# Mapping: source file -> alternative icon name (matching AppLogo enum)
mapping = {
    '01_N_degrade_fond_bleu.png': 'Classic',
    '02_N_degrade_fond_clair.png': 'Gradient',
    '03_symbole_progression.png': 'Minimal',
    '04_etoile.png': 'Bold',
    '05_N_circulaire.png': 'Mono',
}

# Only iPhone sizes (since TARGETED_DEVICE_FAMILY = 1)
ICON_SIZES = [
    ("20", "iphone", "2x"),
    ("20", "iphone", "3x"),
    ("29", "iphone", "2x"),
    ("29", "iphone", "3x"),
    ("40", "iphone", "2x"),
    ("40", "iphone", "3x"),
    ("60", "iphone", "2x"),
    ("60", "iphone", "3x"),
    ("1024", "ios-marketing", "1x"),
]

src_dir = r'C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Tools\logo-references'
dst_dir = r'C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Nexora\Resources\Assets.xcassets\AppIcon.appiconset'

# Load existing contents
contents_path = os.path.join(dst_dir, 'Contents.json')
with open(contents_path, 'r') as f:
    contents = json.load(f)

# Remove existing alternative icon entries
contents['images'] = [img for img in contents['images'] if not img['filename'].startswith('AppIcon-Classic') and not img['filename'].startswith('AppIcon-Gradient') and not img['filename'].startswith('AppIcon-Minimal') and not img['filename'].startswith('AppIcon-Bold') and not img['filename'].startswith('AppIcon-Mono')]

# Track existing filenames to avoid duplicates
existing_files = {img['filename'] for img in contents['images']}

for src_file, alt_name in mapping.items():
    src_path = os.path.join(r'C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Tools\logo-references', src_file)
    img = Image.open(src_path)
    
    # Convert to RGBA first if needed
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # For app icons, iOS requires OPAQUE images (no alpha channel)
    # Create white background and paste with alpha mask
    background = Image.new('RGB', img.size, (255, 255, 255))
    background.paste(img, mask=img.split()[3])
    img = background
    
    for size_str, idiom, scale in ICON_SIZES:
        size = int(float(size_str))
        if scale == "1x":
            suffix = ""
        else:
            suffix = f"@{scale}"
        
        filename = f"AppIcon-{alt_name}-{size_str}{suffix}.png"
        
        if filename in existing_files:
            print(f"Skipping existing: {filename}")
            continue
        
        resized = img.resize((size, size), Image.LANCZOS)
        dst_file = os.path.join(dst_dir, filename)
        resized.save(dst_file, 'PNG', optimize=True)
        print(f'Created {filename} ({size}x{size})')
        
        json_idiom = "iphone" if idiom == "iphone" else "ios-marketing"
        
        contents['images'].append({
            "filename": filename,
            "idiom": json_idiom,
            "size": f"{size_str}x{size_str}",
            "scale": f"{scale}x" if scale != "1x" else "1x"
        })
        existing_files.add(filename)

# Write updated Contents.json
with open(contents_path, 'w') as f:
    json.dump(contents, f, indent=2)

print("Done! Updated Contents.json with alternative icons.")