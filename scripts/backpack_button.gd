extends Button

const BACKPACK_ICON := preload("res://assets/icons/backpack.svg")


func _ready() -> void:
	custom_minimum_size = Vector2(64.0, 64.0)
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "Backpack"
	text = ""
	icon = BACKPACK_ICON
	expand_icon = true
