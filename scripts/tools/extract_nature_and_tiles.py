import os
from PIL import Image

src_path = r"C:\Users\rusla\.gemini\antigravity\brain\6124bcc7-2cf4-4477-8e33-14074bc620c8\.user_uploaded\media_1795207270497_f63f353f.jpg"
nature_dir = r"c:\Users\rusla\OneDrive\Документы\ant-colony\assets\nature"
tiles_dir = r"c:\Users\rusla\OneDrive\Документы\ant-colony\assets\tiles"

os.makedirs(nature_dir, exist_ok=True)
os.makedirs(tiles_dir, exist_ok=True)

img = Image.open(src_path)

def crop_with_alpha(src, bbox, low_thresh=6, high_thresh=16):
    x1, y1, x2, y2 = bbox
    crop = src.crop((x1, y1, x2 + 1, y2 + 1)).convert("RGBA")
    w, h = crop.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = crop.getpixel((x, y))
            m = max(r, g, b)
            if m <= low_thresh:
                crop.putpixel((x, y), (0, 0, 0, 0))
            elif m < high_thresh:
                alpha = int(((m - low_thresh) / float(high_thresh - low_thresh)) * 255)
                crop.putpixel((x, y), (r, g, b, alpha))
            else:
                crop.putpixel((x, y), (r, g, b, 255))
    return crop

# Extract Nature Props
props = {
    "bush_tall.png": (431, 9, 498, 82),
    "grass_bush.png": (439, 90, 489, 139),
    "flower_white.png": (551, 13, 599, 56),
    "flower_yellow.png": (602, 12, 653, 57),
    "flower_pink.png": (656, 9, 706, 56),
    "clover.png": (498, 79, 544, 114),
    "stone_medium.png": (649, 116, 684, 157),
    "stone_small.png": (560, 120, 587, 154),
    "stone_pebble.png": (681, 138, 717, 171),
}

for name, bbox in props.items():
    p = crop_with_alpha(img, bbox)
    p.save(os.path.join(nature_dir, name))
    print(f"Saved nature prop: {name} ({p.size})")

# Extract Soil / Grass tiles sheet
soil_tiles = img.crop((14, 5, 420, 265)).convert("RGBA")
soil_tiles.save(os.path.join(tiles_dir, "soil_tiles_sheet.png"))
print("Saved soil_tiles_sheet.png:", soil_tiles.size)

# Extract Dug tunnel tiles
tunnel_tiles = img.crop((720, 5, 1014, 250)).convert("RGBA")
tunnel_tiles.save(os.path.join(tiles_dir, "tunnel_tiles_sheet.png"))
print("Saved tunnel_tiles_sheet.png:", tunnel_tiles.size)
