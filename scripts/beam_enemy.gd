extends CharacterBody2D

@export var max_hp: int = 14
@export var move_speed: float = 95.0
@export var charge_time: float = 2.4
@export var fire_cooldown: float = 3.4
@export var beam_range: float = 1900.0
@export var beam_damage: int = 4

var hp: int = 14
var net_id: int = 0
var _net_target := Vector2.ZERO
var _net_rot: float = 0.0
var _net_alive: bool = true
var _net_copy: bool = false
var _net_hitter: int = 0
var _phase: String = "move"
var _phase_time: float = 0.0
var _cooldown: float = 1.4
var _ai_acc: float = 0.0
var _goal := Vector2.ZERO
var _fire_start_angle: float = 0.0
var _beam_hits: Dictionary = {}
var _beam_players: Array = []
var _push := Vector2.ZERO
var _brain := EnemyBrain.new()
var _remote_phase: String = "move"
var _remote_phase_time: float = 0.0
var _remote_phase_duration: float = 0.0
var _burn: float = 0.0
var _burn_tick: float = 0.0
var _burn_damage: float = 0.0
var _slow: float = 0.0
var _charge_orb: Sprite2D
var _charge_ring: Sprite2D
var _warning_line: Sprite2D
var _beam_outer: Sprite2D
var _beam_core: Sprite2D

const NetEnemy := preload("res://scripts/net_enemy.gd")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.tscn")
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const XP_DROP := preload("res://scripts/xp_pickup.gd")
const ORB_TEX := preload("res://assets/orb_projectile.svg")
const CHARGE_TEX := preload("res://assets/charge_ring.svg")
const AIM_TEX := preload("res://assets/aim_line.svg")
const BEAM_TEX := preload("res://assets/beam.svg")
const BEAM_CORE_TEX := preload("res://assets/beam_core.svg")
const STATUS_VISUAL := preload("res://scripts/status_effect_visual.gd")
const MUZZLE := Vector2(30.0, 0.0)
const BEAM_DURATION := 1.2
const BEAM_START_DELAY := 0.22
const BEAM_TICK_INTERVAL := 0.125
const BEAM_DAMAGE_PER_TICK := 0.1

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _bar: HpBar = $HpBar
var _status_visual: Node2D


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("monster")
	add_to_group("beam_enemy")
	collision_layer = 8
	collision_mask = 13
	hp = max_hp
	_build_attack_sprites()
	_status_visual = STATUS_VISUAL.new()
	_status_visual.set("radius", 30.0)
	_status_visual.z_index = 2
	add_child(_status_visual)
	_update_bar()


func _build_attack_sprites() -> void:
	_charge_ring = Sprite2D.new()
	_charge_ring.texture = CHARGE_TEX
	_charge_ring.position = MUZZLE
	_charge_ring.modulate = Color(0.45, 0.8, 1.0, 0.9)
	_charge_ring.visible = false
	add_child(_charge_ring)

	_charge_orb = Sprite2D.new()
	_charge_orb.texture = ORB_TEX
	_charge_orb.position = MUZZLE
	_charge_orb.modulate = Color(0.55, 0.85, 1.0, 1.0)
	_charge_orb.visible = false
	add_child(_charge_orb)

	_warning_line = Sprite2D.new()
	_warning_line.texture = AIM_TEX
	_warning_line.position = Vector2(MUZZLE.x + beam_range * 0.5, 0.0)
	_warning_line.scale = Vector2(beam_range / 64.0, 0.9)
	_warning_line.modulate = Color(0.4, 0.75, 1.0, 0.18)
	_warning_line.visible = false
	add_child(_warning_line)

	_beam_outer = Sprite2D.new()
	_beam_outer.texture = BEAM_TEX
	_beam_outer.position = Vector2(MUZZLE.x + beam_range * 0.5, 0.0)
	_beam_outer.scale = Vector2(beam_range / 64.0, 1.8)
	_beam_outer.modulate = Color(0.35, 0.7, 1.0, 0.9)
	_beam_outer.visible = false
	add_child(_beam_outer)

	_beam_core = Sprite2D.new()
	_beam_core.texture = BEAM_CORE_TEX
	_beam_core.position = _beam_outer.position
	_beam_core.scale = Vector2(beam_range / 64.0, 0.85)
	_beam_core.modulate = Color(0.9, 0.97, 1.0, 1.0)
	_beam_core.visible = false
	add_child(_beam_core)


