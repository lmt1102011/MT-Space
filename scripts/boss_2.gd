extends CharacterBody2D

@export var max_hp: int = 460
@export var move_speed: float = 48.0
@export var contact_damage: int = 3
@export var wave_radius: float = 520.0
@export var wave_duration: float = 0.85
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
var _warning_ring: Sprite2D

const NetEnemy := preload("res://scripts/net_enemy.gd")
const XP_DROP := preload("res://scripts/xp_pickup.gd")
const CARD_DB := preload("res://scripts/card_db.gd")
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const WARNING_TEX := preload("res://assets/charge_ring.svg")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.tscn")

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _bar: HpBar = $HpBar


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("monster")
	add_to_group("boss")
	add_to_group("boss2")
	collision_layer = 8
	collision_mask = 13
	hp = max_hp
	_warning_ring = Sprite2D.new()
	_warning_ring.texture = WARNING_TEX
	_warning_ring.top_level = true
	_warning_ring.z_index = -1
	_warning_ring.modulate = Color(0.55, 0.8, 1.0, 0.3)
	_warning_ring.visible = false
	add_child(_warning_ring)
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
		_remote_warning_time = maxf(_remote_warning_time - delta, 0.0)
		_update_warning(_remote_warning_time > 0.0,
			1.0 - _remote_warning_time / 1.5, _remote_warning_center)
		_bar.global_position = global_position + Vector2(0.0, -82.0)
		_bar.global_rotation = 0.0
		return
	if Net.is_online() and not Net.is_host():
		return

	var target := Net.target_player(global_position)
	if _warning_time >= 0.0:
		_warning_time += delta
		if _warning_time < 0.5:
			_move_step(delta, target)
		else:
			velocity = Vector2.ZERO
			move_and_slide()
		_update_warning(true, _warning_time / 1.5, _warning_center)
		if _warning_time >= 1.5:
			Net.spawn_boss_sonic_wave(_warning_center, wave_radius, wave_duration)
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
	_bar.global_position = global_position + Vector2(0.0, -82.0)
	_bar.global_rotation = 0.0


func _move_step(delta: float, target: Node2D) -> void:
	if target != null:
		var aim := (target.global_position - global_position).angle()
		rotation = lerp_angle(rotation, aim, clampf(2.0 * delta, 0.0, 1.0))
	_ai_acc -= delta
	if _ai_acc <= 0.0:
		_ai_acc = 0.05
		var desired := Vector2.ZERO
		if target != null:
			desired = _brain.move(global_position, target.global_position, move_speed, 0.05)
		else:
			desired = _brain.wander(move_speed * 0.5, 0.05)
		_goal = desired + EnemyAI.steer(self, desired)
	_push = _push.move_toward(Vector2.ZERO, 450.0 * delta)
	velocity = velocity.lerp(_goal + _push, clampf(4.0 * delta, 0.0, 1.0))
	move_and_slide()
	for index in get_slide_collision_count():
		var other := get_slide_collision(index).get_collider()
		if other != null and other.is_in_group("player") \
				and other.has_method("take_damage"):
			other.take_damage(contact_damage)


func _start_warning(center: Vector2) -> void:
	_warning_time = 0.0
	_warning_center = center
	_update_warning(true, 0.0, center)
	Net.broadcast_enemy_attack_state(net_id, "boss2_warn", 1.5, center)
	Game.sfx("charge", -13.0, 0.68, 0.76)


func _update_warning(active: bool, progress: float, center: Vector2) -> void:
	if _warning_ring == null:
		return
	_warning_ring.visible = active
	if not active:
		return
	_warning_ring.global_position = center
	var diameter := lerpf(150.0, wave_radius * 2.0, clampf(progress, 0.0, 1.0))
	_warning_ring.scale = Vector2.ONE * diameter / 120.0
	_warning_ring.modulate.a = lerpf(0.2, 0.58, clampf(progress, 0.0, 1.0))


func apply_network_attack_state(state: String, duration: float,
		point: Vector2 = Vector2.ZERO) -> void:
	if state == "boss2_warn":
		_remote_warning_center = point
		_remote_warning_time = duration
	else:
		_remote_warning_time = 0.0
		_update_warning(false, 0.0, Vector2.ZERO)


func take_damage(amount: float, kind: String = "normal") -> void:
	if NetEnemy.report_hit(self, amount, kind):
		return
	hp -= maxi(1, int(round(amount)))
	_update_bar()
	_spawn_damage_number(amount, kind)
	if hp <= 0:
		_die()


func apply_push(impulse: Vector2) -> void:
	_push = (_push + impulse).limit_length(320.0)


func _update_bar() -> void:
	if _bar == null:
		return
	_bar.set_ratio(float(hp) / float(maxi(max_hp, 1)), Color(0.62, 0.4, 1.0))


func _spawn_damage_number(amount: float, kind: String) -> void:
	var number := DAMAGE_NUMBER.instantiate()
	number.global_position = global_position + Vector2(randf_range(-36.0, 36.0), -92.0)
	var color := Color(1.0, 0.85, 0.2) if kind == "crit" else Color(0.82, 0.85, 0.9)
	number.setup(amount, color, 30)
	get_tree().current_scene.add_child(number)


func _die() -> void:
	if not _net_alive or NetEnemy.is_remote(self):
		return
	_net_alive = false
	var xp := 180
	var drop_xp := NetEnemy.died(self, xp)
	var explosion := EXPLOSION_SCENE.instantiate() as Node2D
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)
	Game.on_enemy_killed()
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
