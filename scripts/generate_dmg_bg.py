#!/usr/bin/env python3
from PIL import Image, ImageDraw
import math

# DMG Window size
WIDTH, HEIGHT = 600, 400

# Create gradient background (Navy to Black)
img = Image.new('RGB', (WIDTH, HEIGHT))
draw = ImageDraw.Draw(img)

for y in range(HEIGHT):
    # Gradient from navy (#0a1628) to black (#000000)
    ratio = y / HEIGHT
    r = int(10 * (1 - ratio))
    g = int(22 * (1 - ratio))
    b = int(40 * (1 - ratio))
    draw.line([(0, y), (WIDTH, y)], fill=(r, g, b))

# Draw centered arrow (chevron style)
arrow_color = (255, 255, 255, 128)  # Semi-transparent white
center_x, center_y = WIDTH // 2, HEIGHT // 2 - 30  # Slightly raised

# Create arrow overlay with transparency
overlay = Image.new('RGBA', (WIDTH, HEIGHT), (0, 0, 0, 0))
draw_overlay = ImageDraw.Draw(overlay)

# Arrow dimensions
arrow_size = 50
line_width = 12

# Draw chevron arrow pointing right
points = [
    (center_x - arrow_size//2, center_y - arrow_size),
    (center_x + arrow_size//2, center_y),
    (center_x - arrow_size//2, center_y + arrow_size)
]
draw_overlay.line(points, fill=(255, 255, 255, 180), width=line_width, joint="curve")

# Composite
img = img.convert('RGBA')
img = Image.alpha_composite(img, overlay)
img = img.convert('RGB')

# Save
img.save('Resources/dmg_background.png')
print("Background generated: Resources/dmg_background.png")
