# -*- coding: utf-8 -*-
"""Пасивки героїв, іконка Арсеналу й нова панель опису героя.

Іконки вже вирізані (прозоре тло) — лише зменшення з премультиплікованою
альфою (інакше прозорі чорні пікселі темним обідком підтікають у край).

Панель: 9-slice розтягує середину країв, тож центральні прикраси зверху
(вензель з камінцем) і знизу (ромбик) розмазались би на широкій панелі.
Їх замальовуємо в рамці (лінійна інтерполяція між чистими стовпцями
обабіч — градієнт і золота лінія лишаються) і зберігаємо окремо, щоб
малювати поверх, по центру, у власному розмірі (OrnatePanel)."""
import os
import numpy as np
from PIL import Image

SRC = r"C:\Users\ibogd\AppData\Local\Temp\claude\D--Claude-code\84884892-6418-4a4b-9745-9370c228148c\images"
PROJ = r"D:\Claude code\idle survivor_like\assets\ui"

ICONS = {
    "21.webp": "skills/phoenix.png",
    "22.webp": "skills/rage.png",
    "23.webp": "skills/rune_charge.png",
    "25.webp": "skills/death_mark.png",
    "24.webp": "skills/arsenal.png",
}
ICON_SIZE = 256

SCALE = 0.4
FRAME = (54, 55, 1946, 797)          # рамка без вензеля над нею
TOP_ORN = (830, 20, 1170, 96)        # вензель (виступає над рамкою)
BOTTOM_ORN = (805, 748, 1195, 780)   # ромбик з лінією внизу


def resize_rgba(img, size):
    return img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def interpolate_patch(arr, box):
    x0, y0, x1, y1 = box
    left = arr[y0:y1, x0 - 1].astype(np.float32)
    right = arr[y0:y1, x1].astype(np.float32)
    w = x1 - x0
    for i in range(w):
        t = (i + 1) / (w + 1)
        arr[y0:y1, x0 + i] = (left * (1 - t) + right * t).astype(np.uint8)


def main():
    for src, dst in ICONS.items():
        img = Image.open(os.path.join(SRC, src)).convert("RGBA")
        out = os.path.join(PROJ, "icons", dst)
        resize_rgba(img, (ICON_SIZE, ICON_SIZE)).save(out, "PNG", optimize=True)
        print("OK", out)

    orig = np.array(Image.open(os.path.join(SRC, "26.webp")).convert("RGBA"))
    clean = orig.copy()
    # Над рамкою (y < 55) — лише вензель на прозорому: прибираємо повністю.
    clean[TOP_ORN[1]:FRAME[1], TOP_ORN[0]:TOP_ORN[2]] = 0
    interpolate_patch(clean, (TOP_ORN[0], FRAME[1], TOP_ORN[2], TOP_ORN[3]))
    interpolate_patch(clean, BOTTOM_ORN)

    def ornament(box):
        x0, y0, x1, y1 = box
        o = orig[y0:y1, x0:x1].astype(np.float32)
        c = clean[y0:y1, x0:x1].astype(np.float32)
        diff = np.abs(o[:, :, :3] - c[:, :, :3]).sum(axis=2)
        alpha = np.clip(diff / 70.0, 0.0, 1.0) * 255.0
        # Над рамкою тло прозоре — там альфа самого оригіналу.
        above = np.arange(y0, y1) < FRAME[1]
        alpha[above] = o[above, :, 3]
        out = o.copy()
        out[:, :, 3] = alpha
        return Image.fromarray(out.astype(np.uint8), "RGBA")

    top = ornament(TOP_ORN)
    bottom = ornament(BOTTOM_ORN)
    frame = Image.fromarray(clean, "RGBA").crop(FRAME)

    def scaled(img):
        return resize_rgba(img, (round(img.width * SCALE), round(img.height * SCALE)))

    theme = os.path.join(PROJ, "theme")
    for name, img in (("ornate_panel.png", frame), ("ornate_panel_top.png", top), ("ornate_panel_bottom.png", bottom)):
        s = scaled(img)
        s.save(os.path.join(theme, name), "PNG", optimize=True)
        print("OK", name, s.size)
    print("top rise px:", round((FRAME[1] - TOP_ORN[1]) * SCALE, 1))
    print("bottom offset from panel bottom px:", round((FRAME[3] - BOTTOM_ORN[1]) * SCALE, 1))


if __name__ == "__main__":
    main()
