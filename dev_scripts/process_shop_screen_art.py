# -*- coding: utf-8 -*-
"""Арт Ринку від гравця: тло-крамниця, іконки наборів і "Без реклами",
картка товару з відсіком під іконку й банер заголовка розділу.

Картка: 9-slice, у якому лівий край (рамка + відсік) не тягнеться, а
текстура одразу зменшена до висоти картки в грі (StyleBoxTexture малює
краї 1:1) — тож відсік лишається квадратним. Банер: так само, а ромбики
посередині верхнього й нижнього краю вирізаємо й малюємо окремо (у 9-slice
їх розмазало б), місце під ними замальовуємо інтерполяцією."""
import os
import numpy as np
from PIL import Image

SRC = r"C:\Users\ibogd\AppData\Local\Temp\claude\D--Claude-code\84884892-6418-4a4b-9745-9370c228148c\images"
PROJ = r"D:\Claude code\idle survivor_like\assets\ui"

CARD_HEIGHT = 120
BANNER_HEIGHT = 58


def load(name):
    return Image.open(os.path.join(SRC, name)).convert("RGBA")


def resize_rgba(img, size):
    return img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def trim(img):
    a = np.array(img)[:, :, 3]
    ys, xs = np.nonzero(a > 8)
    return img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)), (xs.min(), ys.min())


def save(img, rel):
    path = os.path.join(PROJ, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG", optimize=True)
    print("OK", rel, img.size, os.path.getsize(path) // 1024, "KB")


def icon(src, rel, out=256):
    img, _ = trim(load(src))
    side = max(img.size)
    pad = round(side * 0.04)
    square = Image.new("RGBA", (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
    square.paste(img, ((square.width - img.width) // 2, (square.height - img.height) // 2))
    save(resize_rgba(square, (out, out)), rel)


def interpolate_rows(arr, x0, x1, y0, y1):
    """Замалювати прямокутник [x0, x1) × [y0, y1) лінійно між стовпцями x0-1 і x1."""
    left = arr[y0:y1, x0 - 1].astype(np.float32)
    right = arr[y0:y1, x1].astype(np.float32)
    w = x1 - x0
    for i in range(w):
        t = (i + 1) / (w + 1)
        arr[y0:y1, x0 + i] = (left * (1 - t) + right * t).astype(np.uint8)


def extract_layer(orig, clean, box):
    """Шар орнаменту: те, чим оригінал відрізняється від замальованого."""
    x0, y0, x1, y1 = box
    o = orig[y0:y1, x0:x1].astype(np.float32)
    c = clean[y0:y1, x0:x1].astype(np.float32)
    po = o[:, :, :3] * (o[:, :, 3:] / 255.0)
    pc = c[:, :, :3] * (c[:, :, 3:] / 255.0)
    diff = np.abs(po - pc).sum(axis=2) + np.abs(o[:, :, 3] - c[:, :, 3])
    alpha = np.minimum(o[:, :, 3], np.clip(diff / 60.0, 0, 1) * 255.0)
    layer = o.copy()
    layer[:, :, 3] = alpha
    return Image.fromarray(layer.astype(np.uint8), "RGBA")


def card(height=CARD_HEIGHT, rel="theme/item_card.png"):
    """Висота текстури = висота картки в грі. 84 — компактна (меню)."""
    img, _ = trim(load("44.webp"))
    s = height / img.height
    out = resize_rgba(img, (round(img.width * s), height))
    save(out, rel)
    # Кільце відсіку в оригіналі (після обрізки): x 83..353, y 86..348.
    print("  card scale %.4f  left cap ~%d  ring center x %.1f y %.1f  ring side %.1f" % (
        s, round(430 * s), (83 + 353) / 2 * s, (86 + 348) / 2 * s, 270 * s))


def banner():
    img, _ = trim(load("45.webp"))
    orig = np.array(img)
    clean = orig.copy()
    h, w = orig.shape[:2]
    cx = w // 2
    # Ромбики: згори y 0..64, знизу y h-68..h, по ширині cx-40..cx+40.
    top_box = (cx - 40, 0, cx + 40, 66)
    bottom_box = (cx - 40, h - 68, cx + 40, h)
    for x0, y0, x1, y1 in (top_box, bottom_box):
        interpolate_rows(clean, x0, x1, y0, y1)
    s = BANNER_HEIGHT / h
    body = resize_rgba(Image.fromarray(clean, "RGBA"), (round(w * s), BANNER_HEIGHT))
    save(body, "theme/section_banner.png")
    for name, box in (("top", top_box), ("bottom", bottom_box)):
        layer, offset = trim(extract_layer(orig, clean, box))
        size = (max(1, round(layer.width * s)), max(1, round(layer.height * s)))
        save(resize_rgba(layer, size), "theme/section_banner_gem_%s.png" % name)
        print("  gem %s y=%.1f" % (name, (box[1] + offset[1]) * s))
    print("  banner scale %.4f  caps ~%d" % (s, round(175 * s)))


def rune_frame():
    """Та сама рамка картки з рунами по кутах, але без відсіку — загальна
    плашка (картки здібностей у Залі героїв). Тут середина тягнеться,
    тож висоту текстури задає лише бажаний розмір кутів.
    Відсік не замальовуємо (довкола нього різкі перепади тіні — латка
    світилась квадратом), а беремо праву половину картки, де його немає,
    і віддзеркалюємо її вліво: рамка симетрична, кути з рунами з обох боків."""
    img, _ = trim(load("44.webp"))
    arr = np.array(img)
    half = arr[:, arr.shape[1] // 2:]
    img = Image.fromarray(np.concatenate([half[:, ::-1], half], axis=1), "RGBA")
    s = 0.2
    save(resize_rgba(img, (round(img.width * s), round(img.height * s))), "theme/rune_frame.png")
    print("  rune frame scale %.2f corners ~%d" % (s, round(95 * s)))


def background():
    bg = Image.open(os.path.join(SRC, "39.webp")).convert("RGB").resize((1600, 893), Image.LANCZOS)
    path = os.path.join(PROJ, "backgrounds", "shop.jpg")
    bg.save(path, "JPEG", quality=88, optimize=True)
    print("OK backgrounds/shop.jpg", bg.size, os.path.getsize(path) // 1024, "KB")


if __name__ == "__main__":
    import sys
    if "--card-small" in sys.argv:
        card(84, "theme/item_card_small.png")
        sys.exit(0)
    if "--rune-frame" in sys.argv:
        rune_frame()
        sys.exit(0)
    background()
    icon("40.webp", "icons/shop/starter_ads.png")
    icon("41.webp", "icons/shop/starter_hero.png")
    icon("42.webp", "icons/shop/starter_gold.png")
    icon("43.webp", "icons/shop/remove_ads.png")
    card()
    banner()
