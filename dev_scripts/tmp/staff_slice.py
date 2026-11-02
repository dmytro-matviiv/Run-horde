import bpy, sys
import numpy as np
argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.import_scene.gltf(filepath=argv[0])
m = max((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: len(o.data.polygons))
c = np.array([(m.matrix_world @ v.co)[:] for v in m.data.vertices])
x, y, z = c[:, 0], c[:, 1], c[:, 2]
for lo in np.arange(0.0, 1.95, 0.1):
    band = (z >= lo) & (z < lo + 0.1)
    left = band & (x < -0.30)
    shaft = band & (np.abs(x + 0.465) < 0.04) & (np.abs(y + 0.18) < 0.05)
    sx = x[left]; sy = y[left]
    print("z %.1f  x<-0.3: %4d  x[%.2f..%.2f] y[%.2f..%.2f] | shaft %3d  x[%s] y[%s]" % (lo, left.sum(),
        sx.min() if len(sx) else 0, sx.max() if len(sx) else 0, sy.min() if len(sy) else 0, sy.max() if len(sy) else 0,
        shaft.sum(), "%.2f..%.2f" % (x[shaft].min(), x[shaft].max()) if shaft.any() else "-",
        "%.2f..%.2f" % (y[shaft].min(), y[shaft].max()) if shaft.any() else "-"))
# Робa без посоха: найлівіша точка тіла на кожній висоті (поза |y+0.18|<0.07)
for lo in np.arange(0.0, 1.95, 0.1):
    band = (z >= lo) & (z < lo + 0.1) & ~((np.abs(x + 0.465) < 0.07) & (np.abs(y + 0.18) < 0.08))
    print("body z %.1f min x %.2f" % (lo, x[band].min() if band.any() else 0))
