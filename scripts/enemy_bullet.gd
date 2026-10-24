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
	var core := Sprite2D.new()
	core.texture = BEAM_CORE_TEX
	core.modulate = Color(1.0, 1.0, 1.0, 0.6)
	core.scale = Vector2(beam_length / BEAM_W, beam_width * 0.4 / BEAM_H)
	add_child(core)


func _beam_color() -> Color:
	if burn > 0:
		return Color(1.0, 0.35, 0.05, 1.0)
	if freeze > 0:
		return Color(0.4, 0.85, 1.0, 1.0)
	return Color(1.0, 0.15, 0.15, 1.0)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_detonate()


func _on_body_entered(body: Node2D) -> void:
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
	var boom := EXPLOSION_SCENE.instantiate()
	boom.global_position = global_position
	get_tree().current_scene.add_child(boom)
	queue_free()


func _draw() -> void:
	pass
