# Знаки (осі арматури): нахил уперед хребта — +x; нога/рука вперед — -x.
# Права рука (булава) на -x: "y" < 0 — ближче до тіла. Ліва (щит) на +x:
# "y" > 0 — ближче до тіла (щит перед грудьми).
# Стійка щитоносця: щит трохи вперед, булава опущена, коліна пружинять.
# Щит прив'язаний уздовж передпліччя: щоб дошка лишалась стоячою, лікоть
# не згинаємо, а щит виводимо вперед поворотом усієї руки навколо
# вертикалі ("z" < 0 — лицем щита вперед).
GUARD = {"upperarm.L": {"x": -10, "z": -22}, "forearm.L": {"x": 6},
         "upperarm.R": {"x": -8, "y": -10}, "forearm.R": {"x": -25},
         "thigh.L": {"x": -6}, "thigh.R": {"x": 4}, "shin.L": {"x": 8}, "shin.R": {"x": 6}}


def pose(extra, base=None):
    base = GUARD if base is None else base
    out = {k: dict(v) for k, v in base.items()}
    for bone, spec in extra.items():
        merged = dict(out.get(bone, {}))
        for axis, value in spec.items():
            merged[axis] = merged.get(axis, 0) + value if axis != "loc" else value
        out[bone] = merged
    return out


make_action("Idle", 64, {
    0: pose({"chest": {"x": 2}, "head": {"x": 2}, "root": {"loc": (0, 0, -0.01)}}),
    32: pose({"chest": {"x": -2}, "head": {"x": -2, "z": 6}, "upperarm.R": {"x": 4},
              "root": {"loc": (0, 0, -0.025)}}),
}, loop=True)


def walk_pose(phase, stride, lean, bob, arms):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({
        "thigh.L": {"x": -stride * s}, "thigh.R": {"x": stride * s},
        "shin.L": {"x": stride * 1.1 * max(0.0, -s) + 4}, "shin.R": {"x": stride * 1.1 * max(0.0, s) + 4},
        "foot.L": {"x": -8 * s}, "foot.R": {"x": 8 * s},
        "upperarm.R": {"x": arms * s}, "upperarm.L": {"x": -arms * 0.3 * s},
        "spine": {"z": 6 * s, "x": lean}, "chest": {"z": -5 * s}, "head": {"z": 3 * s},
        "root": {"loc": (0, 0, -bob * abs(c))},
    })


# Важка хода "танка": короткий крок, корпус перевалюється.
make_action("Walk", 36, {f: walk_pose(f / 36 * math.tau, 20, 4, 0.03, 14) for f in range(0, 36, 4)}, loop=True)

# Таран: нахилився вперед, щит виставлений перед собою, булава відведена.
CHARGE = {"upperarm.L": {"x": -32, "z": -68, "y": 12}, "forearm.L": {"x": 26},
          "upperarm.R": {"x": 35, "y": -5}, "forearm.R": {"x": -35},
          "spine": {"x": 18}, "chest": {"x": 10}, "head": {"x": -14}}


def charge_pose(phase):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({
        "thigh.L": {"x": -40 * s - 10}, "thigh.R": {"x": 40 * s - 10},
        "shin.L": {"x": 45 * max(0.0, -s) + 10}, "shin.R": {"x": 45 * max(0.0, s) + 10},
        "foot.L": {"x": -10 * s}, "foot.R": {"x": 10 * s},
        "spine": {"z": 4 * s}, "root": {"loc": (0, 0, -0.06 - 0.05 * abs(c))},
    }, CHARGE)


charge = {f: charge_pose(f / 20 * math.tau) for f in range(0, 20, 2)}
make_action("Charge", 20, dict(charge), loop=True)
make_action("Run", 20, dict(charge), loop=True)

# Булавою зверху: замах над головою, удар униз із присідом.
make_action("Weapon", 30, {
    0: pose({}),
    10: pose({"upperarm.R": {"x": -150, "y": 15}, "forearm.R": {"x": -55}, "chest": {"x": -10, "z": 18},
              "spine": {"x": -6}, "head": {"x": -6}}),
    15: pose({"upperarm.R": {"x": -55, "y": 5}, "forearm.R": {"x": -5}, "chest": {"x": 22, "z": -12},
              "spine": {"x": 12}, "thigh.L": {"x": -20}, "shin.L": {"x": 22}, "root": {"loc": (0, 0, -0.08)}}),
    22: pose({"upperarm.R": {"x": -45}, "forearm.R": {"x": -10}, "chest": {"x": 16, "z": -8},
              "spine": {"x": 8}, "root": {"loc": (0, 0, -0.06)}}),
    30: pose({}),
})

