extends CharacterBody2D

@export var max_hp: int = 4
@export var speed: float = 250.0
@export var lifetime: float = 5.0

var hp: int = 4
var net_id: int = 0
var _net_target := Vector2.ZERO
var _net_rot: float = 0.0
var _net_alive: bool = true
var _net_copy: bool = false
var _net_hitter: int = 0
var _age: float = 0.0
var _push := Vector2.ZERO

const NetEnemy := preload("res://scripts/net_enemy.gd")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.tscn")
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const XP_DROP := preload("res://scripts/xp_pickup.gd")

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _bar: HpBar = $HpBar


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("monster")
	add_to_group("boss_drone")
	collision_layer = 8
	collision_mask = 13
	hp = max_hp
	_update_bar()


func setup(speed_mult: float = 1.0, dmg_bonus: int = 0,
		fire_mult: float = 1.0, hp_mult: float = 1.0) -> void:
	speed *= minf(speed_mult, 1.35)
	max_hp = int(round(float(max_hp) * minf(hp_mult, 1.5)))
	hp = max_hp
	_update_bar()


func _physics_process(delta: float) -> void:
	if NetEnemy.is_remote(self):
		collision_layer = 2
		collision_mask = 0
		NetEnemy.follow(self, delta)
		_bar.global_position = global_position + Vector2(0.0, 24.0)
		_bar.global_rotation = 0.0
		return
	if Net.is_online() and not Net.is_host():
		return

	_age += delta
	var target := Net.target_player(global_position)
	if target != null:
		var offset := target.global_position - global_position
		if not offset.is_zero_approx():
			var direction := offset.normalized()
			rotation = lerp_angle(rotation, direction.angle(), clampf(7.0 * delta, 0.0, 1.0))
			velocity = direction * speed + _push
		move_and_slide()
		for index in get_slide_collision_count():
			var other := get_slide_collision(index).get_collider()
			if other != null and other.is_in_group("player"):
				_detonate(true, false)
				return
		if offset.length() <= 22.0:
			_detonate(true, false)
			return
	else:
		velocity = Vector2.ZERO
	_push = _push.move_toward(Vector2.ZERO, 500.0 * delta)
	lifetime -= delta
	if lifetime <= 0.0:
		_detonate(false, false)
	_bar.global_position = global_position + Vector2(0.0, 24.0)
	_bar.global_rotation = 0.0


func take_damage(amount: float, kind: String = "normal") -> void:
	if NetEnemy.report_hit(self, amount, kind):
		return
	hp -= maxi(1, int(round(amount)))
	_update_bar()
	_spawn_damage_number(amount)
	if hp <= 0:
		_detonate(false, true)


func apply_push(impulse: Vector2) -> void:
	_push = (_push + impulse).limit_length(360.0)


func _detonate(hit_player: bool, shot_down: bool) -> void:
	if not _net_alive:
		return
	_net_alive = false
	var xp := 10 if shot_down else 0
	var drop_xp := NetEnemy.died(self, xp)
	if shot_down:
		Game.on_enemy_killed()
		if drop_xp:
			XP_DROP.drop(get_tree(), global_position, xp)
	var blast_radius := 180.0 if hit_player else 90.0
	for candidate in get_tree().get_nodes_in_group("player"):
		var player := candidate as Node2D
		if player == null or not is_instance_valid(player):
			continue
		if player.get("_dead") == true or player.get("net_alive") == false:
			continue
		var distance := player.global_position.distance_to(global_position)
		if distance > blast_radius:
			continue
		var damage := 3 if hit_player and distance < 70.0 else 1
		if player.has_method("take_damage"):
			player.take_damage(damage)
		if player.has_method("apply_knockback"):
			var away := (player.global_position - global_position).normalized()
			player.apply_knockback(away * 220.0, 0.35)
	var explosion := EXPLOSION_SCENE.instantiate() as Node2D
	explosion.global_position = global_position
	explosion.call("setup", 1.8 if hit_player else 0.9)
	get_tree().current_scene.add_child(explosion)
	Net.broadcast_boss_drone_explosion(global_position, hit_player)
	queue_free()


func _spawn_damage_number(amount: float) -> void:
	var number := DAMAGE_NUMBER.instantiate()
	number.global_position = global_position + Vector2(0.0, -25.0)
	number.setup(amount, Color(0.82, 0.85, 0.9), 20)
	get_tree().current_scene.add_child(number)


func _update_bar() -> void:
	if _bar == null:
		return
	_bar.set_ratio(float(hp) / float(maxi(max_hp, 1)), Color(0.9, 0.55, 0.25))
