# Знаки: нахил уперед хребта — +x; рука/нога вперед — -x. Права рука
# (посох) на -x, ліва (чари) на +x.
STOOP = {"spine": {"x": 4}, "head": {"x": -4}}


def pose(extra, base=None):
    base = STOOP if base is None else base
    out = {k: dict(v) for k, v in base.items()}
    for bone, spec in extra.items():
        merged = dict(out.get(bone, {}))
        for axis, value in spec.items():
            merged[axis] = merged.get(axis, 0) + value if axis != "loc" else value
        out[bone] = merged
    return out


# Стійка: важко дихає, ліва рука з чарами ледь поводить.
make_action("Idle", 70, {
    0: pose({"chest": {"x": 3}, "upperarm.L": {"x": -4}, "forearm.L": {"z": 4}}),
    35: pose({"chest": {"x": -2}, "head": {"z": 6, "x": -3}, "upperarm.L": {"x": -10, "y": 6},
              "forearm.L": {"z": -6}, "root": {"loc": (0, 0, -0.015)}}),
}, loop=True)


def walk_pose(phase, stride):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({
        "thigh.L": {"x": -stride * s}, "thigh.R": {"x": stride * s},
        "shin.L": {"x": stride * max(0.0, -s) + 4}, "shin.R": {"x": stride * max(0.0, s) + 4},
        "upperarm.L": {"x": 12 * s}, "upperarm.R": {"x": -6 * s},
        "spine": {"z": 5 * s, "x": 4}, "chest": {"z": -4 * s}, "head": {"z": 3 * s},
        "root": {"loc": (0, 0, -0.02 * abs(c))},
    })


# Шаркає: короткий крок, посох іде разом із рукою.
make_action("Walk", 36, {f: walk_pose(f / 36 * math.tau, 16) for f in range(0, 36, 4)}, loop=True)
make_action("Run", 24, {f: walk_pose(f / 24 * math.tau, 26) for f in range(0, 24, 3)}, loop=True)

# Чари стрілою: ліва долоня різко вперед.
make_action("Weapon", 24, {
    0: pose({}),
    8: pose({"upperarm.L": {"x": 25, "y": -10}, "forearm.L": {"x": -40}, "chest": {"z": 14}}),
    12: pose({"upperarm.L": {"x": -70, "y": 10}, "forearm.L": {"x": 10}, "chest": {"z": -14, "x": 6},
              "head": {"x": -4}}),
    18: pose({"upperarm.L": {"x": -60, "y": 8}, "forearm.L": {"x": 5}, "chest": {"z": -8}}),
    24: pose({}),
})

# Підняття кісток: посох угору — і з силою в підлогу, ліва рука вгору.
make_action("Cast", 36, {
    0: pose({}),
    10: pose({"upperarm.R": {"x": -28, "y": -6}, "forearm.R": {"x": -12}, "upperarm.L": {"x": -80, "y": 25},
              "forearm.L": {"x": -20}, "chest": {"x": -14}, "spine": {"x": -6}, "head": {"x": -14}}),
    16: pose({"upperarm.R": {"x": -10}, "forearm.R": {"x": -5}, "upperarm.L": {"x": -30, "y": 10},
              "chest": {"x": 16}, "spine": {"x": 10}, "head": {"x": 8}, "thigh.R": {"x": -15}, "shin.R": {"x": 20},
              "root": {"loc": (0, 0, -0.07)}}),
    26: pose({"upperarm.R": {"x": -12}, "chest": {"x": 12}, "spine": {"x": 8}, "root": {"loc": (0, 0, -0.05)}}),
    36: pose({}),
})

# Темний щит: ліва рука простягнута вбік-уперед, тримає чари.
make_action("Support", 36, {
    0: pose({}),
    8: pose({"upperarm.L": {"x": -55, "y": -20}, "forearm.L": {"x": 10}, "chest": {"z": -12}, "head": {"z": -10}}),
    26: pose({"upperarm.L": {"x": -60, "y": -24}, "forearm.L": {"x": 14}, "chest": {"z": -14, "x": -4},
              "head": {"z": -12}}),
    36: pose({}),
})

make_action("HitReact", 14, {
    0: pose({}),
    4: pose({"chest": {"x": -14, "z": -8}, "head": {"x": -12}, "spine": {"x": -6},
             "upperarm.L": {"x": 20, "y": -10}}),
    14: pose({}),
})

# Смерть: осідає на коліна — і падає ниць.
make_action("Death", 60, {
    0: pose({}),
    12: pose({"chest": {"x": 14}, "head": {"x": 16}, "upperarm.L": {"x": -30, "y": 20}, "forearm.L": {"x": -60}}),
    28: pose({"thigh.L": {"x": -80}, "thigh.R": {"x": -80}, "shin.L": {"x": 140}, "shin.R": {"x": 140},
              "foot.L": {"x": -40}, "foot.R": {"x": -40}, "chest": {"x": 20}, "head": {"x": 20},
              "root": {"loc": (0, 0, -0.30)}}),
    46: pose({"root": {"x": 60, "loc": (0, 0, -0.08)}, "thigh.L": {"x": -50}, "thigh.R": {"x": -50},
              "shin.L": {"x": 90}, "shin.R": {"x": 90}, "upperarm.L": {"x": -60}, "head": {"x": -10}}),
    60: pose({"root": {"x": 82, "loc": (0, 0, 0.0)}, "thigh.L": {"x": -20}, "thigh.R": {"x": -20},
              "shin.L": {"x": 30}, "shin.R": {"x": 30}, "upperarm.L": {"x": -90}, "head": {"x": -15}}),
})
