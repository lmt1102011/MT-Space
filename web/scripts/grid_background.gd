extends Node2D

# The world grid is a single image that repeats over the whole map, so the
# background costs one draw call and needs no per frame script work at all.

const GRID_TEX := preload("res://assets/grid.svg")

# the world is 5400 x 3200, the texture covers 4 x 4 cells of 160px
const WORLD_SIZE := Vector2(5400.0, 3200.0)
const WORLD_ORIGIN := Vector2(-2700.0, -1600.0)

var _sprite: Sprite2D = null


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = GRID_TEX
	_sprite.centered = false
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(Vector2.ZERO, WORLD_SIZE)
	_sprite.position = WORLD_ORIGIN
	_sprite.modulate = Color(1, 1, 1, 1)
	add_child(_sprite)
