# -*- coding: utf-8 -*-
"""Іконки валюти від гравця: золота монета з короною й фіолетовий гем.
Картинки вже прозорі (RGBA) — тло не чіпаємо (convert("RGB") зробив
би прозоре чорним), лише обрізаємо по вмісту й кладемо в квадрат — у грі іконка стоїть поруч із
числом, і порожні поля довкола робили б її дрібнішою за текст."""
import os
import numpy as np
from PIL import Image

SRC = r"C:\Users\ibogd\AppData\Local\Temp\claude\D--Claude-code\84884892-6418-4a4b-9745-9370c228148c\images"
DST = r"D:\Claude code\idle survivor_like\assets\ui\icons\currency"
WORK = 384
OUT = 96


def make(src_name, dst_name):
    img = Image.open(os.path.join(SRC, src_name)).convert("RGBA")
    s = WORK / max(img.size)
    rgba = img.convert("RGBa").resize((round(img.width * s), round(img.height * s)), Image.LANCZOS).convert("RGBA")
    alpha = np.array(rgba)[:, :, 3]
    ys, xs = np.nonzero(alpha > 8)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    rgba = rgba.crop(box)
    side = max(rgba.size)
    pad = round(side * 0.04)
    square = Image.new("RGBA", (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
    square.paste(rgba, ((square.width - rgba.width) // 2, (square.height - rgba.height) // 2))
    out = square.convert("RGBa").resize((OUT, OUT), Image.LANCZOS).convert("RGBA")
    os.makedirs(DST, exist_ok=True)
    path = os.path.join(DST, dst_name)
    out.save(path, "PNG", optimize=True)
    print("OK", dst_name, out.size, os.path.getsize(path) // 1024, "KB")


if __name__ == "__main__":
    make("34.webp", "gold.png")
    make("33.webp", "gem.png")
