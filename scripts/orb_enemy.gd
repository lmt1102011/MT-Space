extends CharacterBody2D

const ORB_PROJECTILE := preload("res://scenes/orb_projectile.tscn")
const XP_DROP := preload("res://scripts/xp_pickup.gd")
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.tscn")
const NetEnemy := preload("res://scripts/net_enemy.gd")
const STATUS_VISUAL := preload("res://scripts/status_effect_visual.gd")

@export var max_hp: int = 18
@export var move_speed: float = 72.0
@export var charge_time: float = 2.8
@export var orb_speed: float = 340.0
@export var orb_radius: float = 56.0
@export var orb_lifetime: float = 6.5
@export var contact_damage: int = 1
@export var radius: float = 34.0

var hp: int = 18
var net_id: int = 0
var _net_target := Vector2.ZERO
var _net_rot: float = 0.0
var _net_alive: bool = true
var _net_copy: bool = false
var _net_hitter: int = 0
var _player: Node2D = null
var _charge := 0.0
var _cooldown := 0.8
var _burn := 0.0
var _burn_tick := 0.0
var _burn_damage := 0.0
var _slow := 0.0
var _push := Vector2.ZERO
var _ai_acc := 0.0
var _contact_t := 0.0
var _brain := EnemyBrain.new()
var elite := false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _bar: HpBar = $HpBar
var _charge_art: Sprite2D = null
var _status_visual: Node2D


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("monster")
	# Full gameplay collision: player, walls and other shapes/enemies.
	collision_layer = 8
	collision_mask = 13
	hp = max_hp
	_charge_art = get_node_or_null("ChargeArt") as Sprite2D
	if _charge_art != null:
		_charge_art.z_index = -1
		_charge_art.modulate = Color(0.35, 1.0, 0.75, 0.0)
	_status_visual = STATUS_VISUAL.new()
	_status_visual.set("radius", radius)
	_status_visual.z_index = 2
	add_child(_status_visual)
	_update_bar()


func setup(speed_mult: float = 1.0, _dmg_bonus: int = 0,
		_fire_mult: float = 1.0, hp_mult: float = 1.0) -> void:
	move_speed *= speed_mult
	contact_damage = 1 + _dmg_bonus
	max_hp = int(round(max_hp * hp_mult))
	hp = max_hp
	_update_bar()


func _physics_process(delta: float) -> void:
	if NetEnemy.is_remote(self):
		collision_layer = 2
		collision_mask = 0
		NetEnemy.follow(self, delta)
		_tick_status(delta, false)
		_bar.global_position = global_position + Vector2(0, radius + 8.0)
		_bar.global_rotation = 0.0
		return
	if Net.is_online() and not Net.is_host():
		return
	_tick_status(delta)
	_contact_t = maxf(_contact_t - delta, 0.0)
	_player = Net.target_player(global_position)
	if _player != null:
		var to_player := _player.global_position - global_position
		var dir := to_player.normalized()
		_sprite.rotation = lerp_angle(_sprite.rotation, dir.angle(), 4.0 * delta)
		var move_mult := 0.55 if _slow > 0.0 else 1.0
		_push = _push.move_toward(Vector2.ZERO, 700.0 * delta)
		var desired := _brain.move(global_position, _player.global_position,
			move_speed * move_mult, delta)
		var avoid := EnemyAI.steer(self, desired)
		velocity = velocity.lerp(desired + avoid + _push,
			clampf(6.0 * delta, 0.0, 1.0))
		move_and_slide()
		_handle_collisions()
		_cooldown -= delta
		if _cooldown <= 0.0:
			_charge += delta
			if _charge >= charge_time:
				_launch_orb(dir)
				_charge = 0.0
				_cooldown = 1.0
	else:
		_push = _push.move_toward(Vector2.ZERO, 700.0 * delta)
		velocity = velocity.move_toward(Vector2.ZERO, 90.0 * delta)
		move_and_slide()
	_update_charge_art()
	_bar.global_position = global_position + Vector2(0, radius + 8.0)
	_bar.global_rotation = 0.0


func _update_charge_art() -> void:
	if _charge_art == null:
		return
	var t := clampf(_charge / charge_time, 0.0, 1.0)
	_charge_art.visible = t > 0.0
	_charge_art.modulate.a = 0.12 + 0.55 * t
	_charge_art.scale = Vector2.ONE * lerpf(0.12, 0.52, t)
	_charge_art.rotation += get_physics_process_delta_time() * 1.4


func _handle_collisions() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider()
		if other == null or not is_instance_valid(other):
			continue
		if other.is_in_group("player"):
			if _contact_t <= 0.0 and other.has_method("take_damage"):
				other.take_damage(contact_damage)
				_contact_t = 0.5
			continue
		if other.is_in_group("enemy"):
			if other.has_method("apply_push"):
				other.apply_push(-collision.get_normal() * 90.0)
			continue
		# Walls/obstacles reflect the steering direction instead of letting the
		# brain push the orb through them.
		velocity = velocity.bounce(collision.get_normal())
		_push = velocity * 0.25


func _launch_orb(dir: Vector2) -> void:
	Game.sfx("charge", -17.0, 0.68, 0.78)
	var orb := Pool.acquire(ORB_PROJECTILE,
		get_tree().current_scene) as OrbProjectile
	if orb == null:
		return
	orb.global_position = global_position + dir * 30.0
	orb.direction = dir
	orb.speed = orb_speed
	orb.radius = orb_radius
	orb.lifetime = orb_lifetime
	# Fractional contact damage is accumulated by Player, so it really deals
	# 0.1 every 0.25s instead of rounding every hit up to one HP.
	orb.damage = 0.1 * (1.0 + 0.15 * float(maxi(Game.wave - 1, 0)))
	orb.knockback = 360.0
	if Net.is_online() and Net.is_host():
		Net.broadcast_orb(global_position + dir * 30.0, dir, orb_speed,
			orb_radius, orb_lifetime)


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


func _spawn_damage_number(amount: float, kind: String) -> void:
	var number := Pool.acquire(DAMAGE_NUMBER,
		get_tree().current_scene) as DamageNumber
	if number == null:
		return
	number.global_position = global_position + Vector2(
		randf_range(-24.0, 24.0), -radius - randf_range(8.0, 34.0)
	)
	match kind:
		"crit":
			number.setup(amount, Color(1.0, 0.85, 0.2), 34)
		"burn":
			number.setup(amount, Color(1.0, 0.55, 0.15), 18)
		_:
			number.setup(amount, Color(0.82, 0.85, 0.9), 22)


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


func apply_network_elite(network_max_hp: int) -> void:
	elite = true
	max_hp = maxi(network_max_hp, 1)
	_sprite.modulate = Color(1.0, 0.8, 0.35)
	_update_bar()


func _update_bar() -> void:
	if _bar == null:
		return
	_bar.set_ratio(float(hp) / float(maxi(max_hp, 1)),
		Color(1.0, 0.8, 0.25) if elite else Color(0.3, 0.95, 0.75))


func _die() -> void:
	if NetEnemy.is_remote(self):
		queue_free()
		return
	_net_alive = false
	var xp := 20
	var drop := NetEnemy.died(self, xp)
	var boom := Pool.acquire(EXPLOSION_SCENE,
		get_tree().current_scene) as Explosion
	if boom == null:
		return
	boom.global_position = global_position
	boom.setup(1.0, Color(0.55, 1.0, 0.55))
	Game.combat_impact(0.8)
	Game.on_enemy_killed()
	if drop:
		XP_DROP.drop(get_tree(), global_position, xp)
	queue_free()
