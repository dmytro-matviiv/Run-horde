# Знаки: нахил уперед — +x; рука вперед — -x; "z" — поворот навколо
# вертикалі. Меч (обидві руки на руків'ї) — на правій кисті.
GUARD = {}


def pose(extra, base=None):
    base = GUARD if base is None else base
    out = {k: dict(v) for k, v in base.items()}
    for bone, spec in extra.items():
        merged = dict(out.get(bone, {}))
        for axis, value in spec.items():
            merged[axis] = merged.get(axis, 0) + value if axis != "loc" else value
        out[bone] = merged
    return out


# Статуя: майже не рухається — ледь "дихає".
make_action("Idle", 80, {
    0: pose({}),
    40: pose({"chest": {"x": 1.5}, "head": {"x": 1}, "root": {"loc": (0, 0, -0.005)}}),
}, loop=True)


def walk_pose(phase, stride):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({
        "thigh.L": {"x": -stride * s}, "thigh.R": {"x": stride * s},
        "shin.L": {"x": stride * max(0.0, -s) + 4}, "shin.R": {"x": stride * max(0.0, s) + 4},
        "foot.L": {"x": -6 * s}, "foot.R": {"x": 6 * s},
        "spine": {"z": 4 * s, "x": 3}, "chest": {"z": -3 * s},
        "root": {"loc": (0, 0, -0.025 * abs(c))},
    })


# Важка лицарська хода, меч перед собою.
make_action("Walk", 40, {f: walk_pose(f / 40 * math.tau, 20) for f in range(0, 40, 4)}, loop=True)
make_action("Run", 26, {f: walk_pose(f / 26 * math.tau, 30) for f in range(0, 26, 2)}, loop=True)

# Широкий розмах: меч заведений праворуч — і дугою наліво.
make_action("Weapon", 34, {
    0: pose({}),
    12: pose({"chest": {"z": 45}, "spine": {"z": 20}, "upperarm.R": {"x": -60, "z": 30}, "upperarm.L": {"x": -50, "z": 30},
              "forearm.R": {"x": -20}, "forearm.L": {"x": -20}, "thigh.R": {"x": -10}, "head": {"z": -20}}),
    18: pose({"chest": {"z": -40}, "spine": {"z": -18}, "upperarm.R": {"x": -70, "z": -35}, "upperarm.L": {"x": -60, "z": -35},
              "forearm.R": {"x": -5}, "forearm.L": {"x": -5}, "thigh.L": {"x": -15}, "shin.L": {"x": 12},
              "root": {"loc": (0, 0, -0.05)}}),
    25: pose({"chest": {"z": -30}, "spine": {"z": -12}, "upperarm.R": {"x": -50, "z": -25}, "upperarm.L": {"x": -45, "z": -25},
              "root": {"loc": (0, 0, -0.04)}}),
    34: pose({}),
})

# Оживання: б'є з розвороту — повний оберт із мечем навідліг.
make_action("Wake", 30, {
    0: pose({}),
    6: pose({"root": {"z": 0}, "chest": {"z": 35}, "upperarm.R": {"x": -70, "z": 40}, "upperarm.L": {"x": -60, "z": 40},
             "thigh.L": {"x": -12}, "shin.L": {"x": 14}}),
    12: pose({"root": {"z": -120}, "chest": {"z": -10}, "upperarm.R": {"x": -85, "z": 10}, "upperarm.L": {"x": -75, "z": 10}}),
    18: pose({"root": {"z": -240}, "chest": {"z": -30}, "upperarm.R": {"x": -85, "z": -20}, "upperarm.L": {"x": -75, "z": -20}}),
    24: pose({"root": {"z": -350}, "chest": {"z": -20}, "upperarm.R": {"x": -60, "z": -20}, "upperarm.L": {"x": -55, "z": -20}}),
    30: pose({"root": {"z": -360}}),
})

make_action("HitReact", 14, {
    0: pose({}),
    4: pose({"chest": {"x": -12, "z": 8}, "head": {"x": -12}, "spine": {"x": -5}}),
    14: pose({}),
})

# Смерть: хитнувся й важко падає ниць (далі код розбиває його на уламки).
make_action("Death", 40, {
    0: pose({}),
    10: pose({"chest": {"x": -10}, "head": {"x": -15}, "thigh.L": {"x": -20}, "shin.L": {"x": 30}}),
    26: pose({"root": {"x": 70}, "thigh.L": {"x": -30}, "thigh.R": {"x": -20}, "shin.L": {"x": 40}, "shin.R": {"x": 30}}),
    40: pose({"root": {"x": 84, "loc": (0, 0, 0.02)}, "thigh.L": {"x": -10}, "thigh.R": {"x": -10}}),
})
