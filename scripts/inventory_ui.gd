extends CanvasLayer

signal discarded(card_id: String)

@onready var panel: Control = $Panel
@onready var list: GridContainer = $Panel/HBox/Left/ScrollContainer/List
@onready var right_panel: Control = $Panel/HBox/Right
@onready var card_preview: Control = $Panel/HBox/Right/Preview
@onready var stacks_label: Label = $Panel/HBox/Right/Stacks
@onready var discard_btn: Button = $Panel/HBox/Right/DiscardButton
@onready var close_btn: Button = $Panel/CloseButton

var _cards: Array = []
var _selected_id: String = ""

const IconBank := preload("res://scripts/icon_bank.gd")
const CardScript := preload("res://scripts/card.gd")

func _get_card_def(id: String) -> Dictionary:
	var cards: Array = CardDB.all_cards()
	for c in cards:
		if typeof(c) == TYPE_DICTIONARY and c.get("id") == id:
			return c
	for c in CardDB.weapon_cards():
		if typeof(c) == TYPE_DICTIONARY and c.get("id") == id:
			return c
	return {}


func _ready() -> void:
	layer = 80
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.card_collected.connect(_on_card_collected)
	var locale := get_node_or_null("/root/Locale")
	if locale and locale.has_signal("locale_changed"):
		locale.locale_changed.connect(_on_locale_changed)
	if close_btn:
		close_btn.pressed.connect(close)
	if discard_btn:
		discard_btn.pressed.connect(_on_discard)
	right_panel.visible = false
	discard_btn.visible = false


func open() -> void:
	_build_list()
	visible = true


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _build_list() -> void:
	for c in list.get_children():
		c.queue_free()
	_cards.clear()
	_selected_id = ""
	right_panel.visible = false
	discard_btn.visible = false
	var stacks = Game.upg_stacks if Game != null else {}
	for id in stacks.keys():
		var taken = int(stacks[id])
		if taken <= 0:
			continue
		var def := _get_card_def(id)
		if def.is_empty():
			continue
		_cards.append({"id": id, "def": def, "count": taken})
	for entry in _cards:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(92, 92)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.clip_contents = true
		btn.tooltip_text = str(entry.def.get("name", entry.id))
		btn.pressed.connect(_on_card_selected.bind(entry.id))

		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(center)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(52, 52)
		icon.size = Vector2(52, 52)
		var def_e: Dictionary = entry.def
		icon.texture = IconBank.get_icon(str(def_e.get("id", "default")))
		icon.modulate = CardScript.icon_color(
			str(def_e.get("id", "")),
			CardDB.rarity_color(int(def_e.get("rarity", CardDB.Rarity.COMMON)))
		)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)

		var badge_bg := Panel.new()
		badge_bg.anchor_left = 1.0
		badge_bg.anchor_right = 1.0
		badge_bg.offset_left = -28.0
		badge_bg.offset_right = -4.0
		badge_bg.offset_top = 4.0
		badge_bg.offset_bottom = 28.0
		badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = CardDB.rarity_color(
			int(def_e.get("rarity", CardDB.Rarity.COMMON))
		).darkened(0.35)
		badge_style.border_color = CardDB.rarity_color(
			int(def_e.get("rarity", CardDB.Rarity.COMMON))
		)
		badge_style.set_border_width_all(1)
		badge_style.set_corner_radius_all(12)
		badge_bg.add_theme_stylebox_override("panel", badge_style)
		btn.add_child(badge_bg)

		var badge := Label.new()
		badge.text = str(entry.count)
		badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_bg.add_child(badge)
		list.add_child(btn)


func _on_card_selected(card_id: String) -> void:
	_selected_id = card_id
	var def := _get_card_def(card_id)
	if def.is_empty():
		return
	right_panel.visible = true
	discard_btn.visible = true
	card_preview.call("setup", def, 0)
	card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stacks = Game.upg_stacks if Game != null else {}
	if stacks_label:
		var locale := get_node_or_null("/root/Locale")
		var label := "UPGRADE STACKS: %d / %d" % [
			int(stacks.get(card_id, 0)), int(def.get("max", 1))
		]
		stacks_label.text = locale.translate_text(label) if locale else label


func _on_discard() -> void:
	if _selected_id == "":
		return
	if Game == null:
		return
	var discarded_id := _selected_id
	var card_def := _get_card_def(discarded_id)
	if card_def.is_empty() or int(Game.upg_stacks.get(discarded_id, 0)) <= 0:
		return
	var player := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		return
	var direction := Vector2.RIGHT.rotated(player.global_rotation)
	var ship_sprite := player.get_node_or_null("Sprite2D") as Node2D
	if ship_sprite != null:
		direction = Vector2.RIGHT.rotated(ship_sprite.global_rotation)
	if not Net.request_discarded_card(discarded_id, player.global_position, direction):
		return
	if not Game.remove_card(card_def):
		return
	discarded.emit(discarded_id)
	_build_list()
	if Game.upg_stacks.has(discarded_id):
		_on_card_selected(discarded_id)
	else:
		right_panel.visible = false
		discard_btn.visible = false


func _on_card_collected(_card: Dictionary) -> void:
	if not visible:
		return
	var selected_id := _selected_id
	_build_list()
	if selected_id != "":
		_on_card_selected(selected_id)


func _on_locale_changed(_locale: String) -> void:
	if not visible:
		return
	var selected_id := _selected_id
	_build_list()
	if selected_id != "":
		_on_card_selected(selected_id)
