# -*- coding: utf-8 -*-
"""Кнопка "Меню" в місті (арт гравця): синя плашка з рунами по кутах і
трьома рисками-гамбургером зліва. Текстуру зменшуємо до висоти кнопки
(StyleBoxTexture малює краї 1:1), а лівий край разом із рисками в 9-slice
не тягнеться — риски лишаються рівними, напис стає праворуч від них."""
import os
import numpy as np
from PIL import Image

SRC = r"C:\Users\ibogd\AppData\Local\Temp\claude\D--Claude-code\84884892-6418-4a4b-9745-9370c228148c\images"
DST = r"D:\Claude code\idle survivor_like\assets\ui\theme\button_menu.png"
HEIGHT = 48


def main():
    img = Image.open(os.path.join(SRC, "53.webp")).convert("RGBA")
    a = np.array(img)[:, :, 3]
    ys, xs = np.nonzero(a > 8)
    img = img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    s = HEIGHT / img.height
    out = img.convert("RGBa").resize((round(img.width * s), HEIGHT), Image.LANCZOS).convert("RGBA")
    out.save(DST, "PNG", optimize=True)
    # Риски в оригіналі (після обрізки) ~ x 150..330, край лівої частини ~372.
    print("OK", out.size, "scale %.3f" % s, "left cap ~%d" % round(372 * s), "right corner ~%d" % round(105 * s))


def arrow():
    """Стрілка гортання (вибір данжу): висока синя плашка з рунами по кутах
    і золотим шевроном посередині. Плашка тягнеться лише вздовж, тож
    шеврон вирізаємо (інакше його витягнуло б) — кнопка малює його іконкою
    по центру. Місце під ним замальовуємо вертикальною інтерполяцією: бічні
    канти плашки однакові по всій висоті. Права стрілка — дзеркальний шеврон."""
    theme = os.path.dirname(DST)
    img = Image.open(os.path.join(SRC, "60.webp")).convert("RGBA")
    a = np.array(img)[:, :, 3]
    ys, xs = np.nonzero(a > 8)
    img = img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    orig = np.array(img)
    clean = orig.copy()
    # Шеврон зі світінням (після обрізки): x 30..170, y 860..1080.
    x0, x1, y0, y1 = 30, 170, 860, 1080
    top = clean[y0 - 1, x0:x1].astype(np.float32)
    bottom = clean[y1, x0:x1].astype(np.float32)
    h = y1 - y0
    for i in range(h):
        t = (i + 1) / (h + 1)
        clean[y0 + i, x0:x1] = (top * (1 - t) + bottom * t).astype(np.uint8)
    o = orig[y0:y1, x0:x1].astype(np.float32)
    c = clean[y0:y1, x0:x1].astype(np.float32)
    diff = np.abs(o[:, :, :3] - c[:, :, :3]).sum(axis=2)
    layer = o.copy()
    layer[:, :, 3] = np.minimum(o[:, :, 3], np.clip(diff / 60.0, 0, 1) * 255.0)
    chevron = Image.fromarray(layer.astype(np.uint8), "RGBA")
    cb = np.array(chevron)[:, :, 3]
    ys, xs = np.nonzero(cb > 6)
    chevron = chevron.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))

    s = ARROW_WIDTH / img.width
    frame = Image.fromarray(clean, "RGBA").convert("RGBa").resize(
        (ARROW_WIDTH, round(img.height * s)), Image.LANCZOS).convert("RGBA")
    frame.save(os.path.join(theme, "arrow_frame.png"), "PNG", optimize=True)
    size = (round(chevron.width * s), round(chevron.height * s))
    left = chevron.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    left.save(os.path.join(theme, "arrow_chevron_left.png"), "PNG", optimize=True)
    left.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(theme, "arrow_chevron_right.png"), "PNG", optimize=True)
    print("OK arrow frame", frame.size, "chevron", size, "corners ~%d" % round(62 * s))


ARROW_WIDTH = 60

if __name__ == "__main__":
    import sys
    if "--arrow" in sys.argv:
        arrow()
    else:
        main()
