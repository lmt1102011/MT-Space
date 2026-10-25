extends CanvasLayer

const PROMPT_SCENE := preload("res://scenes/name_prompt.tscn")

@onready var _ui: Control = $UI
@onready var _play_btn: Button = $UI/PlayButton
@onready var _quit_btn: Button = $UI/QuitButton
@onready var _title: Label = $UI/Title
@onready var _subtitle: Label = $UI/Subtitle
@onready var _settings_btn: Button = $UI/SettingsButton
@onready var _settings_panel: Control = $UI/SettingsPanel
@onready var _volume_slider: HSlider = $UI/SettingsPanel/VolumeSlider
@onready var _volume_value: Label = $UI/SettingsPanel/VolumeValue
@onready var _lang_option: OptionButton = $UI/SettingsPanel/LangOption
@onready var _settings_close: Button = $UI/SettingsPanel/CloseButton
@onready var _update_btn: Button = $UI/UpdateButton
@onready var _version_label: Label = $UI/Version


func _ready() -> void:
	_play_btn.pressed.connect(_on_play)
	_quit_btn.pressed.connect(_on_quit)
	_settings_btn.pressed.connect(_on_settings_pressed)
	_settings_close.pressed.connect(_on_settings_close)
	_update_btn.visible = false
	_update_btn.text = "CHECK FOR UPDATE"
	_update_btn.pressed.connect(_on_update_pressed)
	_version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version/name")
	Web.update_available.connect(_on_update_available)
	call_deferred("_check_for_updates")
	if Web.has_update():
		_on_update_available(Web.available_version)
	_volume_slider.value = Game.get_master_volume()
	_volume_slider.value_changed.connect(_on_volume_changed)
	_on_volume_changed(_volume_slider.value)
	if _lang_option:
		var cur := get_node_or_null("/root/Locale")
		if cur != null and cur.has_method("get_locale"):
			var lcur := str(cur.get_locale())
			if lcur == "vi":
				_lang_option.select(1)
			else:
				_lang_option.select(0)
		_lang_option.item_selected.connect(_on_lang_selected)
	# a link can ask for the game right away, that is handy for the website
	if _wants_to_play_now():
		_start_game()
		return
	# gentle fade in (fade the Control, a CanvasLayer has no modulate)
	_ui.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_ui, "modulate:a", 1.0, 0.5)
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(_title, "scale", Vector2.ONE, 0.6).from(Vector2(0.85, 0.85)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(_subtitle, "modulate:a", 1.0, 0.6).from(0.0)


func _check_for_updates() -> void:
	if is_inside_tree():
		Web.check_for_new_version()


func _on_play() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	# if name already set, go directly to lobby
	if Net.player_name != "":
		call_deferred("_change_to_lobby")
		return
	# ask for the name first, then go to the lobby
	var prompt := PROMPT_SCENE.instantiate() as Control
	add_child(prompt)
	prompt.name_chosen.connect(_on_named)


# True when the address of the page asks for the game right away.
func _wants_to_play_now() -> bool:
	if not Web.is_web():
		return false
	if not ClassDB.class_exists("JavaScriptBridge"):
		return false
	var js := "new URLSearchParams(window.location.search).get('play')"
	return str(JavaScriptBridge.eval(js, true)) == "1"


# Straight into the game, without asking for a name.
func _start_game() -> void:
	Net.player_name = "PLAYER"
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_named(_name: String) -> void:
	# defer the scene change so the prompt can be freed cleanly
	call_deferred("_change_to_lobby")


func _change_to_lobby() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _on_quit() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	get_tree().quit()


# --- the update ------------------------------------------------------------
func _on_update_available(_version: String) -> void:
	_update_btn.visible = true
	var text := "NEW VERSION - UPDATE"
	var locale := get_node_or_null("/root/Locale")
	_update_btn.text = locale.translate_text(text) if locale else text
	# the scene has its own button now, the page one would be a duplicate
	Web.hide_web_update_button()


func _on_update_pressed() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	Web.request_update()


# --- the settings ----------------------------------------------------------
func _on_settings_pressed() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	_settings_panel.visible = not _settings_panel.visible


func _on_settings_close() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	_settings_panel.visible = false


func _on_lang_selected(idx: int) -> void:
	var cur := get_node_or_null("/root/Locale")
	if cur == null or not cur.has_method("set_locale"):
		return
	if idx == 1:
		cur.set_locale("vi")
	else:
		cur.set_locale("en")


func _on_volume_changed(value: float) -> void:
	Game.set_master_volume(value)
	_volume_value.text = "%d%%" % int(round(value * 100.0))


func _unhandled_input(event: InputEvent) -> void:
	# F11 is the usual key for fullscreen
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_F11:
			Game.sfx("click", -10.0, 0.95, 1.05)
			Web.toggle_fullscreen()
			get_viewport().set_input_as_handled()
