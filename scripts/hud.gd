extends CanvasLayer

const CardScript := preload("res://scripts/card.gd")
const NAME_PROMPT := preload("res://scenes/name_prompt.tscn")
const SETTINGS_ICON := preload("res://assets/icons/settings.svg")
const TEST_MENU := preload("res://scripts/test_menu.gd")

@onready var _wave_label: Label = $WaveLabel
@onready var _clear_label: Label = $WaveClear
@onready var _countdown_label: Label = $Countdown
@onready var _lv_label: Label = $XpBar/LvLabel
@onready var _xp_fill: ColorRect = $XpBar/Bg/Fill
@onready var _xp_bg: ColorRect = $XpBar/Bg
@onready var _settings_btn: Button = $SettingsButton
@onready var _settings_panel: Control = $SettingsPanel
@onready var _volume_value: Label = $SettingsPanel/VolumeValue
@onready var _settings_quit: Button = $SettingsPanel/QuitButton
@onready var _spectate_label: Label = $SpectateLabel
@onready var _update_btn: Button = $UpdateButton
@onready var _backpack_btn: Button = get_node_or_null("BackpackButton")
const INVENTORY_SCENE := preload("res://scenes/inventory_ui.tscn")
var _inventory: CanvasLayer = null

var _countdown: int = 0

var _game_over_layer: Control
var _game_over_panel: PanelContainer
var _game_over_scroll: ScrollContainer
var _game_over_total: Label
var _game_over_footer: VBoxContainer
var _play_again_btn: Button
var _menu_btn: Button
var _name_prompt: Control


func _ready() -> void:
	Game.wave_changed.connect(_on_wave_changed)
	Game.xp_changed.connect(_on_xp_changed)
	Game.level_changed.connect(_on_level_changed)
	Game.countdown_changed.connect(_on_countdown_changed)
	Game.game_over.connect(_on_game_over)
	Game.card_collected.connect(show_card_reward)
	Game.spectate_changed.connect(_on_spectate_changed)
	Net.player_name_taken.connect(_on_player_name_taken)
	if Net.name_change_required:
		_on_player_name_taken()
	Web.update_available.connect(_on_update_available)
	if _update_btn:
		_update_btn.visible = false
		_update_btn.text = "CHECK FOR UPDATE"
		_update_btn.pressed.connect(_on_update_pressed)
		_style_tech_button(_update_btn, false)
	if _backpack_btn:
		_backpack_btn.pressed.connect(_on_backpack_pressed)
	if Web.has_update():
		_on_update_available(Web.available_version)
	_style_tech_button(_settings_btn, false)
	_style_tech_button(_settings_quit, true)
	var spawner := get_node_or_null("../Spawner")
	if spawner:
		spawner.wave_cleared_text.connect(_on_wave_cleared)
	_on_wave_changed(Game.wave)
	_on_level_changed(Game.level)
	Game.level_changed.connect(_show_level_up)
	call_deferred("_refresh_xp")
	_clear_label.visible = false
	_countdown_label.visible = false
	_setup_settings()
	if Game.test_mode:
		var test_menu: Control = TEST_MENU.new()
		test_menu.name = "TestMenu"
		add_child(test_menu)


func _on_player_name_taken() -> void:
	if is_instance_valid(_name_prompt):
		return
	_name_prompt = NAME_PROMPT.instantiate() as Control
	add_child(_name_prompt)
	_name_prompt.call("show_name_taken")
	_name_prompt.name_chosen.connect(_on_replacement_name_chosen)


func _on_replacement_name_chosen(_name: String) -> void:
	_name_prompt = null
	Net.retry_hello()


