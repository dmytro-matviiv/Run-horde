# -*- coding: utf-8 -*-
D = "D:/RuneHorde_work/scripts/blender/"
src = open(D + "rig_shield_orc.py", encoding="utf-8").read()
a = src.index("# Центр тіла зміщений")
b = src.index("]\n", src.index("BONES = [")) + 2
bones = '''# Хранитель Склепів: центр тіла на x = 0.16; молот-надгробок у правій руці
# (-x), ліва рука (+x) з ланцюгом ключів опущена вздовж тіла.
CX = 0.16
BONES = [
    ("root", None, bl(CX, 0.0, 0), bl(CX, 0.12, 0), 0.0),
    ("hips", "root", bl(CX, 0.72, 0.0), bl(CX, 0.95, 0.0), 0.30),
    ("spine", "hips", bl(CX, 0.95, 0.0), bl(CX, 1.18, 0.0), 0.32),
    ("chest", "spine", bl(CX, 1.18, 0.0), bl(CX, 1.42, 0.02), 0.34),
    ("neck", "chest", bl(CX, 1.42, 0.02), bl(0.14, 1.55, 0.05), 0.14),
    ("head", "neck", bl(0.14, 1.55, 0.05), bl(0.13, 1.85, 0.08), 0.20),
    ("upperarm.R", "chest", bl(-0.12, 1.38, 0.0), bl(-0.33, 1.12, 0.02), 0.13),
    ("forearm.R", "upperarm.R", bl(-0.33, 1.12, 0.02), bl(-0.47, 0.95, 0.06), 0.12),
    ("hand.R", "forearm.R", bl(-0.47, 0.95, 0.06), bl(-0.52, 0.88, 0.08), 0.10),
    ("upperarm.L", "chest", bl(0.48, 1.38, 0.0), bl(0.66, 1.08, 0.0), 0.13),
    ("forearm.L", "upperarm.L", bl(0.66, 1.08, 0.0), bl(0.74, 0.82, 0.02), 0.12),
    ("hand.L", "forearm.L", bl(0.74, 0.82, 0.02), bl(0.76, 0.62, 0.03), 0.11),
    ("thigh.R", "hips", bl(-0.04, 0.72, 0.0), bl(-0.08, 0.38, 0.0), 0.17),
    ("shin.R", "thigh.R", bl(-0.08, 0.38, 0.0), bl(-0.10, 0.10, 0.0), 0.14),
    ("foot.R", "shin.R", bl(-0.10, 0.10, 0.0), bl(-0.10, 0.0, 0.18), 0.12),
    ("thigh.L", "hips", bl(0.38, 0.72, 0.0), bl(0.42, 0.38, 0.0), 0.17),
    ("shin.L", "thigh.L", bl(0.42, 0.38, 0.0), bl(0.43, 0.10, 0.0), 0.14),
    ("foot.L", "shin.L", bl(0.43, 0.10, 0.0), bl(0.43, 0.0, 0.18), 0.12),
]
'''
s = src[:a] + bones + src[b:]
s = s.replace('"""Орк-щитоносець (модель гравця з Rodin, без скелета). Той самий конвеєр,',
              '"""Хранитель Склепів, бос 1-го данжу (модель гравця з Rodin, без скелета). Той самий конвеєр,')
s = s.replace('mesh_obj.name = "ShieldOrc"', 'mesh_obj.name = "CryptKeeper"').replace("TARGET_TRIS = 8000", "TARGET_TRIS = 12000")
ra = s.index("# Булава й кулак")
end = 'print("RIGID shield", rigid("forearm.L", shield))'
rb = s.index(end) + len(end)
s = s[:ra] + '''# Молот-надгробок (держак і голова) — цілком на правій кисті.
x = coords[:, 0]
hammer = (x < -0.44) | near_bone("hand.R", 0.1)
print("RIGID hammer", rigid("hand.R", hammer))''' + s[rb:]
aa = s.index("# Знаки (осі арматури)")
ab = s.index("# --- текстури й експорт ---")
s = s[:aa] + open("D:/RuneHorde_work/scripts/tmp/keeper_anims.py", encoding="utf-8").read() + "\n" + s[ab:]
open(D + "rig_keeper.py", "w", encoding="utf-8").write(s)
print("ok")
