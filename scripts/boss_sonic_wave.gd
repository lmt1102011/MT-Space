extends Node2D

@export var max_radius: float = 520.0
@export var duration: float = 0.85
@export var player_damage: int = 3
@export var shape_damage: int = 2
@export var stun_duration: float = 2.0
@export var visual_only: bool = false
@export var direction: Vector2 = Vector2.RIGHT
@export_range(1.0, 80.0) var half_angle_degrees: float = 44.0

var _elapsed: float = 0.0
var _scan_timer: float = 0.0
var _previous_radius: float = 0.0
var _hit_players: Dictionary = {}
var _hit_enemies: Dictionary = {}
var _players: Array = []
var _enemies: Array = []
var _sector: Polygon2D
var _wavefront: Line2D


func _ready() -> void:
	add_to_group("boss_sonic_wave")
	_players = get_tree().get_nodes_in_group("player")
	_enemies = get_tree().get_nodes_in_group("enemy")
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	direction = direction.normalized()
	_sector = Polygon2D.new()
	_sector.color = Color(0.35, 0.84, 1.0, 0.5)
	add_child(_sector)
	_wavefront = Line2D.new()
	_wavefront.width = 9.0
	_wavefront.default_color = Color(0.72, 0.96, 1.0, 0.95)
	_wavefront.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_wavefront.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_wavefront)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var radius := max_radius * progress
	_update_visual(radius, 1.0 - progress)
	if not visual_only:
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_scan_timer = 0.04
			_apply_crossing_hits(_previous_radius, radius)
	_previous_radius = radius
	if _elapsed >= duration:
		queue_free()


func _update_visual(radius: float, fade: float) -> void:
	var points := PackedVector2Array([Vector2.ZERO])
	var arc := PackedVector2Array()
	var half_angle := deg_to_rad(half_angle_degrees)
	for i in range(33):
		var angle := lerpf(-half_angle, half_angle, float(i) / 32.0)
		var point := direction.rotated(angle) * radius
		points.append(point)
		arc.append(point)
	_sector.polygon = points
	_sector.color = Color(0.35, 0.84, 1.0, 0.5 * fade)
	_wavefront.points = arc
	_wavefront.default_color = Color(0.72, 0.96, 1.0, 0.95 * fade)


func _apply_crossing_hits(previous_radius: float, current_radius: float) -> void:
	for candidate in _players:
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var player := candidate as Node2D
		if player.get("_dead") == true or player.get("net_alive") == false:
			continue
		var player_id := player.get_instance_id()
		if _hit_players.has(player_id):
			continue
		var offset := player.global_position - global_position
		if not _crossed_sector(offset, 18.0, previous_radius, current_radius):
			continue
		_hit_players[player_id] = true
		if player.has_method("apply_hit"):
			player.call("apply_hit", player_damage, 0, 0,
				direction * 760.0, stun_duration)
		else:
			if player.has_method("take_damage"):
				player.take_damage(player_damage)
			if player.has_method("apply_knockback"):
				player.apply_knockback(direction * 760.0, stun_duration)

	for candidate in _enemies:
		if not is_instance_valid(candidate) or not candidate is Node2D:
			continue
		var enemy := candidate as Node2D
		if enemy.is_in_group("boss"):
			continue
		var enemy_id := enemy.get_instance_id()
		if _hit_enemies.has(enemy_id):
			continue
		var offset := enemy.global_position - global_position
		var body_radius := 24.0
		if enemy.is_in_group("shape_enemy"):
			body_radius = maxf(float(enemy.get("radius")), 18.0)
		if not _crossed_sector(offset, body_radius, previous_radius, current_radius):
			continue
		_hit_enemies[enemy_id] = true
		if enemy.has_method("apply_push"):
			enemy.apply_push(direction * 300.0)
		if enemy.is_in_group("shape_enemy"):
			if enemy.has_method("take_damage"):
				enemy.take_damage(shape_damage)


func _crossed_sector(offset: Vector2, body_radius: float,
		previous_radius: float, current_radius: float) -> bool:
	var distance := offset.length()
	if distance + body_radius < previous_radius \
			or distance - body_radius > current_radius:
		return false
	if distance <= body_radius:
		return true
	var cosine := direction.normalized().dot(offset / distance)
	var angular_margin := asin(clampf(body_radius / distance, 0.0, 1.0))
	return acos(clampf(cosine, -1.0, 1.0)) \
		<= deg_to_rad(half_angle_degrees) + angular_margin