# The little panel with the volume and the quit button.
func _setup_settings() -> void:
	if _settings_btn:
		_settings_btn.text = ""
		_settings_btn.icon = SETTINGS_ICON
		_settings_btn.expand_icon = true
		_settings_btn.add_theme_constant_override("corner_radius", 16)
		_settings_btn.pressed.connect(_on_settings_pressed)
	if _settings_panel:
		var title = _settings_panel.get_node_or_null("Title")
		if title: title.visible = false
		var vol_label = _settings_panel.get_node_or_null("VolumeLabel")
		if vol_label: vol_label.visible = true
		var vol_slider = _settings_panel.get_node_or_null("VolumeSlider")
		if vol_slider:
			vol_slider.visible = true
			vol_slider.value = Game.get_master_volume()
			vol_slider.value_changed.connect(_on_volume_changed)
		var vol_value = _settings_panel.get_node_or_null("VolumeValue")
		if vol_value: vol_value.visible = true
		var close_btn = _settings_panel.get_node_or_null("CloseButton")
		if close_btn: close_btn.visible = false
		if _settings_quit:
			_settings_quit.text = "TO LOBBY"
			_settings_quit.pressed.connect(_on_settings_quit)


func _on_settings_pressed() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	if _settings_panel:
		_settings_panel.visible = not _settings_panel.visible


func _on_settings_close() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	if _settings_panel:
		_settings_panel.visible = false


func _on_settings_quit() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	_leave_to_lobby()


# Leaving a match goes back to the lobby, it does not close the whole game.
func _leave_to_lobby() -> void:
	Game.set_fire(false)
	Game.finish_run()
	Game.reset_run()
	Game.test_mode = false
	Game.test_data = {}
	Net.leave()
	call_deferred("_change_to_lobby")


func _change_to_lobby() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _on_volume_changed(value: float) -> void:
	Game.set_master_volume(value)
	if _volume_value:
		_volume_value.text = "%d%%" % int(round(value * 100.0))


# The dead player watches somebody, the name of that player is shown.
func _on_spectate_changed(_target_id: int) -> void:
	if not _spectate_label:
		return
	if not Game.spectate_mode:
		_spectate_label.visible = false
		return
	var who := Game.spectate_name()
	var spectating_text := "SPECTATING %s" % who if who != "" else "SPECTATING"
	var locale := get_node_or_null("/root/Locale")
	_spectate_label.text = locale.translate_text(spectating_text) if locale else spectating_text
	_spectate_label.visible = true


# A new version is up there, the button shows up.
func _on_update_available(_version: String) -> void:
	if _update_btn and not Game.test_mode:
		_update_btn.visible = true
		var text := "NEW VERSION - UPDATE"
		var locale := get_node_or_null("/root/Locale")
		_update_btn.text = locale.translate_text(text) if locale else text
	elif _update_btn:
		_update_btn.visible = false
	Web.hide_web_update_button()


func _on_update_pressed() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	Web.request_update()


func _on_backpack_pressed() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	if _inventory == null or not is_instance_valid(_inventory):
		_inventory = INVENTORY_SCENE.instantiate()
		add_child(_inventory)
	if _inventory.has_method("open"):
		_inventory.open()


func _unhandled_input(event: InputEvent) -> void:
	# F11 is the usual key for fullscreen
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_F11:
			Game.sfx("click", -12.0, 0.95, 1.05)
			Web.toggle_fullscreen()
			get_viewport().set_input_as_handled()


func _refresh_xp() -> void:
	_on_xp_changed(Game.xp, Game.xp_needed())


func _on_wave_changed(wave: int) -> void:
	var text := "WAVE %d" % maxi(wave, 1)
	var locale := get_node_or_null("/root/Locale")
	_wave_label.text = locale.translate_text(text) if locale else text
	# a new wave started: hide the intermission overlays
	_countdown_label.visible = false
	_clear_label.visible = false


func _on_level_changed(level: int) -> void:
	var text := "LV %d" % level
	var locale := get_node_or_null("/root/Locale")
	_lv_label.text = locale.translate_text(text) if locale else text


func _show_level_up(level: int) -> void:
	# Compact world-space-independent banner: readable on both desktop and phone.
	var fx := Control.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.set_anchors_preset(Control.PRESET_CENTER)
	fx.position = Vector2(-110, -95)
	fx.size = Vector2(220, 60)
	var label := Label.new()
	var text := "LEVEL %d" % level
	var locale := get_node_or_null("/root/Locale")
	label.text = locale.translate_text(text) if locale else text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = fx.size
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.02, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.modulate.a = 0.0
	label.scale = Vector2(0.72, 0.72)
	label.pivot_offset = fx.size * 0.5
	fx.add_child(label)
	add_child(fx)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.14)
	tween.tween_property(label, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "position:y", -18.0, 0.95).set_delay(0.18)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.72)
	tween.set_parallel(false)
	tween.tween_callback(fx.queue_free)


