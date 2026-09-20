# Куди класти арт

Гра шукає файли за назвами сама. Поклав файл із правильним іменем у
правильну папку — він з'явився в грі. Нічого в коді міняти не треба.
Поки файлу немає, показується заглушка (кольорова рамка або тимчасова
модель), і гра все одно працює.

## 3D-моделі героїв

    assets/models/heroes/<id героя>.glb

| Герой | id | Стан |
|---|---|---|
| Клинкова Вартова | `blade_warden` | є модель (Hooded Adventurer) |
| Руновод | `runewielder` | тимчасова |
| Жриця Багаття | `ember_priestess` | тимчасова |
| Асасин Порожнечі | `void_assassin` | тимчасова |

**Вимоги до моделі героя.** Найпростіше брати персонажів того самого
автора (Quaternius): у них однаковий скелет і однакові назви анімацій,
тож модель запрацює одразу, без налаштувань. Потрібні анімації:

    Idle, Walk, Run, Run_Back, Run_Left, Run_Right,
    Sword_Slash, Kick_Right, Roll, HitRecieve, Death

Чого немає — гра підмінить схожим (наприклад, бігу назад — ходою), але
що більше з цього списку є, то краще виглядає бій.

Якщо модель з іншого набору й анімації звуться інакше, їх можна
перейменувати в описі героя: поле `animation_names` у
`data/heroes/<герой>.tres` (ключ — наша назва, значення — назва в
моделі). Там же `weapon_bone` — кістка правої руки, до якої кріпиться
зброя (за замовчуванням `Wrist.R`).

## 3D-моделі зброї

    assets/models/weapons/<id зброї>.glb

| Герой | Зброя (id) |
|---|---|
| Клинкова Вартова | `war_blade`, `battle_axe`, `harpoon_glaive`, `blade_storm` |
| Руновод | `rune_bolt`, `staff_meteor`, `storm_scepter`, `frost_staff` |
| Жриця Багаття | `ember_bolt`, `flamethrower`, `pyre_totem`, `sun_lance` |
| Асасин Порожнечі | `shadow_dagger`, `venom_daggers`, `void_scythe`, `shadow_chains` |

Модель має «дивитись» руків'ям униз, вістрям угору (вісь Y). Якщо лягла
криво — підженіть `grip_offset`, `grip_rotation_deg` і `model_scale` в
`data/weapons/<зброя>.tres`.

## Іконки

    assets/ui/icons/menu/<назва>.png       play, heroes, weapons, talents, shop, chest
    assets/ui/icons/skills/<id>.png        whirlwind, rage_dash, rune_nova, fire_ring, smoke_veil
    assets/ui/icons/talents/<id>.png       meta_max_hp, meta_damage, meta_move_speed,
                                           meta_pickup_radius, meta_gold_gain, meta_luck,
                                           meta_start_level, talent_extra_blades,
                                           talent_bolt_pierce, talent_aura_power,
                                           talent_shadow_clones
    assets/ui/icons/weapons/<id зброї>.png

Іконки — квадратні PNG з прозорим тлом, 128×128 достатньо (кнопки
менші, але з запасом виглядає різкіше).

## Що зараз тимчасове

- моделі трьох героїв (крім Вартової) — це модель Вартової, пофарбована
  в колір героя;
- моделі зброї — прості фігури (лезо, держак, кулька на посоху),
  зібрані кодом: сокира, глефа, посох і кинджали відрізняються
  формою й довжиною;
- усі іконки — кольорові рамки-заглушки.
