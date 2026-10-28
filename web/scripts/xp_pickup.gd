extends RefCounted

# XP drops are merged instead of piling up. Without this the map slowly fills
# with hundreds of pickups (the arena is huge, the player never collects them
# all) and that was the main source of the lag on busy waves.
#
# Deliberately no class_name: the enemies reference this through a plain
# preload so it never depends on the editor's global class cache.

const ORB_SCENE := preload("res://scenes/xp_orb.tscn")
const MAX_ORBS := 32
const MERGE_DIST := 120.0


static func drop(tree: SceneTree, pos: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	# Scavenger: kills are worth more xp
	amount = int(round(float(amount) * (1.0 + 0.4 * float(Game.upg_scavenger))))
	var orbs: Array = tree.get_nodes_in_group("xp_orb")
	if orbs.is_empty():
		_spawn(tree, pos, amount)
		return

	# merge into a nearby orb when there is one
	for o in orbs:
		var n := o as Node2D
		if n == null or n.is_queued_for_deletion():
			continue
		if n.global_position.distance_to(pos) < MERGE_DIST:
			_add_xp(o, amount)
			return

	# too many orbs on the map: pour the xp into the closest one
	if orbs.size() >= MAX_ORBS:
		var best: Node2D = null
		var best_d := INF
		for o in orbs:
			var n := o as Node2D
			if n == null or n.is_queued_for_deletion():
				continue
			var d := n.global_position.distance_squared_to(pos)
			if d < best_d:
				best_d = d
				best = n
		if best != null:
			_add_xp(best, amount)
			return

	_spawn(tree, pos, amount)


static func _add_xp(orb: Node, amount: int) -> void:
	if orb.has_method("add_xp_value"):
		orb.call("add_xp_value", amount)
	else:
		orb.set("xp_value", int(orb.get("xp_value")) + amount)


static func _spawn(tree: SceneTree, pos: Vector2, amount: int) -> void:
	var orb := ORB_SCENE.instantiate()
	orb.set("global_position", pos + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 18.0))
	orb.set("xp_value", amount)
	tree.current_scene.add_child(orb)
