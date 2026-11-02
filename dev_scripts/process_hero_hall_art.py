# -*- coding: utf-8 -*-
"""Арт Зали героїв від гравця: зелена кнопка "Обрати", синя "Назад",
фіолетовий банер заголовка з гербом і загальне тло екрана.

Кнопки й банер ріжуться 9-slice у грі; текстуру зменшуємо так, щоб її
висота була близькою до висоти кнопки/банера в інтерфейсі (StyleBoxTexture
малює кути 1:1, масштабу в нього немає). Герб банера — посередині
верхнього краю, тож його вирізаємо й малюємо окремо (OrnateBanner),
а місце під ним у рамці замальовуємо інтерполяцією."""
import os
import numpy as np
from PIL import Image

SRC = r"C:\Users\ibogd\AppData\Local\Temp\claude\D--Claude-code\84884892-6418-4a4b-9745-9370c228148c\images"
PROJ = r"D:\Claude code\idle survivor_like\assets\ui"


def load(name):
    return Image.open(os.path.join(SRC, name)).convert("RGBA")


def resize_rgba(img, size):
    return img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def scaled_to_height(img, height):
    s = height / img.height
    return resize_rgba(img, (round(img.width * s), height)), s


def interpolate_patch(arr, box):
    x0, y0, x1, y1 = box
    left = arr[y0:y1, x0 - 1].astype(np.float32)
    right = arr[y0:y1, x1].astype(np.float32)
    w = x1 - x0
    for i in range(w):
        t = (i + 1) / (w + 1)
        arr[y0:y1, x0 + i] = (left * (1 - t) + right * t).astype(np.uint8)


def save(img, rel):
    path = os.path.join(PROJ, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG", optimize=True)
    print("OK", rel, img.size)


def main():
    # --- зелена "Обрати" ---
    green = load("28.webp").crop((69, 67, 1932, 433))
    g, s = scaled_to_height(green, 56)
    save(g, "theme/button_hero_select.png")
    print("  green margins x/y:", round(178 * s), round(150 * s))
    # Сіра (вимкнена) — "Обрано" чи не вистачає гемів: знебарвлена й темніша.
    arr = np.array(g).astype(np.float32)
    gray = arr[:, :, :3] @ np.array([0.299, 0.587, 0.114])
    arr[:, :, :3] = (arr[:, :, :3] * 0.25 + gray[:, :, None] * 0.75) * 0.72
    save(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA"), "theme/button_hero_select_disabled.png")

    # --- синя "Назад" ---
    blue = load("29.webp").crop((49, 48, 1951, 451))
    b, s = scaled_to_height(blue, 48)
    save(b, "theme/button_hero_back.png")
    print("  blue margins x/y:", round(105 * s), round(80 * s))

    # --- банер заголовка ---
    banner = np.array(load("30.webp"))
    clean = banner.copy()
    crest_box = (898, 294, 1102, 462)
    clean[crest_box[1]:383, crest_box[0]:crest_box[2]] = 0
    interpolate_patch(clean, (crest_box[0], 383, crest_box[2], crest_box[3]))
    o = banner[crest_box[1]:crest_box[3], crest_box[0]:crest_box[2]].astype(np.float32)
    c = clean[crest_box[1]:crest_box[3], crest_box[0]:crest_box[2]].astype(np.float32)
    alpha = np.clip(np.abs(o[:, :, :3] - c[:, :, :3]).sum(axis=2) / 70.0, 0, 1) * 255.0
    above = np.arange(crest_box[1], crest_box[3]) < 383
    alpha[above] = o[above, :, 3]
    crest = o.copy()
    crest[:, :, 3] = alpha
    body = Image.fromarray(clean, "RGBA").crop((31, 383, 1969, 734))
    body_s, s = scaled_to_height(body, 70)
    save(body_s, "theme/banner_title.png")
    crest_img = Image.fromarray(crest.astype(np.uint8), "RGBA")
    crest_s = resize_rgba(crest_img, (round(crest_img.width * s), round(crest_img.height * s)))
    save(crest_s, "theme/banner_title_crest.png")
    print("  banner caps:", round(320 * s), "crest rise:", round((383 - crest_box[1]) * s, 1))

    # --- тло екрана ---
    bg = Image.open(os.path.join(SRC, "31.webp")).convert("RGB").resize((1600, 893), Image.LANCZOS)
    path = os.path.join(PROJ, "backgrounds", "hero_hall.jpg")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bg.save(path, "JPEG", quality=90, optimize=True)
    print("OK backgrounds/hero_hall.jpg", bg.size, os.path.getsize(path) // 1024, "KB")


if __name__ == "__main__":
    main()
