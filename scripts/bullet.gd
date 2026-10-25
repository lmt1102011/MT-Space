extends Area2D

@export var speed: float = 640.0
@export var lifetime: float = 2.6
@export var damage: float = 1.0
@export var burn: int = 0
@export var freeze: int = 0
@export var pierce: int = 0          # extra enemies to pass through
@export var crit: bool = false       # this hit was a critical hit
@export var beam_length: float = 26.0
@export var beam_width: float = 5.0
@export var beam_color: Color = Color(1.0, 0.9, 0.2)

var direction: Vector2 = Vector2.RIGHT
var network_visual: bool = false
var source_position: Vector2 = Vector2.ZERO

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const ENEMY_INDEX := preload("res://scripts/enemy_spatial_index.gd")
const BEAM_TEX := preload("res://assets/beam.svg")
const BEAM_CORE_TEX := preload("res://assets/beam_core.svg")
# the size of the beam textures
const BEAM_W := 64.0
const BEAM_H := 16.0
const HOMING_RANGE := 520.0
const HOMING_TURN := 4.6
const HOMING_TURN_FIRST := 0.8
const HOMING_SEARCH := 0.08
const HOMING_CONE := 1.75        # acquire a target in a broad front arc
const HOMING_MAX_TIME := 2.4     # enough time to make a real correction
const HOMING_LEAD := 0.35        # seconds of target velocity to lead the shot

var _hit: Array = []
var _home_t: float = 0.0
var _home_age: float = 0.0
var _home_target: Node2D = null
var _beam: Sprite2D = null


func _ready() -> void:
	add_to_group("player_bullet")
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	# the shot is an image: the outer bolt and a solid hot core
	_beam = Sprite2D.new()
	_beam.texture = BEAM_TEX
	_beam.modulate = beam_color
	_beam.scale = Vector2(beam_length / BEAM_W, beam_width / BEAM_H)
	add_child(_beam)
	# bright core
	var core := Sprite2D.new()
	core.texture = BEAM_CORE_TEX
	core.modulate = Color(1.0, 1.0, 0.85, 1.0)
	core.scale = Vector2(beam_length / BEAM_W, beam_width * 0.4 / BEAM_H)
	add_child(core)


func _physics_process(delta: float) -> void:
	_home(delta)
	var previous := global_position
	position += direction * speed * delta
	_check_swept_enemy_hits(previous, global_position)
	lifetime -= delta
	if lifetime <= 0.0:
		_detonate()


# --- homing ---------------------------------------------------------------
func _home(delta: float) -> void:
	if network_visual or Game.upg_homing <= 0:
		return
	_home_age += delta
	if _home_age > HOMING_MAX_TIME:
		return
	_home_t -= delta
	if _home_t <= 0.0:
		_home_t = HOMING_SEARCH
		var found := _pick_target()
		if found != null:
			_home_target = found
		elif _home_target != null and not is_instance_valid(_home_target):
			_home_target = null
	var target := _home_target
	if target != null and is_instance_valid(target) and target.get("_net_alive") == false:
		_home_target = null
		target = null
	if target == null or not is_instance_valid(target):
		return
	# aim at where the target is going, not where it was
	var aim := target.global_position + _target_velocity(target) * HOMING_LEAD
	var want := (aim - global_position).angle()
	var diff := angle_difference(direction.angle(), want)
	# never turn around: a target behind us is simply not chased
	if absf(diff) > 2.4:
		return
	var turn := HOMING_TURN_FIRST if Game.upg_homing == 1 else \
		HOMING_TURN * (1.0 + 0.25 * float(Game.upg_homing - 2))
	direction = direction.rotated(diff * clampf(turn * delta, 0.0, 1.0))
	rotation = direction.angle()   # keep the beam pointing where it flies
	speed *= 0.999   # barely bleeds speed so it still reaches the target


# Picks the enemy that is closest to the line the bullet is already flying
# along. That way homing helps instead of dragging the shot off sideways.
func _pick_target() -> Node2D:
	var best: Node2D = null
	var best_score := INF
	var fwd := direction.angle()
	var search := Rect2(
		global_position - Vector2(HOMING_RANGE, HOMING_RANGE),
		Vector2(HOMING_RANGE * 2.0, HOMING_RANGE * 2.0)
	)
	for e in ENEMY_INDEX.query_rect(get_tree(), search):
		var n := e as Node2D
		if n == null or not is_instance_valid(n):
			continue
		var to := n.global_position - global_position
		var d := to.length()
		if d > HOMING_RANGE or d < 0.001:
			continue
		var off := absf(angle_difference(fwd, to.angle()))
		if off > HOMING_CONE:
			continue
		# distance decides, the angle off the flight line only breaks ties
		var score := d + off * 60.0
		if score < best_score:
			best_score = score
			best = n
	return best


