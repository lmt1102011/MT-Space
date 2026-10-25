extends Control

const IconBank := preload("res://scripts/icon_bank.gd")
const CARD_COMMON := preload("res://assets/cards/card_common.svg")
const CARD_RARE := preload("res://assets/cards/card_rare.svg")
const CARD_EPIC := preload("res://assets/cards/card_epic.svg")
const ICON_PLATE := preload("res://assets/cards/card_icon_plate.svg")

signal chosen(card: Dictionary)

var card: Dictionary = {}
var _background: TextureRect
var _icon_plate: TextureRect
var _icon: TextureRect
var _rarity_label: Label
var _name_label: Label
var _desc_label: Label
var _pros_label: Label
var _cons_label: Label
var _hovered: bool = false
var _ui_built: bool = false

const CARD_SIZE := Vector2(200.0, 280.0)
const INK := Color(0.93, 0.95, 0.97)
const INK_DIM := Color(0.68, 0.73, 0.80)
const GOOD := Color(0.52, 0.84, 0.60)
const BAD := Color(0.95, 0.48, 0.48)
const C_GOLD := Color(1.0, 0.84, 0.36)
const C_FIRE := Color(1.0, 0.48, 0.13)
const C_ICE := Color(0.46, 0.80, 1.0)
const C_STEEL := Color(0.64, 0.74, 0.92)
const C_LIFE := Color(0.45, 0.90, 0.58)
const C_BLOOD := Color(0.96, 0.34, 0.44)


func setup(data: Dictionary, _index: int) -> void:
	card = data
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_node_ready():
		_update_card()


func _ready() -> void:
	_build_ui()
	_update_card()
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	gui_input.connect(_on_gui_input)
	var locale := get_node_or_null("/root/Locale")
	if locale and locale.has_signal("locale_changed"):
		locale.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_locale: String) -> void:
	_update_card()


func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE

	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_icon_plate = TextureRect.new()
	_icon_plate.position = Vector2(56.0, 43.0)
	_icon_plate.size = Vector2(88.0, 88.0)
	_icon_plate.texture = ICON_PLATE
	_icon_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_plate.stretch_mode = TextureRect.STRETCH_SCALE
	_icon_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_plate)

	_icon = TextureRect.new()
	_icon.position = Vector2(68.0, 55.0)
	_icon.size = Vector2(64.0, 64.0)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_rarity_label = _make_label(Vector2(28.0, 8.0), Vector2(156.0, 22.0), 10, true)
	_name_label = _make_label(Vector2(16.0, 139.0), Vector2(168.0, 30.0), 18, true)
	_desc_label = _make_label(Vector2(16.0, 171.0), Vector2(168.0, 48.0), 13)
	_pros_label = _make_label(Vector2(28.0, 225.0), Vector2(156.0, 18.0), 12)
	_cons_label = _make_label(Vector2(28.0, 244.0), Vector2(156.0, 18.0), 12)


func _make_label(label_position: Vector2, label_size: Vector2, font_size: int,
		bold: bool = false) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK if bold else INK_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _update_card() -> void:
	if not _ui_built or card.is_empty():
		return
	var rarity := int(card.get("rarity", CardDB.Rarity.COMMON))
	var rarity_color: Color = CardDB.rarity_color(rarity)
	match rarity:
		CardDB.Rarity.RARE:
			_background.texture = CARD_RARE
		CardDB.Rarity.EPIC:
			_background.texture = CARD_EPIC
		_:
			_background.texture = CARD_COMMON

	var id := str(card.get("id", ""))
	var icon_tint := icon_color(id, rarity_color)
	_icon.texture = IconBank.get_icon(id)
	_icon.modulate = icon_tint
	_icon_plate.modulate = icon_tint

	var locale := get_node_or_null("/root/Locale")
	var rarity_name := str(CardDB.RARITY_NAMES.get(rarity, ""))
	var card_name := str(card.get("name", ""))
	var description := str(card.get("desc", ""))
	var pros := str(card.get("pros", ""))
	var cons := str(card.get("cons", ""))
	if locale:
		rarity_name = locale.translate_text(rarity_name)
		card_name = locale.translate_text(card_name)
		description = locale.translate_text(description)
		pros = locale.translate_text(pros)
		cons = locale.translate_text(cons)
	_rarity_label.text = rarity_name
	_rarity_label.add_theme_color_override("font_color", rarity_color.lightened(0.25))
	_name_label.text = card_name
	_desc_label.text = description
	_pros_label.text = ("● " + pros) if not pros.is_empty() else ""
	_cons_label.text = ("● " + cons) if not cons.is_empty() else ""
	_pros_label.add_theme_color_override("font_color", GOOD)
	_cons_label.add_theme_color_override("font_color", BAD)
	_pros_label.visible = not pros.is_empty()
	_cons_label.visible = not cons.is_empty()
	_desc_label.visible = not description.is_empty()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(card)


func _set_hovered(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	scale = Vector2(1.025, 1.025) if value else Vector2.ONE


static func icon_color(id: String, rarity_col: Color) -> Color:
	if id in ["fire_rate", "crit", "weapon_shotgun", "weapon_burst",
			"splash", "elite_hunter", "pierce_focus", "scavenger"]:
		return C_GOLD
	if id in ["bullet_speed", "burn", "weapon_twin_cannon", "inferno", "explosive"]:
		return C_FIRE
	if id in ["move_speed", "freeze", "weapon_railgun", "homing", "brittle", "rushed", "longshot"]:
		return C_ICE
	if id in ["damage", "lifesteal", "bloodthirst", "cold_blood", "point_blank"]:
		return C_BLOOD
	if id in ["orb_magnet", "max_hp", "regen", "level_heal", "xp_greed", "second_chance"]:
		return C_LIFE
	if id in ["pierce", "weapon_machine_gun", "plating", "thorns", "heavy_caliber", "momentum"]:
		return C_STEEL
	return rarity_col
