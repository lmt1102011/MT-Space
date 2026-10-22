extends Node2D

# The little ghost that a dead player becomes while watching somebody else.
#
# It is a small circle with two eyes that floats around the player that is
# being watched, with the name of the dead player underneath.

# how big the circle is
const RADIUS := 7.0
# how far the ghost floats around the player it watches
const ORBIT := 26.0
# how fast it goes around
const SPIN := 1.1
# how high the name sits under the ghost
const NAME_OFFSET := 16.0

var ghost_name: String = ""
var _t: float = 0.0
var _target: Node2D = null
var _label: Label = null


func _ready() -> void:
	_t = randf() * TAU
	_label = Label.new()
	_label.name = "GhostName"
	_label.text = ghost_name
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.75))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_label.add_theme_constant_override("outline_size", 2)
	_label.size = Vector2(80, 12)
	_label.position = Vector2(-40, NAME_OFFSET)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


# The player that is being watched, the ghost floats around it.
func set_target(target: Node2D) -> void:
	_target = target


func set_name_text(text: String) -> void:
	ghost_name = text
	if _label:
		_label.text = text


func _process(delta: float) -> void:
	_t += delta * SPIN
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position + Vector2.from_angle(_t) * ORBIT
	else:
		global_position += Vector2.from_angle(_t) * 12.0 * delta
	queue_redraw()


func _draw() -> void:
	# the little body
	draw_circle(Vector2.ZERO, RADIUS, Color(0.75, 0.88, 1.0, 0.32))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color(0.8, 0.92, 1.0, 0.55), 1.5)
	# the two eyes
	var eye := Vector2(-2.6, -1.2)
	var eye2 := Vector2(2.6, -1.2)
	draw_circle(eye, 1.7, Color(0.06, 0.08, 0.1, 0.9))
	draw_circle(eye2, 1.7, Color(0.06, 0.08, 0.1, 0.9))
	# a little shine on top
	draw_circle(Vector2(0.0, -RADIUS + 2.0), 2.0, Color(1, 1, 1, 0.25))
