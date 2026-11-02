import glob
import json
import os
import struct
import sys

# Метадані GLB: генератор, авторське право, extras — щоб зрозуміти, чиї моделі.
root = sys.argv[1] if len(sys.argv) > 1 else 'D:/RuneHorde_work/dungeon_in'
seen = {}
for path in sorted(glob.glob(os.path.join(root, '**', '*.glb'), recursive=True)):
    with open(path, 'rb') as f:
        data = f.read()
    length = struct.unpack('<I', data[12:16])[0]
    j = json.loads(data[20:20 + length])
    asset = j.get('asset', {})
    folder = os.path.basename(os.path.dirname(path))
    key = (folder, asset.get('generator', ''), asset.get('copyright', ''), json.dumps(asset.get('extras', {}), ensure_ascii=False)[:160])
    seen.setdefault(key, []).append(os.path.basename(path))
for key, files in seen.items():
    print(key, len(files), files[:4])
