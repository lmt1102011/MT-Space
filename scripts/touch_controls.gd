extends Control

# The touch controls, they only show up when the screen is touched.
#
# On the left a small stick moves the ship, on the right a button shoots. The
# stick is drawn where the finger went down, so the player does not have to
# look at it.

# how far the finger may go from the middle of the stick
const STICK_RADIUS := 70.0
# the shoot button is this big
const FIRE_RADIUS := 56.0
# how far from the edge of the screen the controls sit
const EDGE := 150.0

var _stick_touch: int = -1
var _fire_touch: int = -1
var _stick_center: Vector2 = Vector2.ZERO
var _stick_pos: Vector2 = Vector2.ZERO
var _fire_pos: Vector2 = Vector2.ZERO
var _visible: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize_home()
	get_viewport().size_changed.connect(_resize_home)
	visible = false


# The controls sit in the bottom corners, they follow the size of the window.
func _resize_home() -> void:
	var size := get_viewport_rect().size
	if _stick_touch == -1:
		_stick_center = Vector2(EDGE, size.y - EDGE)
		_stick_pos = _stick_center
	if _fire_touch == -1:
		_fire_pos = Vector2(size.x - EDGE, size.y - EDGE)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		# a mouse works as a finger too, that is handy on a desktop browser
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_on_touch(_touch_from_mouse(mb.pressed, mb.position, 0))


func _touch_from_mouse(pressed: bool, pos: Vector2, index: int) -> InputEventScreenTouch:
	var t := InputEventScreenTouch.new()
	t.pressed = pressed
	t.position = pos
	t.index = index
	return t


func _on_touch(t: InputEventScreenTouch) -> void:
	if t.pressed:
		_visible = true
		visible = true
		if t.position.x < get_viewport_rect().size.x * 0.5:
			if _stick_touch == -1:
				_stick_touch = t.index
				_stick_center = t.position
				_stick_pos = t.position
		else:
			if _fire_touch == -1:
				_fire_touch = t.index
				_fire_pos = t.position
	else:
		if t.index == _stick_touch:
			_stick_touch = -1
			_resize_home()
		elif t.index == _fire_touch:
			_fire_touch = -1
			_resize_home()
	queue_redraw()


func _on_drag(d: InputEventScreenDrag) -> void:
	if d.index == _stick_touch:
		_stick_pos = d.position
		queue_redraw()


# The direction the stick points in, for the ship.
func move_direction() -> Vector2:
	if _stick_touch == -1:
		return Vector2.ZERO
	var delta := _stick_pos - _stick_center
	if delta.length() < 8.0:
		return Vector2.ZERO
	return delta / STICK_RADIUS


# True while the shoot button is held down.
func is_shooting() -> bool:
	return _fire_touch != -1


# Where the player is aiming, the finger on the fire button.
func aim_position() -> Vector2:
	return _fire_pos


func _draw() -> void:
	if not _visible:
		return
	# the stick
	var base := _stick_center
	var knob := _stick_pos
	draw_circle(base, STICK_RADIUS, Color(0.1, 0.14, 0.16, 0.35))
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 32, Color(0.6, 0.8, 0.9, 0.35), 3.0)
	var off := knob - base
	if off.length() > STICK_RADIUS:
		off = off.normalized() * STICK_RADIUS
	draw_circle(base + off, 26.0, Color(0.45, 0.85, 1.0, 0.5))
	# the shoot button
	var fire := _fire_pos
	draw_circle(fire, FIRE_RADIUS, Color(0.9, 0.35, 0.2, 0.4 if _fire_touch != -1 else 0.22))
	draw_arc(fire, FIRE_RADIUS, 0.0, TAU, 32, Color(1.0, 0.6, 0.4, 0.5), 3.0)
