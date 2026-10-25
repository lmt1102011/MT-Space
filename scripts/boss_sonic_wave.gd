extends Node2D

@export var max_radius: float = 520.0
@export var duration: float = 0.85
@export var player_damage: int = 3
@export var shape_damage: int = 2
@export var stun_duration: float = 2.0
@export var visual_only: bool = false

var _elapsed: float = 0.0
var _scan_timer: float = 0.0
var _previous_radius: float = 0.0
var _hit_players: Dictionary = {}
var _hit_enemies: Dictionary = {}
var _players: Array = []
var _enemies: Array = []
var _ring: Sprite2D

const RING_TEX := preload("res://assets/charge_ring.svg")


func _ready() -> void:
	_players = get_tree().get_nodes_in_group("player")
	_enemies = get_tree().get_nodes_in_group("enemy")
	_ring = Sprite2D.new()
	_ring.texture = RING_TEX
	_ring.modulate = Color(0.55, 0.88, 1.0, 0.78)
	add_child(_ring)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var radius := max_radius * clampf(_elapsed / duration, 0.0, 1.0)
	_ring.scale = Vector2.ONE * (radius * 2.0 / 120.0)
	_ring.modulate.a = 0.78 * (1.0 - clampf(_elapsed / duration, 0.0, 1.0) * 0.45)
	if not visual_only:
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_scan_timer = 0.04
			_apply_crossing_hits(_previous_radius, radius)
	_previous_radius = radius
	if _elapsed >= duration:
		queue_free()


func _apply_crossing_hits(previous_radius: float, current_radius: float) -> void:
	for candidate in _players:
		var player := candidate as Node2D
		if player == null or not is_instance_valid(player):
			continue
		if player.get("_dead") == true or player.get("net_alive") == false:
			continue
		var player_id := player.get_instance_id()
		if _hit_players.has(player_id):
			continue
		var offset := player.global_position - global_position
		if not _crossed_ring(offset.length(), 18.0, previous_radius, current_radius):
			continue
		_hit_players[player_id] = true
		var direction := offset.normalized()
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		if player.has_method("take_damage"):
			player.take_damage(player_damage)
		if player.has_method("apply_knockback"):
			player.apply_knockback(direction * 460.0, stun_duration)

	for candidate in _enemies:
		var enemy := candidate as Node2D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_in_group("boss"):
			continue
		var enemy_id := enemy.get_instance_id()
		if _hit_enemies.has(enemy_id):
			continue
		var offset := enemy.global_position - global_position
		var body_radius := 24.0
		if enemy.is_in_group("shape_enemy"):
			body_radius = maxf(float(enemy.get("radius")), 18.0)
		if not _crossed_ring(offset.length(), body_radius, previous_radius, current_radius):
			continue
		_hit_enemies[enemy_id] = true
		var direction := offset.normalized()
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		if enemy.has_method("apply_push"):
			enemy.apply_push(direction * 300.0)
		if enemy.is_in_group("shape_enemy"):
			if enemy.has_method("take_damage"):
				enemy.take_damage(shape_damage)


func _crossed_ring(distance: float, body_radius: float,
		previous_radius: float, current_radius: float) -> bool:
	return distance + body_radius >= previous_radius \
		and distance - body_radius <= current_radius
