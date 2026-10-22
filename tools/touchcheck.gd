extends Node

# Checks the two sticks for a phone and the settings of the game.

var _failed: int = 0
var _scene: Node = null


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failed += 1
		print("  FAIL ", what)


func _ready() -> void:
	_scene = load("res://scenes/main.tscn").instantiate() as Node
	add_child(_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	_run()


func _run() -> void:
	print("=== two sticks and settings check ===")
	var pad := get_tree().get_first_node_in_group("touch_controls") as Control
	_check(pad != null, "the sticks are in the game scene")
	if pad == null:
		print("=== done: %d failure(s) ===" % _failed)
		get_tree().quit(1)
		return

	# the phone mode shows the sticks right away
	Game.set_control_mode(Game.CONTROL_MOBILE)
	await get_tree().process_frame
	_check(pad.visible, "the sticks show in the phone mode")
	_check(bool(pad.call("always_visible")), "the phone mode keeps the sticks on")
	_check(pad.move_direction() == Vector2.ZERO, "the left stick is at rest")
	_check(pad.aim_direction() == Vector2.ZERO, "the right stick is at rest")
	_check(not pad.is_shooting(), "the right stick does not shoot yet")

	# a finger on the left half moves the ship
	var move_touch := InputEventScreenTouch.new()
	move_touch.pressed = true
	move_touch.position = Vector2(200, 500)
	move_touch.index = 0
	pad._input(move_touch)
	await get_tree().process_frame
	_check(pad.visible, "the sticks show up when a finger touches the screen")

	# the finger moves to the right, the left stick points that way
	var move_drag := InputEventScreenDrag.new()
	move_drag.index = 0
	move_drag.position = Vector2(280, 500)
	pad._input(move_drag)
	await get_tree().process_frame
	var mdir: Vector2 = pad.move_direction()
	_check(mdir.x > 0.1, "the left stick points to the right: %s" % str(mdir))
	_check(absf(mdir.y) < 0.01, "the left stick does not point up or down")

	# a finger on the right half aims and shoots
	var aim_touch := InputEventScreenTouch.new()
	aim_touch.pressed = true
	aim_touch.position = Vector2(900, 500)
	aim_touch.index = 1
	pad._input(aim_touch)
	await get_tree().process_frame
	_check(pad.is_shooting(), "the right stick shoots while it is held")
	var adir: Vector2 = pad.aim_direction()
	_check(adir == Vector2.ZERO, "the right stick is straight at first")

	# the finger on the right stick moves, now it aims
	var aim_drag := InputEventScreenDrag.new()
	aim_drag.index = 1
	aim_drag.position = Vector2(820, 400)
	pad._input(aim_drag)
	await get_tree().process_frame
	adir = pad.aim_direction()
	_check(adir.x < -0.1, "the right stick aims to the left: %s" % str(adir))
	_check(adir.y < -0.1, "the right stick aims up: %s" % str(adir))
	_check(pad.is_shooting(), "the right stick still shoots")

	# letting go of both
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = Vector2(200, 500)
	up.index = 0
	pad._input(up)
	up.index = 1
	up.position = Vector2(900, 500)
	pad._input(up)
	await get_tree().process_frame
	_check(pad.move_direction() == Vector2.ZERO, "the left stick is at rest again")
	_check(not pad.is_shooting(), "the right stick stops shooting")

	# the settings of the game
	Game.set_control_mode(Game.CONTROL_PC)
	await get_tree().process_frame
	_check(not bool(pad.call("always_visible")), "the keyboard mode hides the sticks")
	_check(Game.get_master_volume() >= 0.0, "the volume is there")

	print("=== done: %d failure(s) ===" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)
