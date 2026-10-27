extends ScrollContainer
class_name TouchScrollContainer

const DRAG_DEADZONE := 10.0

static var _touch_target: TouchScrollContainer

var _touch_start := Vector2.ZERO
var _touch_last := Vector2.ZERO
var _touch_index := -1
var _touch_dragging := false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_touch(event.position, event.index)
		elif _touch_target == self and event.index == _touch_index:
			if _touch_dragging:
				accept_event()
			_clear_touch()
	elif event is InputEventScreenDrag \
			and _touch_target == self and event.index == _touch_index:
		_update_touch_drag(event.position)


func _begin_touch(position: Vector2, index: int) -> void:
	if not is_visible_in_tree() or not get_global_rect().has_point(position):
		return
	if _touch_target != null and is_instance_valid(_touch_target) \
			and _touch_target.get_global_rect().get_area() \
				<= get_global_rect().get_area():
		return
	_touch_target = self
	_touch_index = index
	_touch_start = position
	_touch_last = position
	_touch_dragging = false


func _update_touch_drag(position: Vector2) -> void:
	if not _touch_dragging \
			and position.distance_to(_touch_start) < DRAG_DEADZONE:
		return
	_touch_dragging = true
	var delta := position - _touch_last
	var vertical_bar := get_v_scroll_bar()
	var horizontal_bar := get_h_scroll_bar()
	if vertical_bar.max_value > vertical_bar.page:
		vertical_bar.value = clampf(
			vertical_bar.value - delta.y, 0.0,
			vertical_bar.max_value - vertical_bar.page
		)
	if horizontal_bar.max_value > horizontal_bar.page:
		horizontal_bar.value = clampf(
			horizontal_bar.value - delta.x, 0.0,
			horizontal_bar.max_value - horizontal_bar.page
		)
	_touch_last = position
	accept_event()


func _clear_touch() -> void:
	_touch_target = null
	_touch_index = -1
	_touch_dragging = false
	_touch_start = Vector2.ZERO
	_touch_last = Vector2.ZERO
