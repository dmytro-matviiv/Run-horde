# -*- coding: utf-8 -*-
D = "D:/RuneHorde_work/scripts/blender/"
src = open(D + "rig_shield_orc.py", encoding="utf-8").read()
a = src.index("# Центр тіла зміщений")
b = src.index("]\n", src.index("BONES = [")) + 2
bones = '''# Згорблений чаклун: голова й груди подані вперед, горб ззаду. Посох
# (права рука) — на -x, ліва рука (чари) — на +x, витягнута вперед.
CX = 0.03
BONES = [
    ("root", None, bl(CX, 0.0, 0), bl(CX, 0.12, 0), 0.0),
    ("hips", "root", bl(CX, 0.80, 0.0), bl(CX, 1.00, 0.0), 0.24),
    ("spine", "hips", bl(CX, 1.00, 0.0), bl(CX, 1.20, -0.02), 0.26),
    ("chest", "spine", bl(CX, 1.20, -0.02), bl(0.0, 1.45, 0.02), 0.28),
    ("neck", "chest", bl(0.0, 1.45, 0.02), bl(-0.03, 1.55, 0.08), 0.12),
    ("head", "neck", bl(-0.03, 1.55, 0.08), bl(-0.05, 1.85, 0.12), 0.20),
    ("upperarm.R", "chest", bl(-0.28, 1.38, 0.0), bl(-0.40, 1.10, 0.0), 0.10),
    ("forearm.R", "upperarm.R", bl(-0.40, 1.10, 0.0), bl(-0.47, 0.95, 0.0), 0.09),
    ("hand.R", "forearm.R", bl(-0.47, 0.95, 0.0), bl(-0.62, 0.95, 0.0), 0.08),
    ("upperarm.L", "chest", bl(0.36, 1.36, 0.0), bl(0.50, 1.12, 0.05), 0.10),
    ("forearm.L", "upperarm.L", bl(0.50, 1.12, 0.05), bl(0.58, 0.98, 0.18), 0.09),
    ("hand.L", "forearm.L", bl(0.58, 0.98, 0.18), bl(0.72, 0.95, 0.28), 0.09),
    ("thigh.R", "hips", bl(-0.12, 0.80, 0.0), bl(-0.15, 0.42, -0.05), 0.14),
    ("shin.R", "thigh.R", bl(-0.15, 0.42, -0.05), bl(-0.18, 0.08, -0.10), 0.12),
    ("foot.R", "shin.R", bl(-0.18, 0.08, -0.10), bl(-0.19, 0.0, 0.02), 0.10),
    ("thigh.L", "hips", bl(0.22, 0.80, 0.0), bl(0.28, 0.42, 0.05), 0.14),
    ("shin.L", "thigh.L", bl(0.28, 0.42, 0.05), bl(0.30, 0.08, 0.0), 0.12),
    ("foot.L", "shin.L", bl(0.30, 0.08, 0.0), bl(0.30, 0.0, 0.14), 0.10),
]
'''
s = src[:a] + bones + src[b:]
s = s.replace('"""Орк-щитоносець (модель гравця з Rodin, без скелета). Той самий конвеєр,',
              '"""Склепний чаклун (модель гравця з Rodin, без скелета). Той самий конвеєр,')
s = s.replace('mesh_obj.name = "ShieldOrc"', 'mesh_obj.name = "CryptWarlock"').replace("TARGET_TRIS = 8000", "TARGET_TRIS = 7000")
ra = s.index("# Булава й кулак")
end = 'print("RIGID shield", rigid("forearm.L", shield))'
rb = s.index(end) + len(end)
s = s[:ra] + '''# Посох — цілком на правій кисті.
x = coords[:, 0]
staff = (x < -0.53) | near_bone("hand.R", 0.08)
print("RIGID staff", rigid("hand.R", staff))''' + s[rb:]
aa = s.index("# Знаки (осі арматури)")
ab = s.index("# --- текстури й експорт ---")
s = s[:aa] + open("D:/RuneHorde_work/scripts/tmp/warlock_anims.py", encoding="utf-8").read() + "\n" + s[ab:]
open(D + "rig_warlock.py", "w", encoding="utf-8").write(s)
print("ok")
