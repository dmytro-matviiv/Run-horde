# -*- coding: utf-8 -*-
"""Готує згенерований арт до імпорту: зменшує з величезних (1-4K) до
розумного розміру й прибирає білий фон (заливка від країв картинки —
не чіпає білі відблиски всередині значка, бо вони не межують із краєм).
"""
import io
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

ICON_SIZE = 256
DUNGEON_SIZE = 320
WHITE_THRESHOLD = 225     # канал >= це — кандидат у фон (низько: з'їдає
                          # сіру облямівку згладжування, а не лише чисто білий)
FEATHER_BAND = 3          # скільки пікселів углиб від залитого фону ще м'яко гасимо
FEATHER_LOW = 0.45        # яскравість, звідки починає гаснути залишок країв


def remove_white_background(img: Image.Image) -> Image.Image:
    arr = np.asarray(img.convert("RGB"), dtype=np.int16)
    h, w, _ = arr.shape
    is_white = np.all(arr >= WHITE_THRESHOLD, axis=2)

    visited = np.zeros((h, w), dtype=bool)
    stack = deque()
    for x in range(w):
        if is_white[0, x]:
            stack.append((0, x))
        if is_white[h - 1, x]:
            stack.append((h - 1, x))
    for y in range(h):
        if is_white[y, 0]:
            stack.append((y, 0))
        if is_white[y, w - 1]:
            stack.append((y, w - 1))

    for y, x in stack:
        visited[y, x] = True

    while stack:
        y, x = stack.popleft()
        base = arr[y, x]
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and is_white[ny, nx]:
                if np.max(np.abs(arr[ny, nx].astype(np.int16) - base.astype(np.int16))) <= 40:
                    visited[ny, nx] = True
                    stack.append((ny, nx))

    alpha = np.full((h, w), 255, dtype=np.uint8)
    alpha[visited] = 0

    # М'який край, кілька пікселів углиб (не лише сусід упритул) — сіро-
    # білий обідок згладжування зазвичай ширший за один піксель, особливо
    # після зменшення з 4К. Для кожного з цих пікселів ще й знімаємо
    # білизну з кольору (деконтамінація): він же не лише напівпрозорий,
    # а ще й підмішаний у білий фон, тож без цього лишався б сірий ореол
    # навіть при частковій прозорості.
    band = visited.copy()
    frontier = visited.copy()
    for _ in range(FEATHER_BAND):
        pad = np.pad(frontier, 1, mode="constant", constant_values=False)
        grown = (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]) & ~band
        band |= grown
        frontier = grown
    edge_band = band & ~visited

    brightness = arr.mean(axis=2) / 255.0
    fade = np.clip((brightness - FEATHER_LOW) / (1.0 - FEATHER_LOW), 0.0, 1.0)
    edge_alpha_frac = 1.0 - fade[edge_band]
    alpha[edge_band] = (edge_alpha_frac * 255.0).astype(np.uint8)

    # Деконтамінація: Cobs = a*Cfg + (1-a)*білий  =>  Cfg = (Cobs - (1-a)*255) / a
    safe_a = np.clip(edge_alpha_frac, 0.12, 1.0)
    decontaminated = (arr[edge_band].astype(np.float32) - (1.0 - safe_a)[:, None] * 255.0) / safe_a[:, None]
    arr[edge_band] = np.clip(decontaminated, 0, 255).astype(np.int16)

    rgba = np.dstack([arr.astype(np.uint8), alpha])
    return Image.fromarray(rgba, mode="RGBA")


def process(src_path: str, dst_path: str, size: int) -> None:
    img = Image.open(src_path)
    img = img.convert("RGB")
    img = img.resize((size, size), Image.LANCZOS)
    img = remove_white_background(img)
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    img.save(dst_path, "PNG", optimize=True)
    kb = os.path.getsize(dst_path) / 1024
    print("OK  %s  (%d KB)" % (dst_path, kb))


if __name__ == "__main__":
    import json
    jobs = json.loads(sys.argv[1])
    for job in jobs:
        process(job["src"], job["dst"], job["size"])
