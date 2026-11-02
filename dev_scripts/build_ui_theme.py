# Збирає текстури оформлення з наборів Kenney (CC0) у assets/ui/:
#   theme/    — панелі, кнопки, слоти, розділювач (Fantasy UI Borders);
#   controls/ — джойстик, кругла кнопка й білі іконки (Mobile Controls, Style E);
#   cursors/  — курсор-лезо й рука для ПК (Cursor Pixel Pack).
# Рамки Kenney білі — тут їх фарбуємо й заливаємо темним тлом, щоб у грі
# не рахувати відтінки на льоту.
# Запуск: python D:/RuneHorde_work/scripts/build_ui_theme.py
import os
import shutil
from PIL import Image, ImageDraw

SRC = 'D:/RuneHorde_work/ui_in'
DST = 'D:/Claude code/idle survivor_like/assets/ui'

LINE = (232, 228, 214, 255)
FILL = (22, 27, 32, 235)


def framed(border_file, fill, line, scale=1):
    """Рамка Kenney: лінії — колір line, усе всередині — fill."""
    src = Image.open(border_file).convert('RGBA')
    w, h = src.size
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    mask = Image.new('L', (w, h), 0)
    mp = mask.load()
    sp = src.load()
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] > 128:
                mp[x, y] = 255
    # Заливка зсередини до ліній (враховує вирізані кути).
    flood = mask.copy()
    ImageDraw.floodfill(flood, (w // 2, h // 2), 128)
    op = out.load()
    fp = flood.load()
    for y in range(h):
        for x in range(w):
            if fp[x, y] == 128:
                op[x, y] = fill
            if mp[x, y] == 255:
                op[x, y] = line
    if scale != 1:
        out = out.resize((w * scale, h * scale), Image.NEAREST)
    return out


def recolor(file, color):
    """Білу картинку — у заданий колір (альфа лишається)."""
    src = Image.open(file).convert('RGBA')
    px = src.load()
    for y in range(src.size[1]):
        for x in range(src.size[0]):
            r, g, b, a = px[x, y]
            if a:
                k = (r + g + b) / (3 * 255)
                px[x, y] = (int(color[0] * k), int(color[1] * k), int(color[2] * k), a * color[3] // 255)
    return src


os.makedirs(DST + '/theme', exist_ok=True)
os.makedirs(DST + '/controls', exist_ok=True)
os.makedirs(DST + '/cursors', exist_ok=True)

border_panel = SRC + '/PNG/Default/Border/panel-border-000.png'   # вирізані кути ("Quest")
border_button = SRC + '/PNG/Default/Border/panel-border-008.png'  # квадратики на кутах ("Accept quest")
slot = SRC + '/PNG/Default/Transparent center/panel-transparent-center-000.png'

framed(border_panel, FILL, LINE).save(DST + '/theme/panel.png')
framed(border_button, FILL, LINE).save(DST + '/theme/button.png')
framed(border_button, (40, 47, 55, 245), (255, 255, 255, 255)).save(DST + '/theme/button_hover.png')
framed(border_button, (12, 15, 18, 245), (190, 186, 172, 255)).save(DST + '/theme/button_pressed.png')
framed(border_button, (22, 27, 32, 150), (96, 100, 104, 255)).save(DST + '/theme/button_disabled.png')
# Головна кнопка — світла з темним текстом, як "Accept quest".
framed(border_button, (234, 231, 220, 255), (70, 74, 78, 255)).save(DST + '/theme/button_primary.png')
framed(border_button, (252, 250, 244, 255), (40, 44, 48, 255)).save(DST + '/theme/button_primary_hover.png')
framed(border_button, (196, 192, 180, 255), (40, 44, 48, 255)).save(DST + '/theme/button_primary_pressed.png')

# Слот для іконки: кремова рамка й сіре тло.
src = Image.open(slot).convert('RGBA')
px = src.load()
for y in range(src.size[1]):
    for x in range(src.size[0]):
        a = px[x, y][3]
        if a > 200:
            px[x, y] = LINE
        elif a > 0:
            px[x, y] = (72, 78, 84, 225)
src.save(DST + '/theme/slot.png')

# Розділювач із руків'ям меча — для заголовків.
recolor(SRC + '/PNG/Default/Divider/divider-004.png', LINE).save(DST + '/theme/divider.png')
recolor(SRC + '/PNG/Default/Divider Fade/divider-fade-004.png', LINE).save(DST + '/theme/divider_fade.png')

# --- мобільне керування (темний стиль E, великі — для різкості) ---
style = SRC + '/mobile/Sprites/Style E/Large (2\u00d7)'
for name in ['joystick_circle_pad_a', 'joystick_circle_nub_a', 'button_circle']:
    shutil.copy(style + '/' + name + '.png', DST + '/controls/' + name + '.png')
icons = SRC + '/mobile/Sprites/Icons/Large (2\u00d7)'
for name in ['icon_sword', 'icon_crosshair', 'icon_jump', 'icon_arrow_rotate', 'icon_arrow', 'icon_burst',
             'icon_fire', 'icon_cog', 'icon_menu', 'icon_pause', 'icon_play', 'icon_star', 'icon_shield',
             'icon_lock', 'icon_checkmark', 'icon_cross', 'icon_money', 'icon_skull', 'icon_target']:
    shutil.copy(icons + '/' + name + '.png', DST + '/controls/' + name + '.png')

# --- курсори для ПК (піксельні 16x16 — удвічі більші, без розмиття) ---
for tile, name in [('0086', 'cursor_blade'), ('0178', 'cursor_hand')]:
    im = Image.open(SRC + '/cursor/Tiles/tile_%s.png' % tile).convert('RGBA')
    im.resize((32, 32), Image.NEAREST).save(DST + '/cursors/%s.png' % name)

for folder in ['theme', 'controls', 'cursors']:
    print(folder, sorted(os.listdir(DST + '/' + folder)))
print('sizes:', Image.open(DST + '/controls/button_circle.png').size, Image.open(DST + '/controls/joystick_circle_pad_a.png').size,
      Image.open(DST + '/controls/joystick_circle_nub_a.png').size, Image.open(DST + '/controls/icon_sword.png').size)
