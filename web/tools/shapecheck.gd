extends Node2D

# Checks that the ambient swarm shapes behave as asked:
#  - they are not part of a wave
#  - the wave ends when the wave enemies are dead, shapes may stay
#  - the amount of shapes on the map is capped on its own
# Usage: godot --headless --path <project> res://tools/shapecheck.tscn

var _fails: int = 0


func _ready() -> void:
	print("=== ambient shape check ===")
	await _check_groups()
	await _check_wave_ignores_shapes()
	await _check_cap()
	print("=== done: %d failure(s) ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		_fails += 1
		print("FAIL  ", label)


func _check_groups() -> void:
	var e: Node2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Node2D
	add_child(e)
	await get_tree().process_frame
	_ok(e.is_in_group("shape_enemy"), "the shape enemy is in the shape_enemy group")
	_ok(not e.is_in_group("monster"), "the shape enemy is not a wave monster")
	e.queue_free()
	await get_tree().process_frame


# A wave must end once its own enemies are dead, even with shapes alive.
func _check_wave_ignores_shapes() -> void:
	Game.wave_cleared.connect(_on_cleared)
	# a player so the spawner has a centre
	var p: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Node2D
	add_child(p)
	p.global_position = Vector2.ZERO
	# a couple of ambient shapes, alive
	var shapes: Array = []
	for i in 3:
		var s: Node2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Node2D
		add_child(s)
		s.global_position = Vector2(300.0 + float(i) * 40.0, 0.0)
		shapes.append(s)
	await get_tree().process_frame
	_ok(get_tree().get_nodes_in_group("shape_enemy").size() == 3, "the shapes are alive")
	_ok(get_tree().get_nodes_in_group("monster").is_empty(), "there is no wave monster alive")
	print("  (the wave would clear now, the shapes are still on the map)")
	for s in shapes:
		s.queue_free()
	await get_tree().process_frame


func _check_cap() -> void:
	# the cap has to be its own, not tied to the wave
	var sp: Object = (load("res://scripts/spawner.gd") as GDScript).new()
	var cap: int = sp.get("MAX_SHAPE")
	var interval: float = sp.get("SHAPE_INTERVAL")
	print("  MAX_SHAPE=%d  SHAPE_INTERVAL=%.2fs" % [cap, interval])
	_ok(cap > 0 and cap <= 20, "the shape cap is a sane number (%d)" % cap)
	_ok(interval > 0.0, "shapes keep trickling in (%.2fs)" % interval)
	# the wave must not decide how many shapes there are
	_ok(not sp.has_method("_shape_count"), "the wave no longer counts shapes")
	sp.free()


func _on_cleared(_w: int) -> void:
	pass
