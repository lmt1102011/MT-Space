extends CanvasLayer

signal discarded(card_id: String)

@onready var panel: Control = $Panel
@onready var main_layout: VBoxContainer = $Panel/MainLayout
@onready var header: HBoxContainer = $Panel/MainLayout/Header
@onready var wide_body: HBoxContainer = $Panel/MainLayout/WideBody
@onready var mobile_body: VBoxContainer = $Panel/MainLayout/MobileBody
@onready var wide_left: Control = $Panel/MainLayout/WideBody/Left
@onready var wide_right: Control = $Panel/MainLayout/WideBody/Right
@onready var mobile_left: Control = $Panel/MainLayout/MobileBody/MobileLeft
@onready var mobile_right: Control = $Panel/MainLayout/MobileBody/MobileRight
@onready var close_btn: Button = $Panel/MainLayout/Header/CloseButton

var list: GridContainer
var right_panel: Control
var card_preview: Control
var stacks_label: Label
var discard_btn: Button
var _mobile_layout := false

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
	_apply_visual_style()
	_layout_inventory()
	Game.card_collected.connect(_on_card_collected)
	var locale := get_node_or_null("/root/Locale")
	if locale and locale.has_signal("locale_changed"):
		locale.locale_changed.connect(_on_locale_changed)
	get_viewport().size_changed.connect(_layout_inventory)
	if close_btn:
		close_btn.pressed.connect(close)
		close_btn.pressed.connect(_play_click)
	for discard_button_path in [
		"Panel/MainLayout/WideBody/Right/DetailLayout/DiscardButton",
		"Panel/MainLayout/MobileBody/MobileRight/DetailLayout/DiscardButton",
	]:
		var discard_button := get_node(discard_button_path) as Button
		discard_button.pressed.connect(_on_discard)
		discard_button.pressed.connect(_play_click)
	right_panel.visible = false
	discard_btn.visible = false


func open() -> void:
	_layout_inventory()
	_build_list()
	visible = true
	$Dim.modulate.a = 0.0
	panel.modulate.a = 0.0
	create_tween().set_parallel(true) \
		.tween_property($Dim, "modulate:a", 1.0, 0.16)
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.20) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	panel.scale = Vector2(0.98, 0.98)
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
		btn.name = "InventoryCard_" + str(entry.id)
		btn.custom_minimum_size = Vector2(92, 96)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		btn.clip_contents = true
		btn.tooltip_text = str(entry.def.get("name", entry.id))
		btn.add_theme_stylebox_override("normal", _card_button_style(
			Color(0.035, 0.075, 0.12, 0.96),
			Color(0.23, 0.42, 0.57, 0.58)
		))
		btn.add_theme_stylebox_override("hover", _card_button_style(
			Color(0.065, 0.14, 0.20, 1.0), Color(0.32, 0.78, 0.91, 0.95)
		))
		btn.add_theme_stylebox_override("pressed", _card_button_style(
			Color(0.08, 0.19, 0.25, 1.0), Color(0.32, 0.78, 0.91, 1.0)
		))
		btn.add_theme_stylebox_override("focus", _card_button_style(
			Color(0.065, 0.14, 0.20, 1.0), Color(0.32, 0.78, 0.91, 0.95)
		))
		btn.pressed.connect(_on_card_selected.bind(entry.id))
		btn.pressed.connect(_play_click)

		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(center)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_size := 58.0 if _mobile_layout else 52.0
		icon.custom_minimum_size = Vector2.ONE * icon_size
		icon.size = Vector2.ONE * icon_size
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
	_update_grid_columns()
	_scale_mobile_controls()


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


func _layout_inventory() -> void:
	if not is_node_ready():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_apply_inventory_layout(viewport_size.x < 760.0, viewport_size)


