# -*- coding: utf-8 -*-
"""Перетворює згенероване зображення на готовий спрайт для гри:
прибирає пурпуровий фон, обрізає порожнечу, зменшує до потрібного розміру.

Виклик: python make_sprite.py <url> <вихідний .png> <розмір> [--keep-bg]
"""
import sys
import urllib.request
from collections import deque

import numpy as np
from PIL import Image, ImageFilter


def fetch(url: str) -> Image.Image:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = resp.read()
    tmp = "_fetched.webp"
    with open(tmp, "wb") as f:
        f.write(data)
    return Image.open(tmp).convert("RGB")


def background_mask(rgb: np.ndarray, key: str) -> np.ndarray:
    """Фон-хромакей. Колір фону підбираємо під персонажа: пурпуровий
    не годиться для фіолетового асасина — його плащ теж зник би."""
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)
    if key == "green":
        return (g - r > 25) & (g - b > 25)
    return (r - g > 25) & (b - g > 25)


def flood_from_edges(mask: np.ndarray) -> np.ndarray:
    """Лишає тільки фон, сполучений з краєм кадру, щоб не проїдати
    пурпурові деталі всередині персонажа."""
    h, w = mask.shape
    out = np.zeros_like(mask)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if mask[y, x] and not out[y, x]:
                out[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if mask[y, x] and not out[y, x]:
                out[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                q.append((ny, nx))
    return out


def main() -> None:
    url, out_path, size = sys.argv[1], sys.argv[2], int(sys.argv[3])
    keep_bg = "--keep-bg" in sys.argv
    key = "green" if "--green" in sys.argv else "magenta"

    image = fetch(url)
    if keep_bg:
        # Для фонових текстур (підлога) прозорість не потрібна.
        image.resize((size, size), Image.LANCZOS).save(out_path)
        print("saved", out_path, image.size, "-> bg tile")
        return

    rgb = np.array(image)
    bg = flood_from_edges(background_mask(rgb, key))
    alpha = np.where(bg, 0, 255).astype(np.uint8)

    result = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
    # Розмиваємо край альфи на пікселі, щоб не лишалось "сходинок"
    # і кольорової облямівки від фону.
    blurred = result.split()[3].filter(ImageFilter.GaussianBlur(1.0))
    result.putalpha(blurred)

    bbox = result.getbbox()
    if bbox:
        result = result.crop(bbox)

    # Квадратне полотно: спрайт не перекошується при масштабуванні в грі.
    side = max(result.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(result, ((side - result.width) // 2, (side - result.height) // 2))
    canvas.resize((size, size), Image.LANCZOS).save(out_path)

    opaque = int((np.array(canvas)[:, :, 3] > 16).mean() * 100)
    print("saved %s  %dx%d  непрозорих пікселів %d%%" % (out_path, size, size, opaque))


main()
