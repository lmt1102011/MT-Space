extends Area2D
class_name EnemyBullet

@export var speed: float = 420.0
@export var lifetime: float = 2.5
@export var damage: int = 1
@export var burn: int = 0
@export var freeze: int = 0
@export var beam_length: float = 20.0
@export var beam_width: float = 5.0

var direction: Vector2 = Vector2.RIGHT
var network_visual: bool = false
var _beam: Sprite2D = null
var _beam_core: Sprite2D = null
var _pooled: bool = false
var _collision_shape: CollisionShape2D = null
var _shape_template: Shape2D = null

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const BEAM_TEX := preload("res://assets/beam.svg")
const BEAM_CORE_TEX := preload("res://assets/beam_core.svg")
# the size of the beam textures
const BEAM_W := 64.0
const BEAM_H := 16.0


func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	# the shot is an image: the outer bolt and a solid hot core
	_beam = Sprite2D.new()
	_beam.texture = BEAM_TEX
	_beam.modulate = _beam_color()
	_beam.scale = Vector2(beam_length / BEAM_W, beam_width / BEAM_H)
	add_child(_beam)
	_beam_core = Sprite2D.new()
	_beam_core.texture = BEAM_CORE_TEX
	_beam_core.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_beam_core.scale = Vector2(beam_length / BEAM_W,
		beam_width * 0.4 / BEAM_H)
	add_child(_beam_core)
	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision_shape != null and _collision_shape.shape != null:
		_collision_shape.shape = _collision_shape.shape.duplicate()
		_shape_template = _collision_shape.shape.duplicate()


func pool_activate() -> void:
	_pooled = false
	speed = 420.0
	lifetime = 2.5
	damage = 1
	burn = 0
	freeze = 0
	beam_length = 20.0
	beam_width = 5.0
	direction = Vector2.RIGHT
	network_visual = false
	if _collision_shape != null and _shape_template != null:
		_collision_shape.shape = _shape_template.duplicate()
	collision_layer = 16
	collision_mask = 5
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


func pool_deactivate() -> void:
	_pooled = true


func _beam_color() -> Color:
	if burn > 0:
		return Color(1.0, 0.35, 0.05, 1.0)
	if freeze > 0:
		return Color(0.4, 0.85, 1.0, 1.0)
	return Color(1.0, 0.15, 0.15, 1.0)


func _physics_process(delta: float) -> void:
	if _pooled:
		return
	rotation = direction.angle()
	_beam.modulate = _beam_color()
	_beam.scale = Vector2(beam_length / BEAM_W, beam_width / BEAM_H)
	_beam_core.scale = Vector2(beam_length / BEAM_W,
		beam_width * 0.4 / BEAM_H)
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_detonate()


func _on_body_entered(body: Node2D) -> void:
	if _pooled:
		return
	if network_visual:
		_detonate()
		return
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("apply_status"):
			body.apply_status(burn, freeze)
		Game.sfx("hit", -13.0, 0.85, 1.15)
		_detonate()
	elif body.is_in_group("obstacle"):
		_detonate()


func _detonate() -> void:
	if _pooled:
		return
	var boom := Pool.acquire(EXPLOSION_SCENE, get_tree().current_scene) as Explosion
	if boom == null:
		return
	boom.global_position = global_position
	Pool.release(self)


func _draw() -> void:
	pass
