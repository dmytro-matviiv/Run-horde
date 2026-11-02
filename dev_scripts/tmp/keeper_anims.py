# Знаки: нахил уперед хребта — +x; рука/нога вперед — -x. Права рука
# (молот-надгробок) на -x, ліва (ланцюг із ключами) на +x.
STANCE = {"thigh.L": {"x": -4}, "thigh.R": {"x": 4}, "shin.L": {"x": 6}, "shin.R": {"x": 6}}


def pose(extra, base=None):
    base = STANCE if base is None else base
    out = {k: dict(v) for k, v in base.items()}
    for bone, spec in extra.items():
        merged = dict(out.get(bone, {}))
        for axis, value in spec.items():
            merged[axis] = merged.get(axis, 0) + value if axis != "loc" else value
        out[bone] = merged
    return out


make_action("Idle", 70, {
    0: pose({"chest": {"x": 2}, "root": {"loc": (0, 0, -0.01)}}),
    35: pose({"chest": {"x": -2}, "head": {"z": 6}, "upperarm.L": {"y": 4}, "root": {"loc": (0, 0, -0.03)}}),
}, loop=True)


def walk_pose(phase, stride, lean):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({
        "thigh.L": {"x": -stride * s}, "thigh.R": {"x": stride * s},
        "shin.L": {"x": stride * max(0.0, -s) + 6}, "shin.R": {"x": stride * max(0.0, s) + 6},
        "foot.L": {"x": -6 * s}, "foot.R": {"x": 6 * s},
        "upperarm.L": {"x": 14 * s}, "upperarm.R": {"x": -5 * s},
        "spine": {"z": 6 * s, "x": lean}, "chest": {"z": -5 * s}, "head": {"z": 3 * s},
        "root": {"loc": (0, 0, -0.035 * abs(c))},
    }, {})


# Важка хода: короткий крок, корпус перевалюється.
make_action("Walk", 40, {f: walk_pose(f / 40 * math.tau, 18, 3) for f in range(0, 40, 4)}, loop=True)
make_action("Run", 26, {f: walk_pose(f / 26 * math.tau, 30, 10) for f in range(0, 26, 2)}, loop=True)

# Звичайний удар: молот з-за плеча навскіс.
make_action("Weapon", 30, {
    0: pose({}),
    10: pose({"upperarm.R": {"x": -110, "y": -25}, "forearm.R": {"x": -55}, "chest": {"z": 25, "x": -6},
              "spine": {"z": 10}}),
    15: pose({"upperarm.R": {"x": -40, "y": 20}, "forearm.R": {"x": -10}, "chest": {"z": -25, "x": 14},
              "spine": {"z": -10, "x": 8}, "thigh.R": {"x": -18}, "shin.R": {"x": 18}, "root": {"loc": (0, 0, -0.06)}}),
    22: pose({"upperarm.R": {"x": -30, "y": 15}, "chest": {"z": -15, "x": 10}, "root": {"loc": (0, 0, -0.04)}}),
    30: pose({}),
})

# Удар надгробком: обома руками над головою — і з присідом об підлогу.
make_action("Slam", 44, {
    0: pose({}),
    16: pose({"upperarm.R": {"x": -165, "y": 10}, "forearm.R": {"x": -40}, "upperarm.L": {"x": -150, "y": -25},
              "forearm.L": {"x": -50}, "chest": {"x": -16}, "spine": {"x": -8}, "head": {"x": -10},
              "root": {"loc": (0, 0, 0.02)}}),
    22: pose({"upperarm.R": {"x": -55, "y": 10}, "forearm.R": {"x": -5}, "upperarm.L": {"x": -55, "y": -15},
              "forearm.L": {"x": -10}, "chest": {"x": 30}, "spine": {"x": 18}, "head": {"x": 10},
              "thigh.L": {"x": -35}, "thigh.R": {"x": -35}, "shin.L": {"x": 50}, "shin.R": {"x": 50},
              "root": {"loc": (0, 0, -0.18)}}),
    34: pose({"upperarm.R": {"x": -50}, "upperarm.L": {"x": -45, "y": -10}, "chest": {"x": 26}, "spine": {"x": 15},
              "thigh.L": {"x": -30}, "thigh.R": {"x": -30}, "shin.L": {"x": 45}, "shin.R": {"x": 45},
              "root": {"loc": (0, 0, -0.16)}}),
    44: pose({}),
})

