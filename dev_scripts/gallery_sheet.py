import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

# Складає кадри галереї моделей в один підписаний аркуш.
#   python gallery_sheet.py <папка кадрів> <лог godot> <аркуш.png> [колонок]
frames_dir, log_path, out_path = sys.argv[1:4]
columns = int(sys.argv[4]) if len(sys.argv) > 4 else 8
names = {}
for line in open(log_path, encoding='utf-8', errors='replace'):
    m = re.match(r'GALLERY (\d+) (.*)', line.strip())
    if m:
        names[m.group(1)] = m.group(2)
cell_w, cell_h = 240, 150
keys = sorted(names)
rows = (len(keys) + columns - 1) // columns
sheet = Image.new('RGB', (columns * cell_w, rows * cell_h), (30, 30, 34))
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype('arial.ttf', 14)
except OSError:
    font = ImageFont.load_default()
for i, key in enumerate(keys):
    im = Image.open(os.path.join(frames_dir, key + '.png')).convert('RGB')
    im.thumbnail((cell_w - 6, cell_h - 22))
    x = (i % columns) * cell_w
    y = (i // columns) * cell_h
    sheet.paste(im, (x + 3, y + 3))
    draw.text((x + 4, y + cell_h - 18), '%s %s' % (key, names[key][:28]), fill=(235, 235, 220), font=font)
sheet.save(out_path)
print(out_path, sheet.size)
