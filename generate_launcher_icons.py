"""
Generate official Scaneliq production launcher icons and branding assets.
Requirements:
1. Extract ONLY the central 3D 'S' ribbon and document icon from scaneliq_logo_original.jpg.
   - Remove outer light-gray background.
   - Remove rounded square neon border.
   - Remove 4 cyan corner brackets.
2. Full-bleed square background layer (1024x1024 px) filled 100% edge-to-edge with #021642.
3. Central graphic centered and scaled to ~57-60% of canvas, sitting safely inside the 66% Android safe zone.
4. Regenerate Android adaptive foregrounds, legacy mipmaps (ic_launcher, launcher_icon, ic_launcher_round), and iOS AppIcon assets.
"""

import os
import json
import math
from PIL import Image, ImageFilter

def main():
    base_dir = r"c:\Scaneliq"
    source_path = os.path.join(base_dir, "assets", "branding", "scaneliq_logo_original.jpg")
    print(f"Loading source logo: {source_path}")
    orig = Image.open(source_path).convert("RGB")
    w, h = orig.size
    assert (w, h) == (1024, 1024), f"Expected 1024x1024, got {w}x{h}"

    bg_color = (2, 22, 66) # #021642

    print("Step 1: Identifying ribbon and document core components...")
    fg_mask = set()
    for y in range(185, 833):
        for x in range(248, 722):
            # Exclude bracket regions
            if (x <= 340 and y <= 220) or (x >= 675 and y <= 220):
                continue
            if (x <= 340 and y >= 780) or (x >= 675 and y >= 780):
                continue
            r, g, b = orig.getpixel((x, y))
            is_doc = (r > 90 and g > 90 and b > 90)
            is_ribbon = (b >= 75 and (b > r + 20 or g > 45))
            if is_doc or is_ribbon:
                fg_mask.add((x, y))

    # BFS from document center (512, 512) to extract the connected ribbon+document
    visited = set([(512, 512)])
    q = [(512, 512)]
    while q:
        curr = q.pop()
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            np = (curr[0] + dx, curr[1] + dy)
            if np in fg_mask and np not in visited:
                visited.add(np)
                q.append(np)

    c0 = visited
    print(f"Found {len(c0)} core foreground pixels.")

    print("Step 2: Flood filling exterior to seal internal 3D ribbon folds and shadows...")
    exterior = set([(0, 0)])
    eq = [(0, 0)]
    while eq:
        cx, cy = eq.pop()
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < 1024 and 0 <= ny < 1024:
                if (nx, ny) not in c0 and (nx, ny) not in exterior:
                    exterior.add((nx, ny))
                    eq.append((nx, ny))

    # Build binary silhouette mask (1 inside ribbon/doc, 0 in exterior)
    mask = Image.new("L", (1024, 1024), 0)
    mask_pix = mask.load()
    solid_count = 0
    for y in range(1024):
        for x in range(1024):
            if (x, y) not in exterior:
                mask_pix[x, y] = 255
                solid_count += 1
    print(f"Solid ribbon+doc silhouette contains {solid_count} pixels.")

    # Apply 1.2px Gaussian blur to produce an anti-aliased alpha boundary
    smooth_mask = mask.filter(ImageFilter.GaussianBlur(1.2))

    # Create RGBA extracted graphic
    extracted = orig.copy().convert("RGBA")
    extracted.putalpha(smooth_mask)

    # Crop to tight non-zero bounding box
    bbox = extracted.getbbox()
    print(f"Tight bounding box: {bbox} (width: {bbox[2]-bbox[0]}, height: {bbox[3]-bbox[1]})")
    tight_graphic = extracted.crop(bbox)

    # Step 3: Scale graphic to fit comfortably within Android Adaptive Icon 66% safe zone
    # Target height = 580 px (approx 56.6% of 1024), width = 422 px
    target_h = 580
    scale = target_h / tight_graphic.height
    target_w = int(round(tight_graphic.width * scale))
    scaled_graphic = tight_graphic.resize((target_w, target_h), Image.Resampling.LANCZOS)
    print(f"Scaled graphic size: {scaled_graphic.size}")

    paste_x = (1024 - target_w) // 2
    paste_y = (1024 - target_h) // 2

    # Verify maximum distance from center
    cx, cy = 512, 512
    max_d = 0.0
    for y in range(target_h):
        for x in range(target_w):
            if scaled_graphic.getpixel((x, y))[3] > 0:
                dist = math.sqrt((paste_x + x - cx)**2 + (paste_y + y - cy)**2)
                if dist > max_d:
                    max_d = dist
    print(f"Max distance from center: {max_d:.1f} px (Safe zone radius is 341.3 px, margin: {341.3 - max_d:.1f} px)")

    # 1. Master transparent foreground (1024x1024 RGBA)
    foreground_1024 = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    foreground_1024.paste(scaled_graphic, (paste_x, paste_y), scaled_graphic)

    # 2. Master full-bleed composite (1024x1024 RGB #021642)
    composite_1024 = Image.new("RGB", (1024, 1024), bg_color)
    composite_1024.paste(scaled_graphic, (paste_x, paste_y), scaled_graphic)

    # Save to assets/branding/
    branding_dir = os.path.join(base_dir, "assets", "branding")
    os.makedirs(branding_dir, exist_ok=True)
    symbol_path = os.path.join(branding_dir, "scaneliq_symbol.png")
    logo_png_path = os.path.join(branding_dir, "scaneliq_logo.png")
    logo_jpg_path = os.path.join(branding_dir, "scaneliq_logo.jpg")

    foreground_1024.save(symbol_path, "PNG", optimize=True)
    composite_1024.save(logo_png_path, "PNG", optimize=True)
    composite_1024.save(logo_jpg_path, "JPEG", quality=100, optimize=True)
    print(f"Updated master branding assets in {branding_dir}")

    # Step 4: Generate Android Adaptive Icon Foregrounds (ic_launcher_foreground.png)
    # Adaptive densities:
    # mdpi: 108x108
    # hdpi: 162x162
    # xhdpi: 216x216
    # xxhdpi: 324x324
    # xxxhdpi: 432x432
    android_res = os.path.join(base_dir, "android", "app", "src", "main", "res")
    adaptive_sizes = {
        "drawable-mdpi": 108,
        "drawable-hdpi": 162,
        "drawable-xhdpi": 216,
        "drawable-xxhdpi": 324,
        "drawable-xxxhdpi": 432
    }
    for folder, size in adaptive_sizes.items():
        out_dir = os.path.join(android_res, folder)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, "ic_launcher_foreground.png")
        resized = foreground_1024.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(out_path, "PNG", optimize=True)
        print(f"Generated {folder}/ic_launcher_foreground.png ({size}x{size})")

    # Step 5: Generate Android Legacy Mipmap Icons (ic_launcher.png, launcher_icon.png, ic_launcher_round.png)
    # Legacy mipmap densities:
    # mdpi: 48x48
    # hdpi: 72x72
    # xhdpi: 96x96
    # xxhdpi: 144x144
    # xxxhdpi: 192x192
    mipmap_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192
    }
    for folder, size in mipmap_sizes.items():
        out_dir = os.path.join(android_res, folder)
        os.makedirs(out_dir, exist_ok=True)
        resized = composite_1024.resize((size, size), Image.Resampling.LANCZOS)
        for icon_name in ["ic_launcher.png", "launcher_icon.png", "ic_launcher_round.png"]:
            out_path = os.path.join(out_dir, icon_name)
            resized.save(out_path, "PNG", optimize=True)
        print(f"Generated {folder}/ (ic_launcher, launcher_icon, ic_launcher_round) ({size}x{size})")

    # Step 6: Generate iOS AppIcon assets in ios/Runner/Assets.xcassets/AppIcon.appiconset
    ios_iconset = os.path.join(base_dir, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    os.makedirs(ios_iconset, exist_ok=True)

    ios_specs = [
        {"size": "20x20", "idiom": "iphone", "filename": "Icon-App-20x20@2x.png", "scale": "2x", "px": 40},
        {"size": "20x20", "idiom": "iphone", "filename": "Icon-App-20x20@3x.png", "scale": "3x", "px": 60},
        {"size": "29x29", "idiom": "iphone", "filename": "Icon-App-29x29@1x.png", "scale": "1x", "px": 29},
        {"size": "29x29", "idiom": "iphone", "filename": "Icon-App-29x29@2x.png", "scale": "2x", "px": 58},
        {"size": "29x29", "idiom": "iphone", "filename": "Icon-App-29x29@3x.png", "scale": "3x", "px": 87},
        {"size": "40x40", "idiom": "iphone", "filename": "Icon-App-40x40@2x.png", "scale": "2x", "px": 80},
        {"size": "40x40", "idiom": "iphone", "filename": "Icon-App-40x40@3x.png", "scale": "3x", "px": 120},
        {"size": "60x60", "idiom": "iphone", "filename": "Icon-App-60x60@2x.png", "scale": "2x", "px": 120},
        {"size": "60x60", "idiom": "iphone", "filename": "Icon-App-60x60@3x.png", "scale": "3x", "px": 180},
        {"size": "20x20", "idiom": "ipad", "filename": "Icon-App-20x20@1x_ipad.png", "scale": "1x", "px": 20},
        {"size": "20x20", "idiom": "ipad", "filename": "Icon-App-20x20@2x_ipad.png", "scale": "2x", "px": 40},
        {"size": "29x29", "idiom": "ipad", "filename": "Icon-App-29x29@1x_ipad.png", "scale": "1x", "px": 29},
        {"size": "29x29", "idiom": "ipad", "filename": "Icon-App-29x29@2x_ipad.png", "scale": "2x", "px": 58},
        {"size": "40x40", "idiom": "ipad", "filename": "Icon-App-40x40@1x_ipad.png", "scale": "1x", "px": 40},
        {"size": "40x40", "idiom": "ipad", "filename": "Icon-App-40x40@2x_ipad.png", "scale": "2x", "px": 80},
        {"size": "76x76", "idiom": "ipad", "filename": "Icon-App-76x76@1x.png", "scale": "1x", "px": 76},
        {"size": "76x76", "idiom": "ipad", "filename": "Icon-App-76x76@2x.png", "scale": "2x", "px": 152},
        {"size": "83.5x83.5", "idiom": "ipad", "filename": "Icon-App-83.5x83.5@2x.png", "scale": "2x", "px": 167},
        {"size": "1024x1024", "idiom": "ios-marketing", "filename": "App-Icon-1024x1024@1x.png", "scale": "1x", "px": 1024}
    ]

    images_metadata = []
    for spec in ios_specs:
        px = spec["px"]
        fn = spec["filename"]
        out_path = os.path.join(ios_iconset, fn)
        resized = composite_1024.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(out_path, "PNG", optimize=True)
        images_metadata.append({
            "size": spec["size"],
            "idiom": spec["idiom"],
            "filename": fn,
            "scale": spec["scale"]
        })

    contents_json = {
        "images": images_metadata,
        "info": {
            "version": 1,
            "author": "xcode"
        }
    }
    with open(os.path.join(ios_iconset, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump(contents_json, f, indent=2)
    print(f"Generated iOS AppIcon asset catalog in {ios_iconset}")

    print("\nIcon asset generation completed successfully!")

if __name__ == "__main__":
    main()
