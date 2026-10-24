extends Control

# Asks the player for their name before the game starts. The name is shown
# under their own ship and under the ship of every other player.

signal name_chosen(name: String)

@onready var _edit: LineEdit = $Panel/NameEdit
@onready var _play_btn: Button = $Panel/PlayButton
@onready var _title: Label = $Panel/Title
@onready var _hint: Label = $Panel/Hint

const MAX_NAME := 14


func show_name_taken() -> void:
	_title.text = "NAME ALREADY IN USE"
	_hint.text = "choose a different name to join this room"
	_play_btn.text = "CHANGE NAME"


func _ready() -> void:
	_play_btn.pressed.connect(_on_play)
	_edit.text_submitted.connect(func(_t): _on_play())
	# start with the name that was used last, if there was one
	_edit.text = Net.player_name if Net.player_name != "" else ""
	_edit.placeholder_text = "your name"
	_edit.max_length = MAX_NAME
	_edit.grab_focus()
	_ui_fade_in()


func _ui_fade_in() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)


func _on_play() -> void:
	var name := _edit.text.strip_edges()
	if name == "":
		# no name typed: the field turns red for a moment
		_edit.modulate = Color(1.0, 0.5, 0.5)
		var tw := create_tween()
		tw.tween_property(_edit, "modulate", Color.WHITE, 0.4)
		Game.sfx("click", -12.0, 0.9, 1.0)
		return
	Net.player_name = name
	Game.sfx("cardget", -10.0, 0.98, 1.04)
	name_chosen.emit(name)
	queue_free()