# Удар щитом: розгорнувся — і поштовх щитом уперед із кроком.
make_action("Weapon2", 26, {
    0: pose({}),
    8: pose({"upperarm.L": {"x": 10, "z": 22}, "forearm.L": {"x": -6}, "chest": {"z": 22}, "spine": {"z": 8}}),
    13: pose({"upperarm.L": {"x": -38, "z": -52, "y": 14}, "forearm.L": {"x": 22}, "chest": {"z": -24, "x": 10},
              "spine": {"x": 8}, "thigh.L": {"x": -28}, "shin.L": {"x": 18}, "root": {"loc": (0, 0, -0.05)}}),
    19: pose({"upperarm.L": {"x": -30, "z": -44, "y": 10}, "forearm.L": {"x": 18}, "chest": {"z": -12, "x": 6},
              "root": {"loc": (0, 0, -0.03)}}),
    26: pose({}),
})

# Блок: щит різко вгору, корпус за ним.
make_action("Block", 16, {
    0: pose({}),
    4: pose({"upperarm.L": {"x": -40, "z": -46, "y": 14}, "forearm.L": {"x": 30}, "chest": {"x": 6},
             "head": {"x": 8}, "root": {"loc": (0, 0, -0.04)}}),
    10: pose({"upperarm.L": {"x": -36, "z": -44, "y": 12}, "forearm.L": {"x": 28}, "chest": {"x": 4}}),
    16: pose({}),
})

# Оглушений після стіни: щит опущений, руки висять, голова хилитається.
LIMP = {"upperarm.L": {"x": 5, "y": 10}, "forearm.L": {"x": -10},
        "upperarm.R": {"x": 5, "y": -12}, "forearm.R": {"x": -10},
        "spine": {"x": 14}, "chest": {"x": 8}, "thigh.L": {"x": -12}, "thigh.R": {"x": -8},
        "shin.L": {"x": 20}, "shin.R": {"x": 16}}


def dizzy_pose(phase):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({"head": {"z": 18 * s, "x": 12 + 6 * c}, "chest": {"z": -7 * s, "y": 5 * c},
                 "spine": {"y": 4 * s}, "root": {"loc": (0.03 * s, 0, -0.08)}}, LIMP)


make_action("Stunned", 40, {f: dizzy_pose(f / 40 * math.tau) for f in range(0, 40, 5)}, loop=True)

make_action("HitReact", 14, {
    0: pose({}),
    4: pose({"chest": {"x": -14, "z": 8}, "head": {"x": -12}, "spine": {"x": -6},
             "upperarm.R": {"x": 15, "y": -8}}),
    14: pose({}),
})

# Смерть: хитнувся назад, щит обвис — і важко, як колода, ниць.
make_action("Death", 56, {
    0: pose({}),
    10: pose({"chest": {"x": -14}, "head": {"x": -20}, "spine": {"x": -6}, "upperarm.L": {"x": 15, "z": 15},
              "upperarm.R": {"x": 20, "y": 5}}),
    22: pose({"root": {"x": 25}, "chest": {"x": 6}, "head": {"x": 8}}, LIMP),
    38: pose({"root": {"x": 84, "loc": (0, 0, 0.02)}, "upperarm.L": {"x": -30, "z": 20},
              "upperarm.R": {"x": -40, "y": 15}, "head": {"x": -25}}, LIMP),
    46: pose({"root": {"x": 80, "loc": (0, 0, 0.05)}, "upperarm.L": {"x": -35, "z": 20},
              "upperarm.R": {"x": -45, "y": 15}, "head": {"x": -20}}, LIMP),
    56: pose({"root": {"x": 84, "loc": (0, 0, 0.02)}, "upperarm.L": {"x": -30, "z": 20},
              "upperarm.R": {"x": -40, "y": 15}, "head": {"x": -22}}, LIMP),
})
