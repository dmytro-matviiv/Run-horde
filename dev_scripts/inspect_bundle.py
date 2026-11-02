# -*- coding: utf-8 -*-
"""Розпаковує набір монстрів і показує, у кого які анімації."""
import io
import json
import os
import struct
import zipfile

SRC = r'D:\Claude code\assets_incoming\Ultimate Monsters Bundle-glb (1).zip'
DST = r'D:\Claude code\assets_incoming\monsters'

os.makedirs(DST, exist_ok=True)
archive = zipfile.ZipFile(SRC)
for name in archive.namelist():
    if name.endswith('.glb') and not name.startswith('__MACOSX'):
        target = os.path.join(DST, os.path.basename(name))
        with open(target, 'wb') as out:
            out.write(archive.read(name))

for file_name in sorted(os.listdir(DST)):
    if not file_name.endswith('.glb'):
        continue
    with open(os.path.join(DST, file_name), 'rb') as f:
        f.read(12)
        chunk_len, _ = struct.unpack('<II', f.read(8))
        data = json.loads(f.read(chunk_len).decode('utf-8'))
    animations = [a.get('name', '?') for a in data.get('animations', [])]
    print('%-26s анімацій %2d: %s' % (file_name[:-4], len(animations), ', '.join(animations[:12])))
