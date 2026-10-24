extends Node

# Checks that the menu asks for the name before the lobby is opened.

var _failed: int = 0
var _menu: CanvasLayer = null


func _ready() -> void:
	_menu = load("res://scenes/menu.tscn").instantiate() as CanvasLayer
	add_child(_menu)
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
	print("=== menu check ===")
	Net.player_name = ""
	var play: Button = _menu.get_node("UI/PlayButton")
	_check(play != null, "the menu has a play button")

	# pressing play opens the name prompt
	play.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var prompt: Control = null
	for c in _menu.get_children():
		if c is Control and (c as Control).get_node_or_null("Panel/NameEdit") != null:
			prompt = c
			break
	_check(prompt != null, "the name prompt opens")

	# the lobby is not open yet
	_check(get_tree().current_scene == null or get_tree().current_scene.name != "Lobby",
		"the lobby is not open before the name is given")

	# typing a name and pressing play continues to the lobby
	if prompt != null:
		var edit := prompt.get_node("Panel/NameEdit") as LineEdit
		edit.text = "MAVERICK"
		# do not really change the scene, that would free this test
		for conn in prompt.name_chosen.get_connections():
			prompt.name_chosen.disconnect(conn["callable"])
		(prompt.get_node("Panel/PlayButton") as Button).pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(Net.player_name == "MAVERICK", "the name is taken over")

	print("=== done: %d failure(s) ===" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)
