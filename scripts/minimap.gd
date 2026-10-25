extends Control

@export var world_half: Vector2 = Vector2(2700.0, 1600.0)
@export var map_size: Vector2 = Vector2(220.0, 130.0)

const COL_PLAYER := Color(1.0, 0.95, 0.2)
const COL_SHAPE := Color(0.4, 0.9, 0.6)
const COL_SHOOTER := Color(1.0, 0.2, 0.2)
const COL_DOUBLE := Color(1.0, 0.6, 0.15)
const COL_RAILGUN := Color(0.68, 0.45, 1.0)
const COL_CHARGER := Color(0.4, 1.0, 0.2)
const COL_ELITE := Color(1.0, 0.85, 0.25)
const COL_BOSS := Color(1.0, 0.25, 0.35)
const COL_BEAM := Color(0.35, 0.82, 1.0)
const COL_Ba := Color(0.05, 0.09, 0.08, 0.8)
const COL_BORDER := Color(0.3, 0.5, 0.45, 1.0)
const COL_OBSTACLE := Color(0.25, 0.4, 0.36, 1.0)
const COL_ORB := Color(0.3, 1.0, 0.5)

const REFRESH := 0.066       # ~15fps redraw
const RESCAN := 0.25         # group lists are reused between scans

const FRAME_TEX := preload("res://assets/minimap_frame.svg")

var _acc: float = 0.0
var _scan_acc: float = 0.0
var _obstacles: Array = []
var _orbs: Array = []
var _enemies: Array = []
var _frame: TextureRect = null


func _ready() -> void:
	custom_minimum_size = map_size
	# the panel itself is an image, only the dots are drawn.
	# it has to sit behind the parent's own drawing, otherwise it would cover
	# the dots and dim them
	_frame = TextureRect.new()
	_frame.texture = FRAME_TEX
	_frame.position = Vector2.ZERO
	_frame.size = map_size
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.show_behind_parent = true
	add_child(_frame)
	set_process(true)
	_scan()


func _world_to_map(p: Vector2) -> Vector2:
	var n := p / (world_half * 2.0) + Vector2(0.5, 0.5)
	return Vector2(n.x * map_size.x, n.y * map_size.y)


func _scan() -> void:
	_obstacles = get_tree().get_nodes_in_group("obstacle")
	_orbs = get_tree().get_nodes_in_group("xp_orb")
	_enemies = get_tree().get_nodes_in_group("enemy")


func _process(delta: float) -> void:
	_scan_acc -= delta
	if _scan_acc <= 0.0:
		_scan_acc = RESCAN
		_scan()
	_acc -= delta
	if _acc <= 0.0:
		_acc = REFRESH
		queue_redraw()


func _draw() -> void:
	# the panel is a texture, only the moving dots are drawn here
	for o in _obstacles:
		if is_instance_valid(o):
			draw_rect(Rect2(_world_to_map(o.global_position) - Vector2(3, 2), Vector2(6, 4)), COL_OBSTACLE)

	for orb in _orbs:
		if is_instance_valid(orb):
			draw_circle(_world_to_map(orb.global_position), 1.5, COL_ORB)

	# every enemy is listed, even the ones culled from the world view
	for e in _enemies:
		if not is_instance_valid(e):
			continue
		var p := _world_to_map(e.global_position)
		if e.is_in_group("boss"):
			draw_circle(p, 4.5, COL_BOSS)
		elif e.is_in_group("beam_enemy"):
			draw_circle(p, 3.0, COL_BEAM)
		elif e.is_in_group("elite"):
			draw_circle(p, 3.6, COL_ELITE)
		elif e.is_in_group("charger_enemy"):
			draw_circle(p, 3.2, COL_CHARGER)
		elif e.is_in_group("railgun_enemy"):
			draw_circle(p, 3.2, COL_RAILGUN)
		elif e.is_in_group("double_enemy"):
			draw_circle(p, 3.0, COL_DOUBLE)
		elif e.is_in_group("shooter_enemy"):
			draw_circle(p, 3.0, COL_SHOOTER)
		else:
			draw_circle(p, 2.0, COL_SHAPE)

	# Draw every local and remote player, not just the first group member.
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue
		var pcol := COL_PLAYER
		if player.has_method("_refresh_name") or player.get("net_id") != null:
			pcol = Net.player_color_of(int(player.get("net_id")))
		if player.get("_dead") == true or player.get("net_alive") == false:
			pcol.a = 0.35
		draw_circle(_world_to_map(player.global_position), 3.5, pcol)
