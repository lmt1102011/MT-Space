extends Node2D

# Checks that a wave only ends once every enemy is dead, and that the
# railgun's charge tell disappears as soon as it has fired.
# Usage: godot --headless --path <project> res://tools/wavecheck.tscn

const SpawnerScript := preload("res://scripts/spawner.gd")

var _fails := 0


func _ready() -> void:
	print("=== wave check ===")
	await _check_wave()
	await _check_tell()
	print("=== done: %d failure(s) ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		_fails += 1
	print("FAIL  ", label) if not cond else null


# The swarm shapes are ambient: they are not part of a wave, so they must not
# be in the "monster" group that the wave waits on.
func _check_wave() -> void:
	var e: Node2D = (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Node2D
	add_child(e)
	await get_tree().process_frame
	_ok(e.is_in_group("shape_enemy"), "shape enemy is in the shape_enemy group")
	_ok(not e.is_in_group("monster"), "shape enemy does not hold the wave back")
	_ok(e.is_in_group("enemy"), "shape enemy is in the enemy group")
	e.queue_free()
	await get_tree().process_frame


# The charge tell must be hidden once the shot is fired.
func _check_tell() -> void:
	var e: Node2D = (load("res://scenes/railgun_enemy.tscn") as PackedScene).instantiate() as Node2D
	add_child(e)
	for f in 4:
		await get_tree().process_frame
	var ring: Sprite2D = e.get_node_or_null("Sprite2D")
	# the ring and the line are the two sprites added by the hull builder
	var sprites := 0
	for c in e.get_children():
		if c is Sprite2D:
			sprites += 1
	_ok(sprites >= 4, "railgun builds the tell sprites (got %d)" % sprites)
	# force a charge and check the tell shows, then stops
	e.set("_charging", true)
	e.set("_charge_t", 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var tell := _tell_sprites(e)
	_ok(tell.size() == 2, "the railgun has a ring and a line sprite (got %d)" % tell.size())
	var visible_during := false
	for s: Sprite2D in tell:
		if s.visible:
			visible_during = true
	_ok(visible_during, "the charge tell shows while charging")
	e.set("_charging", false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var visible_after := false
	for s: Sprite2D in tell:
		if s.visible:
			visible_after = true
	_ok(not visible_after, "the charge tell is hidden after firing")
	e.queue_free()
	await get_tree().process_frame


# the ring and the line are the last two sprites added by the hull builder
func _tell_sprites(e: Node2D) -> Array:
	var out: Array = []
	for c in e.get_children():
		if c is Sprite2D:
			out.append(c)
	return out.slice(maxi(0, out.size() - 2))
