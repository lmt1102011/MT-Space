extends RefCounted

# Small helpers the enemies use to behave differently when they are drawn on
# a client instead of being thought for by the host.
#
# On the host an enemy runs its own brain. On a client it only follows the
# position the host sent, so the whole fight looks the same everywhere.

# how fast a remote enemy catches up with the position it was told about
const FOLLOW_SPEED := 14.0
const FOLLOW_TURN := 10.0

# the fields every enemy needs for the network
static func net_fields() -> Array:
	return ["net_id", "_net_target", "_net_rot", "_net_alive", "_net_copy", "_net_hitter"]


# True when this enemy is only a copy of the one on the host.
#
# The host also gives its own enemies a net id, so the id alone does not tell
# the two apart: only the copies carry the copy flag.
static func is_remote(node: Node) -> bool:
	return node.get("_net_copy") == true


# A copy of a host enemy walks towards the position the host sent, so the
# movement stays smooth even though the updates are only a few per second.
static func follow(node: Node2D, delta: float) -> void:
	var target: Vector2 = node.get("_net_target")
	var to := target - node.global_position
	var step := to * clampf(FOLLOW_SPEED * delta, 0.0, 1.0)
	# never move further in one frame than the enemy could travel, so a long
	# distance is walked over instead of teleported
	var limit := 700.0 * minf(delta, 1.0 / 60.0)
	if step.length() > limit:
		step = step.normalized() * limit
	node.global_position += step
	node.rotation = lerp_angle(node.rotation, float(node.get("_net_rot")),
		clampf(FOLLOW_TURN * delta, 0.0, 1.0))


# A client asks the host to deal the damage, the host is the one who decides.
static func report_hit(node: Node, amount: float, kind: String) -> bool:
	if not is_remote(node):
		return false
	# a copy without an id cannot be reported, so it is hit locally
	var id := int(node.get("net_id"))
	if id == 0:
		return false
	Net.report_hit(id, amount, kind)
	return true


# The host killed an enemy: the clients have to let it go as well.
#
# The xp goes to the player that landed the last blow. A remote player gets
# it sent over the network, the host drops it on the map as usual.
#
# Returns true when the xp still has to be dropped on the map.
static func died(node: Node, xp: int) -> bool:
	node.set("_net_alive", false)
	var id := int(node.get("net_id"))
	if id != 0:
		Net.remove_enemy(id)
	# the peer that hit the enemy last earns the xp
	var hitter := int(node.get("_net_hitter"))
	if hitter > 0 and hitter != Net.my_id() and xp > 0:
		Net.send_xp(hitter, xp)
		return false
	return true
