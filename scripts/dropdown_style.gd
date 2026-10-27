extends RefCounted

const CYAN := Color(0.34, 0.84, 0.96)


static func apply(option: OptionButton) -> void:
	if option.has_meta("sci_fi_dropdown_styled"):
		return
	option.set_meta("sci_fi_dropdown_styled", true)
	option.custom_minimum_size.y = maxf(option.custom_minimum_size.y, 40.0)
	option.add_theme_font_size_override("font_size", 14)
	option.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	option.add_theme_color_override("font_hover_color", Color.WHITE)
	option.add_theme_color_override("font_pressed_color", Color.WHITE)
	option.add_theme_color_override("font_disabled_color", Color(0.48, 0.59, 0.68))
	var normal := _stylebox(
		Color(0.045, 0.09, 0.15, 0.96),
		Color(0.24, 0.52, 0.68, 0.78)
	)
	normal.content_margin_left = 12
	normal.content_margin_right = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.07, 0.15, 0.22, 1.0)
	hover.border_color = CYAN
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.06, 0.13, 0.19, 1.0)
	pressed.border_color = CYAN
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.035, 0.065, 0.10, 0.9)
	disabled.border_color = Color(0.17, 0.31, 0.39, 0.55)
	option.add_theme_stylebox_override("normal", normal)
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("pressed", pressed)
	option.add_theme_stylebox_override("focus", hover)
	option.add_theme_stylebox_override("disabled", disabled)
	var popup := option.get_popup()
	var popup_panel := _stylebox(
		Color(0.025, 0.05, 0.085, 0.99),
		Color(0.24, 0.52, 0.68, 0.9)
	)
	popup.add_theme_stylebox_override("panel", popup_panel)
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_color_override("font_color", Color(0.82, 0.9, 0.98))
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_pressed_color", CYAN)
	popup.add_theme_font_size_override("font_size", 14)


static func _stylebox(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style
