# -*- coding: utf-8 -*-
"""Атласи й шоломи для 20 сетів (рідкості 2..5) за кольорами з описів."""
import subprocess, sys, os, re, shutil
OUT = r"D:/Claude code/idle survivor_like/assets/models/character/outfits"
S = r"D:/RuneHorde_work/scripts"
# tag: (cloth, cloth2, leather, metal, helmet_base, helmet_accent)
SETS = {
 "Sword2": ("2f4f8f", "6b6f76", "5a4632", "b8bec8", "aab2bc", "3a5fa8"),
 "Sword3": ("9a2a24", "8c939c", "6b4a2a", "d9b24a", "c8ccd2", "d4a83a"),
 "Sword4": ("1e1a1c", "8a1420", "3a1e1e", "b02030", "2a2528", "c02030"),
 "Sword5": ("e8e2d4", "d4a536", "8a6a30", "f0c850", "e0b84a", "5ab0f0"),
 "Tank2": ("5c6066", "3d3f44", "4a3a2c", "9aa0a8", "8a9098", "5c6066"),
 "Tank3": ("7d7a72", "4f6b3a", "5a5248", "a8a49a", "8a867c", "5a7a40"),
 "Tank4": ("233a6b", "8a7a64", "4a3a2c", "7f9cc8", "2c4a80", "b8c4d8"),
 "Tank5": ("c8962e", "8a5a2a", "6a4a24", "f2d060", "d8aa3c", "ffd870"),
 "Mage2": ("1f2f6e", "2a3c8a", "3a3050", "c0c8d8", None, None),
 "Mage3": ("e8ecf2", "1f4fa8", "8a7040", "d4b050", None, None),
 "Mage4": ("1c1618", "8a1c18", "3a2420", "e07020", None, None),
 "Mage5": ("5a2a8a", "3c1c64", "7a5a30", "e0b84a", None, None),
 "Archer2": ("2f5a2a", "5a4028", "6a4a2a", "9a8a6a", None, None),
 "Archer3": ("a07a4a", "6a4a2c", "7a5530", "d8d0c0", None, None),
 "Archer4": ("1f3a6e", "1c2030", "3a3a4a", "c8d4e8", None, None),
 "Archer5": ("a01e18", "d4a030", "5a1a14", "f0c040", None, None),
 "Druid2": ("4a6a2a", "3a5a24", "6a5030", "9a8a5a", None, None),
 "Druid3": ("5a4028", "8a1e1e", "4a3020", "7a6a50", None, None),
 "Druid4": ("8a8c90", "d8d8d0", "4a4038", "a8c8e8", None, None),
 "Druid5": ("c89a3a", "4a9a3a", "7a5a28", "f0d060", None, None),
}
for tag, (c0, c1, c2, c3, hb, ha) in SETS.items():
    for fam, atlas in (("ranger", "T_Ranger_BaseColor.png"), ("peasant", "T_Peasant_BaseColor.png")):
        dst = f"{OUT}/T_{tag}_{fam.capitalize()}.png"
        subprocess.run([sys.executable, f"{S}/recolor_atlas.py", f"{OUT}/{atlas}", fam, dst, c0, c1, c2, c3], check=True)
    if hb:
        src_tag = "Sword1" if tag.startswith("Sword") else "Tank1"
        for g in ("Male", "Female"):
            subprocess.run([sys.executable, f"{S}/recolor_helmet.py", f"{OUT}/{g}_{src_tag}_Head_diffuse.jpg",
                            f"{OUT}/{g}_{tag}_Head_diffuse.jpg", hb, ha], check=True)
            text = open(f"{OUT}/{g}_{src_tag}_Head.gltf", encoding="utf-8").read()
            text = text.replace(f'"{g}_{src_tag}_Head_diffuse.jpg"', f'"{g}_{tag}_Head_diffuse.jpg"')
            open(f"{OUT}/{g}_{tag}_Head.gltf", "w", encoding="utf-8").write(text)
