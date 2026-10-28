extends Node2D

# Loads the lobby scene to verify it parses. Usage:
# godot --headless --path <project> res://tools/loadlobby.tscn

func _ready() -> void:
	var res: Resource = load("res://scenes/lobby.tscn")
	if res == null:
		print("FAIL cannot load lobby.tscn")
		get_tree().quit(1)
		return
	var inst = (res as PackedScene).instantiate()
	if inst == null:
		print("FAIL cannot instantiate lobby")
		get_tree().quit(1)
		return
	print("lobby OK ", inst.get_class())
	inst.free()
	get_tree().quit(0)
