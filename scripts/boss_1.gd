extends CharacterBody2D

const ENEMY_BULLET := preload("res://scenes/enemy_bullet.tscn")
const BOSS_MISSILE := preload("res://scenes/boss_missile.tscn")
const XP_DROP := preload("res://scripts/xp_pickup.gd")
const CARD_DB := preload("res://scripts/card_db.gd")
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.tscn")
const NetEnemy := preload("res://scripts/net_enemy.gd")

@export var max_hp: int = 420
@export var move_speed: float = 38.0
@export var radius: float = 76.0
@export var contact_damage: int = 4

const BARRAGE_DURATION := 3.5
const RECHARGE_DURATION := 2.8
const BARRAGE_INTERVAL := 0.3
const MISSILE_INTERVAL := 5.0
const MINION_INTERVAL := 8.0
const BARRAGE_SPREAD := [-0.3, -0.15, 0.0, 0.15, 0.3]

var hp: int = 420
var elite := false
var net_id: int = 0
var _net_target := Vector2.ZERO
var _net_rot: float = 0.0
var _net_alive: bool = true
var _net_copy: bool = false
var _net_hitter: int = 0
var _burn := 0.0
var _burn_tick := 0.0
var _burn_damage := 0.0
var _slow := 0.0
var _push := Vector2.ZERO
var _contact_timer := 0.0
var _barrage_timer := BARRAGE_DURATION
var _recharge_timer := 0.0
var _bullet_timer := 0.0
var _missile_timer := 2.5
var _minion_timer := 6.0
var _damage_bonus := 0
var _fire_rate_mult := 1.0
var _brain := EnemyBrain.new()

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _bar: HpBar = $HpBar


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("monster")
	add_to_group("boss")
	collision_layer = 8
	collision_mask = 13
	_update_bar()


func setup(speed_mult: float = 1.0, dmg_bonus: int = 0,
		fire_mult: float = 1.0, hp_mult: float = 1.0) -> void:
	move_speed *= speed_mult * 0.65
	_damage_bonus = dmg_bonus
	_fire_rate_mult = maxf(fire_mult, 0.1)
	contact_damage = 4 + dmg_bonus
	max_hp = int(round(float(max_hp) * hp_mult))
	hp = max_hp
	_update_bar()


func _physics_process(delta: float) -> void:
	if NetEnemy.is_remote(self):
		collision_layer = 2
		collision_mask = 0
		NetEnemy.follow(self, delta)
		_bar.global_position = global_position + Vector2(0.0, -radius - 20.0)
		_bar.global_rotation = 0.0
		return
	if Net.is_online() and not Net.is_host():
		return

	_burn = maxf(_burn - delta, 0.0)
	_slow = maxf(_slow - delta, 0.0)
	_contact_timer = maxf(_contact_timer - delta, 0.0)
	_tick_burn(delta)
	var target := Net.target_player(global_position)
	if target != null:
		var to_target := target.global_position - global_position
		if not to_target.is_zero_approx():
			rotation = lerp_angle(rotation, to_target.angle(), 2.2 * delta)
		var speed_scale := 0.55 if _slow > 0.0 else 1.0
		var desired := _brain.move(global_position, target.global_position,
			move_speed * speed_scale, delta)
		var avoid := EnemyAI.steer(self, desired)
		_push = _push.move_toward(Vector2.ZERO, 500.0 * delta)
		velocity = velocity.lerp(desired + avoid + _push,
			clampf(4.0 * delta, 0.0, 1.0))
		move_and_slide()
		_handle_collisions()
		_update_attacks(delta, to_target.angle())
	else:
		_push = _push.move_toward(Vector2.ZERO, 500.0 * delta)
		velocity = velocity.move_toward(Vector2.ZERO, 70.0 * delta)
		move_and_slide()
	_bar.global_position = global_position + Vector2(0.0, -radius - 20.0)
	_bar.global_rotation = 0.0


func _update_attacks(delta: float, aim_angle: float) -> void:
	if _recharge_timer > 0.0:
		_recharge_timer = maxf(_recharge_timer - delta, 0.0)
		if _recharge_timer == 0.0:
			_barrage_timer = BARRAGE_DURATION
	else:
		_barrage_timer -= delta
		_bullet_timer -= delta
		if _bullet_timer <= 0.0 and _barrage_timer > 0.0:
			_fire_fan(aim_angle)
			_bullet_timer = BARRAGE_INTERVAL / _fire_rate_mult
		if _barrage_timer <= 0.0:
			_recharge_timer = RECHARGE_DURATION

	_missile_timer -= delta
	if _missile_timer <= 0.0:
		_fire_missile_pair(aim_angle)
		_missile_timer = MISSILE_INTERVAL / _fire_rate_mult

	_minion_timer -= delta
	if _minion_timer <= 0.0:
		var spawner := get_tree().current_scene.get_node_or_null("Spawner")
		if spawner != null and spawner.has_method("spawn_boss_minions"):
			spawner.call("spawn_boss_minions")
		_minion_timer = MINION_INTERVAL