func _on_xp_changed(xp: int, needed: int) -> void:
	var t := float(xp) / float(maxi(needed, 1))
	_xp_fill.size = Vector2((_xp_bg.size.x - 4.0) * t, _xp_bg.size.y - 4.0)


func _on_countdown_changed(seconds_left: int) -> void:
	_countdown = seconds_left
	var text := "Next wave in %d" % maxi(_countdown, 0)
	var locale := get_node_or_null("/root/Locale")
	_countdown_label.text = locale.translate_text(text) if locale else text


func _on_wave_cleared(has_cleared: bool) -> void:
	if has_cleared:
		_show_clear_text()
		_countdown_label.visible = true
		Game.sfx("fanfare", -17.0, 0.97, 1.04)
	else:
		_countdown_label.visible = false


func _show_clear_text() -> void:
	_clear_label.visible = true
	_clear_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_clear_label, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func(): _clear_label.visible = false)


func show_card_reward(card: Dictionary) -> void:
	# a real card graphic drops in from the top of the screen
	var vp := get_viewport().get_visible_rect().size
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var c: Control = Control.new()
	c.set_script(CardScript)
	c.setup(card, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.scale = Vector2(0.55, 0.55)
	holder.add_child(c)
	c.position = Vector2(vp.x * 0.5 - 55.0, -320.0)
	Game.sfx("card", -15.0, 0.98, 1.05)

	var tw := create_tween()
	tw.tween_property(c, "position:y", 30.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.5)
	tw.tween_property(c, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): holder.queue_free())


