extends Control

# The controls for a phone: two sticks.
#
# The left stick moves the ship, the right stick aims and shoots at the same
# time. The sticks are drawn where the finger went down, so the player does
# not have to look at them.
#
# On a computer the sticks are hidden, the keyboard does the job.

# how big the sticks are
const STICK_RADIUS := 68.0
# how far the finger may go from the middle of the stick
const MAX_OFFSET := 66.0
# a small dead zone keeps tiny finger movements from turning into movement
const DEAD_ZONE := 16.0
# how far from the edge of the screen the sticks sit
const EDGE := 140.0

var _move_touch: int = -1
var _aim_touch: int = -1
var _move_center: Vector2 = Vector2.ZERO
var _move_pos: Vector2 = Vector2.ZERO
var _aim_center: Vector2 = Vector2.ZERO
var _aim_pos: Vector2 = Vector2.ZERO
var _last_aim_dir: Vector2 = Vector2.RIGHT
# true when the player touched the screen, the sticks show up then
var _touched: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize_home()
	get_viewport().size_changed.connect(_resize_home)
	visible = false


# The sticks sit in the bottom corners, they follow the size of the window.
func _resize_home() -> void:
	var size := get_viewport_rect().size
	if _move_touch == -1:
		_move_center = Vector2(EDGE, size.y - EDGE)
		_move_pos = _move_center
	if _aim_touch == -1:
		_aim_center = Vector2(size.x - EDGE, size.y - EDGE)
		_aim_pos = _aim_center
	queue_redraw()


func _input(event: InputEvent) -> void:
	# on a computer the keyboard and the mouse do the job, the sticks are only
	# for a device with a touchscreen
	if not Game.is_mobile_mode():
		return
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _on_touch(t: InputEventScreenTouch) -> void:
	if t.pressed:
		# Touches on the HUD belong to the button/panel, never to a stick.
		# Without this, the left half of the screen also captures Settings.
		if _is_ui_touch(t.position):
			return
		_touched = true
		visible = true
		# the left half moves, the right half aims and shoots
		var vp := get_viewport_rect().size
		if t.position.x < vp.x * 0.5:
			if _move_touch == -1:
				_move_touch = t.index
				_move_center = t.position
				_move_pos = t.position
		else:
			if _aim_touch == -1:
				_aim_touch = t.index
				_aim_center = t.position
				_aim_pos = t.position
				var direction := _stick_vector(_aim_pos - _aim_center)
				if direction != Vector2.ZERO:
					_last_aim_dir = direction
	else:
		if t.index == _move_touch:
			_move_touch = -1
			_resize_home()
		elif t.index == _aim_touch:
			_aim_touch = -1
			_resize_home()
	queue_redraw()


func _on_drag(d: InputEventScreenDrag) -> void:
	if d.index == _move_touch:
		_move_pos = d.position
	elif d.index == _aim_touch:
		_aim_pos = d.position
		var direction := _stick_vector(_aim_pos - _aim_center)
		if direction != Vector2.ZERO:
			_last_aim_dir = direction
	queue_redraw()


# The direction the left stick points in, for the ship.
func move_direction() -> Vector2:
	if _move_touch == -1:
		return Vector2.ZERO
	return _stick_vector(_move_pos - _move_center)


# The direction the right stick points in, that is where the ship aims.
func aim_direction() -> Vector2:
	if _aim_touch == -1:
		return Vector2.ZERO
	return _stick_vector(_aim_pos - _aim_center)


func last_aim_direction() -> Vector2:
	return _last_aim_dir


# The right stick shoots as long as it is held down.
func is_shooting() -> bool:
	return _aim_touch != -1


# The place the ship aims at, the finger on the right stick.
func aim_position() -> Vector2:
	return _aim_pos


# True when the sticks have to be shown all the time, that is the phone mode.
func always_visible() -> bool:
	return Game.is_mobile_mode()


func _is_ui_touch(position: Vector2) -> bool:
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if hud == null:
		return false
	var settings := hud.get_node_or_null("SettingsButton") as Control
	if settings != null and settings.get_global_rect().has_point(position):
		return true
	var panel := hud.get_node_or_null("SettingsPanel") as Control
	return panel != null and panel.visible and panel.get_global_rect().has_point(position)


func _stick_vector(offset: Vector2) -> Vector2:
	if offset.length() < DEAD_ZONE:
		return Vector2.ZERO
	if offset.length() > MAX_OFFSET:
		offset = offset.normalized() * MAX_OFFSET
	return offset / MAX_OFFSET


func _process(_delta: float) -> void:
	# in the phone mode the sticks are always there
	if always_visible() and not visible:
		visible = true


func _draw() -> void:
	if not visible:
		return
	_draw_stick(_move_center, _move_pos, Color(0.45, 0.85, 1.0), _move_touch != -1)
	_draw_stick(_aim_center, _aim_pos, Color(1.0, 0.6, 0.35), _aim_touch != -1)


func _draw_stick(center: Vector2, knob: Vector2, tint: Color, held: bool) -> void:
	draw_circle(center, STICK_RADIUS, Color(0.1, 0.14, 0.16, 0.35))
	draw_arc(center, STICK_RADIUS, 0.0, TAU, 32, Color(tint.r, tint.g, tint.b, 0.35), 3.0)
	var off := knob - center
	if off.length() > MAX_OFFSET:
		off = off.normalized() * MAX_OFFSET
	draw_circle(center + off, 26.0, Color(tint.r, tint.g, tint.b, 0.5 if held else 0.35))
