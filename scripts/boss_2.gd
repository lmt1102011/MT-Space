extends CharacterBody2D

@export var max_hp: int = 460
@export var move_speed: float = 48.0
@export var radius: float = 76.0
@export var contact_damage: int = 3
@export var wave_radius: float = 760.0
@export var wave_duration: float = 0.38
@export_range(1.0, 80.0) var wave_half_angle_degrees: float = 44.0
@export var wave_damage: int = 3
@export var wave_stun: float = 2.0
@export var attack_cooldown: float = 7.0
@export var drone_cooldown: float = 9.0

var hp: int = 460
var net_id: int = 0
var _net_target := Vector2.ZERO
var _net_rot: float = 0.0
var _net_alive: bool = true
var _net_copy: bool = false
var _net_hitter: int = 0
var _burn: float = 0.0
var _burn_tick: float = 0.0
var _burn_damage: float = 0.0
var _slow: float = 0.0
var _push := Vector2.ZERO
var _brain := EnemyBrain.new()
var _ai_acc: float = 0.0
var _goal := Vector2.ZERO
var _attack_timer: float = 3.2
var _drone_timer: float = 1.5
var _warning_time: float = -1.0
var _warning_center := Vector2.ZERO
var _remote_warning_time: float = 0.0
var _remote_warning_center := Vector2.ZERO
var _warning_ring: Polygon2D
var _cannon_glow: Polygon2D
var _warning_direction := Vector2.RIGHT

const NetEnemy := preload("res://scripts/net_enemy.gd")
const XP_DROP := preload("res://scripts/xp_pickup.gd")
const CARD_DB := preload("res://scripts/card_db.gd")
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const WARNING_TEX := preload("res://assets/charge_ring.svg")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.tscn")
const STATUS_VISUAL := preload("res://scripts/status_effect_visual.gd")

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _bar: HpBar = $HpBar
var _status_visual: Node2D


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("monster")
	add_to_group("boss")
	add_to_group("boss2")
	collision_layer = 8
	collision_mask = 13
	hp = max_hp
	_warning_ring = Polygon2D.new()
	_warning_ring.polygon = _sector_polygon(0.0)
	_warning_ring.top_level = true
	_warning_ring.z_index = -1
	_warning_ring.color = Color(1.0, 0.08, 0.06, 0.32)
	_warning_ring.visible = false
	add_child(_warning_ring)
	_add_sonic_cannon()
	_status_visual = STATUS_VISUAL.new()
	_status_visual.set("radius", radius)
	_status_visual.z_index = 2
	add_child(_status_visual)
	Game.register_boss_spawn(get_instance_id())
	_update_bar()


func setup(speed_mult: float = 1.0, dmg_bonus: int = 0,
		fire_mult: float = 1.0, hp_mult: float = 1.0) -> void:
	move_speed *= speed_mult * 0.55
	contact_damage += dmg_bonus
	attack_cooldown /= maxf(fire_mult, 0.1)
	drone_cooldown /= maxf(fire_mult, 0.1)
	max_hp = int(round(float(max_hp) * clampf(sqrt(hp_mult), 1.0, 1.55)))
	hp = max_hp
	_update_bar()


func _physics_process(delta: float) -> void:
	if NetEnemy.is_remote(self):
		collision_layer = 2
		collision_mask = 0
		NetEnemy.follow(self, delta)
		_tick_status(delta, false)
		_remote_warning_time = maxf(_remote_warning_time - delta, 0.0)
		_warning_direction = (
			_remote_warning_center - global_position
		).normalized()
		_update_warning(_remote_warning_time > 0.0,
			1.0 - _remote_warning_time / 1.5, _remote_warning_center,
			_warning_direction)
		_bar.place_at(global_position + Vector2(0.0, -82.0))
		return
	if Net.is_online() and not Net.is_host():
		return

	_tick_status(delta)
	_ignore_own_drones()
	var target := Net.target_player(global_position)
	if _warning_time >= 0.0:
		_warning_time += delta
		velocity = Vector2.ZERO
		move_and_slide()
		_update_warning(true, _warning_time / 1.5, _warning_center,
			_warning_direction)
		if _warning_time >= 1.5:
			Game.sfx("boom", -14.0, 0.64, 0.78)
			Net.spawn_boss_sonic_wave(_warning_center, wave_radius,
				wave_duration, _warning_direction, wave_half_angle_degrees)
			_warning_time = -1.0
			_attack_timer = attack_cooldown
			_update_warning(false, 0.0, Vector2.ZERO)
			Net.broadcast_enemy_attack_state(net_id, "boss2_idle", 0.0)
	else:
		_attack_timer = maxf(_attack_timer - delta, 0.0)
		_drone_timer = maxf(_drone_timer - delta, 0.0)
		_move_step(delta, target)
		if _drone_timer <= 0.0:
			var spawner := get_tree().current_scene.get_node_or_null("Spawner")
			if spawner != null and spawner.has_method("spawn_boss_drones"):
				spawner.call("spawn_boss_drones", global_position)
			_drone_timer = drone_cooldown
		if _attack_timer <= 0.0 and target != null:
			_start_warning(target.global_position)
	_bar.place_at(global_position + Vector2(0.0, -82.0))


