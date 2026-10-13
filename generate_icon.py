#!/usr/bin/env python3
"""
Generate Nexora app icon - geometric design representing convergence/organization
A central hexagon with 6 surrounding circles converging toward center
"""

import os
import math
from PIL import Image, ImageDraw

# iOS icon sizes
SIZES = [
    (20, 20), (20, 20), (29, 29), (29, 29), (40, 40), (40, 40),
    (58, 58), (60, 60), (76, 76), (80, 80), (87, 87), (120, 120),
    (152, 152), (167, 167), (180, 180), (1024, 1024)
]

def draw_icon(draw, size, center_x, center_y, radius):
    """Draw the Nexora icon: central hexagon with 6 converging elements"""
    
    # Colors
    bg_color = (0x1A, 0x1A, 0x2E, 255)  # Dark navy background
    primary_color = (0x00, 0xD4, 0xAA, 255)  # Teal/cyan primary
    secondary_color = (0x63, 0x66, 0xF1, 255)  # Indigo secondary
    accent_color = (0xF5, 0x9E, 0x0B, 255)  # Amber accent
    white = (255, 255, 255, 255)
    
    # Background circle
    margin = size * 0.08
    draw.ellipse([
        margin, margin, 
        size - margin, size - margin
    ], fill=bg_color)
    
    # Central hexagon
    hex_radius = radius * 0.28
    hex_points = []
    for i in range(6):
        angle = math.radians(i * 60 - 30)
        x = center_x + hex_radius * math.cos(angle)
        y = center_y + hex_radius * math.sin(angle)
        hex_points.append((x, y))
    
    # Draw central hexagon
    draw.polygon(hex_points, fill=primary_color)
    
    # Draw 6 converging elements around the hexagon
    for i in range(6):
        angle = math.radians(i * 60 - 30)
        outer_r = radius * 0.65
        outer_x = center_x + outer_r * math.cos(angle)
        outer_y = center_y + outer_r * math.sin(angle)
        
        inner_r = hex_radius * 1.15
        inner_x = center_x + inner_r * math.cos(angle)
        inner_y = center_y + inner_r * math.sin(angle)
        
        colors = [primary_color, secondary_color, accent_color, primary_color, secondary_color, accent_color]
        color = colors[i]
        
        # Draw connecting line
        line_width = max(2, size // 100)
        draw.line([
            outer_x, outer_y,
            inner_x, inner_y
        ], fill=color, width=line_width)
        
        # Draw outer circle
        circle_r = max(4, size // 50)
        draw.ellipse([
            outer_x - circle_r, outer_y - circle_r,
            outer_x + circle_r, outer_y + circle_r
        ], fill=color)
        
        # Draw inner small circle at hexagon corner
        inner_circle_r = max(3, size // 80)
        corner_x = center_x + hex_radius * math.cos(angle)
        corner_y = center_y + hex_radius * math.sin(angle)
        draw.ellipse([
            corner_x - inner_circle_r, corner_y - inner_circle_r,
            corner_x + inner_circle_r, corner_y + inner_circle_r
        ], fill=white)
    
    # Inner glow on hexagon
    inner_hex_radius = hex_radius * 0.6
    inner_hex_points = []
    for i in range(6):
        angle = math.radians(i * 60 - 30)
        x = center_x + inner_hex_radius * math.cos(angle)
        y = center_y + inner_hex_radius * math.sin(angle)
        inner_hex_points.append((x, y))
    
    draw.polygon(inner_hex_points, fill=(255, 255, 255, 40))
    
    # Central dot
    dot_r = max(2, size // 120)
    draw.ellipse([
        center_x - dot_r, center_y - dot_r,
        center_x + dot_r, center_y + dot_r
    ], fill=white)


def generate_icons():
    output_dir = r"C:\Dev\_Mathieu\02_Projets\Perso\Nexora\Nexora\Resources\Assets.xcassets\AppIcon.appiconset"
    
    # Backup original
    import shutil
    original = os.path.join(output_dir, "AppIcon.jpg")
    backup = os.path.join(output_dir, "AppIcon_MuscuLog_backup.jpg")
    if os.path.exists(original):
        shutil.copy2(original, backup)
        print(f"Backed up original to {backup}")
    
    # Get unique sizes
    unique_sizes = sorted(set([s[0] for s in SIZES]))
    
    for size in unique_sizes:
        max_scale = max([s[1] // s[0] for s in SIZES if s[0] == size])
        render_size = size * max_scale
        
        img = Image.new('RGBA', (render_size, render_size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        center = render_size // 2
        radius = min(render_size, render_size) // 2 - int(render_size * 0.08)
        
        draw_icon(draw, render_size, center, center, radius)
        
        # Save
        filename = f"AppIcon_{size}@{max_scale}x.png"
        if max_scale == 1:
            filename = f"AppIcon_{size}.png"
        filepath = os.path.join(output_dir, filename)
        img.save(filepath, 'PNG')
        print(f"Generated: {filename} ({render_size}x{render_size})")
    
    # High-res 1024 for App Store
    img_1024 = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img_1024)
    draw_icon(draw, 1024, 512, 512, 470)
    img_1024.save(os.path.join(output_dir, "AppIcon_1024.png"), 'PNG')
    print("Generated: AppIcon_1024.png (1024x1024)")
    
    print("\nDone! Update Contents.json to reference new PNG files.")


if __name__ == "__main__":
    generate_icons()