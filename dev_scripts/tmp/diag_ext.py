# -*- coding: utf-8 -*-
"""Діагностика: які ребра сітки найбільше розтягуються в позі анімації.
  blender -b --factory-startup -P diag_stretch.py -- <модель.glb> <Action> <кадр>"""
import sys
from collections import Counter

import bpy
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
mesh = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
rest = np.array([(mesh.matrix_world @ v.co)[:] for v in mesh.data.vertices])
arm.animation_data.action = bpy.data.actions[argv[1]]
bpy.context.scene.frame_set(int(argv[2]))
deps = bpy.context.evaluated_depsgraph_get()
ev = mesh.evaluated_get(deps)
posed = np.array([(mesh.matrix_world @ v.co)[:] for v in ev.data.vertices])
edges = np.array([e.vertices[:] for e in mesh.data.edges])
r = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
p = np.linalg.norm(posed[edges[:, 0]] - posed[edges[:, 1]], axis=1)
ratio = (p - r) * 100
bad = np.argsort(-ratio)[:400]
groups = {g.index: g.name for g in mesh.vertex_groups}
def top(vi):
    ws = sorted(((g.weight, groups[g.group]) for g in mesh.data.vertices[vi].groups), reverse=True)[:3]
    return ", ".join("%s %.2f" % (n, w) for w, n in ws)
print("STRETCH max %.1f, >3x: %d edges" % (ratio.max(), int((ratio > 3).sum())))
pairs = Counter()
for e in bad[:400]:
    if ratio[e] < 4:
        break
    a, b = edges[e]
    ga = top(a).split(" ")[0]
    gb = top(b).split(" ")[0]
    pairs[(ga, gb) if ga < gb else (gb, ga)] += 1
for pair, n in pairs.most_common(10):
    print("PAIR", pair, n)
for e in bad[:8]:
    a, b = edges[e]
    print("EDGE x%.1f  A %s [%s]  B %s [%s]" % (ratio[e], np.round(rest[a], 3), top(a), np.round(rest[b], 3), top(b)))
sel = ratio > 4
mid = (rest[edges[sel, 0]] + rest[edges[sel, 1]]) / 2
if len(mid):
    for lo in np.arange(0, 1.9, 0.2):
        m = (mid[:, 2] >= lo) & (mid[:, 2] < lo + 0.2)
        if m.any():
            print("BAND z%.1f n %3d  x %.2f..%.2f  y %.2f..%.2f" % (lo, m.sum(), mid[m, 0].min(), mid[m, 0].max(), mid[m, 1].min(), mid[m, 1].max()))
