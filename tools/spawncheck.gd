extends Node2D

# Spawns one of every enemy type, makes them elite and fires the railgun
# laser, then reports any runtime error that showed up.
# Usage: godot --headless --path <project> res://tools/spawncheck.tscn

func _ready() -> void:
	Game.reset_run()
	var scenes := {
		"shape": "res://scenes/enemy.tscn",
		"shooter": "res://scenes/shooter_enemy.tscn",
		"double": "res://scenes/double_enemy.tscn",
		"railgun": "res://scenes/railgun_enemy.tscn",
		"charger": "res://scenes/charger_enemy.tscn",
	}
	var player: Node2D = null
	var pl_scene: Resource = load("res://scenes/player.tscn")
	if pl_scene != null:
		player = pl_scene.instantiate() as Node2D
		player.global_position = Vector2(0, 0)
		add_child(player)
	for key: String in scenes.keys():
		var res: Resource = load(scenes[key])
		if res == null:
			print("FAIL  cannot load ", scenes[key])
			continue
		var e: Node2D = res.instantiate() as Node2D
		e.global_position = Vector2(120.0 + float(key.length()) * 10.0, 0.0)
		add_child(e)
		if e.has_method("setup"):
			e.setup(1.0, 0, 1.0, 1.0)
		if e.has_method("make_elite"):
			e.make_elite(2)
		# count the visual nodes
		var polys := 0
		var lines := 0
		var sprites := 0
		for c in e.get_children():
			if c is Polygon2D:
				polys += 1
			elif c is Line2D:
				lines += 1
			elif c is Sprite2D:
				sprites += 1
		print("%-8s polys=%d lines=%d sprites=%d" % [key, polys, lines, sprites])
	print("spawned all, running 240 frames")
	for i in 240:
		await get_tree().physics_frame
	print("OK - no runtime crash")
	get_tree().quit(0)
