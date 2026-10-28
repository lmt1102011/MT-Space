extends Control

const CardDBScript := preload("res://scripts/card_db.gd")

const ENEMY_LIST := ["shape", "shooter", "double", "railgun", "charger", "orb", "beam_enemy"]
const BOSS_LIST := ["boss", "boss2"]
const WEAPON_LIST := ["basic", "machine_gun", "twin_cannon", "shotgun", "railgun", "burst"]

var _toggle_btn: Button
var _panel: Panel
var _card_ids: Array = []

var _wave_spin: SpinBox
var _level_spin: SpinBox
var _enemy_opt: OptionButton
var _boss_opt: OptionButton
var _card_opt: OptionButton
var _weapon_opt: OptionButton


func _ready() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(_sync_viewport_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_layout_panel()


func _sync_viewport_size() -> void:
	size = get_viewport_rect().size
	_layout_panel()


func _layout_panel() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport_rect().size
	var panel_size := Vector2(
		minf(440.0, maxf(180.0, viewport_size.x - 24.0)),
		minf(520.0, maxf(180.0, viewport_size.y - 136.0))
	)
	_panel.size = panel_size
	var bottom_limit := maxf(12.0, viewport_size.y - panel_size.y - 12.0)
	var top_limit := minf(118.0, bottom_limit)
	var centered_top := (viewport_size.y - panel_size.y) * 0.5
	_panel.position = Vector2(
		(viewport_size.x - panel_size.x) * 0.5,
		clampf(centered_top, top_limit, bottom_limit)
	)


func _spawner() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Spawner") if scene != null else null


func _player() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Player") if scene != null else null


func _build_ui() -> void:
	_toggle_btn = Button.new()
	_toggle_btn.name = "TestControlsButton"
	_set_text(_toggle_btn, "TEST MENU")
	_toggle_btn.custom_minimum_size = Vector2(130, 40)
	_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_btn.anchor_left = 0.5
	_toggle_btn.anchor_right = 0.5
	_toggle_btn.anchor_top = 0.0
	_toggle_btn.anchor_bottom = 0.0
	_toggle_btn.offset_left = -65.0
	_toggle_btn.offset_top = 66.0
	_toggle_btn.offset_right = 65.0
	_toggle_btn.offset_bottom = 106.0
	_toggle_btn.pressed.connect(_on_toggle)
	add_child(_toggle_btn)

	_panel = Panel.new()
	_panel.name = "TestControlsPanel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.97)
	style.border_color = Color(0.35, 0.55, 0.75, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var header := HBoxContainer.new()
	header.position = Vector2(14.0, 10.0)
	header.size = Vector2(0.0, 38.0)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 14.0
	header.offset_top = 10.0
	header.offset_right = -14.0
	header.offset_bottom = 48.0
	header.add_theme_constant_override("separation", 8)
	_panel.add_child(header)

	var title := _make_label("TEST CONTROLS")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(42.0, 36.0)
	_set_text(close_btn, "CLOSE")
	close_btn.pressed.connect(_on_toggle)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.name = "ControlsScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 14.0
	scroll.offset_top = 58.0
	scroll.offset_right = -14.0
	scroll.offset_bottom = -14.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	_wave_spin = SpinBox.new()
	_wave_spin.min_value = 1
	_wave_spin.max_value = 999
	_wave_spin.value = maxi(Game.wave, 1)
	var jump_btn := _make_button("JUMP TO WAVE", _on_jump_wave)
	_add_row(content, "SET WAVE", _wave_spin, jump_btn)

	_level_spin = SpinBox.new()
	_level_spin.min_value = 1
	_level_spin.max_value = 99
	_level_spin.value = Game.level
	var level_btn := _make_button("SET LEVEL", _on_set_level)
	_add_row(content, "PLAYER LEVEL", _level_spin, level_btn)

	_enemy_opt = _make_option(ENEMY_LIST)
	var spawn_btn := _make_button("SPAWN ENEMY", _on_spawn_enemy)
	_add_row(content, "SPAWN ENEMY", _enemy_opt, spawn_btn)

	_boss_opt = _make_option(BOSS_LIST)
	var boss_btn := _make_button("SPAWN BOSS", _on_spawn_boss)
	_add_row(content, "SPAWN BOSS", _boss_opt, boss_btn)

	_card_opt = OptionButton.new()
	_card_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_opt.custom_minimum_size.y = 40.0
	_card_opt.add_item("NONE")
	for card in CardDBScript.all_cards():
		if typeof(card) == TYPE_DICTIONARY and card.has("id"):
			_card_ids.append(str(card.get("id")))
			_card_opt.add_item(str(card.get("name", card.get("id"))))
	var card_btn := _make_button("GIVE CARD", _on_give_card)
	_add_row(content, "GIVE CARD", _card_opt, card_btn)

	_weapon_opt = _make_option(WEAPON_LIST)
	var weapon_btn := _make_button("GIVE WEAPON", _on_give_weapon)
	_add_row(content, "GIVE WEAPON", _weapon_opt, weapon_btn)

	var clear_btn := _make_button("CLEAR ALL", _on_clear_all)
	clear_btn.name = "ClearAllButton"
	clear_btn.custom_minimum_size.y = 42.0
	content.add_child(clear_btn)


func _add_row(parent: VBoxContainer, title: String,
		choice: Control, action: Button) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 3)
	parent.add_child(section)
	section.add_child(_make_label(title))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	section.add_child(row)
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.custom_minimum_size.y = maxf(choice.custom_minimum_size.y, 40.0)
	action.custom_minimum_size = Vector2(116.0, 40.0)
	row.add_child(choice)
	row.add_child(action)


func _make_option(items: Array) -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size.y = 40.0
	for item in items:
		option.add_item(str(item).to_upper())
	option.select(0)
	return option


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	_set_text(button, text)
	button.pressed.connect(callback)
	return button


func _make_label(text: String) -> Label:
	var label := Label.new()
	_set_text(label, text)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _set_text(control: Control, text: String) -> void:
	var locale := get_node_or_null("/root/Locale")
	if locale != null and locale.has_method("localize_control"):
		locale.localize_control(control, text)
	else:
		control.set("text", text)


func _on_toggle() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	if _panel != null:
		_panel.visible = not _panel.visible


func _on_jump_wave() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	var spawner := _spawner()
	if spawner != null and spawner.has_method("test_jump_wave"):
		spawner.test_jump_wave(int(_wave_spin.value))


func _on_set_level() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	Game.level = int(_level_spin.value)
	Game.level_changed.emit(Game.level)
	var player := _player()
	if player != null and player.has_method("heal") and player.get("_dead") == false:
		player.call("heal", 9999)


func _on_spawn_enemy() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	var spawner := _spawner()
	if spawner != null and spawner.has_method("test_spawn_now"):
		spawner.test_spawn_now(ENEMY_LIST[_enemy_opt.selected])


func _on_spawn_boss() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	var spawner := _spawner()
	if spawner != null and spawner.has_method("test_spawn_now"):
		spawner.test_spawn_now(BOSS_LIST[_boss_opt.selected])


func _on_give_card() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	var index := _card_opt.selected
	if index <= 0 or index > _card_ids.size():
		return
	var card_id: String = _card_ids[index - 1]
	for card in CardDBScript.all_cards():
		if typeof(card) == TYPE_DICTIONARY and str(card.get("id")) == card_id:
			Game.grant_card(card)
			Game.card_collected.emit(card)
			break


func _on_give_weapon() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	Game.weapon = WEAPON_LIST[_weapon_opt.selected]
	Game.weapon_chosen = true


func _on_clear_all() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	var groups := [
		"enemy", "xp_orb", "upgrade_drop", "player_bullet",
		"enemy_bullet", "boss_missile", "orb_projectile",
		"boss_sonic_wave", "damage_number",
	]
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				node.process_mode = Node.PROCESS_MODE_DISABLED
				node.queue_free()
	Game.xp = 0
	Game.xp_changed.emit(Game.xp, Game.xp_needed())