func _move_step(delta: float, target: Node2D) -> void:
	if target != null:
		var aim := (target.global_position - global_position).angle()
		rotation = lerp_angle(rotation, aim, clampf(2.0 * delta, 0.0, 1.0))
	_ai_acc -= delta
	if _ai_acc <= 0.0:
		_ai_acc = 0.05
		var desired := Vector2.ZERO
		var move_mult := 0.55 if _slow > 0.0 else 1.0
		if target != null:
			desired = _brain.move(global_position, target.global_position,
				move_speed * move_mult, 0.05)
		else:
			desired = _brain.wander(move_speed * 0.5 * move_mult, 0.05)
		_goal = desired + EnemyAI.steer(self, desired)
	_push = _push.move_toward(Vector2.ZERO, 450.0 * delta)
	velocity = velocity.move_toward(_goal + _push, 180.0 * delta)
	move_and_slide()
	for index in get_slide_collision_count():
		var other := get_slide_collision(index).get_collider()
		if other != null and other.is_in_group("player") \
				and other.has_method("take_damage"):
			other.take_damage(contact_damage)


func _ignore_own_drones() -> void:
	for candidate in get_tree().get_nodes_in_group("boss_drone"):
		if not is_instance_valid(candidate) or not candidate is PhysicsBody2D:
			continue
		var drone := candidate as PhysicsBody2D
		if not get_collision_exceptions().has(drone):
			add_collision_exception_with(drone)
		if not drone.get_collision_exceptions().has(self):
			drone.add_collision_exception_with(self)


func _start_warning(center: Vector2) -> void:
	_warning_time = 0.0
	rotation = (center - global_position).angle()
	_warning_direction = Vector2.RIGHT.rotated(rotation)
	_warning_center = _cannon_muzzle_position()
	_update_warning(true, 0.0, _warning_center, _warning_direction)
	Net.broadcast_enemy_attack_state(net_id, "boss2_warn", 1.5, _warning_center)
	Game.sfx("charge", -13.0, 0.68, 0.76)


func _add_sonic_cannon() -> void:
	var cannon := Node2D.new()
	cannon.name = "SonicCannon"
	cannon.position = Vector2(30.0, 0.0)
	cannon.z_index = 1
	add_child(cannon)

	var body := Polygon2D.new()
	body.color = Color(0.12, 0.16, 0.24)
	body.polygon = PackedVector2Array([
		Vector2(-12.0, -14.0), Vector2(18.0, -14.0),
		Vector2(35.0, -9.0), Vector2(52.0, -7.0),
		Vector2(52.0, 7.0), Vector2(35.0, 9.0),
		Vector2(18.0, 14.0), Vector2(-12.0, 14.0),
	])
	cannon.add_child(body)

	var barrel := Polygon2D.new()
	barrel.color = Color(0.42, 0.53, 0.68)
	barrel.polygon = PackedVector2Array([
		Vector2(-2.0, -5.0), Vector2(45.0, -5.0),
		Vector2(52.0, -3.0), Vector2(52.0, 3.0),
		Vector2(45.0, 5.0), Vector2(-2.0, 5.0),
	])
	cannon.add_child(barrel)

	_cannon_glow = Polygon2D.new()
	_cannon_glow.name = "MuzzleGlow"
	_cannon_glow.color = Color(0.35, 0.85, 1.0, 0.0)
	_cannon_glow.polygon = PackedVector2Array([
		Vector2(44.0, -9.0), Vector2(62.0, -6.0),
		Vector2(62.0, 6.0), Vector2(44.0, 9.0),
	])
	cannon.add_child(_cannon_glow)


