# -*- coding: utf-8 -*-
"""Обробляє весь згенерований арт користувача й кладе готові PNG у
assets/ui/icons/... (де їх сама підхопить ArtSlots)."""
import os
import process_ui_art as p

DESKTOP = r"C:\Users\ibogd\OneDrive\Desktop"
PROJECT = r"D:\Claude code\idle survivor_like\assets\ui\icons"

ICON_SIZE = 256
DUNGEON_SIZE = 320

JOBS = []

def add(src_dir, dst_dir, ids, size):
    for name in ids:
        JOBS.append({
            "src": os.path.join(DESKTOP, src_dir, name + ".png"),
            "dst": os.path.join(PROJECT, dst_dir, name + ".png"),
            "size": size,
        })

add("Картинки данжів", "dungeons", [
    "abyss", "bone_yard", "citadel", "crypts", "deep_hell_forge", "forge",
    "forgotten_gods_abyss", "frozen_citadel_north", "fungal", "herald_of_doom",
    "icy_abyss_lord", "shadow_lord", "sunken_gardens", "vault", "village",
], DUNGEON_SIZE)

add("Меню", "menu", ["chest", "shop"], ICON_SIZE)

add("Бій — базові кнопки", "combat", [
    "attack", "bolt", "book", "cards", "dash", "dodge", "fire", "frost",
    "gun", "nova", "rune", "smoke", "staff", "venom", "whirl",
], ICON_SIZE)

add("Бій — здібності героїв", "skills", [
    "arcane_barrage", "card_storm", "fire_ring", "frost_nova", "great_seal",
    "moon_storm", "rage_dash", "rune_nova", "smoke_veil", "venom_swamp", "whirlwind",
], ICON_SIZE)

add("Таланти (Зала героїв, довгостроковий розвиток)", "talents", [
    "meta_damage", "meta_gold_gain", "meta_luck", "meta_max_hp",
    "meta_move_speed", "meta_pickup_radius",
], ICON_SIZE)

add("Магазин", "shop", ["exchange", "gems_large", "gems_medium", "gems_small"], ICON_SIZE)

if __name__ == "__main__":
    ok, fail = 0, 0
    for job in JOBS:
        try:
            p.process(job["src"], job["dst"], job["size"])
            ok += 1
        except Exception as exc:
            print("FAIL", job["src"], "->", exc)
            fail += 1
    print("---")
    print("Готово: %d, помилок: %d" % (ok, fail))
