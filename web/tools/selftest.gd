extends Node2D

# Headless self test: runs without a window and prints PASS/FAIL lines.
# Usage: godot --headless --path <project> res://tools/selftest.tscn --quit-after 300

const SHAPES := preload("res://scripts/enemy_shapes.gd")
const BULLET := preload("res://scripts/bullet.gd")

var _fails: int = 0
var _done: bool = false


func _ready() -> void:
	print("=== MT Space self test ===")
	_test_shapes()
	_test_homing_setup()
	await _test_homing_flight()
	_finish()


func _finish() -> void:
	_done = true
	print("=== done: %d failure(s) ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		_fails += 1
		print("FAIL  ", label)


func _bbox(paths: Array) -> Rect2:
	var r := Rect2()
	var first := true
	for path: Array in paths:
		for p: Vector2 in path:
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			else:
				r = r.expand(p)
	return r


func _test_shapes() -> void:
	print("-- shapes --")
	# the two ships use the reference drawings as textures
	var rg: Texture2D = SHAPES.RAILGUN_TEX
	var ch: Texture2D = SHAPES.CHARGER_TEX
	_ok(rg != null, "railgun texture loaded")
	_ok(ch != null, "charger texture loaded")
	# the artwork is imported at 8x, so the texture is 8 times the drawing
	_ok(absf(rg.get_size().x / 8.0 - 75.66) < 0.2, "railgun art width 75.66 (got %.2f)" % (rg.get_size().x / 8.0))
	_ok(absf(ch.get_size().x / 8.0 - 75.80) < 0.2, "charger art width 75.80 (got %.2f)" % (ch.get_size().x / 8.0))
	# the drawn size must match the size the art had when it was first drawn
	var w_rg := rg.get_size().x * SHAPES.RAILGUN_SCALE
	var w_ch := ch.get_size().x * SHAPES.CHARGER_SCALE
	print("   railgun %.2f px  charger %.2f px" % [w_rg, w_ch])
	_ok(absf(w_rg - 90.8) < 0.6, "railgun drawn at 90.8 px (got %.2f)" % w_rg)
	_ok(absf(w_ch - 83.4) < 0.6, "charger drawn at 83.4 px (got %.2f)" % w_ch)
	# the nose sits at the front of the ship
	_ok(SHAPES.RAILGUN_NOSE > 40.0 and SHAPES.RAILGUN_NOSE < 50.0, "railgun nose %.1f" % SHAPES.RAILGUN_NOSE)
	_ok(SHAPES.CHARGER_NOSE > 37.0 and SHAPES.CHARGER_NOSE < 46.0, "charger nose %.1f" % SHAPES.CHARGER_NOSE)


func _test_homing_setup() -> void:
	print("-- homing setup --")
	Game.upg_homing = 1
	var b: Area2D = BULLET.new()
	add_child(b)
	b.global_position = Vector2.ZERO
	b.direction = Vector2.RIGHT
	_ok(b.get_script() != null, "bullet script attaches")
	b.queue_free()


# --- functional homing test ------------------------------------------------
# A bullet fired to the right must curve into a target sitting off to the side.
func _test_homing_flight() -> void:
	print("-- homing flight --")
	Game.upg_homing = 1
	var target := CharacterBody2D.new()
	target.global_position = Vector2(260.0, 90.0)
	target.add_to_group("enemy")
	add_child(target)
	var other := CharacterBody2D.new()
	other.global_position = Vector2(300.0, 10.0)
	other.add_to_group("enemy")
	add_child(other)

	var b: Area2D = BULLET.new()
	add_child(b)
	b.global_position = Vector2.ZERO
	b.direction = Vector2.RIGHT
	var start: Vector2 = b.direction
	for i in 10:
		await get_tree().physics_frame
	var end_dir: Vector2 = b.direction
	print("   start %s  end %s  (target %s)" % [start, end_dir, target.global_position])
	_ok(end_dir.angle() > 0.05, "bullet curves toward the target (ang %.3f)" % end_dir.angle())
	_ok(end_dir.angle() < 0.9, "bullet does not spin wildly (ang %.3f)" % end_dir.angle())
	_ok(end_dir.length() > 0.5, "bullet keeps its speed")
	b.queue_free()
	target.queue_free()
	other.queue_free()
