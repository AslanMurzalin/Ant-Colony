import random
from PIL import Image, ImageFilter

# Create a smooth, organic sandy subsoil texture matching antcolony.gg
width = 512
height = 512

img = Image.new("RGBA", (width, height))

# Base color from antcolony.gg: RGB (222, 197, 143)
base_r = 222
base_g = 197
base_b = 143

# Generate soft multi-frequency noise
for y in range(height):
    for x in range(width):
        # Subtle organic variation (-6 to +6)
        noise = random.randint(-5, 5)
        # Very rare tiny sand specks
        if random.random() < 0.003:
            noise -= random.randint(15, 25)
        elif random.random() < 0.003:
            noise += random.randint(10, 20)
            
        r = max(0, min(255, base_r + noise))
        g = max(0, min(255, base_g + noise))
        b = max(0, min(255, base_b + noise))
        img.putpixel((x, y), (r, g, b, 255))

# Apply slight Gaussian blur to make it smooth (not pixelated!)
img_smooth = img.filter(ImageFilter.GaussianBlur(radius=1.5))
img_smooth.save(r"c:\Users\rusla\OneDrive\Документы\ant-colony\assets\tiles\smooth_earth_bg.png")
print("Saved smooth_earth_bg.png successfully!")
