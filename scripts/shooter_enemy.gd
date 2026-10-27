extends CharacterBody2D

@export var max_hp: int = 8
@export var orbit_radius: float = 300.0
@export var move_speed: float = 130.0
@export var fire_cooldown: float = 1.6
@export var bullet_speed: float = 420.0
@export var contact_damage: int = 1

var hp: int = 8
var _push: Vector2 = Vector2.ZERO
var _player: Node2D = null
var _cooldown: float = 0.0
var _orbit_dir: float = 1.0
var _thrust: float = 0.0
var _flame_time: float = 0.0
var _burn: float = 0.0
var _burn_tick: float = 0.0
var _burn_dmg: float = 0.0
var _slow: float = 0.0
var elite: bool = false
var _owned_cards: Array = []
var _elite_burn: int = 0
var _elite_freeze: int = 0
var _elite_crit: float = 0.0
var _elite_regen: int = 0
var _elite_regen_acc: float = 0.0
var _on_screen: bool = true
var _ai_acc: float = 0.0
var _goal: Vector2 = Vector2.ZERO
var _cull_acc: float = 0.0
var _brain := EnemyBrain.new()

const ENEMY_BULLET := preload("res://scenes/enemy_bullet.tscn")
const NetEnemy := preload("res://scripts/net_enemy.gd")
const UPGRADE_DROP := preload("res://scenes/upgrade_drop.tscn")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.tscn")
const XP_DROP := preload("res://scripts/xp_pickup.gd")
const ELITE_DROP_CHANCE := 0.5
const STATUS_VISUAL := preload("res://scripts/status_effect_visual.gd")

# --- network ---------------------------------------------------------------
# On the host this enemy thinks for itself. On a client it is only a copy:
# the position comes from the host and the damage is reported back to it.
var net_id: int = 0
var _net_target: Vector2 = Vector2.ZERO
var _net_rot: float = 0.0
var _net_alive: bool = true
# true on a client: this enemy is only a copy of the one on the host
var _net_copy: bool = false
# the peer that hit this enemy last, they earn the xp
var _net_hitter: int = 0

@onready var _bar: HpBar = $HpBar
@onready var _sprite: Sprite2D = $Sprite2D

var _flame_out: Polygon2D = null
var _flame_in: Polygon2D = null
var _status_visual: Node2D


func _make_flame(width: float) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(0, width), Vector2(-1, 0), Vector2(0, -width)])
	add_child(poly)
	return poly


# The flame is a node: it is animated by moving and scaling it, so nothing is
# re-drawn every frame.
func _update_flame() -> void:
	if _flame_out == null:
		return
	var ang := _sprite.rotation
	var back := Vector2(-14, 0).rotated(ang)
	var flicker := 0.8 + sin(_flame_time * 40.0) * 0.2
	var length := (5.0 + _thrust * 20.0) * flicker
	var lit := _thrust > 0.02
	_flame_out.position = back
	_flame_out.rotation = ang
	_flame_out.scale = Vector2(length, 1.0)
	_flame_out.color = Color(1.0, 0.55, 0.3, 0.35 + 0.5 * _thrust)
	_flame_out.visible = lit
	_flame_in.position = back
	_flame_in.rotation = ang
	_flame_in.scale = Vector2(length * 0.55, 1.0)
	_flame_in.color = Color(1.0, 0.9, 0.7, 0.6 + 0.4 * _thrust)
	_flame_in.visible = lit


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("monster")
	hp = max_hp
	_orbit_dir = 1.0 if randf() < 0.5 else -1.0
	_cooldown = randf_range(0.4, fire_cooldown)
	_flame_out = _make_flame(4.0)
	_flame_in = _make_flame(2.0)
	_status_visual = STATUS_VISUAL.new()
	_status_visual.set("radius", 31.0)
	_status_visual.z_index = 2
	add_child(_status_visual)
	_update_bar()


