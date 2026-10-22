extends Node

# Checks the touch controls: the stick moves the ship, the fire button
# shoots and both hide themselves until a finger shows up.

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
	print("=== touch controls check ===")
	var found := get_tree().get_first_node_in_group("touch_controls") as Control
	_check(found != null, "the touch pad is in the game scene")
	if found == null:
		print("--- children: ", _scene.get_children())
		print("=== done: %d failure(s) ===" % _failed)
		get_tree().quit(1)
		return

	_check(found.visible == false, "the controls are hidden to begin with")
	_check(found.move_direction() == Vector2.ZERO, "the stick is at rest")
	_check(not found.is_shooting(), "the fire button is not pressed")

	# a finger on the left half starts the stick
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(200, 400)
	touch.index = 0
	found._input(touch)
	await get_tree().process_frame
	_check(found.visible, "the controls show up when a finger touches the screen")

	# the finger moves to the right, the stick points that way
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(280, 400)
	found._input(drag)
	await get_tree().process_frame
	var dir: Vector2 = found.move_direction()
	_check(dir.x > 0.1, "the stick points to the right: %s" % str(dir))
	_check(absf(dir.y) < 0.01, "the stick does not point up or down")

	# a finger on the right half is the fire button
	var fire := InputEventScreenTouch.new()
	fire.pressed = true
	fire.position = Vector2(900, 400)
	fire.index = 1
	found._input(fire)
	await get_tree().process_frame
	_check(found.is_shooting(), "the fire button is pressed")
	_check(found.aim_position() == Vector2(900, 400), "the aim follows the finger")

	# letting go of both
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = Vector2(200, 400)
	up.index = 0
	found._input(up)
	up.index = 1
	up.position = Vector2(900, 400)
	found._input(up)
	await get_tree().process_frame
	_check(found.move_direction() == Vector2.ZERO, "the stick is at rest again")
	_check(not found.is_shooting(), "the fire button is free again")

	# the player knows the stick
	var player := get_tree().get_first_node_in_group("player")
	_check(player != null, "the player is in the scene")

	print("=== done: %d failure(s) ===" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)
