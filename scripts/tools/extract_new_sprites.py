"""
Extracts entity sprites and UI assets from the user-provided sprite sheet image
and saves clean PNGs with transparent background into assets/sprites_topdown/ and assets/ui/.
"""
import os
from PIL import Image

USER_IMAGE_PATH = r"C:\Users\rusla\.gemini\antigravity\brain\6124bcc7-2cf4-4477-8e33-14074bc620c8\.user_uploaded\media_1795207270497_f63f353f.jpg"
SPRITES_DIR = r"c:\Users\rusla\OneDrive\Документы\ant-colony\assets\sprites_topdown"
UI_DIR = r"c:\Users\rusla\OneDrive\Документы\ant-colony\assets\ui"

os.makedirs(SPRITES_DIR, exist_ok=True)
os.makedirs(UI_DIR, exist_ok=True)

img = Image.open(USER_IMAGE_PATH)

def crop_with_alpha(src, bbox, low_thresh=6, high_thresh=16, pad=0):
    x1, y1, x2, y2 = bbox
    x1 = max(0, x1 - pad)
    y1 = max(0, y1 - pad)
    x2 = min(src.width - 1, x2 + pad)
    y2 = min(src.height - 1, y2 + pad)
    
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

# 1. ENTITY SPRITES
# Queen
queen = crop_with_alpha(img, (470, 275, 605, 360))
queen.save(os.path.join(SPRITES_DIR, "queen.png"))

# Beetle
beetle = crop_with_alpha(img, (655, 298, 770, 395))
beetle.save(os.path.join(SPRITES_DIR, "beetle.png"))

# Spider
spider = crop_with_alpha(img, (765, 300, 890, 385))
spider.save(os.path.join(SPRITES_DIR, "spider.png"))

# Worker Ants (Roles)
# Forager (Brown)
forager = crop_with_alpha(img, (18, 276, 78, 309))
forager.save(os.path.join(SPRITES_DIR, "worker_forager.png"))

# Digger (Orange)
digger = crop_with_alpha(img, (17, 323, 68, 354))
digger.save(os.path.join(SPRITES_DIR, "worker_digger.png"))

# Nurse (Green)
nurse = crop_with_alpha(img, (15, 360, 74, 396))
nurse.save(os.path.join(SPRITES_DIR, "worker_nurse.png"))

# Defender (Red)
defender = crop_with_alpha(img, (335, 360, 402, 398))
defender.save(os.path.join(SPRITES_DIR, "worker_defender.png"))

# Eggs and Larvae
egg = crop_with_alpha(img, (480, 363, 508, 402))
egg.save(os.path.join(SPRITES_DIR, "egg.png"))

egg_clutch = crop_with_alpha(img, (545, 362, 585, 403))
egg_clutch.save(os.path.join(SPRITES_DIR, "egg_clutch.png"))

larva = crop_with_alpha(img, (630, 380, 682, 420))
larva.save(os.path.join(SPRITES_DIR, "larva.png"))

larva_small = crop_with_alpha(img, (590, 364, 632, 406))
larva_small.save(os.path.join(SPRITES_DIR, "larva_small.png"))

# Also keep egg_larva_worker.png updated with larva sprite
larva.save(os.path.join(SPRITES_DIR, "egg_larva_worker.png"))

# Weather and Environmental
rain = crop_with_alpha(img, (920, 300, 1014, 388))
rain.save(os.path.join(SPRITES_DIR, "rain.png"))

puddle = crop_with_alpha(img, (800, 375, 965, 452))
puddle.save(os.path.join(SPRITES_DIR, "water_puddle.png"))

stump = crop_with_alpha(img, (435, 160, 555, 265))
stump.save(os.path.join(SPRITES_DIR, "tree_stump.png"))

entrance = crop_with_alpha(img, (320, 190, 420, 265))
entrance.save(os.path.join(SPRITES_DIR, "anthill_entrance.png"))

# Food Resources
apple = crop_with_alpha(img, (565, 195, 593, 230))
apple.save(os.path.join(SPRITES_DIR, "food_apple.png"))

crumb = crop_with_alpha(img, (536, 240, 582, 276))
crumb.save(os.path.join(SPRITES_DIR, "food_crumb.png"))

mushroom = crop_with_alpha(img, (698, 230, 746, 282))
mushroom.save(os.path.join(SPRITES_DIR, "food_mushroom.png"))

# 2. UI ASSETS
# Job task icons
crop_with_alpha(img, (11, 466, 46, 515)).save(os.path.join(UI_DIR, "icon_forage.png"))
crop_with_alpha(img, (49, 467, 82, 514)).save(os.path.join(UI_DIR, "icon_dig.png"))
crop_with_alpha(img, (86, 467, 118, 514)).save(os.path.join(UI_DIR, "icon_nurse.png"))
crop_with_alpha(img, (122, 467, 154, 513)).save(os.path.join(UI_DIR, "icon_defend.png"))

# Alert & Status icons
crop_with_alpha(img, (784, 465, 817, 512)).save(os.path.join(UI_DIR, "icon_warning.png"))
crop_with_alpha(img, (830, 464, 870, 503)).save(os.path.join(UI_DIR, "icon_skull.png"))
crop_with_alpha(img, (878, 464, 919, 505)).save(os.path.join(UI_DIR, "icon_trophy.png"))
crop_with_alpha(img, (928, 463, 964, 498)).save(os.path.join(UI_DIR, "icon_star.png"))

# Button icons
crop_with_alpha(img, (105, 415, 142, 455)).save(os.path.join(UI_DIR, "btn_pause.png"))
crop_with_alpha(img, (59, 415, 97, 455)).save(os.path.join(UI_DIR, "btn_settings.png"))

# Day badge plate
crop_with_alpha(img, (571, 436, 646, 514)).save(os.path.join(UI_DIR, "badge_day.png"))

print("Successfully extracted all entity models and UI icons!")