func _on_game_over() -> void:
	if _game_over_layer:
		return

	_game_over_layer = Control.new()
	_game_over_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_game_over_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.015, 0.035, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_layer.add_child(dim)

	_game_over_panel = PanelContainer.new()
	_game_over_panel.name = "RunResultsPanel"
	_game_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	_game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.10, 0.98)
	panel_style.border_color = Color(0.24, 0.68, 0.84, 0.88)
	panel_style.set_border_width_all(1)
	panel_style.set_border_width(SIDE_LEFT, 3)
	panel_style.set_corner_radius_all(14)
	panel_style.shadow_color = Color(0.0, 0.01, 0.035, 0.8)
	panel_style.shadow_size = 22
	_game_over_panel.add_theme_stylebox_override("panel", panel_style)
	_game_over_layer.add_child(_game_over_panel)

	var margin := MarginContainer.new()
	margin.name = "RunResultsMargin"
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		margin.add_theme_constant_override("margin_" + _side_name(side), 16)
	_game_over_panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	layout.add_child(header)
	var title_label := Label.new()
	var locale := get_node_or_null("/root/Locale")
	title_label.text = str(locale.call("translate_text", "GAME OVER")) \
		if locale else "GAME OVER"
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.37))
	header.add_child(title_label)
	var summary_label := Label.new()
	summary_label.name = "RunResultsSummary"
	summary_label.text = _run_results_subtitle(Game.latest_run)
	summary_label.add_theme_font_size_override("font_size", 12)
	summary_label.add_theme_color_override("font_color", Color(0.57, 0.82, 0.93))
	header.add_child(summary_label)

	_game_over_scroll = ScrollContainer.new()
	_game_over_scroll.name = "KillRewardScroll"
	_game_over_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_game_over_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_game_over_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(_game_over_scroll)
	var rows := VBoxContainer.new()
	rows.name = "KillRewardRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	_game_over_scroll.add_child(rows)
	_add_run_reward_rows(rows, Game.latest_run)

	_game_over_footer = VBoxContainer.new()
	_game_over_footer.name = "RunRewardFooter"
	_game_over_footer.add_theme_constant_override("separation", 8)
	var footer_style := StyleBoxFlat.new()
	footer_style.bg_color = Color(0.045, 0.12, 0.18, 0.98)
	footer_style.border_color = Color(0.25, 0.68, 0.82, 0.65)
	footer_style.set_border_width_all(1)
	footer_style.set_corner_radius_all(9)
	var footer_panel := PanelContainer.new()
	footer_panel.name = "RunRewardBar"
	footer_panel.add_theme_stylebox_override("panel", footer_style)
	layout.add_child(footer_panel)
	var footer_margin := MarginContainer.new()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		footer_margin.add_theme_constant_override("margin_" + _side_name(side), 10)
	footer_panel.add_child(footer_margin)
	footer_margin.add_child(_game_over_footer)
	var total_row := HBoxContainer.new()
	total_row.add_theme_constant_override("separation", 8)
	_game_over_footer.add_child(total_row)
	var total_title := Label.new()
	total_title.text = _translate("TOTAL EARNED")
	total_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_title.add_theme_font_size_override("font_size", 14)
	total_title.add_theme_color_override("font_color", Color(0.76, 0.88, 0.94))
	total_row.add_child(total_title)
	_game_over_total = Label.new()
	_game_over_total.name = "TotalCashEarned"
	_game_over_total.text = "+%d $" % int(Game.latest_run.get("cash_earned", 0))
	_game_over_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_game_over_total.add_theme_font_size_override("font_size", 20)
	_game_over_total.add_theme_color_override("font_color", Color(1.0, 0.73, 0.38))
	total_row.add_child(_game_over_total)
	var experience_row := HBoxContainer.new()
	experience_row.name = "TotalExperienceRow"
	experience_row.add_theme_constant_override("separation", 8)
	_game_over_footer.add_child(experience_row)
	var experience_title := Label.new()
	experience_title.text = _translate("TOTAL EXPERIENCE")
	experience_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experience_title.add_theme_font_size_override("font_size", 13)
	experience_title.add_theme_color_override("font_color", Color(0.69, 0.86, 0.94))
	experience_row.add_child(experience_title)
	var total_experience := Label.new()
	total_experience.name = "TotalExperienceEarned"
	total_experience.text = "+%d XP" % int(Game.latest_run.get("xp_earned", 0))
	total_experience.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_experience.add_theme_font_size_override("font_size", 18)
	total_experience.add_theme_color_override("font_color", Color(0.42, 0.86, 0.98))
	experience_row.add_child(total_experience)
	if not bool(Game.latest_run.get("cash_saved", true)) \
			or not bool(Game.latest_run.get("xp_saved", true)):
		var save_warning := Label.new()
		save_warning.name = "CashSaveWarning"
		save_warning.text = _translate("REWARD SAVE FAILED")
		save_warning.add_theme_font_size_override("font_size", 11)
		save_warning.add_theme_color_override("font_color", Color(1.0, 0.48, 0.35))
		_game_over_footer.add_child(save_warning)

	var actions := HBoxContainer.new()
	actions.name = "RunResultActions"
	actions.add_theme_constant_override("separation", 8)
	_game_over_footer.add_child(actions)
	_play_again_btn = Button.new()
	_play_again_btn.text = str(locale.call("translate_text", "PLAY AGAIN")) \
		if locale else "PLAY AGAIN"
	_play_again_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_again_btn.custom_minimum_size.y = 42
	_style_tech_button(_play_again_btn, true)
	_play_again_btn.pressed.connect(_on_play_again)
	_menu_btn = Button.new()
	_menu_btn.text = _translate("RETURN TO LOBBY")
	_menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_btn.custom_minimum_size.y = 42
	_style_tech_button(_menu_btn, false)
	_menu_btn.pressed.connect(_on_main_menu)
	actions.add_child(_play_again_btn)
	actions.add_child(_menu_btn)
	_layout_game_over()
	get_viewport().size_changed.connect(_layout_game_over)

	dim.modulate.a = 0.0
	_game_over_panel.modulate.a = 0.0
	_game_over_panel.scale = Vector2(0.97, 0.97)
	_game_over_panel.pivot_offset = _game_over_panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(dim, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(_game_over_panel, "modulate:a", 1.0, 0.28)
	tw.parallel().tween_property(
		_game_over_panel, "scale", Vector2.ONE, 0.28
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _layout_game_over() -> void:
	if not is_instance_valid(_game_over_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_size := Vector2(
		minf(820.0, maxf(280.0, viewport_size.x - 28.0)),
		minf(650.0, maxf(300.0, viewport_size.y - 28.0))
	)
	_game_over_panel.offset_left = -panel_size.x * 0.5
	_game_over_panel.offset_top = -panel_size.y * 0.5
	_game_over_panel.offset_right = panel_size.x * 0.5
	_game_over_panel.offset_bottom = panel_size.y * 0.5
	_game_over_panel.pivot_offset = panel_size * 0.5


func _side_name(side: int) -> String:
	match side:
		SIDE_LEFT: return "left"
		SIDE_TOP: return "top"
		SIDE_RIGHT: return "right"
		_: return "bottom"


func _translate(text: String) -> String:
	var locale := get_node_or_null("/root/Locale")
	return str(locale.call("translate_text", text)) if locale else text


func _run_results_subtitle(run: Dictionary) -> String:
	var kills: Dictionary = run.get("enemy_kills", {})
	var defeated := 0
	for count: Variant in kills.values():
		defeated += int(count)
	return "%s   %d     |     %s   %d" % [
		_translate("WAVE REACHED"), int(run.get("wave", 0)),
		_translate("ENEMIES DEFEATED"), defeated,
	]


func _add_run_reward_rows(parent: VBoxContainer, run: Dictionary) -> void:
	var reward_rows: Array = run.get("reward_rows", [])
	if reward_rows.is_empty():
		var empty := Label.new()
		empty.text = _translate("NO REWARDS EARNED")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.62, 0.73, 0.83))
		parent.add_child(empty)
		return
	for reward: Dictionary in reward_rows:
		var row := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.055, 0.10, 0.16, 0.96)
		row_style.border_color = Color(0.20, 0.42, 0.56, 0.52)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(7)
		row.add_theme_stylebox_override("panel", row_style)
		parent.add_child(row)
		var row_margin := MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", 9)
		row_margin.add_theme_constant_override("margin_top", 6)
		row_margin.add_theme_constant_override("margin_right", 9)
		row_margin.add_theme_constant_override("margin_bottom", 6)
		row.add_child(row_margin)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 10)
		row_margin.add_child(content)
		var icon := TextureRect.new()
		icon.name = "RewardIcon_" + str(reward["id"])
		icon.custom_minimum_size = Vector2(42, 42)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(str(reward["icon"])) as Texture2D
		if str(reward["id"]) == "shooter":
			icon.modulate = Color(1.0, 0.26, 0.28)
		content.add_child(icon)
		var identity := VBoxContainer.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.alignment = BoxContainer.ALIGNMENT_CENTER
		identity.add_theme_constant_override("separation", 2)
		content.add_child(identity)
		var name := Label.new()
		name.text = _translate(str(reward["name"]))
		name.add_theme_font_size_override("font_size", 14)
		name.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
		identity.add_child(name)
		var cash_calculation := Label.new()
		cash_calculation.name = "CashCalculation_" + str(reward["id"])
		cash_calculation.text = "%d x %d $" % [
			int(reward["count"]), int(reward["unit_reward"]),
		]
		cash_calculation.add_theme_font_size_override("font_size", 11)
		cash_calculation.add_theme_color_override("font_color", Color(0.53, 0.72, 0.84))
		identity.add_child(cash_calculation)
		var xp_calculation := Label.new()
		xp_calculation.name = "ExperienceCalculation_" + str(reward["id"])
		xp_calculation.text = "%d x %d XP" % [
			int(reward["count"]), int(reward["unit_xp"]),
		]
		xp_calculation.add_theme_font_size_override("font_size", 11)
		xp_calculation.add_theme_color_override("font_color", Color(0.42, 0.78, 0.91))
		identity.add_child(xp_calculation)
		var reward_amounts := VBoxContainer.new()
		reward_amounts.custom_minimum_size.x = 78
		reward_amounts.alignment = BoxContainer.ALIGNMENT_CENTER
		reward_amounts.add_theme_constant_override("separation", 2)
		content.add_child(reward_amounts)
		var amount := Label.new()
		amount.name = "CashReward_" + str(reward["id"])
		amount.text = "+%d $" % int(reward["reward"])
		amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amount.add_theme_font_size_override("font_size", 15)
		amount.add_theme_color_override("font_color", Color(1.0, 0.73, 0.38))
		reward_amounts.add_child(amount)
		var xp_amount := Label.new()
		xp_amount.name = "ExperienceReward_" + str(reward["id"])
		xp_amount.text = "+%d XP" % int(reward["xp_reward"])
		xp_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		xp_amount.add_theme_font_size_override("font_size", 12)
		xp_amount.add_theme_color_override("font_color", Color(0.42, 0.86, 0.98))
		reward_amounts.add_child(xp_amount)


