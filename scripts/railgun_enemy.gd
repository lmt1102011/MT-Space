
extends CharacterBody2D

# Railgun drone: darts around fast, then stops dead to charge a long laser.
# The first half of the charge keeps tracking the player, the second half
# locks the aim so the shot can be dodged sideways.

@export var max_hp: int = 10
@export var move_speed: float = 215.0
@export var fire_cooldown: float = 3.0
@export var charge_time: float = 1.2
@export var laser_speed: float = 3800.0
@export var laser_length: float = 190.0
@export var laser_width: float = 8.0
@export var laser_damage: int = 2
@export var contact_damage: int = 1
@export var engage_range: float = 900.0

var hp: int = 10
var _push: Vector2 = Vector2.ZERO
var _player: Node2D = null
var _cooldown: float = 0.0
var _charging: bool = false
var _charge_t: float = 0.0
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
var _redraw_acc: float = 0.0
var _ai_acc: float = 0.0
var _goal: Vector2 = Vector2.ZERO
var _cull_acc: float = 0.0
var _brain := EnemyBrain.new()
var _hull_nodes: Array = []
var _ship: Sprite2D = null
var _elite_ship: Sprite2D = null
var _tell_ring: Sprite2D = null
var _tell_line: Sprite2D = null

const SHAPES := preload("res://scripts/enemy_shapes.gd")
const NetEnemy := preload("res://scripts/net_enemy.gd")
const HULL_COLOR := SHAPES.RAILGUN_COLOR
const HULL_EDGE := SHAPES.HULL_EDGE
const HULL_SCALE := SHAPES.RAILGUN_SCALE
const MUZZLE := Vector2(SHAPES.RAILGUN_NOSE, 0.0)
const ENEMY_BULLET := preload("res://scenes/enemy_bullet.tscn")
const CHARGE_RING_TEX := preload("res://assets/charge_ring.svg")
const AIM_LINE_TEX := preload("res://assets/aim_line.svg")
const UPGRADE_DROP := preload("res://scenes/upgrade_drop.tscn")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.tscn")
const XP_DROP := preload("res://scripts/xp_pickup.gd")

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


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("monster")
	add_to_group("railgun_enemy")
	collision_layer = 8
	collision_mask = 13
	hp = max_hp
	_cooldown = randf_range(0.8, fire_cooldown)
	_build_hull()
	queue_redraw()
	_update_bar()


func _build_hull() -> void:
	# the reference drawing is used as a texture, so the ship looks exactly
	# like the artwork
	for c in _hull_nodes:
		c.queue_free()
	_hull_nodes.clear()
	_ship = SHAPES.make_ship(SHAPES.RAILGUN_TEX, HULL_SCALE)
	add_child(_ship)
	_hull_nodes.append(_ship)
	# the elite version sits behind and glows gold
	_elite_ship = SHAPES.make_ship(SHAPES.RAILGUN_TEX, HULL_SCALE)
	_elite_ship.modulate = SHAPES.ELITE_EDGE
	_elite_ship.scale = Vector2(HULL_SCALE * 1.08, HULL_SCALE * 1.08)
	_elite_ship.visible = false
	add_child(_elite_ship)
	_hull_nodes.append(_elite_ship)
	# the charge tell: a ring that grows at the nose plus a warning line
	_tell_ring = Sprite2D.new()
	_tell_ring.texture = CHARGE_RING_TEX
	_tell_ring.modulate = Color(0.9, 0.8, 1.0, 0.9)
	_tell_ring.position = MUZZLE
	_tell_ring.visible = false
	add_child(_tell_ring)
	_tell_line = Sprite2D.new()
	_tell_line.texture = AIM_LINE_TEX
	_tell_line.modulate = Color(0.75, 0.55, 1.0, 0.22)
	_tell_line.position = MUZZLE + Vector2(550.0, 0.0)
	_tell_line.scale = Vector2(1100.0 / 64.0, 1.0)
	_tell_line.visible = false
	add_child(_tell_line)


# Shows the charge tell and grows it with the charge time.
func _update_tell() -> void:
	if _tell_ring == null:
		return
	var t := clampf(_charge_t / charge_time, 0.0, 1.0)
	_tell_ring.visible = _charging
	_tell_line.visible = _charging
	if not _charging:
		return
	# the ring grows from nothing into a big circle right before the shot
	var r := 26.0 * t
	_tell_ring.scale = Vector2(r * 2.0 / 120.0, r * 2.0 / 120.0)
	_tell_ring.modulate = Color(0.9, 0.8, 1.0, 0.9 * t)
	_tell_line.modulate = Color(0.75, 0.55, 1.0, 0.22 * t)