func _target_velocity(target: Node2D) -> Vector2:
	var body := target as CharacterBody2D
	if body == null:
		return Vector2.ZERO
	return body.velocity


# --- damage ---------------------------------------------------------------
func _hurt(target: Node2D) -> void:
	if Net.is_host() and target.get("_net_copy") != true:
		target.set("_net_hitter", Net.my_id())
	var dmg := damage
	if Game.upg_close_quarters > 0 \
			and source_position.distance_squared_to(target.global_position) <= 150.0 * 150.0:
		dmg *= 1.0 + 0.15 * float(Game.upg_close_quarters)
	# Elite Hunter: extra damage against elites
	if Game.upg_elite_hunter > 0 and target.is_in_group("elite"):
		dmg *= 1.0 + 0.5 * float(Game.upg_elite_hunter)
	if target.has_method("take_damage"):
		target.take_damage(dmg, "crit" if crit else "normal")
		Game.sfx("hit", -20.0, 0.9, 1.2)
	if target.has_method("apply_status"):
		target.apply_status(burn, freeze)
	# Shatter: a critical hit bursts and hurts everything close by
	if crit and Game.upg_splash > 0:
		_splash(target, dmg)


func _splash(origin: Node2D, dmg: float) -> void:
	var radius := 50.0 + 10.0 * float(Game.upg_splash)
	var r2 := radius * radius
	var o_pos := origin.global_position
	var search := Rect2(o_pos - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	for e in ENEMY_INDEX.query_rect(get_tree(), search):
		if e == origin:
			continue
		var n := e as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if n.global_position.distance_squared_to(o_pos) > r2:
			continue
		if Net.is_host() and n.get("_net_copy") != true:
			n.set("_net_hitter", Net.my_id())
		if n.has_method("take_damage"):
			n.take_damage(dmg * 0.4, "normal")


func _on_body_entered(body: Node2D) -> void:
	if network_visual:
		_detonate()
		return
	if body.is_in_group("enemy"):
		if _hit.has(body):
			return
		_hit.append(body)
		_hurt(body)
		if pierce > 0:
			pierce -= 1
			if Game.upg_pierce_focus > 0:
				damage *= 1.0 + 0.25 * float(Game.upg_pierce_focus)
			return
		_detonate()
	elif body.is_in_group("obstacle"):
		_detonate()


func _check_swept_enemy_hits(from: Vector2, to: Vector2) -> void:
	# Fast rounds can move farther than an enemy's collider in one physics
	# frame. Test the travelled segment so homing rounds cannot visually pass
	# through a target they crossed.
	if network_visual:
		return
	var travel := to - from
	var length_sq := travel.length_squared()
	var start := from.min(to)
	var end := from.max(to)
	var search := Rect2(start, end - start)
	for enemy in ENEMY_INDEX.query_rect(get_tree(), search, 48.0):
		var target := enemy as Node2D
		if target == null or not is_instance_valid(target) or _hit.has(target):
			continue
		var u := 0.0
		if length_sq > 0.001:
			u = clampf((target.global_position - from).dot(travel) / length_sq, 0.0, 1.0)
		var closest := from + travel * u
		var hit_radius := 14.0
		var shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape != null and shape.shape is CircleShape2D:
			hit_radius += (shape.shape as CircleShape2D).radius * 0.6
		if closest.distance_squared_to(target.global_position) <= hit_radius * hit_radius:
			_on_body_entered(target)
			if not is_instance_valid(self):
				return
func _detonate() -> void:
	# Explosive Rounds: a small burst when the round dies
	if Game.upg_explosive > 0:
		_burst(global_position, damage * 0.3, 45.0 + 8.0 * float(Game.upg_explosive))
	var boom := EXPLOSION_SCENE.instantiate() as Explosion
	boom.global_position = global_position
	get_tree().current_scene.add_child(boom)
	queue_free()


# Damages every enemy inside the radius (used by Shatter and Explosive Rounds).
func _burst(center: Vector2, dmg: float, radius: float) -> void:
	var r2 := radius * radius
	var search := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	for e in ENEMY_INDEX.query_rect(get_tree(), search):
		var n := e as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if n.global_position.distance_squared_to(center) > r2:
			continue
		if n.has_method("take_damage"):
			n.take_damage(dmg, "normal")


func _draw() -> void:
	pass
