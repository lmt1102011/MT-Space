extends RefCounted
class_name EnemyAI

# Shared steering helpers so enemies avoid obstacles and each other.
#
# Performance: local neighbours and incoming shots come from the shared spatial
# index, and the scans stop once enough relevant neighbours are found.

const PROBE := 90.0          # how far ahead to look
const AVOID_STRENGTH := 1.6  # how hard to steer away
const SEPARATION_DIST := 44.0
const MAX_SEPARATION := 4    # neighbours considered for separation
const MAX_DODGES := 4        # incoming bullets considered for dodging
const ENEMY_INDEX := preload("res://scripts/enemy_spatial_index.gd")


static func _obstacle_pts(tree: SceneTree) -> Array:
	if not tree.has_meta("obstacle_pts"):
		var pts: Array = []
		for o in tree.get_nodes_in_group("obstacle"):
			var n := o as Node2D
			if n:
				pts.append({"pos": n.global_position, "node": n})
		tree.set_meta("obstacle_pts", pts)
	return tree.get_meta("obstacle_pts")


# Returns a steering vector to add to the desired velocity.
static func steer(self_node: CharacterBody2D, desired: Vector2) -> Vector2:
	var tree := self_node.get_tree()
	var pos := self_node.global_position
	var speed := desired.length()
	if speed < 1.0:
		return Vector2.ZERO
	var dir := desired / speed

	var steer := Vector2.ZERO

	# --- obstacle avoidance: probe ahead, steer away from nearby obstacles ---
	for entry in _obstacle_pts(tree):
		var p: Vector2 = entry["pos"]
		var to_obs := p - pos
		var distance_sq := to_obs.length_squared()
		var max_distance := PROBE + 120.0
		if distance_sq > max_distance * max_distance:
			continue
		var dist := sqrt(distance_sq)
		# is the obstacle roughly ahead?
		if dir.dot(to_obs.normalized()) < 0.35:
			continue
		# steer perpendicular, choosing the side that turns away from the obstacle
		var side := dir.orthogonal()
		if side.dot(to_obs) > 0.0:
			side = -side
		var closeness := clampf(1.0 - dist / (PROBE + 120.0), 0.0, 1.0)
		steer += side * AVOID_STRENGTH * closeness * speed

	# --- separation: gently push away from other enemies that are very close ---
	var found := 0
	var nearby := Rect2(pos - Vector2.ONE * SEPARATION_DIST,
		Vector2.ONE * SEPARATION_DIST * 2.0)
	for other in ENEMY_INDEX.query_group_rect(tree, "enemy", nearby):
		if other == null or not is_instance_valid(other) or other == self_node:
			continue
		var other_node := other as Node2D
		if other_node == null:
			continue
		if self_node.is_in_group("boss2") \
				and other_node.is_in_group("boss_drone"):
			continue
		var away: Vector2 = pos - other_node.global_position
		var distance_sq := away.length_squared()
		if distance_sq > 0.001 and distance_sq < SEPARATION_DIST * SEPARATION_DIST:
			var d := sqrt(distance_sq)
			steer += away.normalized() * (SEPARATION_DIST - d) * 6.0
			found += 1
			if found >= MAX_SEPARATION:
				break

	return steer


# Steers away from incoming player bullets that are heading toward us.
# Soft/smooth: the sidestep ramps in with proximity so it never snaps.
static func danger_steer(self_node: CharacterBody2D, speed: float) -> Vector2:
	var tree := self_node.get_tree()
	var pos := self_node.global_position
	var steer := Vector2.ZERO
	var found := 0
	var danger_area := Rect2(pos - Vector2.ONE * 240.0,
		Vector2.ONE * 480.0)
	for b in ENEMY_INDEX.query_group_rect(tree, "player_bullet", danger_area):
		# the cache can hold bullets that were freed since the last refresh,
		# so check validity BEFORE casting (casting a freed object throws)
		if b == null or not is_instance_valid(b):
			continue
		if b.get("_pooled") == true:
			continue
		var bn := b as Node2D
		if bn == null:
			continue
		var to_self: Vector2 = pos - bn.global_position
		var distance_sq := to_self.length_squared()
		if distance_sq > 240.0 * 240.0 or distance_sq < 0.001:
			continue
		var dist := sqrt(distance_sq)
		# only dodge bullets roughly flying toward us
		var bdir: Vector2 = bn.direction if "direction" in bn else Vector2.ZERO
		if bdir == Vector2.ZERO:
			continue
		var incoming := bdir.dot(-to_self.normalized())
		if incoming < 0.55:
			continue
		# sidestep perpendicular to the bullet path
		var side: Vector2 = bdir.orthogonal()
		if side.dot(to_self) < 0.0:
			side = -side
		var closeness := clampf(1.0 - dist / 240.0, 0.0, 1.0)
		# smooth ramp (squared) and a firm cap so the dodge stays believable
		steer += side * closeness * closeness * (incoming - 0.55) * speed * 1.4
		found += 1
		if found >= MAX_DODGES:
			break
	return steer.limit_length(speed * 1.1)
