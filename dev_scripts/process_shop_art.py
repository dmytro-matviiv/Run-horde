# -*- coding: utf-8 -*-
"""Іконки Ринку від гравця: жменя гемів, мішечок, скриня й обмін.
Картинки вже прозорі — лише обрізаємо по вмісту й кладемо в квадрат
256×256 (той самий розмір, що й попередні іконки товарів)."""
import os
import numpy as np
from PIL import Image

SRC = r"C:\Users\ibogd\AppData\Local\Temp\claude\D--Claude-code\84884892-6418-4a4b-9745-9370c228148c\images"
DST = r"D:\Claude code\idle survivor_like\assets\ui\icons\shop"
OUT = 256
JOBS = {
    "37.webp": "gems_small.png",
    "36.webp": "gems_medium.png",
    "35.webp": "gems_large.png",
    "38.webp": "exchange.png",
}


def make(src_name, dst_name):
    img = Image.open(os.path.join(SRC, src_name)).convert("RGBA")
    alpha = np.array(img)[:, :, 3]
    ys, xs = np.nonzero(alpha > 8)
    img = img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    side = max(img.size)
    pad = round(side * 0.04)
    square = Image.new("RGBA", (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
    square.paste(img, ((square.width - img.width) // 2, (square.height - img.height) // 2))
    out = square.convert("RGBa").resize((OUT, OUT), Image.LANCZOS).convert("RGBA")
    path = os.path.join(DST, dst_name)
    out.save(path, "PNG", optimize=True)
    print("OK", dst_name, out.size, os.path.getsize(path) // 1024, "KB")


if __name__ == "__main__":
    for src_name, dst_name in JOBS.items():
        make(src_name, dst_name)
