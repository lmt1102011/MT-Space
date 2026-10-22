extends Node2D

# Checks that a ship that is told where to go actually moves smoothly:
# it should chase the position it was given, not jump to it.
# Usage: godot --headless --path <project> res://tools/smoothtest.tscn

const REMOTE_PLAYER := preload("res://scenes/remote_player.tscn")

var _fails := 0


func _ready() -> void:
	print("=== smooth follow check ===")
	await _check_follow()
	print("=== done: %d failure(s) ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		_fails += 1
		print("FAIL  ", label)


func _check_follow() -> void:
	var p := REMOTE_PLAYER.instantiate() as Node2D
	add_child(p)
	p.set("_net_target", Vector2(400.0, 0.0))
	await get_tree().physics_frame
	await get_tree().physics_frame

	# the ship starts at the origin and has to walk over
	var start := p.global_position
	var biggest_jump := 0.0
	var last := start
	var frames := 0
	while frames < 90:
		await get_tree().physics_frame
		var now := p.global_position
		biggest_jump = maxf(biggest_jump, now.distance_to(last))
		last = now
		frames += 1
		if frames % 15 == 0:
			print("   frame %2d  pos=(%.1f, %.1f)" % [frames, now.x, now.y])

	_ok(start.distance_to(Vector2.ZERO) < 1.0, "the ship starts at its own position")
	_ok(biggest_jump < 30.0, "the ship never jumps (biggest step %.1f px)" % biggest_jump)
	_ok(last.distance_to(Vector2(400.0, 0.0)) < 8.0,
		"the ship arrives at the target (off by %.1f px)" % last.distance_to(Vector2(400.0, 0.0)))
	# and it keeps up with a target that moves
	var target := Vector2(400.0, 0.0)
	var lag := 0.0
	for i in 60:
		target.x += 6.0
		p.set("_net_target", target)
		await get_tree().physics_frame
		lag = maxf(lag, p.global_position.distance_to(target))
	_ok(lag < 60.0, "the ship keeps up with a moving target (worst lag %.1f px)" % lag)
	p.queue_free()
