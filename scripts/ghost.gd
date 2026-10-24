extends Node2D

# The little ghost that a dead player becomes while watching somebody else.
#
# It is a small circle with two eyes that floats around the player that is
# being watched, with the name of the dead player underneath.

# how big the circle is
const RADIUS := 7.0
# how far the ghost floats around the player it watches
const ORBIT := 26.0
# how fast it goes around
const SPIN := 1.1
# how high the name sits under the ghost
const NAME_OFFSET := 16.0

var ghost_name: String = ""
var network_owned: bool = false
var local_target: bool = false
var _t: float = 0.0
var _target: Node2D = null
var _target_id: int = 0
var _label: Label = null


func _ready() -> void:
	# Every ghost is centrally discoverable so a wave transition can remove
	# stale local and network-created ghosts, even if one was not registered in
	# NetWorld because death and disconnect arrived in the same frame.
	add_to_group("spectator_ghost")
	z_index = 30
	_t = randf() * TAU
	_label = Label.new()
	_label.name = "GhostName"
	_label.text = ghost_name
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.75))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_label.add_theme_constant_override("outline_size", 2)
	_label.size = Vector2(80, 12)
	_label.position = Vector2(-40, NAME_OFFSET)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


# The player that is being watched, the ghost floats around it.
func set_target(target: Node2D) -> void:
	_target = target
	if target == null:
		return
	_target_id = int(target.get("net_id"))


func set_target_id(id: int) -> void:
	_target_id = id
	_target = null


func set_name_text(text: String) -> void:
	ghost_name = text
	if _label:
		_label.text = text


func _process(delta: float) -> void:
	_t += delta * SPIN
	# Spectating can change before the network proxy is created. Keep the
	# authoritative target id in sync every frame so a host ghost never gets
	# stuck at its old position after a player switch/death.
	if not network_owned and Game.spectate_mode \
			and int(Game.spectate_target) != _target_id:
		_target_id = int(Game.spectate_target)
		_target = null
	# The target proxy may not exist yet when the death RPC arrives. Resolve it
	# continuously so the host ghost starts following as soon as the player is
	# created, instead of drifting forever from its initial position.
	if local_target:
		_target = get_tree().current_scene.get_node_or_null("Player") as Node2D
	elif (_target == null or not is_instance_valid(_target)) and _target_id > 0:
		if Net.world != null and Net.world.has_method("peer_node"):
			_target = Net.world.call("peer_node", _target_id) as Node2D
	if _target != null and is_instance_valid(_target):
		# A stale target can die between snapshots. Let the owner choose a new
		# living target and resolve it on the next frame.
		if _target.has_method("get") and _target.get("net_alive") == false:
			_target = null
			_target_id = 0
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position + Vector2.from_angle(_t) * ORBIT
	else:
		global_position += Vector2.from_angle(_t) * 12.0 * delta
	queue_redraw()


func _draw() -> void:
	# A small, friendly ghost: rounded body, tiny eyes and a subtle smile.
	draw_circle(Vector2(0, 1), 8.0, Color(0.72, 0.88, 1.0, 0.42))
	draw_circle(Vector2(-4.5, 4.0), 3.5, Color(0.72, 0.88, 1.0, 0.42))
	draw_circle(Vector2(4.5, 4.0), 3.5, Color(0.72, 0.88, 1.0, 0.42))
	draw_arc(Vector2(0, 1), 8.0, 0.0, TAU, 28, Color(0.8, 0.94, 1.0, 0.78), 1.4)
	draw_circle(Vector2(-2.7, -0.8), 1.15, Color(0.08, 0.12, 0.18, 0.92))
	draw_circle(Vector2(2.7, -0.8), 1.15, Color(0.08, 0.12, 0.18, 0.92))
	draw_circle(Vector2(-4.0, 1.8), 1.0, Color(1.0, 0.55, 0.65, 0.38))
	draw_circle(Vector2(4.0, 1.8), 1.0, Color(1.0, 0.55, 0.65, 0.38))
	draw_arc(Vector2(0, 0.5), 2.0, 0.25, 2.9, 10, Color(0.08, 0.12, 0.18, 0.8), 0.8)