func _on_play_again() -> void:
	Game.sfx("click", -14.0, 0.95, 1.05)
	# Keep the multiplayer session alive and restart the match in the same room.
	# Clients ask the host to restart so every player enters the new run together.
	if Game.in_a_room():
		Net.restart_room_game()
		return
	Game.reset_run()
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	Game.sfx("click", -14.0, 0.95, 1.05)
	Game.finish_run()
	Game.reset_run()
	Game.test_mode = false
	Game.test_data = {}
	Net.leave()
	call_deferred("_change_to_lobby")


func _style_tech_button(button: Button, primary: bool) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.66, 0.40, 0.20, 1.0) if primary \
		else Color(0.055, 0.13, 0.20, 1.0)
	normal.border_color = Color(0.95, 0.64, 0.32, 0.95) if primary \
		else Color(0.27, 0.67, 0.83, 0.9)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.80, 0.49, 0.24, 1.0) if primary \
		else Color(0.08, 0.19, 0.28, 1.0)
	hover.border_color = Color(1.0, 0.76, 0.44) if primary else Color(0.46, 0.86, 0.98)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.53, 0.31, 0.17, 1.0) if primary \
		else Color(0.04, 0.10, 0.16, 1.0)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.10, 0.13, 0.17, 0.9)
	disabled.border_color = Color(0.28, 0.36, 0.43, 0.55)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.08, 0.10, 0.13)
		if primary else Color(0.82, 0.94, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.08, 0.10, 0.13)
		if primary else Color(0.94, 0.99, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.62, 0.68))


