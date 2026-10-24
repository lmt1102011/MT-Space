extends Node2D

var radius: float = 30.0
var burning: bool = false
var frozen: bool = false

const BURN_TEXTURE := preload("res://assets/burn_effect.png")
const FREEZE_TEXTURE := preload("res://assets/freeze_effect.png")

const FIRE_COLORS := [
	Color(1.0, 0.34, 0.18, 1.0),
	Color(1.0, 0.62, 0.22, 1.0),
	Color(1.0, 0.82, 0.38, 1.0),
	Color(0.92, 0.24, 0.12, 1.0),
	Color(1.0, 0.48, 0.12, 1.0),
]

const FIRE_SCALES := [0.12, 0.085, 0.105, 0.075, 0.095]

var _burn_sprites: Array[Sprite2D] = []
var _freeze_sprite: Sprite2D


func _ready() -> void:
	for i in FIRE_COLORS.size():
		var fire_sprite := Sprite2D.new()
		fire_sprite.texture = BURN_TEXTURE
		fire_sprite.scale = Vector2.ONE * FIRE_SCALES[i]
		fire_sprite.modulate = FIRE_COLORS[i]
		fire_sprite.z_index = 1
		fire_sprite.visible = false
		add_child(fire_sprite)
		_burn_sprites.append(fire_sprite)

	_freeze_sprite = Sprite2D.new()
	_freeze_sprite.texture = FREEZE_TEXTURE
	_freeze_sprite.scale = Vector2.ONE * ((radius * 2.0 + 42.0) / 192.0)
	_freeze_sprite.z_index = 2
	_freeze_sprite.visible = false
	add_child(_freeze_sprite)


func set_status(is_burning: bool, is_frozen: bool) -> void:
	if burning == is_burning and frozen == is_frozen:
		return
	var started_burning := is_burning and not burning
	burning = is_burning
	frozen = is_frozen
	if started_burning:
		_scatter_fire_sprites()
	for fire_sprite in _burn_sprites:
		fire_sprite.visible = burning
	_freeze_sprite.visible = frozen


func _scatter_fire_sprites() -> void:
	for i in _burn_sprites.size():
		var angle := TAU * float(i) / float(_burn_sprites.size()) + randf_range(-0.35, 0.35)
		var distance := randf_range(radius * 0.62, radius * 1.08)
		_burn_sprites[i].position = Vector2.from_angle(angle) * distance