extends SceneTree

func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	var game = root.get_node("Game")
	game.add_xp(9999)
	await create_timer(1.5).timeout
	var cards = main.get_node("UpgradeCards")
	print("VISIBLE=", cards.visible, " PAUSED=", paused)
	var holder = cards.get_node("Control")
	var card0 = holder.get_child(0)
	print("CARD0_POS=", card0.position, " FILTER=", card0.mouse_filter)
	# simulate left click on card 0
	var ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	card0._on_gui_input(ev)
	await create_timer(1.0).timeout
	print("AFTER_CLICK PAUSED=", paused, " VISIBLE=", cards.visible)
	await create_timer(1.0).timeout
	quit()
