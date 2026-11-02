# -*- coding: utf-8 -*-
"""Дивиться, що всередині моделей: чи є скелет і чи є анімації."""
import glob
import json
import os
import struct

os.chdir(r'D:\Claude code\idle survivor_like\assets_incoming\bestiary')

for path in sorted(glob.glob('**/*.glb', recursive=True)):
    with open(path, 'rb') as f:
        f.read(12)
        chunk_len, _ = struct.unpack('<II', f.read(8))
        data = json.loads(f.read(chunk_len).decode('utf-8'))
    names = [n.get('name', '?') for n in data.get('nodes', [])]
    print('GLB %-12s скінів: %d, вузлів: %d, анімацій: %d'
          % (os.path.basename(path), len(data.get('skins', [])), len(names), len(data.get('animations', []))))
    print('    вузли:', names[:14])

for path in sorted(glob.glob('**/*.fbx', recursive=True)):
    blob = open(path, 'rb').read()
    counts = {key.decode(): blob.count(key) for key in
              (b'AnimationStack', b'AnimationLayer', b'AnimCurveNode', b'Deformer', b'LimbNode')}
    print('FBX %-12s %s' % (os.path.basename(path), counts))
