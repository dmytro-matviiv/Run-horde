# Анімації Розкладеної плоті (скелет Rodin; rig_rodin_custom.py). Важкий
# товстун: перевалюється з ноги на ногу, б'є обома руками згори.
# Кути — світові осі: x — нахил уперед (+), руки/ноги вперед (-); y — убік.


def idle_pose(phase):
    s = math.sin(phase)
    return pose({"Spine": {"x": 2 * s}, "Spine1": {"x": -2 * s}, "Head": {"z": 6 * s, "x": 3},
                 "LeftArm": {"x": 4 * s}, "RightArm": {"x": -4 * s}, "Hips": {"loc": (0, 0, -0.012 * (1 + s))}})


make_action("Idle", 72, {f: idle_pose(f / 72 * math.tau) for f in range(0, 72, 9)}, loop=True)


def walk_pose(phase, stride):
    s = math.sin(phase)
    c = math.cos(phase)
    return pose({
        "LeftUpLeg": {"x": -stride * s}, "RightUpLeg": {"x": stride * s},
        "LeftLeg": {"x": stride * 0.9 * max(0.0, -s)}, "RightLeg": {"x": stride * 0.9 * max(0.0, s)},
        "Hips": {"y": 6 * s, "loc": (0, 0, -0.02 * abs(c))}, "Spine": {"z": -5 * s, "x": 4}, "Spine2": {"y": -4 * s},
        "LeftArm": {"x": 12 * s}, "RightArm": {"x": -12 * s}, "Head": {"z": 3 * s},
    })


make_action("Walk", 44, {f: walk_pose(f / 44 * math.tau, 18) for f in range(0, 44, 4)}, loop=True)

# Удар обома руками згори: здійняв (0.5 с) — і всією вагою вниз.
make_action("Weapon", 32, {
    0: idle_pose(0),
    14: pose({"LeftArm": {"x": -95, "y": 10}, "RightArm": {"x": -95, "y": -10}, "LeftForeArm": {"x": -30},
              "RightForeArm": {"x": -30}, "Spine": {"x": -10}, "Spine1": {"x": -6}, "Head": {"x": -8}}),
    18: pose({"LeftArm": {"x": -25}, "RightArm": {"x": -25}, "Spine": {"x": 22}, "Spine1": {"x": 10},
              "Head": {"x": 8}, "LeftUpLeg": {"x": -15}, "RightUpLeg": {"x": -15}, "LeftLeg": {"x": 20},
              "RightLeg": {"x": 20}, "Hips": {"loc": (0, 0, -0.07)}}),
    24: pose({"LeftArm": {"x": -20}, "RightArm": {"x": -20}, "Spine": {"x": 16}, "Hips": {"loc": (0, 0, -0.05)}}),
    32: idle_pose(0),
})

make_action("HitReact", 14, {
    0: idle_pose(0),
    4: pose({"Spine": {"x": -8}, "Spine1": {"x": -5}, "Head": {"x": -14, "z": 6}, "LeftArm": {"x": 8}, "RightArm": {"x": 8}}),
    14: idle_pose(0),
})
