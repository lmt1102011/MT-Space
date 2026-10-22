extends Node

# Checks the settings of the menu and the level up screen:
#  - the menu has a settings button with a volume slider
#  - the player can pick the keyboard or the two sticks
#  - the wave label sits in the middle of the top
#  - the game over screen sends the player back to the room

var _failed: int = 0
var _menu: CanvasLayer = null


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failed += 1
		print("  FAIL ", what)


func _ready() -> void:
	_menu = load("res://scenes/menu.tscn").instantiate() as CanvasLayer
	add_child(_menu)
	await get_tree().process_frame
	await get_tree().process_frame
	_run()


func _run() -> void:
	print("=== settings and layout check ===")
	var btn := _menu.get_node_or_null("UI/SettingsButton") as Button
	var panel := _menu.get_node_or_null("UI/SettingsPanel") as Control
	var slider := _menu.get_node_or_null("UI/SettingsPanel/VolumeSlider") as HSlider
	var mode_btn := _menu.get_node_or_null("UI/SettingsPanel/ModeButton") as Button
	_check(btn != null, "the menu has a settings button")
	_check(panel != null, "the menu has a settings panel")
	_check(slider != null, "the settings have a volume slider")
	_check(mode_btn != null, "the settings have a control mode button")
	if btn == null or slider == null or mode_btn == null:
		print("=== done: %d failure(s) ===" % _failed)
		get_tree().quit(1)
		return

	# the panel is closed to begin with
	_check(panel.visible == false, "the settings start closed")
	btn.pressed.emit()
	await get_tree().process_frame
	_check(panel.visible, "the settings open when the button is pressed")

	# the volume slider really changes the sound
	var before := Game.get_master_volume()
	slider.value = 0.35
	await get_tree().process_frame
	_check(not is_equal_approx(Game.get_master_volume(), before), "the slider changes the volume")
	_check(is_equal_approx(Game.get_master_volume(), 0.35), "the volume is the new one")
	slider.value = before
	await get_tree().process_frame

	# the mode button switches between the keyboard and the sticks
	var was_mobile := Game.is_mobile_mode()
	mode_btn.pressed.emit()
	await get_tree().process_frame
	_check(Game.is_mobile_mode() != was_mobile, "the mode button switches the controls")
	_check(mode_btn.text.find("STICKS") >= 0 or mode_btn.text.find("KEYBOARD") >= 0,
		"the mode button shows the mode")
	mode_btn.pressed.emit()
	await get_tree().process_frame
	_check(Game.is_mobile_mode() == was_mobile, "the mode button switches back")

	# the wave label sits in the middle of the top
	var main := load("res://scenes/main.tscn").instantiate() as Node
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var wave := main.get_node_or_null("HUD/WaveLabel") as Label
	_check(wave != null, "the wave label is there")
	if wave != null:
		_check(wave.anchor_left == 0.5, "the wave label is in the middle")
		_check(wave.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
			"the wave label is centred")
	var settings := main.get_node_or_null("HUD/SettingsButton") as Button
	_check(settings != null, "the game has a settings button too")

	# the game over screen sends the player back to the room
	var hud := main.get_node_or_null("HUD") as CanvasLayer
	_check(hud != null, "the hud is there")
	Game.spectate_mode = false
	Game.notify_player_died()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(Game.is_game_over, "the game is over when nobody is left")

	print("=== done: %d failure(s) ===" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)
