extends Node2D
class_name WebDamageNumber

var _time: float = 0.0
var _value: String = ""
var _color: Color = Color.WHITE
var _size: int = 22
var _drift: Vector2 = Vector2.ZERO
var _tilt: float = 0.0

const RISE := 48.0
const LIFE := 0.7
const MAX_ALIVE := 22      # keep the amount of floating numbers bounded


func _ready() -> void:
	z_index = 60
	add_to_group("damage_number")
	scale = Vector2(0.65, 0.65)
	var live := get_tree().get_nodes_in_group("damage_number")
	if live.size() > MAX_ALIVE:
		live[0].queue_free()


func setup(value: float, color: Color, font_size: int = 22) -> void:
	_value = _fmt(value)
	_color = color
	_size = font_size
	# every number drifts a little on its own so stacked hits stay readable
	_drift = Vector2(randf_range(-46.0, 46.0), randf_range(-16.0, 16.0))
	_tilt = randf_range(-0.13, 0.13)


# keep one decimal only when it matters, so 1.2 shows as "1.2" but 2.0 as "2"
static func _fmt(v: float) -> String:
	var r: float = roundf(v * 10.0) / 10.0
	if is_equal_approx(r, roundf(r)):
		return str(int(roundf(r)))
	return String.num(r, 1)


func _process(delta: float) -> void:
	_time += delta
	position += (Vector2(0.0, -RISE) + _drift) * delta
	_drift = _drift.move_toward(Vector2.ZERO, 60.0 * delta)
	rotation = _tilt
	scale = scale.lerp(Vector2.ONE, clampf(delta * 16.0, 0.0, 1.0))
	modulate.a = clampf(1.0 - _time / LIFE, 0.0, 1.0)
	if _time >= LIFE:
		queue_free()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(_value, HORIZONTAL_ALIGNMENT_LEFT, -1, _size).x
	var pos := Vector2(-w / 2.0, 0)
	# dark outline for readability over any background
	draw_string(font, pos + Vector2(1.5, 1.5), _value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _size, Color(0.0, 0.0, 0.0, 0.75))
	draw_string(font, pos, _value, HORIZONTAL_ALIGNMENT_LEFT, -1, _size, _color)
