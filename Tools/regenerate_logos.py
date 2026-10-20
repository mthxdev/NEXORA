from PIL import Image
import os

mapping = {
    '01_N_degrade_fond_bleu.png': 'NexoraLogo',
    '02_N_degrade_fond_clair.png': 'NexoraLogoGradient',
    '03_symbole_progression.png': 'NexoraLogoMinimal',
    '04_etoile.png': 'NexoraLogoBold',
    '05_N_circulaire.png': 'NexoraLogoMono',
}

sizes = {'1x': 48, '2x': 96, '3x': 144}

src_dir = r'C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Tools\logo-references'
dst_base = r'C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Nexora\Resources\Assets.xcassets'

for src_file, imageset_name in mapping.items():
    src_path = os.path.join(src_dir, src_file)
    img = Image.open(src_path)

    # Keep RGBA mode to preserve transparency
    if img.mode != 'RGBA':
        img = img.convert('RGBA')

    dst_dir = os.path.join(dst_base, imageset_name + '.imageset')
    os.makedirs(dst_dir, exist_ok=True)

    for scale, size in sizes.items():
        resized = img.resize((size, size), Image.LANCZOS)
        suffix = '.png' if scale == '1x' else f'@{scale}.png'
        dst_file = os.path.join(dst_dir, imageset_name + suffix)
        resized.save(dst_file, 'PNG', optimize=True)
        print(f'Created {dst_file} ({size}x{size}) mode={resized.mode}')

print('Done!')