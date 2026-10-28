extends Button

const BACKPACK_ICON := preload("res://assets/icons/backpack.svg")


func _ready() -> void:
	custom_minimum_size = Vector2(64.0, 64.0)
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "Backpack"
	text = ""
	icon = BACKPACK_ICON
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_constant_override("icon_max_width", 34)
	add_theme_stylebox_override("normal", _style(
		Color(0.035, 0.075, 0.12, 0.96),
		Color(0.26, 0.58, 0.73, 0.76)
	))
	var hover := _style(Color(0.065, 0.14, 0.20, 1.0), Color(0.31, 0.77, 0.95))
	hover.shadow_color = Color(0.10, 0.56, 0.76, 0.25)
	hover.shadow_size = 8
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", _style(
		Color(0.08, 0.19, 0.25, 1.0), Color(0.31, 0.77, 0.95, 1.0)
	))
	add_theme_stylebox_override("disabled", _style(
		Color(0.025, 0.05, 0.08, 0.94), Color(0.12, 0.22, 0.29, 0.55)
	))
	add_theme_color_override("icon_normal_color", Color(0.72, 0.91, 1.0))
	add_theme_color_override("icon_hover_color", Color(0.92, 0.98, 1.0))
	add_theme_color_override("icon_pressed_color", Color(0.60, 0.86, 0.95))


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	return style
