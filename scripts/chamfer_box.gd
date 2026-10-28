extends StyleBox

# A StyleBox with a chamfered (cut) top-left corner, used for the PLAY
# button in the lobby to match the reference drawing.

var bg_color := Color(0.93, 0.93, 0.93, 1.0)
var border_color := Color(0.0, 0.0, 0.0, 1.0)
var border_width := 2.0
var chamfer := 30.0
var pad := Vector2(22.0, 14.0)


func _get_minimum_size() -> Vector2:
	return Vector2(pad.x * 2.0 + border_width * 2.0,
		pad.y * 2.0 + border_width * 2.0)


func _get_content_margin(side: Side) -> float:
	match side:
		SIDE_LEFT, SIDE_RIGHT:
			return pad.x + border_width
		SIDE_TOP, SIDE_BOTTOM:
			return pad.y + border_width
	return 0.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var p := rect.position
	var pts := PackedVector2Array([
		p + Vector2(chamfer, 0.0),
		p + Vector2(rect.size.x, 0.0),
		p + Vector2(rect.size.x, rect.size.y),
		p + Vector2(0.0, rect.size.y),
		p + Vector2(0.0, chamfer),
		p + Vector2(chamfer, 0.0),
	])
	var cols := PackedColorArray()
	for i in pts.size():
		cols.append(bg_color)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, pts, cols)
	if border_width > 0.0:
		var bcols := PackedColorArray()
		for i in pts.size():
			bcols.append(border_color)
		RenderingServer.canvas_item_add_polyline(
			to_canvas_item, pts, bcols, border_width, true)