func _fire_fan(aim_angle: float) -> void:
	Game.sfx("shoot", -21.0, 0.72, 0.84)
	var direction := Vector2.from_angle(aim_angle)
	var muzzle := global_position + direction * (radius * 0.82)
	for spread: float in BARRAGE_SPREAD:
		var shot_dir := direction.rotated(spread)
		var bullet := ENEMY_BULLET.instantiate() as EnemyBullet
		bullet.global_position = muzzle
		bullet.direction = shot_dir
		bullet.speed = 380.0
		bullet.damage = 2 + _damage_bonus
		bullet.lifetime = 3.0
		bullet.beam_length = 25.0
		bullet.beam_width = 7.0
		get_tree().current_scene.add_child(bullet)
		Net.broadcast_enemy_bullet(bullet.global_position, bullet.direction,
			bullet.speed, bullet.damage, bullet.burn, bullet.freeze,
			bullet.lifetime, bullet.beam_length, bullet.beam_width)


func _fire_missile_pair(aim_angle: float) -> void:
	Game.sfx("charge", -15.0, 0.78, 0.9)
	for side: float in [-1.0, 1.0]:
		var muzzle_offset := Vector2(-radius * 0.12, side * radius * 0.58).rotated(rotation)
		var direction := Vector2.from_angle(aim_angle)
		var missile := BOSS_MISSILE.instantiate() as BossMissile
		missile.global_position = global_position + muzzle_offset
		missile.direction = direction
		missile.speed = 195.0
		missile.turn_rate = 0.85
		missile.damage = 5 + _damage_bonus
		missile.lifetime = 7.0
		get_tree().current_scene.add_child(missile)
		Net.broadcast_boss_missile(missile.global_position, direction,
			missile.speed, missile.turn_rate, missile.lifetime)


func _handle_collisions() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider()
		if other == null or not is_instance_valid(other):
			continue
		if other.is_in_group("player"):
			if _contact_timer <= 0.0 and other.has_method("take_damage"):
				other.take_damage(contact_damage)
				_contact_timer = 0.65
		elif other.is_in_group("enemy"):
			if other.has_method("apply_push"):
				other.apply_push(-collision.get_normal() * 120.0)
		else:
			velocity = velocity.bounce(collision.get_normal())


func take_damage(amount: float, kind: String = "normal") -> void:
	if not _net_alive or NetEnemy.report_hit(self, amount, kind):
		return
	if _slow > 0.0:
		amount *= 1.0 + 0.35 * float(Game.upg_brittle)
	hp -= maxi(1, int(round(amount)))
	_update_bar()
	_spawn_damage_number(amount, kind)
	if hp <= 0:
		_die()


func _spawn_damage_number(amount: float, kind: String) -> void:
	var number := DAMAGE_NUMBER.instantiate() as DamageNumber
	number.global_position = global_position + Vector2(
		randf_range(-radius * 0.4, radius * 0.4),
		-radius - randf_range(12.0, 45.0)
	)
	match kind:
		"crit":
			number.setup(amount, Color(1.0, 0.85, 0.2), 38)
		"burn":
			number.setup(amount, Color(1.0, 0.55, 0.15), 22)
		_:
			number.setup(amount, Color(0.82, 0.85, 0.9), 30)
	get_tree().current_scene.add_child(number)


func apply_status(burn_stacks: int, freeze_stacks: int) -> void:
	if NetEnemy.report_status(self, burn_stacks, freeze_stacks):
		return
	if burn_stacks > 0:
		_burn = maxf(_burn, 2.0 + burn_stacks * 0.5)
		_burn_damage = (0.6 + burn_stacks * 0.4) \
			* (1.0 + 0.4 * float(Game.upg_inferno))
		Game.sfx("sizzle", -23.0, 0.9, 1.15)
	if freeze_stacks > 0:
		_slow = maxf(_slow, 1.2 + freeze_stacks * 0.4)
		Game.sfx("frost", -23.0, 0.92, 1.12)


func _tick_burn(delta: float) -> void:
	if _burn <= 0.0:
		return
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = 0.4
		take_damage(_burn_damage, "burn")


func _update_bar() -> void:
	if _bar == null:
		return
	_bar.set_ratio(float(hp) / float(maxi(max_hp, 1)), Color(1.0, 0.38, 0.18))


func _die() -> void:
	if not _net_alive or NetEnemy.is_remote(self):
		return
	_net_alive = false
	var xp_amount := 350
	var drop_xp := NetEnemy.died(self, xp_amount)
	var explosion := EXPLOSION_SCENE.instantiate() as Node2D
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)
	Game.on_enemy_killed()
	_drop_upgrade_card()
	if drop_xp:
		XP_DROP.drop(get_tree(), global_position, xp_amount)
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
