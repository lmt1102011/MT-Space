extends Node2D

# Self-playing diorama for the main menu. It uses the real enemy shapes so the
# menu shows the actual roster, and the movement is deliberately loose and
# uneven so it does not look robotic.

const SHAPES := preload("res://scripts/enemy_shapes.gd")
const SHIP_TEX := preload("res://assets/player.svg")
const DOUBLE_TEX := preload("res://assets/double_enemy.svg")

const ZOOM := 0.62                 # wider camera than the screen
const SHOT_CD := 0.75
const SHOT_SPEED := 520.0
const ROSTER := ["shape", "railgun", "shooter", "charger", "double", "shape"]

# only the ranged enemies shoot - shapes are just XP farming
const SHOOTERS := ["shooter", "double", "railgun"]

var _mobs: Array = []
var _shots: Array = []
var _shot_t: float = 0.0
var _t: float = 0.0
var _area: Vector2 = Vector2(2064, 1161)     # visible world size


func _ready() -> void:
	_area = get_viewport_rect().size / ZOOM
	scale = Vector2(ZOOM, ZOOM)
	for i in ROSTER.size():
		var kind: String = ROSTER[i]
		var sides := randi_range(3, 6)
		var pos := Vector2(
			randf_range(-_area.x * 0.42, _area.x * 0.42),
			randf_range(-_area.y * 0.40, _area.y * 0.40))
		var mob := {
			"kind": kind,
			"pos": pos,
			"vel": Vector2.from_angle(randf() * TAU) * randf_range(50.0, 100.0),
			"dir": Vector2.from_angle(randf() * TAU),
			"turn_t": randf_range(0.8, 2.6),
			"speed": randf_range(55.0, 105.0),
			"col": (SHAPES.shape_color(sides) if kind == "shape" else _color_for(kind)),
			"radius": randf_range(18.0, 34.0),
			"sides": sides,
			"hp": 3.0,
			"flash": 0.0,
			"seed": randf() * TAU,
			"ang": randf() * TAU,
			"node": null,
		}
		if kind == "shooter" or kind == "double":
			var spr := Sprite2D.new()
			spr.texture = SHIP_TEX if kind == "shooter" else DOUBLE_TEX
			spr.scale = Vector2(SHAPES.SHOOTER_SCALE, SHAPES.SHOOTER_SCALE) if kind == "shooter" else Vector2(SHAPES.DOUBLE_SCALE, SHAPES.DOUBLE_SCALE)
			spr.modulate = SHAPES.SHOOTER_COLOR if kind == "shooter" else SHAPES.DOUBLE_COLOR
			add_child(spr)
			mob["node"] = spr
		_mobs.append(mob)


func _color_for(kind: String) -> Color:
	match kind:
		"railgun":
			return SHAPES.RAILGUN_COLOR
		"charger":
			return SHAPES.CHARGER_COLOR
		"shooter":
			return SHAPES.SHOOTER_COLOR
		"double":
			return SHAPES.DOUBLE_COLOR
	return SHAPES.shape_color(5)


