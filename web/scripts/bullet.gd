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

const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const BEAM_TEX := preload("res://assets/beam.svg")
const BEAM_CORE_TEX := preload("res://assets/beam_core.svg")
# the size of the beam textures
const BEAM_W := 64.0
const BEAM_H := 16.0
const HOMING_RANGE := 380.0
const HOMING_TURN := 4.6
const HOMING_TURN_FIRST := 0.8
const HOMING_SEARCH := 0.08
const HOMING_CONE := 1.15        # only lock on targets roughly in front
const HOMING_MAX_TIME := 1.6     # stop steering eventually, no endless curls
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
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_detonate()


# --- homing ---------------------------------------------------------------
func _home(delta: float) -> void:
	if Game.upg_homing <= 0:
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
	for e in get_tree().get_nodes_in_group("enemy"):
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
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == origin:
			continue
		var n := e as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if n.global_position.distance_squared_to(o_pos) > r2:
			continue
		if n.has_method("take_damage"):
			n.take_damage(dmg * 0.4, "normal")


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		if _hit.has(body):
			return
		_hit.append(body)
		_hurt(body)
		if pierce <= 0:
			_detonate()
		else:
			pierce -= 1
			# Piercing Focus: every enemy it goes through makes it hit harder
			if Game.upg_pierce_focus > 0:
				damage *= 1.0 + 0.25 * float(Game.upg_pierce_focus)
	elif body.is_in_group("obstacle"):
		_detonate()


func _detonate() -> void:
	# Explosive Rounds: a small burst when the round dies
	if Game.upg_explosive > 0:
		_burst(global_position, damage * 0.3, 45.0 + 8.0 * float(Game.upg_explosive))
	var boom := EXPLOSION_SCENE.instantiate() as WebExplosion
	boom.global_position = global_position
	get_tree().current_scene.add_child(boom)
	queue_free()


# Damages every enemy inside the radius (used by Shatter and Explosive Rounds).
func _burst(center: Vector2, dmg: float, radius: float) -> void:
	var r2 := radius * radius
	for e in get_tree().get_nodes_in_group("enemy"):
		var n := e as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if n.global_position.distance_squared_to(center) > r2:
			continue
		if n.has_method("take_damage"):
			n.take_damage(dmg, "normal")


func _draw() -> void:
	pass
