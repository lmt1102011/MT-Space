extends Area2D

# A large solid rolling orb. The host owns collision and damage; clients only
# receive a visual copy so the hit cannot be applied twice.
const HIT_INTERVAL := 0.25
const PLAYER_RADIUS := 18.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 260.0
var radius: float = 44.0
var lifetime: float = 6.5
var damage: float = 1.0
var knockback: float = 360.0
var slow_duration: float = 0.5
var network_visual: bool = false
var _age: float = 0.0
var _hit_timers: Dictionary = {}
var _pull_timers: Dictionary = {}
var _art: Sprite2D = null


func _current_radius() -> float:
	# Stay full-sized for most of the flight, then dissolve slowly at the end.
	var dissolve_start := maxf(lifetime - 2.2, 0.0)
	var dissolve := clampf((_age - dissolve_start) / 2.2, 0.0, 1.0)
	return lerpf(radius, 0.0, dissolve)


func _ready() -> void:
	add_to_group("orb_projectile")
	_art = get_node_or_null("OrbArt") as Sprite2D
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape != null:
		shape.shape = shape.shape.duplicate()
		(shape.shape as CircleShape2D).radius = radius
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += direction.normalized() * speed * delta
	for key in _hit_timers.keys():
		_hit_timers[key] = float(_hit_timers[key]) - delta
	for key in _pull_timers.keys():
		_pull_timers[key] = float(_pull_timers[key]) - delta
	if not network_visual:
		# A fast Area2D can tunnel through a CharacterBody2D between physics
		# frames. Distance testing makes contact reliable even at high speed.
		var contact_radius := _current_radius() + PLAYER_RADIUS
		for candidate in get_tree().get_nodes_in_group("player"):
			var body := candidate as Node2D
			if body == null or not is_instance_valid(body):
				continue
			if body.get("_dead") == true or body.get("net_alive") == false:
				continue
			if global_position.distance_to(body.global_position) > contact_radius:
				continue
			var key := body.get_instance_id()
			# Apply the carrying force frequently while avoiding one RPC every
			# render frame for remote players.
			if float(_pull_timers.get(key, 0.0)) <= 0.0:
				# One visible movement pulse per damage/stun beat. This makes the
				# player advance in clear steps instead of being held stationary.
				_pull_timers[key] = HIT_INTERVAL
				_pull_player(body)
			if float(_hit_timers.get(key, 0.0)) <= 0.0:
				_hit_timers[key] = HIT_INTERVAL
				_damage_player(body)
	_update_art()
	queue_redraw()


func _update_art() -> void:
	if _art == null:
		return
	var dissolve := clampf((_age - maxf(lifetime - 2.2, 0.0)) / 2.2, 0.0, 1.0)
	var pulse := 1.0 + sin(_age * 14.0) * 0.06
	var size := maxf(_current_radius() / 64.0, 0.02)
	_art.scale = Vector2.ONE * size * pulse
	_art.rotation += 0.9 * get_physics_process_delta_time()
	_art.modulate.a = 1.0 - dissolve


func _pull_player(body: Node2D) -> void:
	if body.has_method("apply_knockback"):
		body.apply_knockback(direction.normalized() * knockback, HIT_INTERVAL)


func _damage_player(body: Node2D) -> void:
	# One HP per contact pulse: this is deliberately not a one-hit attack.
	if body.has_method("apply_orb_damage"):
		body.apply_orb_damage(damage)
	elif body.has_method("take_damage"):
		body.take_damage(damage)
	if body.has_method("apply_orb_slow"):
		body.apply_orb_slow(slow_duration)


func _draw() -> void:
	pass
