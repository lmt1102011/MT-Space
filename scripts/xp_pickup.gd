extends RefCounted

# XP drops merge into nearby pickups to keep the number of live nodes bounded.
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
	var orbs := tree.get_nodes_in_group("xp_orb")
	for orb in orbs:
		var node := orb as Node2D
		if node != null and not node.is_queued_for_deletion() \
				and node.global_position.distance_squared_to(pos) \
				< MERGE_DIST * MERGE_DIST:
			_add_xp(orb, amount)
			return

	if orbs.size() >= MAX_ORBS:
		var closest: Node2D = null
		var closest_distance := INF
		for orb in orbs:
			var node := orb as Node2D
			if node == null or node.is_queued_for_deletion():
				continue
			var distance := node.global_position.distance_squared_to(pos)
			if distance < closest_distance:
				closest_distance = distance
				closest = node
		if closest != null:
			_add_xp(closest, amount)
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
