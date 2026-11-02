# Анімації Кладовищенського привида (скелет Rodin; rig_rodin_custom.py).
# Ширяє: тіло гойдається, хвіст в'ється хвилею, ланцюг на лівій руці
# хитається. Кути — світові осі: x — нахил уперед (+), руки вперед-угору (-).
TAIL = ["Tail1", "Tail2", "Tail3", "Tail4", "Tail5"]
CHAIN = ["LeftShackle", "LeftChain1", "LeftChain2", "LeftChain3"]


def float_pose(phase, wave, lean=0.0, arms=0.0):
    s = math.sin(phase)
    c = math.cos(phase)
    spec = {"Hips": {"loc": (0, 0, 0.04 * s), "x": lean * 0.4},
            "Spine": {"x": 2 * c + lean * 0.3}, "Spine1": {"x": lean * 0.3}, "Head": {"z": 4 * s, "x": -lean * 0.5},
            "LeftArm": {"x": 3 * c + arms}, "RightArm": {"x": -3 * c + arms},
            "LeftForeArm": {"x": 4 * s}, "RightForeArm": {"x": -4 * s}}
    for i, bone in enumerate(TAIL):
        spec[bone] = {"z": wave * math.sin(phase - i * 0.9), "x": 0.3 * wave * math.cos(phase - i * 0.9)}
    for i, bone in enumerate(CHAIN):
        spec[bone] = {"x": 10 * math.sin(phase - 0.8 - i * 0.6), "y": 6 * math.cos(phase - i * 0.5)}
    return pose(spec)


make_action("Idle", 60, {f: float_pose(f / 60 * math.tau, 9) for f in range(0, 60, 5)}, loop=True)
make_action("Walk", 30, {f: float_pose(f / 30 * math.tau, 16, 12, 5) for f in range(0, 30, 3)}, loop=True)

# Холодний дотик: відхилився — і ривком простягає обидві руки вперед.
make_action("Weapon", 26, {
    0: float_pose(0, 9),
    10: pose({"Spine": {"x": -10}, "Spine1": {"x": -6}, "Head": {"x": 6}, "LeftArm": {"x": 8},
              "RightArm": {"x": 8}, "Hips": {"loc": (0, 0.06, 0.03)}}, float_pose(0, 9)),
    16: pose({"Spine": {"x": 8}, "Spine1": {"x": 5}, "Head": {"x": -8}, "LeftArm": {"x": -10},
              "RightArm": {"x": -10}, "LeftForeArm": {"x": -8}, "RightForeArm": {"x": -8},
              "Hips": {"loc": (0, -0.18, -0.02)}}, float_pose(0, 9)),
    20: pose({"Spine": {"x": 6}, "LeftArm": {"x": -8}, "RightArm": {"x": -8},
              "Hips": {"loc": (0, -0.14, 0.0)}}, float_pose(0, 9)),
    26: float_pose(0, 9),
})

make_action("HitReact", 14, {
    0: float_pose(0, 9),
    4: pose({"Spine": {"x": -14}, "Head": {"x": -12}, "LeftArm": {"x": 6}, "RightArm": {"x": 6},
             "Hips": {"loc": (0, 0.1, 0.02)}}, float_pose(0, 9)),
    14: float_pose(0, 9),
})

# Розвіюється: здіймається, відкидається назад, руки в боки.
make_action("Death", 40, {
    0: float_pose(0, 9),
    14: pose({"Spine": {"x": -10}, "Spine1": {"x": -5}, "Head": {"x": -20}, "LeftArm": {"y": -10, "x": -6},
              "RightArm": {"y": 10, "x": -6}, "Hips": {"loc": (0, 0.05, 0.2)}}, float_pose(0, 20)),
    40: pose({"Spine": {"x": -14}, "Spine1": {"x": -8}, "Head": {"x": -30}, "LeftArm": {"y": -14, "x": -8},
              "RightArm": {"y": 14, "x": -8}, "Hips": {"loc": (0, 0.1, 0.45)}}, float_pose(1.5, 25)),
})
