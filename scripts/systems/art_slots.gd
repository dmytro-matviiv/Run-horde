extends RefCounted
class_name ArtSlots

## ЗАГОТОВКИ ПІД АРТ.
##
## Гра не чекає, поки буде намальовано все: кожне місце під картинку чи
## модель має "слот". Поки файлу немає, показується тимчасова заглушка
## (кольорова емблема або тимчасова модель), а щойно ви покладете файл
## із правильною назвою в правильну папку — він підхопиться сам, без
## жодних змін у коді.
##
## Куди що класти (повний список — в assets/ART_GUIDE.md):
##   3D-модель героя     res://assets/models/heroes/<id героя>.glb
##   3D-модель зброї     res://assets/models/weapons/<id зброї>.glb
##   іконка кнопки меню  res://assets/ui/icons/menu/<назва>.png
##   іконка здібності    res://assets/ui/icons/skills/<id здібності>.png
##   іконка таланту      res://assets/ui/icons/talents/<id таланту>.png
##   іконка зброї        res://assets/ui/icons/weapons/<id зброї>.png
##   іконка в магазині   res://assets/ui/icons/shop/<назва товару>.png
##   картинка рівня данжу res://assets/ui/icons/dungeons/<id рівня>.png
##
## id героя та зброї — ті самі, що в data/heroes/*.tres і data/weapons/*.tres
## (наприклад, blade_warden, battle_axe).

const HERO_MODEL_DIR := "res://assets/models/heroes/"
const WEAPON_MODEL_DIR := "res://assets/models/weapons/"
const MENU_ICON_DIR := "res://assets/ui/icons/menu/"
const SKILL_ICON_DIR := "res://assets/ui/icons/skills/"
const TALENT_ICON_DIR := "res://assets/ui/icons/talents/"
const WEAPON_ICON_DIR := "res://assets/ui/icons/weapons/"
const SHOP_ICON_DIR := "res://assets/ui/icons/shop/"
const DUNGEON_ICON_DIR := "res://assets/ui/icons/dungeons/"

const MODEL_EXTENSIONS := [".glb", ".gltf", ".fbx", ".tscn"]
const ICON_EXTENSIONS := [".png", ".webp", ".jpg", ".svg"]

## Згенеровані заглушки-іконки: одна на колір, щоб не робити нову
## картинку для кожної кнопки.
static var _placeholder_icons: Dictionary = {}

# --- моделі ---

## Модель героя: спершу та, що задана в ресурсі, потім файл за назвою
## id героя, інакше — порожньо (гра візьме тимчасову модель).
static func hero_model(hero_id: StringName, explicit: PackedScene = null) -> PackedScene:
	if explicit != null:
		return explicit
	return _find_scene(HERO_MODEL_DIR, String(hero_id))

static func weapon_model(weapon_id: StringName, explicit: PackedScene = null) -> PackedScene:
	if explicit != null:
		return explicit
	return _find_scene(WEAPON_MODEL_DIR, String(weapon_id))

static func has_hero_model(hero_id: StringName, explicit: PackedScene = null) -> bool:
	return hero_model(hero_id, explicit) != null

# --- іконки ---

static func menu_icon(name: String) -> Texture2D:
	return _find_texture(MENU_ICON_DIR, name)

static func skill_icon(skill_id: StringName) -> Texture2D:
	return _find_texture(SKILL_ICON_DIR, String(skill_id))

static func talent_icon(talent_id: StringName) -> Texture2D:
	return _find_texture(TALENT_ICON_DIR, String(talent_id))

## Картинка рівня данжу на екрані вибору (crypts, fungal, citadel).
static func dungeon_icon(level_id: StringName) -> Texture2D:
	return _find_texture(DUNGEON_ICON_DIR, String(level_id))

static func shop_icon(name: String) -> Texture2D:
	return _find_texture(SHOP_ICON_DIR, name) if name != "" else null

static func weapon_icon(weapon_id: StringName, explicit: Texture2D = null) -> Texture2D:
	if explicit != null:
		return explicit
	return _find_texture(WEAPON_ICON_DIR, String(weapon_id))

## Іконка або заглушка — щоб на екрані завжди щось було. Заглушка це
## рамка з кольором, по якій видно: сюди піде картинка.
static func icon_or_placeholder(icon: Texture2D, color: Color, size: int = 64) -> Texture2D:
	if icon != null:
		return icon
	return placeholder_icon(color, size)

## Квадратна емблема з пунктирною рамкою — видно, що місце зарезервоване.
static func placeholder_icon(color: Color, size: int = 64) -> Texture2D:
	var key := "%s|%d" % [color.to_html(), size]
	if _placeholder_icons.has(key):
		return _placeholder_icons[key]
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(color.r, color.g, color.b, 0.16))
	var border := maxi(2, size / 16)
	for x in size:
		for y in size:
			var on_edge := x < border or y < border or x >= size - border or y >= size - border
			# Пунктир: рамка переривається кожні кілька пікселів.
			if on_edge and (x + y) % (border * 4) < border * 3:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, 0.85))
	var texture := ImageTexture.create_from_image(image)
	_placeholder_icons[key] = texture
	return texture

# --- пошук файлів ---

static func _find_scene(directory: String, name: String) -> PackedScene:
	var path := _find_file(directory, name, MODEL_EXTENSIONS)
	return load(path) as PackedScene if path != "" else null

static func _find_texture(directory: String, name: String) -> Texture2D:
	var path := _find_file(directory, name, ICON_EXTENSIONS)
	return load(path) as Texture2D if path != "" else null

## ResourceLoader.exists() знає і про запаковану гру, і про проєкт у
## редакторі — на відміну від FileAccess, який в експортованій грі бачить
## лише .import-версії файлів.
static func _find_file(directory: String, name: String, extensions: Array) -> String:
	for extension: String in extensions:
		var path := directory + name + extension
		if ResourceLoader.exists(path):
			return path
	return ""
