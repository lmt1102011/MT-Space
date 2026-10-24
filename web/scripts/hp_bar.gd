extends Node2D
class_name WebHpBar

# Lightweight world-space HP bar.
# The bar and the fill are two sprites sharing one tiny white texture, so
# nothing is re-recorded when the health changes - only the fill is resized.

var ratio: float = 1.0
var fill_color: Color = Color(0.35, 0.9, 0.4, 1.0)

const BAR_WIDTH := 50.0
const BAR_HEIGHT := 6.0
const Ba_COLOR := Color(0.05, 0.07, 0.06, 0.85)

static var _pixel: ImageTexture = null


static func _pixel_tex() -> ImageTexture:
	if _pixel == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_pixel = ImageTexture.create_from_image(img)
	return _pixel


var _bg: Sprite2D = null
var _fill: Sprite2D = null


func _ready() -> void:
	var tex := _pixel_tex()
	_bg = Sprite2D.new()
	_bg.texture = tex
	_bg.centered = false
	_bg.modulate = Ba_COLOR
	_bg.position = Vector2(-BAR_WIDTH * 0.5, 0.0)
	_bg.scale = Vector2(BAR_WIDTH, BAR_HEIGHT)
	add_child(_bg)
	_fill = Sprite2D.new()
	_fill.texture = tex
	_fill.centered = false
	_fill.modulate = fill_color
	_fill.position = Vector2(-BAR_WIDTH * 0.5 + 1.0, 1.0)
	add_child(_fill)
	_apply()


func set_ratio(value: float, color: Color = Color(0, 0, 0, 0)) -> void:
	var t := clampf(value, 0.0, 1.0)
	if absf(t - ratio) < 0.001 and color.a > 0.0 and color == fill_color:
		return
	ratio = t
	if color.a > 0.0:
		fill_color = color
	_apply()


func _apply() -> void:
	if _fill == null:
		return
	_fill.modulate = fill_color
	_fill.scale = Vector2(maxf((BAR_WIDTH - 2.0) * ratio, 0.0), BAR_HEIGHT - 2.0)