func setup(speed_mult: float = 1.0, dmg_bonus: int = 0,
		fire_mult: float = 1.0, hp_mult: float = 1.0) -> void:
	move_speed *= speed_mult
	beam_damage += dmg_bonus
	fire_cooldown /= maxf(fire_mult, 0.1)
	max_hp = int(round(float(max_hp) * hp_mult))
	hp = max_hp
	_update_bar()


func _physics_process(delta: float) -> void:
	if NetEnemy.is_remote(self):
		collision_layer = 2
		collision_mask = 0
		NetEnemy.follow(self, delta)
		_tick_status(delta, false)
		_remote_phase_time = maxf(_remote_phase_time - delta, 0.0)
		_update_visuals(_remote_phase,
			1.0 - _remote_phase_time / maxf(_remote_phase_duration, 0.01))
		_bar.global_position = global_position + Vector2(0.0, 38.0)
		_bar.global_rotation = 0.0
		return
	if Net.is_online() and not Net.is_host():
		return

	_tick_status(delta)
	var target := Net.target_player(global_position)
	if _phase == "fire":
		_fire_step(delta, target)
	else:
		_move_step(delta, target)
		if _phase == "charge":
			_phase_time += delta
			if target != null:
				_aim_at(target, delta, 3.0)
			_update_visuals("charge", clampf(_phase_time / charge_time, 0.0, 1.0))
			if _phase_time >= charge_time:
				_start_fire()
		else:
			_cooldown = maxf(_cooldown - delta, 0.0)
			_update_visuals("move", 0.0)
			if target != null and _cooldown <= 0.0 \
					and global_position.distance_to(target.global_position) <= 900.0:
				_start_charge()
	_bar.global_position = global_position + Vector2(0.0, 38.0)
	_bar.global_rotation = 0.0


func _move_step(delta: float, target: Node2D) -> void:
	_ai_acc -= delta
	if _ai_acc <= 0.0:
		_ai_acc = 0.05
		var desired := Vector2.ZERO
		if target != null:
			var move_mult := 0.55 if _slow > 0.0 else 1.0
			desired = _brain.move(global_position, target.global_position,
				move_speed * move_mult, 0.05)
		else:
			desired = _brain.wander(move_speed * 0.5, 0.05)
		_goal = desired + EnemyAI.steer(self, desired)
	_push = _push.move_toward(Vector2.ZERO, 500.0 * delta)
	velocity = velocity.lerp(_goal + _push,
		clampf(4.0 * delta, 0.0, 1.0))
	move_and_slide()
	for index in get_slide_collision_count():
		var other := get_slide_collision(index).get_collider()
		if other != null and other.is_in_group("player") \
				and other.has_method("take_damage"):
			other.take_damage(1)


func _aim_at(target: Node2D, delta: float, turn_rate: float) -> void:
	var wanted := (target.global_position - global_position).angle()
	rotation = lerp_angle(rotation, wanted, clampf(turn_rate * delta, 0.0, 1.0))


func _start_charge() -> void:
	_phase = "charge"
	_phase_time = 0.0
	Game.sfx("charge", -15.0, 0.9, 1.15)
	Net.broadcast_enemy_attack_state(net_id, "charge", charge_time)


func _start_fire() -> void:
	_phase = "fire"
	_phase_time = 0.0
	_fire_start_angle = rotation
	_beam_hits.clear()
	_beam_players = get_tree().get_nodes_in_group("player")
	Game.sfx("laser", -9.0, 0.72, 0.82)
	Net.broadcast_enemy_attack_state(net_id, "fire", BEAM_DURATION)


func _fire_step(delta: float, target: Node2D) -> void:
	_phase_time += delta
	velocity = Vector2.ZERO
	if _phase_time >= BEAM_START_DELAY and target != null:
		var wanted := (target.global_position - global_position).angle()
		var offset := clampf(angle_difference(_fire_start_angle, wanted), -0.65, 0.65)
		var limited_angle := _fire_start_angle + offset
		rotation = lerp_angle(rotation, limited_angle,
			clampf(1.25 * delta, 0.0, 1.0))
	if _phase_time >= BEAM_START_DELAY and _phase_time <= BEAM_DURATION:
		_hit_players_with_beam()
	_update_visuals("fire", _phase_time / BEAM_DURATION)
	if _phase_time >= BEAM_DURATION:
		_phase = "move"
		_cooldown = fire_cooldown
		Net.broadcast_enemy_attack_state(net_id, "move", 0.0)