# Обертання ланцюгом: ліва рука витягнута вбік, корпус крутиться по колу.
def spin_pose(phase):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({"upperarm.L": {"y": -70, "x": -20 * c}, "forearm.L": {"x": -10},
                 "spine": {"z": 22 * s}, "chest": {"z": 22 * s}, "head": {"z": -10 * s},
                 "thigh.L": {"x": -10}, "thigh.R": {"x": -10}, "shin.L": {"x": 15}, "shin.R": {"x": 15},
                 "root": {"loc": (0, 0, -0.05)}})


make_action("Spin", 24, {f: spin_pose(f / 24 * math.tau) for f in range(0, 24, 3)}, loop=True)

# Відмикає саркофаг: нахилився до стіни, ліва рука крутить ключ.
def unlock_pose(phase):
    s = math.sin(phase)
    return pose({"spine": {"x": 22}, "chest": {"x": 10}, "head": {"x": 8},
                 "upperarm.L": {"x": -70, "y": -5}, "forearm.L": {"x": -30, "y": 40 * s},
                 "upperarm.R": {"x": 10, "y": -10}, "thigh.L": {"x": -25}, "shin.L": {"x": 30},
                 "thigh.R": {"x": 10}, "root": {"loc": (0, 0, -0.08)}})


make_action("Unlock", 30, {f: unlock_pose(f / 30 * math.tau) for f in range(0, 30, 5)}, loop=True)

# Рев: присів, стиснувся — і розпрямився з руками в боки.
make_action("Roar", 50, {
    0: pose({}),
    12: pose({"upperarm.L": {"x": -30, "y": 25}, "upperarm.R": {"x": -30, "y": -25}, "forearm.L": {"x": -80},
              "forearm.R": {"x": -80}, "chest": {"x": 28}, "spine": {"x": 15}, "head": {"x": 20},
              "thigh.L": {"x": -28}, "thigh.R": {"x": -28}, "shin.L": {"x": 40}, "shin.R": {"x": 40},
              "root": {"loc": (0, 0, -0.14)}}),
    24: pose({"upperarm.L": {"y": -70, "x": -40}, "upperarm.R": {"y": 70, "x": -40}, "forearm.L": {"x": -10},
              "forearm.R": {"x": -10}, "chest": {"x": -22}, "spine": {"x": -8}, "head": {"x": -30}}),
    38: pose({"upperarm.L": {"y": -65, "x": -35}, "upperarm.R": {"y": 65, "x": -35}, "chest": {"x": -20},
              "head": {"x": -28, "z": 6}}),
    50: pose({}),
})

# Кидок свічки з плеча: ліва рука знизу вгору вперед.
make_action("Throw", 26, {
    0: pose({}),
    8: pose({"upperarm.L": {"x": 30, "y": -10}, "forearm.L": {"x": -60}, "chest": {"z": -15}}),
    13: pose({"upperarm.L": {"x": -120, "y": -10}, "forearm.L": {"x": -10}, "chest": {"z": 18, "x": 6}}),
    20: pose({"upperarm.L": {"x": -90}, "chest": {"z": 8}}),
    26: pose({}),
})

make_action("HitReact", 14, {
    0: pose({}),
    4: pose({"chest": {"x": -12, "z": 8}, "head": {"x": -12}, "spine": {"x": -5}}),
    14: pose({}),
})

# Смерть (як у щитоносця): хитнувся назад — і важко, як колода, ниць.
LIMP = {"upperarm.L": {"x": 5, "y": 10}, "forearm.L": {"x": -10},
        "upperarm.R": {"x": 5, "y": -12}, "forearm.R": {"x": -10},
        "spine": {"x": 14}, "chest": {"x": 8}, "thigh.L": {"x": -12}, "thigh.R": {"x": -8},
        "shin.L": {"x": 20}, "shin.R": {"x": 16}}
make_action("Death", 56, {
    0: pose({}),
    10: pose({"chest": {"x": -14}, "head": {"x": -20}, "spine": {"x": -6}, "upperarm.L": {"x": 15},
              "upperarm.R": {"x": 20, "y": 5}}),
    22: pose({"root": {"x": 25}, "chest": {"x": 6}, "head": {"x": 8}}, LIMP),
    38: pose({"root": {"x": 84, "loc": (0, 0, 0.02)}, "upperarm.L": {"x": -30},
              "upperarm.R": {"x": -40, "y": 15}, "head": {"x": -25}}, LIMP),
    46: pose({"root": {"x": 80, "loc": (0, 0, 0.05)}, "upperarm.L": {"x": -35},
              "upperarm.R": {"x": -45, "y": 15}, "head": {"x": -20}}, LIMP),
    56: pose({"root": {"x": 84, "loc": (0, 0, 0.02)}, "upperarm.L": {"x": -30},
              "upperarm.R": {"x": -40, "y": 15}, "head": {"x": -22}}, LIMP),
})
