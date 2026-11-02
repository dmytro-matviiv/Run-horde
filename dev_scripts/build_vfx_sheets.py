# -*- coding: utf-8 -*-
"""Збирає спрайт-листи ефектів із набору CraftPix (окремі кадри PNG).

Навіщо перетворювати: гра малює кадри з ОДНІЄЇ текстури (Sprite2D уміє
різати сітку сам), тож замість 24 окремих файлів на ефект у грі лежить
один аркуш — менше файлів, менше перемикань текстур у бою.

Кадри ще й обрізаються по спільній рамці всіх кадрів ефекту: у вихідних
файлах багато порожнечі, а спільна рамка зберігає рух ефекту (він не
"стрибає" між кадрами).
"""
import io
import json
import math
import os
import zipfile

from PIL import Image

ZIP_PATH = r'D:\Claude code\idle survivor_like\assets_incoming\magic_slash.zip'
OUT_DIR = r'D:\Claude code\idle survivor_like\assets\vfx'
FRAME_SIZE = 192     # розмір одного кадру в аркуші
COLUMNS = 6          # ширина сітки: 6 колонок тримає аркуш у межах 1152 px

SLUGS = {
    'Fire Slash': 'fire_slash',
    'Water Slash': 'water_slash',
    'Lightning Slash': 'lightning_slash',
    'Poisonous Slashes': 'poison_slash',
    'Double Wind Slashes': 'wind_slash',
    'Ultimate Slash': 'ultimate_slash',
}

os.makedirs(OUT_DIR, exist_ok=True)
archive = zipfile.ZipFile(ZIP_PATH)

groups = {}
for name in archive.namelist():
    if name.startswith('__MACOSX') or not name.lower().endswith('.png'):
        continue
    folder = name.split('/')[0]
    if folder in SLUGS:
        groups.setdefault(folder, []).append(name)

manifest = {}
for folder, files in sorted(groups.items()):
    files.sort()
    frames = [Image.open(io.BytesIO(archive.read(f))).convert('RGBA') for f in files]

    # Спільна рамка: об'єднання непорожніх ділянок усіх кадрів.
    box = None
    for frame in frames:
        frame_box = frame.getbbox()
        if frame_box is None:
            continue
        box = frame_box if box is None else (
            min(box[0], frame_box[0]), min(box[1], frame_box[1]),
            max(box[2], frame_box[2]), max(box[3], frame_box[3]),
        )

    rows = math.ceil(len(frames) / COLUMNS)
    sheet = Image.new('RGBA', (COLUMNS * FRAME_SIZE, rows * FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        cropped = frame.crop(box)
        # Вписуємо в квадрат кадру, не спотворюючи пропорції.
        scale = FRAME_SIZE / max(cropped.width, cropped.height)
        resized = cropped.resize(
            (max(int(cropped.width * scale), 1), max(int(cropped.height * scale), 1)),
            Image.LANCZOS,
        )
        cell = Image.new('RGBA', (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        cell.paste(resized, ((FRAME_SIZE - resized.width) // 2, (FRAME_SIZE - resized.height) // 2))
        sheet.paste(cell, ((index % COLUMNS) * FRAME_SIZE, (index // COLUMNS) * FRAME_SIZE))

    slug = SLUGS[folder]
    path = os.path.join(OUT_DIR, slug + '.png')
    sheet.save(path, optimize=True)
    manifest[slug] = {'frames': len(frames), 'columns': COLUMNS, 'rows': rows}
    print('%-16s кадрів %2d  сітка %dx%d  %5d КБ' % (
        slug, len(frames), COLUMNS, rows, os.path.getsize(path) // 1024))

print(json.dumps(manifest, ensure_ascii=False))
