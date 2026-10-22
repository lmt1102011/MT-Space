extends Node2D

# Loads every .gd file in the project and reports parse errors.
# Usage: godot --headless --path <project> res://tools/loadall.tscn

func _ready() -> void:
	var bad := 0
	var count := 0
	for path in _all_scripts("res://scripts"):
		count += 1
		var res: Resource = load(path)
		if res == null:
			bad += 1
			print("FAIL  cannot load ", path)
	for path in _all_scripts("res://tools"):
		if path.ends_with("loadall.gd"):
			continue
		count += 1
		var res2: Resource = load(path)
		if res2 == null:
			bad += 1
			print("FAIL  cannot load ", path)
	print("checked %d scripts, %d failed" % [count, bad])
	get_tree().quit(1 if bad > 0 else 0)


func _all_scripts(root: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if dir.current_is_dir():
			if f != ".godot" and not f.begins_with("."):
				out.append_array(_all_scripts(root + "/" + f))
		elif f.ends_with(".gd"):
			out.append(root + "/" + f)
		f = dir.get_next()
	dir.list_dir_end()
	return out
