extends CanvasLayer

const PROMPT_SCENE := preload("res://scenes/name_prompt.tscn")

@onready var _ui: Control = $UI
@onready var _play_btn: Button = $UI/PlayButton
@onready var _quit_btn: Button = $UI/QuitButton
@onready var _full_btn: Button = $UI/FullscreenButton
@onready var _title: Label = $UI/Title
@onready var _subtitle: Label = $UI/Subtitle


func _ready() -> void:
	_play_btn.pressed.connect(_on_play)
	_quit_btn.pressed.connect(_on_quit)
	_full_btn.pressed.connect(_on_fullscreen)
	# gentle fade in (fade the Control, a CanvasLayer has no modulate)
	_ui.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_ui, "modulate:a", 1.0, 0.5)
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(_title, "scale", Vector2.ONE, 0.6).from(Vector2(0.85, 0.85)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(_subtitle, "modulate:a", 1.0, 0.6).from(0.0)


func _on_play() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	# ask for the name first, then go to the lobby
	var prompt := PROMPT_SCENE.instantiate() as Control
	add_child(prompt)
	prompt.name_chosen.connect(_on_named)


func _on_named(_name: String) -> void:
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _on_quit() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	get_tree().quit()


func _on_fullscreen() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	Web.toggle_fullscreen()
	_refresh_fullscreen_text()


func _refresh_fullscreen_text() -> void:
	_full_btn.text = "WINDOW" if Web.is_fullscreen() else "FULLSCREEN"


func _unhandled_input(event: InputEvent) -> void:
	# F11 is the usual key for fullscreen
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_F11:
			_on_fullscreen()
			get_viewport().set_input_as_handled()
