extends Area2D
class_name BossMissile

@export var speed: float = 195.0
@export var turn_rate: float = 0.85
@export var lifetime: float = 7.0
@export var damage: int = 5

var direction := Vector2.RIGHT
var network_visual := false
var _pooled: bool = false

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")


func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	if network_visual:
		collision_layer = 0
		collision_mask = 0


func pool_activate() -> void:
	_pooled = false
	speed = 195.0
	turn_rate = 0.85
	lifetime = 7.0
	damage = 5
	direction = Vector2.RIGHT
	network_visual = false
	collision_layer = 16
	collision_mask = 5
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


func pool_deactivate() -> void:
	_pooled = true


func _physics_process(delta: float) -> void:
	if _pooled:
		return
	var target := Net.target_player(global_position)
	if target != null:
		var to_target := target.global_position - global_position
		if not to_target.is_zero_approx():
			var turn := angle_difference(direction.angle(), to_target.angle())
			direction = direction.rotated(clampf(turn,
				-turn_rate * delta, turn_rate * delta)).normalized()
		if network_visual and to_target.length() <= 14.0:
			_detonate()
			return
	rotation = direction.angle()
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_detonate()


func _on_body_entered(body: Node2D) -> void:
	if _pooled:
		return
	if network_visual:
		return
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_detonate()
	elif body.is_in_group("obstacle"):
		_detonate()


func _detonate() -> void:
	if _pooled:
		return
	var explosion := Pool.acquire(EXPLOSION_SCENE,
		get_tree().current_scene) as Explosion
	if explosion == null:
		return
	explosion.global_position = global_position
	Pool.release(self)