func setup(speed_mult: float = 1.0, dmg_bonus: int = 0, fire_mult: float = 1.0, hp_mult: float = 1.0) -> void:
	move_speed *= speed_mult
	contact_damage = 1 + dmg_bonus
	fire_cooldown *= fire_mult
	max_hp = int(round(max_hp * hp_mult))
	hp = max_hp
	_update_bar()


func _update_bar() -> void:
	var t := float(hp) / float(max_hp)
	var col := Color(0.7, 0.5, 1.0, 1.0)
	if elite:
		col = Color(0.95, 0.8, 0.3)
	_bar.set_ratio(t, col)


func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	return _player


func _physics_process(delta: float) -> void:
	# on a client this enemy is only a copy of the host's one
	if NetEnemy.is_remote(self):
		# a copy of a host enemy just walks to where the host says it is
		NetEnemy.follow(self, delta)
		_bar.global_position = global_position + Vector2(0, 30.0)
		_bar.global_rotation = 0.0
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

	if _charging:
		_charge_step(delta, target)
	else:
		_fly_step(delta, target)

	if _on_screen:
		# the charge tell is a sprite, it is updated and hidden every frame
		_update_tell()
		# only redraw while something is actually animating
		var need := _burn > 0.0 or _slow > 0.0
		if need:
			_redraw_throttled(delta)
		else:
			_redraw_acc = 0.0
		_bar.global_position = global_position + Vector2(0, 36.0)
		_bar.global_rotation = 0.0


# --- normal flight --------------------------------------------------------
func _fly_step(delta: float, target: Node2D) -> void:
	if target == null:
		velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
		move_and_slide()
		return

	if Game.player_dead:
		# the player is down: stop aiming and drift about
		var stroll := _brain.wander(move_speed * 0.5, delta)
		var avoid := EnemyAI.steer(self, stroll)
		velocity = velocity.lerp(stroll + avoid, clampf(3.0 * delta, 0.0, 1.0))
		move_and_slide()
		return

	var to_player := target.global_position - global_position
	var dist := to_player.length()
	_aim_at(target, delta, 5.0)

	_push = _push.move_toward(Vector2.ZERO, 600.0 * delta)
	var move_mult := 0.45 if _slow > 0.0 else 1.0
	# the expensive steering only runs at 20Hz, movement stays smooth
	_ai_acc -= delta
	if _ai_acc <= 0.0:
		_ai_acc = 0.05
		_update_goal(target, delta, move_mult)
	velocity = velocity.lerp(_goal, clampf(6.0 * delta, 0.0, 1.0))
	move_and_slide()

	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if other and other.is_in_group("player") and other.has_method("take_damage"):
			other.take_damage(contact_damage)

	if _cooldown <= 0.0 and dist < engage_range and not Game.player_dead:
		_charging = true
		_charge_t = 0.0
		Game.sfx("charge", -12.0, 0.95, 1.06)


# --- charging: hold still, track then lock, then fire ---------------------
func _charge_step(delta: float, target: Node2D) -> void:
	if Game.player_dead:
		# the player is down: abandon the charge
		_charging = false
		_charge_t = 0.0
		_cooldown = fire_cooldown
		velocity = Vector2.ZERO
		return
	_charge_t += delta
	# first half keeps following the player, second half the aim is locked
	if _charge_t < charge_time * 0.5 and target != null:
		_aim_at(target, delta, 9.0)
	# stand still while charging
	_push = _push.move_toward(Vector2.ZERO, 600.0 * delta)
	velocity = Vector2.ZERO
	move_and_slide()
	if _charge_t >= charge_time:
		if not Game.player_dead:
			_fire_laser()
		_charging = false
		_charge_t = 0.0
		_cooldown = fire_cooldown


func _aim_at(target: Node2D, delta: float, turn: float) -> void:
	var dir := (target.global_position - global_position).angle()
	rotation = lerp_angle(rotation, dir, turn * delta)


func _fire_laser() -> void:
	var dir := Vector2.RIGHT.rotated(rotation)
	var b := ENEMY_BULLET.instantiate() as EnemyBullet
	b.global_position = global_position + dir * 50.0
	b.direction = dir
	b.speed = laser_speed
	b.lifetime = 0.9
	b.damage = laser_damage
	b.burn = _elite_burn
	b.freeze = _elite_freeze
	if _elite_crit > 0.0 and randf() < _elite_crit:
		b.damage = int(round(b.damage * 2.0))
	b.beam_length = laser_length
	b.beam_width = laser_width
	# make the hitbox as long as the beam it draws
	var cs := b.get_node("CollisionShape2D") as CollisionShape2D
	var cap := cs.shape.duplicate() as CapsuleShape2D
	cap.height = laser_length
	cap.radius = maxf(laser_width * 0.5, 3.0)
	cs.shape = cap
	get_tree().current_scene.add_child(b)
	Game.sfx("laser", -8.0, 0.9, 1.1)


