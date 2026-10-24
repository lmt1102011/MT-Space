extends RefCounted

# Each XP orb has the same value, so enemies scatter several small pickups
# rather than dropping one large orb.
#
# Deliberately no class_name: the enemies reference this through a plain
# preload so it never depends on the editor's global class cache.

const ORB_SCENE := preload("res://scenes/xp_orb.tscn")
const ORB_XP_VALUE := 5


static func drop(tree: SceneTree, pos: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	# Scavenger: kills are worth more xp
	amount = int(round(float(amount) * (1.0 + 0.4 * float(Game.upg_scavenger))))
	var orb_count := maxi(1, int(round(float(amount) / float(ORB_XP_VALUE))))
	for i in orb_count:
		_spawn(tree, pos, i, orb_count)


static func _spawn(tree: SceneTree, pos: Vector2, index: int, count: int) -> void:
	var orb := ORB_SCENE.instantiate()
	var angle := TAU * float(index) / float(count) + randf_range(-0.2, 0.2)
	var distance := randf_range(8.0, 30.0)
	orb.set("global_position", pos + Vector2.from_angle(angle) * distance)
	orb.set("xp_value", ORB_XP_VALUE)
	tree.current_scene.add_child(orb)
