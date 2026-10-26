extends CharacterBody2D

# Another player's ship. It does not think for itself: it chases the position
# the network told it about, which keeps the movement smooth even though the
# updates only arrive a few times a second.

# how fast the ship catches up with the position it was told about
const FOLLOW_SPEED := 38.0
# the rotation is followed a bit slower so it does not snap
const FOLLOW_TURN := 10.0
const STATUS_VISUAL := preload("res://scripts/status_effect_visual.gd")

var net_id: int = 0
var net_name: String = ""
var net_color: Color = Color.WHITE
var net_hp: float = 1.0
var net_alive: bool = true
var net_spectate_target: int = 0
var net_level: int = 1
var net_burning: bool = false
var net_frozen: bool = false
var net_thrust: float = 0.0
var net_velocity: Vector2 = Vector2.ZERO
var net_stunned: bool = false
var net_death_locked: bool = false

var _net_target: Vector2 = Vector2.ZERO
var _net_rot: float = 0.0
var _sprite: Sprite2D = null
var _name_label: Label = null
var _ghost_t: float = 0.0
var _flame_out: Polygon2D = null
var _flame_in: Polygon2D = null
var _flame_time: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var _render_velocity: Vector2 = Vector2.ZERO
var _thrust: float = 0.0
var _status_visual: Node2D = null


func _ready() -> void:
	# Remote players do not need local enemy collision response; the host owns
	# contact damage and the local player must not be pushed by replicas.
	collision_mask = 4
	add_to_group("player")
	_sprite = $Ship
	_flame_out = _make_flame(5.0)
	_flame_in = _make_flame(2.5)
	_last_position = global_position
	_status_visual = STATUS_VISUAL.new()
	_status_visual.set("radius", 24.0)
	_status_visual.z_index = 2
	add_child(_status_visual)
	_sprite.modulate = net_color
	_name_label = $Name
	_refresh_name()
	_name_label.add_theme_color_override("font_color", net_color)
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_name_label.add_theme_constant_override("outline_size", 3)


# The name can arrive after the ship was made, so it is set here too.
func _refresh_name() -> void:
	if _name_label != null:
		_name_label.text = net_name
	if _sprite != null:
		var col := net_color
		col.a = _sprite.modulate.a
		_sprite.modulate = col


func _physics_process(delta: float) -> void:
	if not net_alive:
		# Do not render the dead RemotePlayer itself. It is only a network state
		# holder; rendering it here together with the watched player can look like
		# a duplicated player. A separate ghost node is the only visual marker.
		visible = false
		collision_layer = 0
		collision_mask = 0
	else:
		visible = true
	var follow_alpha := 1.0 - exp(-12.0 * delta)
	# Predict from the replicated velocity and gently correct snapshot error.
	# This removes the stop/start motion between 30 Hz network packets.
	if net_alive or net_spectate_target <= 0:
		var error := _net_target + net_velocity * 0.06 - global_position
		if error.length() > 520.0:
			global_position = _net_target
		else:
			var correction := error * follow_alpha
			_render_velocity = _render_velocity.lerp(net_velocity, follow_alpha)
			var step := _render_velocity * delta * 0.92 + correction
			if step.length() > 26.0:
				step = step.normalized() * 26.0
			global_position += step
		# Only the ship rotates. The name, HP bar and ghost remain upright.
		_sprite.rotation = lerp_angle(_sprite.rotation, _net_rot,
			follow_alpha)
	# the ship fades out when its owner dies
	var want := 1.0 if net_alive else 0.0
	_sprite.modulate.a = lerpf(_sprite.modulate.a, want, 0.1)
	_sprite.visible = net_alive and visible
	# A dead proxy itself is the ghost marker. Its old player name must not be
	# drawn on top of the living target, otherwise it looks like a duplicate
	# player with the target's label.
	_name_label.visible = net_alive and visible
	_name_label.text = "%s %d" % [net_name if net_name != "" else "PLAYER", net_level]
	_flame_time += delta
	# Use the owner's replicated thrust instead of guessing from packet motion.
	# This keeps the flame visible even when the ship is moving slowly or the
	# interpolation has already caught up with the latest packet.
	_thrust = move_toward(_thrust, net_thrust, delta * 12.0)
	_last_position = global_position
	_update_flame()
	if _status_visual != null:
		_status_visual.call("set_status", net_alive and net_burning,
			net_alive and net_frozen)
	collision_layer = 1 if net_alive else 0
	if not net_alive:
		collision_mask = 0
	queue_redraw()


func take_damage(amount: float, _kind: String = "normal") -> void:
	# This proxy only exists on the host. The real health belongs to the
	# player's own process, so forward the hit to that peer.
	if Net.is_host():
		Net.damage_remote_player(net_id, amount)


func apply_orb_damage(amount: float) -> void:
	if Net.is_host():
		Net.damage_remote_player_orb(net_id, amount)


func apply_knockback(impulse: Vector2, stun_time: float = 0.5) -> void:
	if Net.is_host():
		Net.damage_remote_player_with_effect(net_id, 0, 0, 0, impulse, stun_time)


func apply_hit(amount: float, burn: int = 0, freeze: int = 0,
		knockback: Vector2 = Vector2.ZERO, stun_time: float = 0.0,
		orb_damage: bool = false) -> void:
	if Net.is_host():
		Net.damage_remote_player_with_effect(
			net_id, amount, burn, freeze, knockback, stun_time, orb_damage)


func apply_orb_slow(duration: float = 0.5) -> void:
	if Net.is_host():
		Net.slow_remote_player(net_id, duration)


func _draw() -> void:
	if not net_alive:
		# Dead proxies are state-only. The separate ghost node is the only
		# object allowed to draw the dead player's marker.
		return
	var t := clampf(net_hp, 0.0, 1.0)
	if net_stunned:
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32,
			Color(0.65, 0.35, 1.0, 0.85), 2.5)
	var w := 46.0
	draw_rect(Rect2(-w / 2.0, 30.0, w, 5.0), Color(0.05, 0.07, 0.06, 0.85))
	draw_rect(Rect2(-w / 2.0 + 1.0, 31.0, (w - 2.0) * t, 3.0),
		Color(1.0 - t, 0.3 + 0.6 * t, 0.35))
	if not net_alive:
		draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 24, Color(0.7, 0.85, 1.0, 0.75), 2.0)


func _make_flame(width: float) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(0, width), Vector2(-1, 0), Vector2(0, -width)])
	add_child(poly)
	return poly


func _update_flame() -> void:
	if _flame_out == null:
		return
	var back := Vector2(-15, 0).rotated(_sprite.rotation)
	var flicker := 0.8 + sin(_flame_time * 40.0) * 0.2
	var length := (5.0 + _thrust * 20.0) * flicker
	var lit := net_alive and _thrust > 0.02
	_flame_out.position = back
	_flame_out.rotation = _sprite.rotation
	_flame_out.scale = Vector2(length, 1.0)
	_flame_out.color = Color(1.0, 0.75, 0.25, 0.35 + 0.5 * _thrust)
	_flame_out.visible = lit
	_flame_in.position = back
	_flame_in.rotation = _sprite.rotation
	_flame_in.scale = Vector2(length * 0.55, 1.0)
	_flame_in.color = Color(1.0, 1.0, 0.8, 0.6 + 0.4 * _thrust)
	_flame_in.visible = lit
