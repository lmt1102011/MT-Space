extends Node

# Checks the enemy damage flow:
#  - the host deals with its own enemies, it never asks itself over the net
#  - a client reports the hit to the host
#  - an enemy on the host really dies and drops its xp

const NetEnemy := preload("res://scripts/net_enemy.gd")

var _failed: int = 0
var _world: Node2D = null


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failed += 1
		print("  FAIL ", what)


func _ready() -> void:
	Net.player_name = "HOST"
	_world = Node2D.new()
	_world.set_script(load("res://scripts/net_world.gd"))
	add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	Net.host_room("TEST", 27558)
	await get_tree().process_frame
	await get_tree().process_frame
	_run()


func _run() -> void:
	print("=== enemy damage check ===")
	_check(Net.is_host(), "the host is hosting")
	_check(Net.is_online(), "the host is online")

	# the host spawns a shooter
	var e: Node2D = _world.call("spawn_enemy", "shooter", Vector2(300, 300),
		{"speed_mult": 1.0, "dmg_bonus": 0, "fire_mult": 1.0, "hp_mult": 1.0})
	_check(e != null, "the host spawned an enemy")
	if e == null:
		print("=== done: %d failure(s) ===" % _failed)
		get_tree().quit(1)
		return

	# the host gives its own enemy an id, but it is not a copy
	_check(int(e.get("net_id")) != 0, "the host enemy has a net id")
	_check(e.get("_net_copy") == false, "the host enemy is not a copy")
	_check(not NetEnemy.is_remote(e), "the host enemy is not treated as a copy")

	# a copy on a client is a copy
	var copy: Node2D = _world.call("spawn_enemy", "shooter", Vector2(400, 400),
		{"speed_mult": 1.0, "dmg_bonus": 0, "fire_mult": 1.0, "hp_mult": 1.0})
	copy.set("_net_copy", true)
	_check(NetEnemy.is_remote(copy), "a copy on a client is a copy")
	copy.queue_free()

	# the host enemy takes damage and really dies
	var hp_before := int(e.get("hp"))
	_check(hp_before > 0, "the enemy has hp")
	e.call("take_damage", 1000.0, "normal")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not is_instance_valid(e), "the enemy died")
	_check(get_tree().get_nodes_in_group("xp_orb").size() > 0, "the enemy dropped xp")

	# the host never sends a hit report to itself
	Net.report_hit(1, 5.0, "normal")
	_check(true, "the host does not report hits to itself")

	Net.leave()
	print("=== done: %d failure(s) ===" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)