func _process(delta: float) -> void:
	_t += delta
	var screen := get_viewport_rect().size
	_area = screen / ZOOM
	position = screen * 0.5

	for m in _mobs:
		var pos: Vector2 = m["pos"]
		var vel: Vector2 = m["vel"]
		var dir: Vector2 = m["dir"]

		# loose wander: the heading drifts and the speed breathes
		m["turn_t"] = float(m["turn_t"]) - delta
		if float(m["turn_t"]) <= 0.0:
			m["turn_t"] = randf_range(0.9, 2.8)
			m["dir"] = (dir + Vector2.from_angle(randf_range(-1.1, 1.1))).normalized()
			m["speed"] = clampf(float(m["speed"]) + randf_range(-28.0, 28.0), 35.0, 140.0)
		dir = m["dir"]
		var breathe := 0.75 + 0.35 * sin(_t * 0.8 + float(m["seed"]))
		var want := dir * float(m["speed"]) * breathe

		# soft separation so they do not pile up
		for o in _mobs:
			if o == m:
				continue
			var op: Vector2 = o["pos"]
			var away := pos - op
			var d := away.length()
			if d < 90.0 and d > 0.001:
				want += away / d * (90.0 - d) * 2.2

		vel = vel.move_toward(want, 180.0 * delta)
		pos += vel * delta
		var pad := 70.0
		if pos.x < -_area.x * 0.5 + pad:
			pos.x = -_area.x * 0.5 + pad
			m["dir"] = Vector2(absf(dir.x), dir.y).normalized()
			vel.x = absf(vel.x)
		if pos.x > _area.x * 0.5 - pad:
			pos.x = _area.x * 0.5 - pad
			m["dir"] = Vector2(-absf(dir.x), dir.y).normalized()
			vel.x = -absf(vel.x)
		if pos.y < -_area.y * 0.5 + pad:
			pos.y = -_area.y * 0.5 + pad
			m["dir"] = Vector2(dir.x, absf(dir.y)).normalized()
			vel.y = absf(vel.y)
		if pos.y > _area.y * 0.5 - pad:
			pos.y = _area.y * 0.5 - pad
			m["dir"] = Vector2(dir.x, -absf(dir.y)).normalized()
			vel.y = -absf(vel.y)
		m["pos"] = pos
		m["vel"] = vel
		if float(m["flash"]) > 0.0:
			m["flash"] = maxf(float(m["flash"]) - delta * 4.0, 0.0)

		# turn towards whatever it is closest to
		var target := _nearest(pos, m)
		if target != null:
			var tp: Vector2 = target["pos"]
			var want_ang := (tp - pos).angle()
			m["ang"] = lerp_angle(float(m["ang"]), want_ang, clampf(delta * 3.0, 0.0, 1.0))
		var node: Node2D = m["node"]
		if node != null:
			node.position = pos
			node.rotation = float(m["ang"])
		_ensure_visual(m)

	_shot_t -= delta
	if _shot_t <= 0.0:
		_shot_t = SHOT_CD + randf_range(-0.3, 0.4)
		_fire()

	for i in range(_shots.size() - 1, -1, -1):
		var s: Dictionary = _shots[i]
		var p: Vector2 = s["pos"]
		var v: Vector2 = s["vel"]
		p += v * delta
		s["pos"] = p
		var hit := false
		for m in _mobs:
			if m == s["owner"]:
				continue
			var mp: Vector2 = m["pos"]
			if mp.distance_to(p) < 22.0:
				m["hp"] = float(m["hp"]) - 1.0
				m["flash"] = 1.0
				hit = true
				break
		if hit or p.x < -_area.x or p.x > _area.x or p.y < -_area.y or p.y > _area.y:
			_shots.remove_at(i)

	queue_redraw()


func _ensure_visual(m: Dictionary) -> void:
	# build the enemy visual once as nodes (cached mesh), then only move them
	if m["node"] != null:
		return
	var kind: String = m["kind"]
	var col: Color = m["col"]
	if kind == "shape":
		var poly := SHAPES.make_shape(int(m["sides"]), float(m["radius"]), col)
		add_child(poly)
		m["node"] = poly
		return
	if kind == "shooter" or kind == "double":
		return
	# the two new ships use the reference drawings as textures
	var tex: Texture2D = (SHAPES.RAILGUN_TEX if kind == "railgun" else SHAPES.CHARGER_TEX)
	var scl: float = (SHAPES.RAILGUN_SCALE if kind == "railgun" else SHAPES.CHARGER_SCALE)
	var sprite := SHAPES.make_ship(tex, scl)
	sprite.modulate = col
	add_child(sprite)
	m["node"] = sprite


func _nearest(from: Vector2, skip: Dictionary) -> Dictionary:
	var best = null
	var best_d := INF
	for m in _mobs:
		if m == skip:
			continue
		var mp: Vector2 = m["pos"]
		var d: float = mp.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = m
	if best == null:
		return {}
	return best


func _fire() -> void:
	# only the ranged enemies shoot, the shapes just soak up bullets
	var shooters: Array = []
	for m in _mobs:
		if SHOOTERS.has(m["kind"]):
			shooters.append(m)
	if shooters.is_empty():
		return
	var shooter: Dictionary = shooters[randi() % shooters.size()]
	var from: Vector2 = shooter["pos"]
	var best = _nearest(from, shooter)
	if best.is_empty():
		return
	var target: Dictionary = best
	var to: Vector2 = target["pos"]
	var dir := (to - from).normalized()
	_shots.append({
		"pos": from + dir * 30.0,
		"vel": dir * SHOT_SPEED,
		"owner": shooter,
	})


func _draw() -> void:
	# the grid and the drones are nodes, only the shots are drawn here
	for s in _shots:
		var p: Vector2 = s["pos"]
		var v: Vector2 = s["vel"]
		draw_line(p, p - v.normalized() * 18.0, Color(1.0, 0.92, 0.5), 4.0, true)
