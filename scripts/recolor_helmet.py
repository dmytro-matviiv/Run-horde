# -*- coding: utf-8 -*-
"""Перефарбування текстури шолома (Rodin) під сет: сіре/метал -> base,
насичене (оздоби, візор) -> accent; яскравість (тіні) зберігається.
  python recolor_helmet.py <src.jpg> <out.jpg> <base> <accent>"""
import sys
import numpy as np
from PIL import Image
src, out, base, accent = sys.argv[1:5]
col = lambda c: np.array([int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])
base, accent = col(base), col(accent)
rgb = np.asarray(Image.open(src).convert("RGB")).astype(np.float32) / 255.0
mx = rgb.max(2); mn = rgb.min(2)
s = np.where(mx > 1e-4, (mx - mn) / np.maximum(mx, 1e-4), 0.0)
acc = s > 0.35
res = rgb.copy()
for mask, target in ((~acc, base), (acc, accent)):
    if not mask.any():
        continue
    lum = mx[mask]
    f = np.clip(lum / max(np.median(lum), 1e-3), 0.3, 1.9)[:, None]
    res[mask] = np.clip(target[None, :] * f * 0.92 + rgb[mask] * 0.08, 0, 1)
Image.fromarray((res * 255).astype(np.uint8)).save(out, quality=92)
print("saved", out, float(acc.mean()))
