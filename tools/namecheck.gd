extends Node

# Checks the name prompt: it asks for a name, refuses an empty one and
# gives the name to Net.

var _prompt: Control = null
var _failed: int = 0


func _ready() -> void:
	_prompt = load("res://scenes/name_prompt.tscn").instantiate() as Control
	add_child(_prompt)
	await get_tree().process_frame
	await get_tree().process_frame
	_run()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failed += 1
		print("  FAIL ", what)


func _run() -> void:
	print("=== name prompt check ===")
	var edit := _prompt.get_node("Panel/NameEdit") as LineEdit
	var play := _prompt.get_node("Panel/PlayButton") as Button
	_check(edit != null, "the name field exists")
	_check(play != null, "the play button exists")
	_check(edit.max_length > 0, "the name has a maximum length")
	Net.players = [{"id": 1, "name": "Pilot"}]
	_check(Net.is_player_name_taken(" pilot "), "duplicate checks ignore case and whitespace")
	_check(not Net.is_player_name_taken("Other"), "unique player names are accepted")
	Net.players.clear()

	# an empty name is not accepted
	Net.player_name = ""
	edit.text = ""
	play.pressed.emit()
	await get_tree().process_frame
	_check(Net.player_name == "", "an empty name is refused")
	_check(is_instance_valid(_prompt), "the prompt stays open after an empty name")

	# a name is taken over
	edit.text = "  PILOT  "
	play.pressed.emit()
	await get_tree().process_frame
	_check(Net.player_name == "PILOT", "the name is trimmed and taken over")
	_prompt = load("res://scenes/name_prompt.tscn").instantiate() as Control
	add_child(_prompt)
	_prompt.call("show_name_taken")
	await get_tree().process_frame
	_check((_prompt.get_node("Panel/Title") as Label).text == "NAME ALREADY IN USE",
		"duplicate names show a rename request")
	_check((_prompt.get_node("Panel/PlayButton") as Button).text == "CHANGE NAME",
		"the prompt asks the player to choose another name")

	print("=== done: %d failure(s) ===" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)
