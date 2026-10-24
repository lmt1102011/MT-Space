extends RefCounted
class_name WebViewCull

# Distance (world units) kept beyond the camera rect so things do not pop in
# right at the screen edge.
const MARGIN := 220.0


static var _base: Vector2 = Vector2.ZERO


static func _base_size() -> Vector2:
	if _base == Vector2.ZERO:
		_base = Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
	return _base


# World-space half extent of the camera view (plus an optional margin).
static func view_half(node: Node2D, margin: float = 0.0) -> Vector2:
	var fallback := Vector2(900, 600)
	var vp := node.get_viewport()
	if vp == null:
		return fallback + Vector2(margin, margin)
	var cam := vp.get_camera_2d()
	if cam == null:
		return fallback + Vector2(margin, margin)
	var zoom := cam.zoom
	if zoom.x <= 0.0 or zoom.y <= 0.0:
		zoom = Vector2.ONE

	var px := vp.get_visible_rect().size
	# world units per screen pixel (window stretch + camera zoom)
	var fs := vp.get_final_transform().get_scale()
	var half := fallback
	if absf(fs.x) > 0.01 and absf(fs.y) > 0.01:
		half = Vector2(px.x / (2.0 * absf(fs.x)), px.y / (2.0 * absf(fs.y)))
	# never cull less than the base resolution can possibly show
	var safe := Vector2(_base_size().x / (2.0 * zoom.x), _base_size().y / (2.0 * zoom.y))
	half = Vector2(maxf(half.x, safe.x), maxf(half.y, safe.y))
	return half + Vector2(margin, margin)


# True when the node is inside (or near) the active camera's view.
static func is_on_screen(node: Node2D, margin: float = MARGIN) -> bool:
	var vp := node.get_viewport()
	if vp == null:
		return true
	var cam := vp.get_camera_2d()
	if cam == null:
		return true
	var half := view_half(node, margin)
	var c := cam.get_screen_center_position()
	return absf(node.global_position.x - c.x) <= half.x \
		and absf(node.global_position.y - c.y) <= half.y