func _update_goal(target: Node2D, delta: float, move_mult: float) -> void:
	var desired := _brain.move(global_position, target.global_position, move_speed * move_mult, delta)
	var avoid := EnemyAI.steer(self, desired)
	var dodge := EnemyAI.danger_steer(self, move_speed * move_mult)
	var goal := desired + avoid + dodge + _push
	if goal.length() > move_speed * 1.6:
		goal = goal.normalized() * move_speed * 1.6
	_goal = goal


func _cull(delta: float) -> void:
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


func _redraw_throttled(delta: float) -> void:
	_redraw_acc -= delta
	if _redraw_acc <= 0.0:
		_redraw_acc = 1.0 / 20.0
		queue_redraw()


func apply_push(impulse: Vector2) -> void:
	_push += impulse
	_push = _push.limit_length(320.0)


func apply_status(burn_stacks: int, freeze_stacks: int) -> void:
	if burn_stacks > 0:
		_burn = maxf(_burn, 2.0 + burn_stacks * 0.5)
		_burn_dmg = 0.6 + burn_stacks * 0.4
		Game.sfx("sizzle", -23.0, 0.9, 1.15)
	if freeze_stacks > 0:
		_slow = maxf(_slow, 1.2 + freeze_stacks * 0.4)
		Game.sfx("frost", -23.0, 0.92, 1.12)


func _tick_status(delta: float) -> void:
	if _burn > 0.0:
		_burn -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.4
			take_damage(_burn_dmg, "burn")
	if _slow > 0.0:
		_slow -= delta


func _spawn_damage_number(amount: float, kind: String) -> void:
	var n := DAMAGE_NUMBER.instantiate() as DamageNumber
	n.global_position = global_position + Vector2(randf_range(-24.0, 24.0), randf_range(-36.0, -12.0))
	match kind:
		"crit":
			n.setup(amount, Color(1.0, 0.85, 0.2), 34)
		"burn":
			n.setup(amount, Color(1.0, 0.55, 0.15), 18)
		_:
			n.setup(amount, Color(0.82, 0.85, 0.9), 22)
	get_tree().current_scene.add_child(n)


func take_damage(amount: float, kind: String = "normal") -> void:
	# the host decides who dies, a client just reports the hit
	if NetEnemy.report_hit(self, amount, kind):
		return
	hp -= int(round(amount))
	_update_bar()
	_spawn_damage_number(amount, kind)
	if hp <= 0:
		_die()
	else:
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(2, 2, 2, 1), 0.05)
		tw.tween_property(self, "modulate", Color.WHITE, 0.12)


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
	laser_speed *= float(mods["bullet_speed"])
	_elite_burn = int(mods["burn"])
	_elite_freeze = int(mods["freeze"])
	_elite_crit = float(mods["crit"])
	_elite_regen = int(mods["regen"])
	_add_elite_mark()
	if _elite_ship != null:
		_elite_ship.visible = true
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
	if _owned_cards.is_empty() or randf() >= 0.5:
		return
	var card: Dictionary = _owned_cards[randi() % _owned_cards.size()]
	var d := UPGRADE_DROP.instantiate() as UpgradeDrop
	d.card = card
	d.global_position = global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 20.0)
	get_tree().current_scene.add_child(d)


func _die() -> void:
	# the host owns the death, the client waits for the message
	if NetEnemy.is_remote(self):
		queue_free()
		return
	var drop := NetEnemy.died(self, 3)
	var boom := preload("res://scenes/explosion.tscn").instantiate() as Explosion
	boom.global_position = global_position
	get_tree().current_scene.add_child(boom)
	Game.sfx("crunch", -15.0, 0.85, 1.18)
	if Game.upg_lifesteal:
		var pl := get_tree().get_first_node_in_group("player")
		if pl and pl.has_method("heal"):
			pl.heal(1)
	if elite:
		drop_elite_card()
	if drop:
		drop_xp(3)
	queue_free()


func drop_xp(amount: int) -> void:
	XP_DROP.drop(get_tree(), global_position, amount)


# -------------------------------------------------------------------------
func _draw() -> void:
	# the hull is a sprite, so only the status auras are drawn here - and
	# only while a status is active. The charge tell is a sprite too, so it
	# can be hidden the moment the shot is fired.

	# --- status auras ---
	if _burn > 0.0:
		draw_circle(Vector2.ZERO, 34.0, Color(1.0, 0.45, 0.1, 0.18 + 0.08 * sin(_flame_time * 18.0)))
	if _slow > 0.0:
		draw_circle(Vector2.ZERO, 34.0, Color(0.4, 0.8, 1.0, 0.18))

