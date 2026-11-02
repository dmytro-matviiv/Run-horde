# Анімації Кістяного хробака (скелет Rodin; rig_rodin_custom.py). Нижні
# кільця лежать на землі, верхні (Spine5..13) здіймаються до голови.
# Кути — світові осі: x — нахил уперед (+), z — убік.
LOW = ["Spine", "Spine1", "Spine2", "Spine3", "Spine4"]
NECK = ["Spine8", "Spine9", "Spine10", "Spine11", "Spine12", "Spine13"]
RISE = ["Spine5", "Spine6", "Spine7"] + NECK


def sway(phase, side=4.0, nod=2.0, jaw=4.0, crawl=0.0):
    spec = {"Jaw": {"x": jaw * (0.5 + 0.5 * math.sin(phase * 2))}}
    for i, bone in enumerate(NECK):
        spec[bone] = {"z": side * math.sin(phase - i * 0.35), "x": nod * math.cos(phase - i * 0.4)}
    for i, bone in enumerate(LOW):
        spec[bone] = {"z": crawl * math.sin(phase * 2 - i * 1.1)}
    return pose(spec)


make_action("Idle", 60, {f: sway(f / 60 * math.tau) for f in range(0, 60, 5)}, loop=True)
make_action("Walk", 24, {f: sway(f / 24 * math.tau, 6, 3, 6, 8) for f in range(0, 24, 3)}, loop=True)


def lean(angle, jaw, extra=None):
    spec = {bone: {"x": angle} for bone in NECK}
    spec["Jaw"] = {"x": jaw}
    if extra:
        spec.update(extra)
    return pose(spec)


# Укус: відхиляється назад, паща розкрита (0.5 с) — і кидок уперед.
make_action("Weapon", 26, {
    0: sway(0),
    12: lean(-6, 16),
    16: lean(8, 18),
    19: lean(8, -4),
    26: sway(0),
})
# Виринання: стиснутий згин уперед — і випрямляється з розкритою пащею.
make_action("Emerge", 22, {
    0: pose({b: {"x": 12} for b in RISE}),
    10: lean(-5, 18),
    22: sway(0),
})
make_action("HitReact", 12, {0: sway(0), 4: lean(-8, 10), 12: sway(0)})
# Смерть: шия падає вперед на землю, паща розкрита.
make_action("Death", 40, {
    0: sway(0),
    16: pose({**{b: {"x": 7} for b in RISE}, "Jaw": {"x": 15}}),
    40: pose({**{b: {"x": 12} for b in RISE}, "Jaw": {"x": 16}}),
})
