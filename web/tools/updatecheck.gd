extends Node


func _ready() -> void:
	var menu: CanvasLayer = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var btn: Button = menu.get_node("UI/UpdateButton")
	print("before: visible=", btn.visible, " has_update=", Web.has_update())
	Web._check_version("test-version-xyz")
	await get_tree().process_frame
	print("after: visible=", btn.visible, " has_update=", Web.has_update(), " version=", Web.available_version)
	get_tree().quit(0 if btn.visible and Web.has_update() else 1)