func _cannon_muzzle_position() -> Vector2:
	return to_global(Vector2(92.0, 0.0))


func _sector_polygon(distance: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var half_angle := deg_to_rad(wave_half_angle_degrees)
	for i in range(33):
		var angle := lerpf(-half_angle, half_angle, float(i) / 32.0)
		points.append(Vector2.RIGHT.rotated(angle) * distance)
	return points


func _update_warning(active: bool, progress: float, center: Vector2,
		direction: Vector2 = Vector2.RIGHT) -> void:
	if _warning_ring == null:
		return
	_warning_ring.visible = active
	if _cannon_glow != null:
		_cannon_glow.color = Color(1.0, 0.08, 0.06,
			clampf(progress, 0.0, 1.0) * (0.9 if active else 0.0))
	if not active:
		return
	_warning_ring.global_position = center
	_warning_ring.global_rotation = direction.angle()
	_warning_ring.polygon = _sector_polygon(
		wave_radius * clampf(progress, 0.0, 1.0)
	)
	_warning_ring.color.a = lerpf(0.16, 0.4, clampf(progress, 0.0, 1.0))


func apply_network_attack_state(state: String, duration: float,
		point: Vector2 = Vector2.ZERO) -> void:
	if state == "boss2_warn":
		_remote_warning_center = point
		_warning_direction = (point - global_position).normalized()
		_remote_warning_time = duration
	else:
		_remote_warning_time = 0.0
		_update_warning(false, 0.0, Vector2.ZERO, _warning_direction)


func take_damage(amount: float, kind: String = "normal") -> void:
	if NetEnemy.report_hit(self, amount, kind):
		return
	if _slow > 0.0:
		amount *= 1.0 + 0.35 * float(Game.upg_brittle)
	Game.record_damage(mini(maxi(int(round(amount)), 1), maxi(hp, 0)))
	hp -= maxi(1, int(round(amount)))
	_update_bar()
	_spawn_damage_number(amount, kind)
	if hp <= 0:
		_die()


func apply_push(impulse: Vector2) -> void:
	_push = (_push + impulse).limit_length(320.0)


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


func _update_bar() -> void:
	if _bar == null:
		return
	_bar.set_ratio(float(hp) / float(maxi(max_hp, 1)), Color(0.62, 0.4, 1.0))


func _spawn_damage_number(amount: float, kind: String) -> void:
	var number := Pool.acquire(DAMAGE_NUMBER,
		get_tree().current_scene) as DamageNumber
	if number == null:
		return
	number.global_position = global_position + Vector2(randf_range(-36.0, 36.0), -92.0)
	var color := Color(1.0, 0.85, 0.2) if kind == "crit" else Color(0.82, 0.85, 0.9)
	number.setup(amount, color, 30)


func _die() -> void:
	if not _net_alive or NetEnemy.is_remote(self):
		return
	_net_alive = false
	Game.record_boss_kill(get_instance_id())
	Game.spawn_boss_death_effect(global_position, Color(0.62, 0.42, 1.0), 1.25)
	Net.broadcast_boss_death_effect(global_position, Color(0.62, 0.42, 1.0), 1.25)
	Game.combat_impact(1.0)
	var xp := 180
	var drop_xp := NetEnemy.died(self, xp)
	Game.on_enemy_killed("boss_2")
	_drop_upgrade_card()
	if drop_xp:
		XP_DROP.drop(get_tree(), global_position, xp)
	queue_free()


func _drop_upgrade_card() -> void:
	var cards: Array = CARD_DB.passives()
	if cards.is_empty():
		return
	var card: Dictionary = cards.pick_random()
	if Net.is_host() and _net_hitter > 1:
		Net.send_elite_card(_net_hitter, global_position, str(card.get("id", "")))
		return
	var drop := preload("res://scenes/upgrade_drop.tscn").instantiate() as UpgradeDrop
	drop.card = card
	drop.global_position = global_position
	get_tree().current_scene.add_child(drop)
