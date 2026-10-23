extends CanvasLayer

const CardScript := preload("res://scripts/card.gd")

@onready var _wave_label: Label = $WaveLabel
@onready var _clear_label: Label = $WaveClear
@onready var _countdown_label: Label = $Countdown
@onready var _lv_label: Label = $XpBar/LvLabel
@onready var _xp_fill: ColorRect = $XpBar/Bg/Fill
@onready var _xp_bg: ColorRect = $XpBar/Bg
@onready var _settings_btn: Button = $SettingsButton
@onready var _settings_panel: Control = $SettingsPanel
@onready var _volume_slider: HSlider = $SettingsPanel/VolumeSlider
@onready var _volume_value: Label = $SettingsPanel/VolumeValue
@onready var _settings_close: Button = $SettingsPanel/CloseButton
@onready var _settings_quit: Button = $SettingsPanel/QuitButton
@onready var _spectate_label: Label = $SpectateLabel
@onready var _update_btn: Button = $UpdateButton

var _countdown: int = 0

var _game_over_layer: Control
var _play_again_btn: Button
var _menu_btn: Button


func _ready() -> void:
	Game.wave_changed.connect(_on_wave_changed)
	Game.xp_changed.connect(_on_xp_changed)
	Game.level_changed.connect(_on_level_changed)
	Game.countdown_changed.connect(_on_countdown_changed)
	Game.game_over.connect(_on_game_over)
	Game.card_collected.connect(show_card_reward)
	Game.spectate_changed.connect(_on_spectate_changed)
	Web.update_available.connect(_on_update_available)
	if _update_btn:
		_update_btn.pressed.connect(_on_update_pressed)
	if Web.has_update():
		_on_update_available(Web.available_version)
	var spawner := get_node_or_null("../Spawner")
	if spawner:
		spawner.wave_cleared_text.connect(_on_wave_cleared)
	_on_wave_changed(Game.wave)
	_on_level_changed(Game.level)
	call_deferred("_refresh_xp")
	_clear_label.visible = false
	_countdown_label.visible = false
	_setup_settings()


# The little panel with the volume and the quit button.
func _setup_settings() -> void:
	if _settings_btn:
		_settings_btn.text = "⚙"  # icon only
		_settings_btn.pressed.connect(_on_settings_pressed)
	if _settings_panel:
		# hide everything except the quit button
		var title = _settings_panel.get_node_or_null("Title")
		if title: title.visible = false
		var vol_label = _settings_panel.get_node_or_null("VolumeLabel")
		if vol_label: vol_label.visible = false
		var vol_slider = _settings_panel.get_node_or_null("VolumeSlider")
		if vol_slider: vol_slider.visible = false
		var vol_value = _settings_panel.get_node_or_null("VolumeValue")
		if vol_value: vol_value.visible = false
		var close_btn = _settings_panel.get_node_or_null("CloseButton")
		if close_btn: close_btn.visible = false
		if _settings_quit:
			_settings_quit.text = "THOÁT"
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
	Game.reset_run()
	Net.leave()
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
	_spectate_label.text = "SPECTATING %s" % who if who != "" else "SPECTATING"
	_spectate_label.visible = true


# A new version is up there, the button shows up.
func _on_update_available(_version: String) -> void:
	if _update_btn:
		_update_btn.visible = true
	Web.hide_web_update_button()


func _on_update_pressed() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	# the old files are thrown away and the page starts again with the new ones
	Web.apply_update()


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
	_wave_label.text = "WAVE %d" % maxi(wave, 1)
	# a new wave started: hide the intermission overlays
	_countdown_label.visible = false
	_clear_label.visible = false


func _on_level_changed(level: int) -> void:
	_lv_label.text = "LV %d" % level


func _on_xp_changed(xp: int, needed: int) -> void:
	var t := float(xp) / float(maxi(needed, 1))
	_xp_fill.size = Vector2((_xp_bg.size.x - 4.0) * t, _xp_bg.size.y - 4.0)


func _on_countdown_changed(seconds_left: int) -> void:
	_countdown = seconds_left
	_countdown_label.text = "Next wave in %d" % maxi(_countdown, 0)


func _on_wave_cleared(show: bool) -> void:
	if show:
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
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_layer.add_child(dim)

	var title_label := Label.new()
	title_label.text = "GAME OVER"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.offset_left = -400.0
	title_label.offset_right = 400.0
	title_label.offset_top = 190.0
	title_label.offset_bottom = 270.0
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_layer.add_child(title_label)

	_play_again_btn = Button.new()
	_play_again_btn.text = "PLAY AGAIN"
	_play_again_btn.set_anchors_preset(Control.PRESET_CENTER)
	_play_again_btn.offset_left = -110.0
	_play_again_btn.offset_right = 110.0
	_play_again_btn.offset_top = -24.0
	_play_again_btn.offset_bottom = 24.0
	_play_again_btn.add_theme_font_size_override("font_size", 24)
	_play_again_btn.pressed.connect(_on_play_again)
	_game_over_layer.add_child(_play_again_btn)

	_menu_btn = Button.new()
	_menu_btn.text = "MAIN MENU"
	_menu_btn.set_anchors_preset(Control.PRESET_CENTER)
	_menu_btn.offset_left = -110.0
	_menu_btn.offset_right = 110.0
	_menu_btn.offset_top = 34.0
	_menu_btn.offset_bottom = 78.0
	_menu_btn.add_theme_font_size_override("font_size", 18)
	_menu_btn.pressed.connect(_on_main_menu)
	_game_over_layer.add_child(_menu_btn)

	dim.modulate.a = 0.0
	title_label.modulate.a = 0.0
	_play_again_btn.modulate.a = 0.0
	_menu_btn.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(dim, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(title_label, "modulate:a", 1.0, 0.8)
	tw.tween_interval(0.3)
	tw.tween_property(_play_again_btn, "modulate:a", 1.0, 1.5)
	tw.parallel().tween_property(_menu_btn, "modulate:a", 1.0, 1.5)


func _on_play_again() -> void:
	Game.sfx("click", -14.0, 0.95, 1.05)
	# when the game was played in a room, restart the match (stay in the room)
	if Game.in_a_room():
		Game.reset_run()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	Game.reset_run()
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	Game.sfx("click", -14.0, 0.95, 1.05)
	Game.reset_run()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
