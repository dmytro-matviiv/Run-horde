# -*- coding: utf-8 -*-
"""Telegraph / impact art from the player's VFX sheets -> game textures.

Black background becomes transparency: alpha = min(1, max(rgb) / T), colour is
un-premultiplied (rgb / alpha), so over black the result is identical to the
source and over a floor the soft glow blends instead of painting black.

usage: python process_telegraph_art.py <images_dir> <out_dir>
"""
import sys
import os
import numpy as np
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)


def load(n):
    return np.asarray(Image.open(os.path.join(SRC, "%d.webp" % n)).convert("RGB")).astype(np.float32) / 255.0


def to_rgba(rgb, threshold=0.35, floor=0.03):
    m = rgb.max(axis=2)
    # Compression noise of the black background -> fully transparent.
    m = np.clip((m - floor) / (1.0 - floor), 0.0, 1.0)
    alpha = np.clip(m / threshold, 0.0, 1.0)
    safe = np.maximum(alpha, 1e-4)[..., None]
    colour = np.clip(rgb / safe, 0.0, 1.0)
    colour[alpha < 1e-3] = 0.0
    return np.dstack([colour, alpha])


def to_white(rgb, floor=0.03, gain=1.0):
    """Grey sprite for particles: white, alpha = brightness (tinted in game)."""
    lum = rgb.max(axis=2)
    lum = np.clip((lum - floor) / (1.0 - floor) * gain, 0.0, 1.0)
    white = np.ones_like(rgb)
    return np.dstack([white, lum])


def save(rgba, name, size):
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")
    img = img.resize(size, Image.LANCZOS)
    # Keep the border fully transparent (clamped sampling at the quad edge).
    a = np.asarray(img).copy()
    a[:2, :, 3] = 0
    a[-2:, :, 3] = 0
    a[:, :2, 3] = 0
    a[:, -2:, 3] = 0
    Image.fromarray(a, "RGBA").save(os.path.join(OUT, name), optimize=True)
    print(name, size)


# Circles: lava ring (warm), rune circle (magic / shadow) - centred, square.
save(to_rgba(load(70)), "telegraph_circle_lava.png", (512, 512))
magic = load(71)[119:1879, 119:1879]
save(to_rgba(magic, threshold=0.45), "telegraph_circle_rune.png", (512, 512))
# Cone: kept uncropped, the shader maps polar coords around the apex.
save(to_rgba(load(69)), "telegraph_cone.png", (512, 512))
# Impact cracks.
save(to_rgba(load(72), threshold=0.4), "impact_cracks.png", (512, 512))
# Strips: frame lines at the strip edges.
save(to_rgba(load(76)[:, 80:412], threshold=0.4), "telegraph_line_chevrons.png", (128, 768))
save(to_rgba(load(74)[:, 100:392], threshold=0.4), "telegraph_line_flames.png", (128, 768))

# Particle atlas 4x4 (500 px cells): only the cells we use.
atlas = load(68)


def cell(cx, cy):
    return atlas[cy * 500:(cy + 1) * 500, cx * 500:(cx + 1) * 500]


save(to_white(cell(0, 0)), "particle_glow.png", (64, 64))
save(to_rgba(cell(0, 2), threshold=0.3), "particle_rock.png", (64, 64))
save(to_white(cell(1, 2), gain=1.4), "particle_dust.png", (128, 128))