func setup(speed_mult: float = 1.0, dmg_bonus: int = 0, fire_mult: float = 1.0, hp_mult: float = 1.0) -> void:
	move_speed *= speed_mult
	contact_damage = 1 + dmg_bonus
	fire_cooldown *= fire_mult
	max_hp = int(round(max_hp * hp_mult))
	hp = max_hp
	_update_bar()


func _update_bar() -> void:
	var t := float(hp) / float(max_hp)
	var col := Color(0.9, 0.35, 0.35, 1.0)
	if elite:
		col = Color(0.95, 0.8, 0.3)
	_bar.set_ratio(t, col)


func _get_player() -> Node2D:
	if Net.is_online() and not Net.is_host():
		return null
	# Re-evaluate every frame so the nearest living player gets priority.
	_player = Net.target_player(global_position)
	return _player


func _physics_process(delta: float) -> void:
	# on a client this enemy is only a copy of the host's one
	if NetEnemy.is_remote(self):
		# a copy of a host enemy just walks to where the host says it is
		NetEnemy.follow(self, delta)
		_tick_status(delta, false)
		var net_velocity: Vector2 = get_meta("net_velocity", Vector2.ZERO)
		_thrust = move_toward(_thrust,
			clampf(net_velocity.length() / maxf(move_speed, 1.0), 0.0, 1.0), delta * 8.0)
		_flame_time += delta
		_update_flame()
		_bar.place_at(global_position + Vector2(0, 30.0))
		return
	_cooldown -= delta
	_flame_time += delta
	_cull(delta)
	_tick_status(delta)
	if _elite_regen > 0 and hp < max_hp:
		_elite_regen_acc += delta
		if _elite_regen_acc >= 6.0 / float(_elite_regen):
			_elite_regen_acc = 0.0
			hp += 1
			_update_bar()
	var target := _get_player()

	if target:
		var to_player := target.global_position - global_position
		var dist := to_player.length()
		var dir := to_player / maxf(dist, 0.001)

		if not Net.any_player_alive():
			# the player is down: stop aiming and just drift about
			_push = _push.move_toward(Vector2.ZERO, 600.0 * delta)
			var stroll := _brain.wander(move_speed * 0.5, delta)
			var avoid := EnemyAI.steer(self, stroll)
			velocity = velocity.lerp(stroll + avoid + _push, clampf(3.0 * delta, 0.0, 1.0))
			move_and_slide()
			_thrust = move_toward(_thrust, 0.0, 4.0 * delta)
			_sprite.rotation += 0.7 * delta
		else:
			# aim at player (only lead the shot when roughly facing them)
			_sprite.rotation = lerp_angle(_sprite.rotation, dir.angle(), 6.0 * delta)

			_push = _push.move_toward(Vector2.ZERO, 600.0 * delta)
			# the expensive steering only runs at 20Hz, movement stays smooth
			_ai_acc -= delta
			if _ai_acc <= 0.0:
				_ai_acc = 0.05 if _on_screen else 0.16
				_update_goal(target, delta)
			velocity = velocity.lerp(_goal, clampf(6.0 * delta, 0.0, 1.0))
			move_and_slide()
			_thrust = move_toward(_thrust, clampf(velocity.length() / maxf(move_speed, 1.0), 0.0, 1.0), 5.0 * delta)

			for i in get_slide_collision_count():
				var c := get_slide_collision(i)
				var other := c.get_collider()
				if other and other.is_in_group("player"):
					if other.has_method("take_damage"):
						other.take_damage(contact_damage)

			# only fire when facing the player and roughly in range (feels more human)
			var facing := Vector2.RIGHT.rotated(_sprite.rotation).dot(dir)
			if _cooldown <= 0.0 and dist < 640.0 and facing > 0.9:
				_fire(dir)
				_cooldown = fire_cooldown
	else:
		_thrust = move_toward(_thrust, 0.0, 4.0 * delta)
		velocity = _push
		move_and_slide()

	_update_flame()

	if _on_screen:
		_bar.place_at(global_position + Vector2(0, 32.0))


