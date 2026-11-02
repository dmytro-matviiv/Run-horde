# -*- coding: utf-8 -*-
"""Results panels (victory green / defeat red) from the player's art.

- the blurred backdrop around the scroll -> transparent (mask built from the
  victory image, whose backdrop is blue; both images share the layout);
- the baked yellow fills of the two upper right bars are replaced by the empty
  third bar (the game draws live fills);
- cropped to the scroll and scaled for the UI.

usage: python process_results_art.py <images_dir> <out_dir>
"""
import os
import sys
import numpy as np
from PIL import Image, ImageFilter

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)

green = np.asarray(Image.open(os.path.join(SRC, "77.webp")).convert("RGB")).astype(np.int32)
red = np.asarray(Image.open(os.path.join(SRC, "78.webp")).convert("RGB")).astype(np.int32)
H, W = green.shape[:2]

# Backdrop = bluish (b clearly above r) and not bright; flood from the border
# so the bluish portrait slot inside the scroll is kept.
r, g, b = green[..., 0], green[..., 1], green[..., 2]
candidate = (b > r + 12) & (b >= g) & (np.maximum(np.maximum(r, g), b) < 150)
reach = np.zeros_like(candidate)
reach[0, :] = candidate[0, :]
reach[-1, :] = candidate[-1, :]
reach[:, 0] = candidate[:, 0]
reach[:, -1] = candidate[:, -1]
for _ in range(900):
    grown = reach.copy()
    grown[1:, :] |= reach[:-1, :]
    grown[:-1, :] |= reach[1:, :]
    grown[:, 1:] |= reach[:, :-1]
    grown[:, :-1] |= reach[:, 1:]
    grown &= candidate
    if (grown == reach).all():
        break
    reach = grown
alpha = Image.fromarray(np.where(reach, 0, 255).astype(np.uint8))
# Soft 1-2 px edge instead of a jagged cut.
alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))

# Bars: rows of the empty third bar copied over the first two.
BAR_X = (1118, 1758)
BAR3_Y = (894, 1045)
STEP = 207


def clear_bars(img):
    out = img.copy()
    x0, x1 = BAR_X
    y0, y1 = BAR3_Y
    patch = img[y0:y1, x0:x1]
    for k in (1, 2):
        out[y0 - STEP * k:y1 - STEP * k, x0:x1] = patch
    return out


# Crop to the scroll (rods included).
CROP = (40, 70, 1965, 1415)

for name, img in (("results_victory", green), ("results_defeat", red)):
    rgb = clear_bars(img).astype(np.uint8)
    rgba = Image.fromarray(rgb, "RGB").convert("RGBA")
    rgba.putalpha(alpha)
    rgba = rgba.crop(CROP)
    w, h = rgba.size
    scale = 1100 / w
    rgba = rgba.resize((1100, round(h * scale)), Image.LANCZOS)
    rgba.save(os.path.join(OUT, name + ".png"), optimize=True)
    print(name, rgba.size, "scale", scale)
