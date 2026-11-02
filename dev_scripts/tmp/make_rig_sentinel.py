# -*- coding: utf-8 -*-
D = "D:/RuneHorde_work/scripts/blender/"
src = open(D + "rig_shield_orc.py", encoding="utf-8").read()
a = src.index("# Центр тіла зміщений")
b = src.index("]\n", src.index("BONES = [")) + 2
bones = '''# Ожилий вартовий: лицар у латах, обома руками тримає меч вістрям донизу
# перед собою (руків'я на висоті 1.15 м, клинок уздовж ніг).
BONES = [
    ("root", None, bl(0, 0.0, 0), bl(0, 0.12, 0), 0.0),
    ("hips", "root", bl(0, 0.88, 0.0), bl(0, 1.05, 0.0), 0.22),
    ("spine", "hips", bl(0, 1.05, 0.0), bl(0, 1.25, 0.0), 0.26),
    ("chest", "spine", bl(0, 1.25, 0.0), bl(0, 1.45, 0.0), 0.30),
    ("neck", "chest", bl(0, 1.45, 0.0), bl(0, 1.56, 0.0), 0.10),
    ("head", "neck", bl(0, 1.56, 0.0), bl(0, 1.88, 0.0), 0.14),
    ("upperarm.R", "chest", bl(-0.27, 1.42, 0.0), bl(-0.31, 1.20, 0.06), 0.11),
    ("forearm.R", "upperarm.R", bl(-0.31, 1.20, 0.06), bl(-0.20, 1.13, 0.22), 0.10),
    ("hand.R", "forearm.R", bl(-0.20, 1.13, 0.22), bl(-0.07, 1.13, 0.30), 0.08),
    ("upperarm.L", "chest", bl(0.27, 1.42, 0.0), bl(0.31, 1.20, 0.06), 0.11),
    ("forearm.L", "upperarm.L", bl(0.31, 1.20, 0.06), bl(0.20, 1.13, 0.22), 0.10),
    ("hand.L", "forearm.L", bl(0.20, 1.13, 0.22), bl(0.07, 1.13, 0.30), 0.08),
    ("thigh.R", "hips", bl(-0.12, 0.88, 0.0), bl(-0.14, 0.47, 0.0), 0.13),
    ("shin.R", "thigh.R", bl(-0.14, 0.47, 0.0), bl(-0.15, 0.08, 0.0), 0.11),
    ("foot.R", "shin.R", bl(-0.15, 0.08, 0.0), bl(-0.15, 0.0, 0.15), 0.09),
    ("thigh.L", "hips", bl(0.12, 0.88, 0.0), bl(0.14, 0.47, 0.0), 0.13),
    ("shin.L", "thigh.L", bl(0.14, 0.47, 0.0), bl(0.15, 0.08, 0.0), 0.11),
    ("foot.L", "shin.L", bl(0.15, 0.08, 0.0), bl(0.15, 0.0, 0.15), 0.09),
]
'''
s = src[:a] + bones + src[b:]
s = s.replace('"""Орк-щитоносець (модель гравця з Rodin, без скелета). Той самий конвеєр,',
              '"""Ожилий вартовий (модель гравця з Rodin; свій скелет замість Rodin — там меч розмазувався). Той самий конвеєр,')
s = s.replace('mesh_obj.name = "ShieldOrc"', 'mesh_obj.name = "IceSentinel"').replace("TARGET_TRIS = 8000", "TARGET_TRIS = 7000")
# Rodin-скелет у файлі — прибрати, беремо лише меш.
s = s.replace('mesh_obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]',
              'mesh_obj = max((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: len(o.data.polygons))\n'
              'mesh_obj.modifiers.clear()\nmesh_obj.parent = None\nfor g in list(mesh_obj.vertex_groups):\n    mesh_obj.vertex_groups.remove(g)\n'
              'for o in list(bpy.context.scene.objects):\n    if o is not mesh_obj:\n        bpy.data.objects.remove(o, do_unlink=True)\n'
              'for act in list(bpy.data.actions):\n    bpy.data.actions.remove(act)', 1)
ra = s.index("# Булава й кулак")
end = 'print("RIGID shield", rigid("forearm.L", shield))'
rb = s.index(end) + len(end)
s = s[:ra] + '''# Меч (клинок, гарда, руків'я) і обидві кисті на ньому — на правій кисті.
x, y, z = coords[:, 0], coords[:, 1], coords[:, 2]
sword = ((np.abs(x) < 0.06) & (y < -0.18) & (z < 1.25)) | ((np.abs(x) < 0.16) & (y < -0.18) & (z > 0.72) & (z < 1.0))
hands = near_bone("hand.R", 0.08) | near_bone("hand.L", 0.08)
print("RIGID sword", rigid("hand.R", sword | hands))''' + s[rb:]
aa = s.index("# Знаки (осі арматури)")
ab = s.index("# --- текстури й експорт ---")
s = s[:aa] + open("D:/RuneHorde_work/scripts/tmp/sentinel_anims.py", encoding="utf-8").read() + "\n" + s[ab:]
open(D + "rig_sentinel.py", "w", encoding="utf-8").write(s)
print("ok")
