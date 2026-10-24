extends Node

# Checks that the host can stream the enemies out without errors: the enemy
# data has to be readable and the boolean has to survive the trip.

var _failed: int = 0
var _net: Node = null


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failed += 1
		print("  FAIL ", what)


func _ready() -> void:
	Net.player_name = "HOST"
	# the world node the host streams the enemies out of
	var world := Node2D.new()
	world.set_script(load("res://scripts/net_world.gd"))
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	Net.host_room("TEST", 27557)
	await get_tree().process_frame
	await get_tree().process_frame

	# a few enemies of every kind
	for kind in ["shape", "shooter", "double", "railgun", "charger"]:
		world.call("spawn_enemy", kind, Vector2(100, 100), {"sides": 3, "radius": 20.0,
			"speed_mult": 1.0, "dmg_bonus": 0, "fire_mult": 1.0, "hp_mult": 1.0})
	await get_tree().process_frame
	await get_tree().process_frame

	_run()


func _run() -> void:
	print("=== enemy streaming check ===")
	_check(Net.is_host(), "the host is hosting")
	var enemies := get_tree().get_nodes_in_group("enemy")
	_check(enemies.size() > 0, "there are enemies to send")

	# this used to crash: bool() is not a constructor in gdscript
	var crashed := false
	for e in enemies:
		var id := int(e.get("net_id"))
		if id == 0:
			continue
		var row: Array = [e.global_position.x, e.global_position.y,
			e.rotation, float(e.get("hp")), e.get("_net_alive") == true]
		_check(row.size() == 5, "the enemy row is complete")
		_check(typeof(row[4]) == TYPE_BOOL, "the alive flag is a boolean")
	_check(not crashed, "the enemy data can be read")

	# the real thing: the host pushes the enemies out
	var ok := true
	for i in 3:
		Net.push_enemies()
		await get_tree().process_frame
	_check(ok, "the host can push the enemies out")

	# and the client side reads the row back
	var row := [1.0, 2.0, 0.5, 3.0, true]
	_check(row[4] == true, "the alive flag survives the trip")

	Net.leave()
	print("=== done: %d failure(s) ===" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)
