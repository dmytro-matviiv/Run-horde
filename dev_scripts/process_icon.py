# -*- coding: utf-8 -*-
"""Одна вже прозора іконка від гравця -> квадрат OUT×OUT, обрізаний по
вмісту з полем 4% (як решта іконок здібностей і товарів).
  python process_icon.py <src.webp|png> <dst.png> [розмір=256]"""
import os
import sys
import numpy as np
from PIL import Image


def make(src, dst, out=256):
    img = Image.open(src).convert("RGBA")
    a = np.array(img)[:, :, 3]
    ys, xs = np.nonzero(a > 8)
    img = img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    side = max(img.size)
    pad = round(side * 0.04)
    square = Image.new("RGBA", (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
    square.paste(img, ((square.width - img.width) // 2, (square.height - img.height) // 2))
    result = square.convert("RGBa").resize((out, out), Image.LANCZOS).convert("RGBA")
    result.save(dst, "PNG", optimize=True)
    print("OK", dst, result.size, os.path.getsize(dst) // 1024, "KB")


if __name__ == "__main__":
    make(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 256)
