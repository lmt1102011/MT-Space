extends Area2D
class_name BossMissile

@export var speed: float = 195.0
@export var turn_rate: float = 0.85
@export var lifetime: float = 7.0
@export var damage: int = 5

var direction := Vector2.RIGHT
var network_visual := false

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")


func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	if network_visual:
		collision_layer = 0
		collision_mask = 0


func _physics_process(delta: float) -> void:
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
	if network_visual:
		return
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_detonate()
	elif body.is_in_group("obstacle"):
		_detonate()


func _detonate() -> void:
	var explosion := EXPLOSION_SCENE.instantiate() as Node2D
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)
	queue_free()
