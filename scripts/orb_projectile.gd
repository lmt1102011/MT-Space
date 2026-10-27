extends Area2D
class_name OrbProjectile

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
var _art: Sprite2D = null
var _pooled: bool = false
var _shape_radius: float = -1.0


func _init() -> void:
	hide()


func _current_radius() -> float:
	# Stay full-sized for most of the flight, then dissolve slowly at the end.
	var dissolve_start := maxf(lifetime - 2.2, 0.0)
	var dissolve := clampf((_age - dissolve_start) / 2.2, 0.0, 1.0)
	return lerpf(radius, 0.0, dissolve)


func _ready() -> void:
	hide()
	add_to_group("orb_projectile")
	_art = get_node_or_null("OrbArt") as Sprite2D
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape != null:
		shape.shape = shape.shape.duplicate()
		(shape.shape as CircleShape2D).radius = radius
		_shape_radius = radius


func pool_activate() -> void:
	_pooled = false
	hide()
	direction = Vector2.RIGHT
	speed = 260.0
	radius = 44.0
	lifetime = 6.5
	damage = 1.0
	knockback = 360.0
	slow_duration = 0.5
	network_visual = false
	_age = 0.0
	_hit_timers.clear()
	_shape_radius = -1.0
	collision_layer = 0
	collision_mask = 1
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	add_to_group("orb_projectile")
	if _art != null:
		_art.modulate.a = 1.0


func prepare_for_flight() -> void:
	_update_art()
	show()


func pool_deactivate() -> void:
	_pooled = true
	remove_from_group("orb_projectile")
	_hit_timers.clear()


func _physics_process(delta: float) -> void:
	if _pooled:
		return
	_sync_collision_radius()
	_age += delta
	if _age >= lifetime:
		Pool.release(self)
		return
	global_position += direction.normalized() * speed * delta
	for tracked_key in _hit_timers.keys():
		_hit_timers[tracked_key] = float(_hit_timers[tracked_key]) - delta
	if not network_visual:
		# A fast Area2D can tunnel through a CharacterBody2D between physics
		# frames. Distance testing makes contact reliable even at high speed.
		var contact_radius := _current_radius() + PLAYER_RADIUS
		for candidate in Net.players_for_physics_frame():
			var body := candidate as Node2D
			if body == null or not is_instance_valid(body):
				continue
			if body.get("_dead") == true or body.get("net_alive") == false:
				continue
			if global_position.distance_squared_to(body.global_position) \
					> contact_radius * contact_radius:
				continue
			var hit_key := body.get_instance_id()
			if float(_hit_timers.get(hit_key, 0.0)) <= 0.0:
				_hit_timers[hit_key] = HIT_INTERVAL
				_damage_player(body)
	_update_art()


func _sync_collision_radius() -> void:
	if is_equal_approx(_shape_radius, radius):
		return
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null or not shape.shape is CircleShape2D:
		return
	(shape.shape as CircleShape2D).radius = radius
	_shape_radius = radius


func _update_art() -> void:
	if _art == null:
		return
	var dissolve := clampf((_age - maxf(lifetime - 2.2, 0.0)) / 2.2, 0.0, 1.0)
	var pulse := 1.0 + sin(_age * 14.0) * 0.06
	var size := maxf(_current_radius() / 64.0, 0.02)
	_art.scale = Vector2.ONE * size * pulse
	_art.rotation += 0.9 * get_physics_process_delta_time()
	_art.modulate.a = 1.0 - dissolve


func _damage_player(body: Node2D) -> void:
	# One HP per contact pulse: this is deliberately not a one-hit attack.
	if body.has_method("apply_hit"):
		body.call("apply_hit", damage, 0, 0,
			direction.normalized() * knockback, HIT_INTERVAL, true)
	else:
		if body.has_method("apply_orb_damage"):
			body.apply_orb_damage(damage)
		elif body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(direction.normalized() * knockback, HIT_INTERVAL)
	if body.has_method("apply_orb_slow"):
		body.apply_orb_slow(slow_duration)