func _apply_inventory_layout(mobile_layout: bool, viewport_size: Vector2) -> void:
	_mobile_layout = mobile_layout
	var margin_x := 14.0 if _mobile_layout else 28.0
	var margin_y := 14.0 if _mobile_layout else 28.0
	var panel_width := minf(1220.0, viewport_size.x - margin_x * 2.0)
	var panel_height := minf(820.0, viewport_size.y - margin_y * 2.0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5
	panel.scale = Vector2.ONE
	var panel_style := _panel_style(
		Color(0.018, 0.038, 0.072, 0.99),
		Color(0.22, 0.52, 0.70, 0.88), 14
	)
	panel_style.content_margin_left = 22 if not _mobile_layout else 14
	panel_style.content_margin_right = panel_style.content_margin_left
	panel_style.content_margin_top = 18 if not _mobile_layout else 12
	panel_style.content_margin_bottom = panel_style.content_margin_top
	panel.add_theme_stylebox_override("panel", panel_style)
	header.add_theme_constant_override("separation", 10 if _mobile_layout else 16)
	wide_body.visible = not _mobile_layout
	mobile_body.visible = _mobile_layout
	_refresh_active_nodes()
	if is_instance_valid(list):
		_update_grid_columns()
	if is_instance_valid(card_preview):
		var preview_scale := 0.78 if _mobile_layout else 1.0
		card_preview.scale = Vector2.ONE * preview_scale
	if is_instance_valid(right_panel):
		right_panel.visible = not _selected_id.is_empty()
	if is_instance_valid(discard_btn):
		discard_btn.visible = not _selected_id.is_empty()
	var inactive_right: Control
	var inactive_discard: Button
	if _mobile_layout:
		inactive_right = wide_right
		inactive_discard = get_node(
			"Panel/MainLayout/WideBody/Right/DetailLayout/DiscardButton"
		) as Button
	else:
		inactive_right = mobile_right
		inactive_discard = get_node(
			"Panel/MainLayout/MobileBody/MobileRight/DetailLayout/DiscardButton"
		) as Button
	inactive_right.visible = not _selected_id.is_empty()
	inactive_discard.visible = not _selected_id.is_empty()
	_scale_mobile_controls()


func _refresh_active_nodes() -> void:
	var prefix := "MobileBody" if _mobile_layout else "WideBody"
	var side := "MobileRight" if _mobile_layout else "Right"
	var list_side := "MobileLeft" if _mobile_layout else "Left"
	list = get_node("Panel/MainLayout/%s/%s/ScrollContainer/List" % [
		prefix, list_side,
	]) as GridContainer
	right_panel = get_node("Panel/MainLayout/%s/%s" % [prefix, side]) as Control
	card_preview = get_node("Panel/MainLayout/%s/%s/DetailLayout/Preview" % [
		prefix, side,
	]) as Control
	stacks_label = get_node("Panel/MainLayout/%s/%s/DetailLayout/Stacks" % [
		prefix, side,
	]) as Label
	discard_btn = get_node("Panel/MainLayout/%s/%s/DetailLayout/DiscardButton" % [
		prefix, side,
	]) as Button


func _update_grid_columns() -> void:
	if list == null or list.get_parent() == null:
		return
	var available_width := list.get_parent_control().size.x
	var minimum_card_width := 100.0 if _mobile_layout else 92.0
	var separation := 8 if _mobile_layout else 10
	list.columns = maxi(
		1, floori((available_width + separation) / (minimum_card_width + separation))
	)


func _scale_mobile_controls() -> void:
	for node: Node in panel.find_children("*", "Control", true, false):
		var control := node as Control
		if control is Label or control is Button:
			if not control.has_meta("mobile_base_font_size"):
				control.set_meta(
					"mobile_base_font_size",
					control.get_theme_font_size("font_size")
				)
				control.set_meta(
					"mobile_base_minimum_size", control.custom_minimum_size
				)
			var base_size := int(control.get_meta("mobile_base_font_size"))
			var font_size := maxi(1, base_size + (2 if _mobile_layout else 0))
			control.add_theme_font_size_override("font_size", font_size)
			if control is Button and control.name.begins_with("InventoryCard_"):
				control.custom_minimum_size = Vector2(
					100.0, 104.0
				) if _mobile_layout else Vector2(92.0, 96.0)
				var icon := control.get_node_or_null(
					"CenterContainer/TextureRect"
				) as TextureRect
				if icon != null:
					var icon_size := 58.0 if _mobile_layout else 52.0
					icon.custom_minimum_size = Vector2.ONE * icon_size
					icon.size = Vector2.ONE * icon_size
			elif control is Button and _mobile_layout:
				control.custom_minimum_size.y = maxf(
					control.custom_minimum_size.y, 48.0
				)
			elif not _mobile_layout:
				control.custom_minimum_size = control.get_meta(
					"mobile_base_minimum_size"
				)


func _apply_visual_style() -> void:
	var panel_style := _panel_style(
		Color(0.018, 0.038, 0.072, 0.99),
		Color(0.22, 0.52, 0.70, 0.88), 14
	)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	for surface: Control in [wide_left, wide_right, mobile_left, mobile_right]:
		surface.add_theme_stylebox_override("panel", _panel_style(
			Color(0.028, 0.058, 0.098, 0.98),
			Color(0.17, 0.38, 0.52, 0.68), 10
		))
	var accent := get_node("Panel/MainLayout/Accent") as ColorRect
	accent.color = Color(0.31, 0.77, 0.95, 0.84)
	var title := get_node("Panel/MainLayout/Header/Heading/Title") as Label
	title.add_theme_color_override("font_color", Color(0.91, 0.96, 1.0))
	for button: Button in [
		close_btn,
		get_node("Panel/MainLayout/WideBody/Right/DetailLayout/DiscardButton") as Button,
		get_node("Panel/MainLayout/MobileBody/MobileRight/DetailLayout/DiscardButton") as Button,
	]:
		_style_action_button(button)
	var footer := get_node("Panel/MainLayout/Footer") as Label
	footer.add_theme_color_override("font_color", Color(0.43, 0.57, 0.68))


func _style_action_button(button: Button) -> void:
	var normal := _panel_style(
		Color(0.055, 0.12, 0.18, 1.0),
		Color(0.24, 0.48, 0.62, 0.76), 7
	)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.18, 0.25, 1.0)
	hover.border_color = Color(0.31, 0.77, 0.95)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.035, 0.07, 0.10)
	disabled.border_color = Color(0.16, 0.25, 0.32)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.52, 0.60))
	button.focus_mode = Control.FOCUS_NONE


func _card_button_style(background: Color, border: Color) -> StyleBoxFlat:
	return _panel_style(background, border, 8)


func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _play_click() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)


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