func _hit_players_with_beam() -> void:
	var direction := Vector2.RIGHT.rotated(rotation)
	var origin := global_position + direction * MUZZLE.x
	for candidate in _beam_players:
		var player := candidate as Node2D
		if player == null or not is_instance_valid(player):
			continue
		if player.get("_dead") == true or player.get("net_alive") == false:
			continue
		var player_id := player.get_instance_id()
		var offset := player.global_position - origin
		var along := offset.dot(direction)
		if along < 0.0 or along > beam_range:
			continue
		var lateral := absf(direction.cross(offset))
		if lateral > 42.0:
			continue
		var next_hit := float(_beam_hits.get(player_id, 0.0))
		if _phase_time < next_hit:
			continue
		_beam_hits[player_id] = _phase_time + BEAM_TICK_INTERVAL
		if player.has_method("apply_orb_damage"):
			player.apply_orb_damage(BEAM_DAMAGE_PER_TICK)
		elif player.has_method("take_damage"):
			player.take_damage(BEAM_DAMAGE_PER_TICK)


func _update_visuals(phase: String, progress: float) -> void:
	var charging := phase == "charge"
	var firing := phase == "fire" and progress >= BEAM_START_DELAY / BEAM_DURATION
	_charge_orb.visible = charging
	_charge_ring.visible = charging
	_warning_line.visible = charging
	_beam_outer.visible = firing
	_beam_core.visible = firing
	if charging:
		var diameter := lerpf(8.0, 38.0, clampf(progress, 0.0, 1.0))
		_charge_ring.scale = Vector2.ONE * diameter / 120.0
		_charge_ring.modulate.a = lerpf(0.25, 0.95, progress)
		var orb_size := lerpf(0.18, 0.36, progress)
		_charge_orb.scale = Vector2.ONE * orb_size
		_warning_line.modulate.a = lerpf(0.12, 0.55, progress)
	if firing:
		var fade_start := 1.0 - 0.25 / BEAM_DURATION
		var fade := 1.0 - clampf((progress - fade_start) / (0.25 / BEAM_DURATION),
			0.0, 1.0)
		_beam_outer.modulate.a = 0.85 * fade
		_beam_core.modulate.a = fade


func apply_network_attack_state(state: String, duration: float,
		_point: Vector2 = Vector2.ZERO) -> void:
	_remote_phase = state
	_remote_phase_time = duration
	_remote_phase_duration = duration
	if state == "fire":
		_fire_start_angle = rotation


func take_damage(amount: float, kind: String = "normal") -> void:
	if NetEnemy.report_hit(self, amount, kind):
		return
	if _slow > 0.0:
		amount *= 1.0 + 0.35 * float(Game.upg_brittle)
	hp -= maxi(1, int(round(amount)))
	_update_bar()
	if hp <= 0:
		_die()


func apply_status(burn_stacks: int, freeze_stacks: int) -> void:
	NetEnemy.report_status(self, burn_stacks, freeze_stacks)
	if burn_stacks > 0:
		_burn = maxf(_burn, 2.0 + burn_stacks * 0.5)
		_burn_damage = (0.6 + burn_stacks * 0.4) \
			* (1.0 + 0.4 * float(Game.upg_inferno))
		Game.sfx("sizzle", -23.0, 0.9, 1.15)
	if freeze_stacks > 0:
		_slow = maxf(_slow, 1.2 + freeze_stacks * 0.4)
		Game.sfx("frost", -23.0, 0.92, 1.12)


func _tick_status(delta: float, apply_burn_damage: bool = true) -> void:
	if _burn > 0.0:
		_burn = maxf(_burn - delta, 0.0)
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.4
			if apply_burn_damage:
				take_damage(_burn_damage, "burn")
	if _slow > 0.0:
		_slow = maxf(_slow - delta, 0.0)
	_status_visual.call("set_status", _burn > 0.0, _slow > 0.0)


func apply_push(impulse: Vector2) -> void:
	_push = (_push + impulse).limit_length(300.0)


func _update_bar() -> void:
	if _bar == null:
		return
	_bar.set_ratio(float(hp) / float(maxi(max_hp, 1)), Color(0.35, 0.78, 1.0))


func _die() -> void:
	if not _net_alive or NetEnemy.is_remote(self):
		return
	_net_alive = false
	var xp := 25
	var drop_xp := NetEnemy.died(self, xp)
	var boom := EXPLOSION_SCENE.instantiate() as Node2D
	boom.global_position = global_position
	get_tree().current_scene.add_child(boom)
	Game.on_enemy_killed()
	if drop_xp:
		XP_DROP.drop(get_tree(), global_position, xp)
	queue_free()
