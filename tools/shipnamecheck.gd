extends Node

# Checks that the name of the player ends up under the ship, both for the
# local player and for the ones that come in over the network.

var _failed: int = 0


func _ready() -> void:
	Net.player_name = "ACE"
	await get_tree().process_frame
	_run()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failed += 1
		print("  FAIL ", what)


func _run() -> void:
	print("=== player name check ===")
	# the local ship
	var player_scene := load("res://scenes/player.tscn")
	_check(player_scene != null, "the player scene exists")
	var p: Node = null
	if player_scene != null:
		p = player_scene.instantiate()
		add_child(p)
		await get_tree().process_frame
		await get_tree().process_frame
		var lbl := p.get_node_or_null("NameLabel") as Label
		_check(lbl != null, "the local ship has a name label")
		if lbl != null:
			_check(lbl.text == "ACE", "the local name is shown: %s" % lbl.text)
			_check(lbl.position.y > 0.0, "the name is under the ship")
	if p != null:
		p.queue_free()
		await get_tree().process_frame

	# a ship that comes in over the network
	Net.players = [
		{"id": 1, "name": "ACE", "color": Color.WHITE},
		{"id": 2, "name": "BRAVO", "color": Color.RED},
	]
	var world_script := load("res://scripts/net_world.gd")
	_check(world_script != null, "the net world script exists")
	var world := Node2D.new()
	world.set_script(world_script)
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var remote: Node2D = null
	for c in world.get_children():
		if c is Node2D and (c as Node2D).has_method("_refresh_name"):
			remote = c
			break
	_check(remote != null, "the remote ship exists")
	if remote != null:
		var name_label := remote.get_node_or_null("Name") as Label
		_check(name_label != null, "the remote ship has a name label")
		if name_label != null:
			_check(name_label.text == "BRAVO", "the remote name is shown: %s" % name_label.text)
			_check(name_label.position.y > 0.0, "the remote name is under the ship")

	Net.players = []
	print("=== done: %d failure(s) ===" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)
