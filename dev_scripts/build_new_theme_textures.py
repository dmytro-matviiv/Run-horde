# -*- coding: utf-8 -*-
"""Генерує нові 9-slice текстури теми — округлі "пухкі" кнопки й панелі
мобільного стилю (градієнт + блиск зверху + товста рамка + м'яка тінь),
замість старих фентезійних рамок Kenney. Та сама архітектура
(UiTheme._texture_box, texture_margin) — просто нові PNG під тими самими
іменами."""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

OUT = r"D:\Claude code\idle survivor_like\assets\ui\theme"
SIZE = 160            # полотно панелей (з запасом під тінь)
BTN_SIZE = 72         # полотно кнопок/слотів/пігулки — мають лишатись
                      # цілими навіть коли кнопка заввишки лише ~40px
SHADOW_OFFSET = 7
SHADOW_BLUR = 10
CORNER = 30
BORDER = 6
BTN_SHADOW_OFFSET = 2
BTN_SHADOW_BLUR = 3
BTN_CORNER = 13
BTN_BORDER = 3


def rounded_rect(size, radius, fill):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=fill)
    return img


def lighten(c, amt):
    return tuple(min(255, int(ch + (255 - ch) * amt)) for ch in c[:3]) + (c[3] if len(c) > 3 else 255,)


def darken(c, amt):
    return tuple(max(0, int(ch * (1 - amt))) for ch in c[:3]) + (c[3] if len(c) > 3 else 255,)


def vertical_gradient(size, top, bottom):
    img = Image.new("RGBA", size)
    for y in range(size[1]):
        t = y / max(size[1] - 1, 1)
        row = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4))
        for x in range(size[0]):
            img.putpixel((x, y), row)
    return img


def make_button(base_color, radius=BTN_CORNER, border=BTN_BORDER, pressed=False, disabled=False,
                 hover=False, shadow=True, gloss=True, canvas_size=BTN_SIZE,
                 shadow_offset=BTN_SHADOW_OFFSET, shadow_blur=BTN_SHADOW_BLUR):
    w = h = canvas_size
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    inner_w, inner_h = w - shadow_offset - shadow_blur, h - shadow_offset - shadow_blur
    ox, oy = 0, 0

    body_color = base_color
    if disabled:
        gray = sum(base_color[:3]) // 3
        body_color = (gray, gray, gray, 255)
    if hover:
        body_color = lighten(body_color, 0.14)
    if pressed:
        body_color = darken(body_color, 0.18)

    # тінь під кнопкою
    if shadow and not pressed and not disabled:
        shadow_shape = rounded_rect((inner_w, inner_h), radius, (0, 0, 0, 130))
        shadow_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        shadow_layer.paste(shadow_shape, (shadow_offset, shadow_offset + 2), shadow_shape)
        shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(shadow_blur * 0.6))
        canvas = Image.alpha_composite(canvas, shadow_layer)
        oy = 0
    elif pressed:
        oy = min(2, shadow_offset)  # притиснута кнопка лежить нижче, тіні майже нема

    # тіло: градієнт світліше зверху -> темніше знизу + темніша рамка
    top = lighten(body_color, 0.22 if not pressed else 0.05)
    bottom = darken(body_color, 0.22 if not pressed else 0.05)
    grad = vertical_gradient((inner_w, inner_h), top, bottom)
    mask = rounded_rect((inner_w, inner_h), radius, (255, 255, 255, 255))
    body = Image.new("RGBA", (inner_w, inner_h), (0, 0, 0, 0))
    body.paste(grad, (0, 0), mask)

    border_color = darken(body_color, 0.42)
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle([border // 2, border // 2, inner_w - 1 - border // 2, inner_h - 1 - border // 2],
                          radius=max(radius - border // 2, 4), outline=border_color, width=border)

    # глянець зверху (світла дуга у верхній третині)
    if gloss and not pressed and not disabled:
        gloss_h = int(inner_h * 0.42)
        gloss_layer = Image.new("RGBA", (inner_w, inner_h), (0, 0, 0, 0))
        gloss_shape = Image.new("RGBA", (inner_w, gloss_h * 2), (0, 0, 0, 0))
        gd = ImageDraw.Draw(gloss_shape)
        gd.ellipse([border, -gloss_h * 0.6, inner_w - border, gloss_h * 1.15], fill=(255, 255, 255, 60))
        gloss_layer.paste(gloss_shape, (0, border), gloss_shape)
        gloss_mask = rounded_rect((inner_w, inner_h), radius, (255, 255, 255, 255))
        gloss_clipped = Image.new("RGBA", (inner_w, inner_h), (0, 0, 0, 0))
        gloss_clipped.paste(gloss_layer, (0, 0), gloss_mask)
        body = Image.alpha_composite(body, gloss_clipped)

    canvas.paste(body, (ox, oy), body)
    return canvas


def make_panel(base_color, radius=24, border=4, opacity=232):
    w = h = SIZE
    inner_w, inner_h = w - 8, h - 8
    body_color = base_color[:3] + (opacity,)
    top = lighten(body_color, 0.10)
    bottom = darken(body_color, 0.12)
    grad = vertical_gradient((inner_w, inner_h), top, bottom)
    mask = rounded_rect((inner_w, inner_h), radius, (255, 255, 255, 255))
    body = Image.new("RGBA", (inner_w, inner_h), (0, 0, 0, 0))
    body.paste(grad, (0, 0), mask)
    border_color = lighten(base_color, 0.55)[:3] + (255,)
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle([border // 2, border // 2, inner_w - 1 - border // 2, inner_h - 1 - border // 2],
                          radius=max(radius - border // 2, 4), outline=border_color, width=border)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(body, (4, 4), body)
    return canvas


def make_pill(base_color, radius=999):
    w, h = BTN_SIZE, BTN_SIZE
    body_color = base_color
    top = lighten(body_color, 0.18)
    bottom = darken(body_color, 0.18)
    grad = vertical_gradient((w - 8, h - 8), top, bottom)
    mask = rounded_rect((w - 8, h - 8), radius, (255, 255, 255, 255))
    body = Image.new("RGBA", (w - 8, h - 8), (0, 0, 0, 0))
    body.paste(grad, (0, 0), mask)
    border_color = lighten(body_color, 0.5)
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle([3, 3, w - 12, h - 12], radius=radius, outline=border_color, width=4)
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    canvas.paste(body, (4, 4), body)
    return canvas


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path, "PNG")
    print("OK", path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)

    SLATE = (74, 92, 148, 255)       # звичайна кнопка — синьо-сіра
    PRIMARY = (58, 189, 98, 255)     # головна дія — зелена ("Enter")
    PANEL_BG = (30, 26, 58, 255)     # фіолетово-темна панель
    SLOT_BG = (52, 78, 156, 255)     # слот предмета — синій
    TITLE_BG = (68, 48, 128, 255)    # плашка заголовка — фіолетова

    save(make_button(SLATE), "button.png")
    save(make_button(SLATE, hover=True), "button_hover.png")
    save(make_button(SLATE, pressed=True), "button_pressed.png")
    save(make_button(SLATE, disabled=True), "button_disabled.png")

    save(make_button(PRIMARY), "button_primary.png")
    save(make_button(PRIMARY, hover=True), "button_primary_hover.png")
    save(make_button(PRIMARY, pressed=True), "button_primary_pressed.png")

    save(make_panel(PANEL_BG), "panel.png")
    save(make_button(SLOT_BG, radius=20, border=5), "slot.png")
    save(make_pill(TITLE_BG), "title_pill.png")
