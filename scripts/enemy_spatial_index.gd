extends RefCounted

const CELL_SIZE := 128.0
const POSITION_MARGIN := 32.0

static var _tree_id: int = 0
static var _physics_frame: int = -1
static var _cells_by_group: Dictionary = {}


static func query_rect(tree: SceneTree, rect: Rect2, padding: float = 0.0) -> Array:
	return query_group_rect(tree, "enemy", rect, padding)


static func query_group_rect(tree: SceneTree, group: String,
		rect: Rect2, padding: float = 0.0) -> Array:
	_ensure_index(tree, group)
	var area := rect.abs().grow(padding + POSITION_MARGIN)
	var first := Vector2i(
		floori(area.position.x / CELL_SIZE),
		floori(area.position.y / CELL_SIZE)
	)
	var last := Vector2i(
		floori(area.end.x / CELL_SIZE),
		floori(area.end.y / CELL_SIZE)
	)
	var cells: Dictionary = _cells_by_group.get(group, {})
	var result: Array = []
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var bucket: Array = cells.get(Vector2i(x, y), [])
			result.append_array(bucket)
	return result


static func _ensure_index(tree: SceneTree, group: String) -> void:
	var tree_id := tree.get_instance_id()
	var frame := Engine.get_physics_frames()
	if tree_id != _tree_id or frame != _physics_frame:
		_tree_id = tree_id
		_physics_frame = frame
		_cells_by_group.clear()
	if _cells_by_group.has(group):
		return
	var cells: Dictionary = {}
	for candidate in tree.get_nodes_in_group(group):
		var enemy := candidate as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var cell := Vector2i(
			floori(enemy.global_position.x / CELL_SIZE),
			floori(enemy.global_position.y / CELL_SIZE)
		)
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(enemy)
	_cells_by_group[group] = cells