func _update_goal(target: Node2D, delta: float) -> void:
	var move_mult := 0.45 if _slow > 0.0 else 1.0
	var desired := _brain.move(global_position, target.global_position, move_speed * move_mult, delta)
	var avoid := EnemyAI.steer(self, desired)
	var dodge := EnemyAI.danger_steer(self, move_speed * move_mult)
	var goal := desired + avoid + dodge + _push
	if goal.length() > move_speed * 1.6:
		goal = goal.normalized() * move_speed * 1.6
	_goal = goal


func _cull(delta: float) -> void:
	# off-screen enemies are not rendered at all (the minimap still lists them)
	_cull_acc -= delta
	if _cull_acc > 0.0:
		return
	_cull_acc = 0.1
	var on := ViewCull.is_on_screen(self)
	if on == _on_screen:
		return
	_on_screen = on
	visible = on
	if on:
		queue_redraw()


func _fire(dir: Vector2) -> void:
	Game.sfx("shoot", -22.0, 0.92, 1.08)
	var b := Pool.acquire(ENEMY_BULLET,
		get_tree().current_scene) as EnemyBullet
	if b == null:
		return
	b.hide()
	b.global_position = global_position + dir * 26.0
	b.direction = dir
	b.speed = bullet_speed
	b.damage = contact_damage
	b.burn = _elite_burn
	b.freeze = _elite_freeze
	b.prepare_for_flight()
	if _elite_crit > 0.0 and randf() < _elite_crit:
		b.damage = int(round(b.damage * 2.0))
	Net.broadcast_enemy_bullet(b.global_position, b.direction, b.speed, b.damage,
		b.burn, b.freeze, b.lifetime, b.beam_length, b.beam_width)


func apply_push(impulse: Vector2) -> void:
	_push += impulse
	_push = _push.limit_length(320.0)


func apply_status(burn_stacks: int, freeze_stacks: int) -> void:
	NetEnemy.report_status(self, burn_stacks, freeze_stacks)
	if burn_stacks > 0:
		_burn = maxf(_burn, 2.0 + burn_stacks * 0.5)
		_burn_dmg = (0.6 + burn_stacks * 0.4) * (1.0 + 0.4 * float(Game.upg_inferno))
		Game.sfx("sizzle", -23.0, 0.9, 1.15)
	if freeze_stacks > 0:
		_slow = maxf(_slow, 1.2 + freeze_stacks * 0.4)
		Game.sfx("frost", -23.0, 0.92, 1.12)


func _tick_status(delta: float, apply_burn_damage: bool = true) -> void:
	if _burn > 0.0:
		_burn -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.4
			if apply_burn_damage:
				take_damage(_burn_dmg, "burn")
	if _slow > 0.0:
		_slow -= delta
	_status_visual.call("set_status", _burn > 0.0, _slow > 0.0)


func _spawn_damage_number(amount: float, kind: String) -> void:
	var n := Pool.acquire(DAMAGE_NUMBER, get_tree().current_scene) as DamageNumber
	if n == null:
		return
	n.global_position = global_position + Vector2(randf_range(-24.0, 24.0), randf_range(-36.0, -12.0))
	match kind:
		"crit":
			n.setup(amount, Color(1.0, 0.85, 0.2), 34)
		"burn":
			n.setup(amount, Color(1.0, 0.55, 0.15), 18)
		_:
			n.setup(amount, Color(0.82, 0.85, 0.9), 22)