func _format_run_summary(run: Dictionary) -> String:
	if run.is_empty():
		return ""
	var locale := get_node_or_null("/root/Locale")
	var wave_text := "WAVE %d" % int(run.get("wave", 0))
	var bosses := "%s %d" % [
		locale.translate_text("BOSSES") if locale else "BOSSES",
		int(run.get("bosses", 0)),
	]
	var damage := "%s %d" % [
		locale.translate_text("DAMAGE") if locale else "DAMAGE",
		int(run.get("damage", 0)),
	]
	var seconds := int(run.get("seconds", 0.0))
	var survived := "%s %02d:%02d" % [
		locale.translate_text("SURVIVED") if locale else "SURVIVED",
		seconds / 60,
		seconds % 60,
	]
	var boss_kill_seconds := int(run.get("average_boss_kill_seconds", 0.0))
	var boss_ttk := "%s %02d:%02d" % [
		locale.call("translate_text", "BOSS TTK") if locale else "BOSS TTK",
		boss_kill_seconds / 60,
		boss_kill_seconds % 60,
	]
	var build: Array = run.get("build", [])
	var shown_build := PackedStringArray()
	for index in mini(build.size(), 3):
		shown_build.append(Game.build_item_label(str(build[index])))
	if build.size() > 3:
		shown_build.append("+%d" % (build.size() - 3))
	var build_text := ", ".join(shown_build)
	var build_label := str(locale.call("translate_text", "BUILD")) \
		if locale else "BUILD"
	if locale:
		wave_text = str(locale.call("translate_text", wave_text))
		bosses = "%s %d" % [
			locale.call("translate_text", "BOSSES"), int(run.get("bosses", 0))]
		damage = "%s %d" % [
			locale.call("translate_text", "DAMAGE"), int(run.get("damage", 0))]
		survived = "%s %02d:%02d" % [
			locale.call("translate_text", "SURVIVED"),
			seconds / 60,
			seconds % 60,
		]
		boss_ttk = "%s %02d:%02d" % [
			locale.call("translate_text", "BOSS TTK"),
			boss_kill_seconds / 60,
			boss_kill_seconds % 60,
		]
	return "%s   %s\n%s   %s\n%s\n%s: %s" % [
		wave_text, bosses, damage, survived, boss_ttk, build_label, build_text,
	]
