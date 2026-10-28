extends Node2D

var radius: float = 30.0
var burning: bool = false
var frozen: bool = false

const BURN_TEXTURE := preload("res://assets/flame_effect.svg")
const FREEZE_TEXTURE := preload("res://assets/freeze_effect.png")
const FIRE_ANGLES := [-2.5, -1.75, -1.0, 2.75, 0.25]
const FIRE_COLORS := [
	Color(1.0, 0.66, 0.34, 0.9),
	Color(1.0, 0.46, 0.2, 0.84),
	Color(1.0, 0.78, 0.42, 0.88),
	Color(1.0, 0.52, 0.24, 0.86),
	Color(1.0, 0.7, 0.32, 0.9),
]
const FIRE_SCALE_VARIANTS := [0.82, 0.94, 0.76, 0.88, 0.8]

var _burn_sprites: Array[Sprite2D] = []
var _burn_origins: Array[Vector2] = []
var _burn_scales: Array[Vector2] = []
var _burn_phases: Array[float] = []
var _freeze_sprite: Sprite2D
var _anim_time: float = 0.0


func _ready() -> void:
	for i in FIRE_ANGLES.size():
		var fire_sprite := Sprite2D.new()
		fire_sprite.texture = BURN_TEXTURE
		fire_sprite.modulate = FIRE_COLORS[i]
		fire_sprite.z_index = 1
		fire_sprite.visible = false
		add_child(fire_sprite)
		_burn_sprites.append(fire_sprite)
		_burn_phases.append(float(i) * 1.13)

	_freeze_sprite = Sprite2D.new()
	_freeze_sprite.texture = FREEZE_TEXTURE
	_freeze_sprite.z_index = 2
	_freeze_sprite.visible = false
	add_child(_freeze_sprite)
	_update_effect_layout()
	set_process(false)


func set_radius(value: float) -> void:
	radius = maxf(value, 1.0)
	if is_node_ready():
		_update_effect_layout()


func set_status(is_burning: bool, is_frozen: bool) -> void:
	if burning == is_burning and frozen == is_frozen:
		return
	burning = is_burning
	frozen = is_frozen
	for fire_sprite in _burn_sprites:
		fire_sprite.visible = burning
	_freeze_sprite.visible = frozen
	set_process(burning)


func _update_effect_layout() -> void:
	_burn_origins.clear()
	_burn_scales.clear()
	var texture_scale := radius / 110.0
	for i in _burn_sprites.size():
		var angle: float = FIRE_ANGLES[i]
		var fire_sprite := _burn_sprites[i]
		var scale_factor: float = FIRE_SCALE_VARIANTS[i]
		fire_sprite.position = Vector2.from_angle(angle) * radius * 0.68
		fire_sprite.rotation = clampf(cos(angle) * 0.16, -0.16, 0.16)
		fire_sprite.scale = Vector2(texture_scale, texture_scale * scale_factor)
		_burn_origins.append(fire_sprite.position)
		_burn_scales.append(fire_sprite.scale)
	_freeze_sprite.scale = Vector2.ONE * ((radius * 2.0 + 42.0) / 192.0)


func _process(delta: float) -> void:
	_anim_time += delta
	for i in _burn_sprites.size():
		var phase: float = _anim_time * 7.0 + _burn_phases[i]
		var fire_sprite := _burn_sprites[i]
		fire_sprite.position = _burn_origins[i] + Vector2(
			sin(phase * 0.65) * radius * 0.025,
			-sin(phase) * radius * 0.075
		)
		fire_sprite.scale = Vector2(
			_burn_scales[i].x * (0.94 + sin(phase) * 0.08),
			_burn_scales[i].y * (0.9 + cos(phase) * 0.1)
		)