func take_damage(amount: float, kind: String = "normal") -> void:
	# the host decides who dies, a client just reports the hit
	if NetEnemy.report_hit(self, amount, kind):
		return
	# Brittle: frozen targets are softer
	if _slow > 0.0:
		amount *= 1.0 + 0.35 * float(Game.upg_brittle)
	Game.record_damage(mini(maxi(int(round(amount)), 0), maxi(hp, 0)))
	hp -= int(round(amount))
	_update_bar()
	_spawn_damage_number(amount, kind)
	if hp <= 0:
		_die()
	else:
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color(3, 3, 3, 1), 0.05)
		tw.tween_property(_sprite, "modulate", Color(1, 0.15, 0.15, 1), 0.12)


func make_elite(cards: int) -> void:
	elite = true
	add_to_group("elite")
	var pool := CardDB.passives()
	pool.shuffle()
	for i in mini(cards, pool.size()):
		_owned_cards.append(pool[i])
	var mods := EliteCards.mods_for(_owned_cards)
	max_hp = int(roundf(max_hp * 2.5)) + int(mods["hp_bonus"])
	hp = max_hp
	contact_damage = int(roundf(contact_damage * float(mods["damage"]))) + 1
	move_speed *= float(mods["move_speed"])
	fire_cooldown /= maxf(float(mods["fire_rate"]), 0.01)
	bullet_speed *= float(mods["bullet_speed"])
	_elite_burn = int(mods["burn"])
	_elite_freeze = int(mods["freeze"])
	_elite_crit = float(mods["crit"])
	_elite_regen = int(mods["regen"])
	_sprite.modulate = Color(1.0, 0.85, 0.4, 1.0)
	_add_elite_mark()
	_update_bar()


func apply_network_elite(network_max_hp: int) -> void:
	if not elite:
		elite = true
		add_to_group("elite")
		_sprite.modulate = Color(1.0, 0.85, 0.4, 1.0)
		_add_elite_mark()
	max_hp = maxi(network_max_hp, 1)
	_update_bar()


func _add_elite_mark() -> void:
	var mark := Polygon2D.new()
	mark.polygon = PackedVector2Array([
		Vector2(0, -7), Vector2(6, 5), Vector2(0, 1), Vector2(-6, 5)
	])
	mark.color = Color(0.95, 0.8, 0.3)
	mark.position = Vector2(0, -18)
	mark.z_index = 10
	_bar.add_child(mark)
	var tw := create_tween().set_loops()
	tw.tween_property(mark, "modulate:a", 0.35, 0.5)


func drop_elite_card() -> void:
	if _owned_cards.is_empty() or randf() >= ELITE_DROP_CHANCE:
		return
	var card: Dictionary = _owned_cards[randi() % _owned_cards.size()]
	if Net.is_host() and int(_net_hitter) > 1:
		Net.send_elite_card(int(_net_hitter), global_position, str(card.get("id", "")))
		return
	var d := UPGRADE_DROP.instantiate() as UpgradeDrop
	d.card = card
	d.global_position = global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 20.0)
	get_tree().current_scene.add_child(d)


func _die() -> void:
	# the host owns the death, the client waits for the message
	if NetEnemy.is_remote(self):
		queue_free()
		return
	var xp := 15
	if elite:
		xp *= 3
	var drop := NetEnemy.died(self, xp)
	var boom := Pool.acquire(preload("res://scenes/explosion.tscn"),
		get_tree().current_scene) as Explosion
	if boom == null:
		return
	boom.global_position = global_position
	Game.sfx("crunch", -15.0, 0.85, 1.18)
	if Game.upg_lifesteal:
		var pl := get_tree().get_first_node_in_group("player")
		if pl and pl.has_method("heal"):
			pl.heal(1)
	boom.setup(1.0, Color(1.0, 0.55, 0.3))
	Game.combat_impact(0.8)
	Game.on_enemy_killed("shooter")
	if elite:
		drop_elite_card()
	if drop:
		drop_xp(xp)
	queue_free()


func drop_xp(amount: int) -> void:
	XP_DROP.drop(get_tree(), global_position, amount)


func _draw() -> void:
	pass
