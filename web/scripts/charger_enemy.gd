
extends CharacterBody2D

# Charger: closes in, winds up for 1.5s (rings of light collapse into it),
# then dashes straight and knocks the player flying with a short stun.
# It always faces the player - except while dashing, when the direction is
# locked so the player can dodge sideways.

@export var max_hp: int = 14
@export var move_speed: float = 170.0
@export var charge_time: float = 1.5
@export var dash_range: float = 340.0
@export var dash_speed: float = 1500.0
@export var dash_time: float = 0.30
@export var dash_cooldown: float = 2.2   # tired afterwards, cannot dash again yet
@export var knockback_force: float = 640.0
@export var stun_time: float = 0.5
@export var contact_damage: int = 1
@export var dash_damage: int = 1        # the knockback is the real punish, not the hit
@export var radius: float = 26.0

enum State { CHASE, CHARGE, DASH }

var hp: int = 14
var _state: int = State.CHASE
var _state_t: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _push: Vector2 = Vector2.ZERO
var _player: Node2D = null
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
var _cull_acc: float = 0.0
var _brain := WebEnemyBrain.new()
var _hulls: Array = []
var _ship: Sprite2D = null
var _elite_ship: Sprite2D = null
var _drew_effects: bool = false
var _tint_winded: bool = false

const SHAPES := preload("res://scripts/enemy_shapes.gd")
const NetEnemy := preload("res://scripts/net_enemy.gd")
const HULL_COLOR := SHAPES.CHARGER_COLOR
const HULL_EDGE := SHAPES.HULL_EDGE
const HULL_SCALE := SHAPES.CHARGER_SCALE
const MUZZLE := Vector2(SHAPES.CHARGER_NOSE, 0.0)

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

@onready var _bar: WebHpBar = $HpBar


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("monster")
	add_to_group("charger_enemy")
	collision_layer = 8
	collision_mask = 13
	hp = max_hp
	_build_hull()
	queue_redraw()
	_update_bar()


func _build_hull() -> void:
	# the reference drawing is used as a texture, so the ship looks exactly
	# like the artwork
	for c in _hulls:
		c.queue_free()
	_hulls.clear()
	_ship = SHAPES.make_ship(SHAPES.CHARGER_TEX, HULL_SCALE)
	add_child(_ship)
	_hulls.append(_ship)
	# the elite version sits behind and glows gold
	_elite_ship = SHAPES.make_ship(SHAPES.CHARGER_TEX, HULL_SCALE)
	_elite_ship.modulate = SHAPES.ELITE_EDGE
	_elite_ship.scale = Vector2(HULL_SCALE * 1.08, HULL_SCALE * 1.08)
	_elite_ship.visible = false
	add_child(_elite_ship)
	_hulls.append(_elite_ship)


func setup(speed_mult: float = 1.0, dmg_bonus: int = 0, fire_mult: float = 1.0, hp_mult: float = 1.0) -> void:
	move_speed *= speed_mult
	contact_damage = 1 + dmg_bonus
	max_hp = int(roundf(max_hp * hp_mult))
	hp = max_hp
	_update_bar()


func _update_bar() -> void:
	var t := float(hp) / float(max_hp)
	var col := Color(0.45, 0.95, 0.3, 1.0)
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
	if target == null:
		velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
		move_and_slide()
		return

	_state_t += delta
	if Game.player_dead:
		# the player is down: no hunting, no charging, just ambling about
		_stroll_step(delta)
		_redraw_if_needed(delta)
		_bar.global_position = global_position + Vector2(0, radius + 18.0)
		_bar.global_rotation = 0.0
		return

	match _state:
		State.CHASE:
			_chase(delta, target)
		State.CHARGE:
			_charge(delta, target)
		State.DASH:
			_dash(delta)

	# always look at the player, except while dashing (direction is locked)
	if _state != State.DASH and not Game.player_dead:
		_face(target, delta)

	_redraw_if_needed(delta)
	_bar.global_position = global_position + Vector2(0, radius + 18.0)
	_bar.global_rotation = 0.0


func _chase(delta: float, target: Node2D) -> void:
	var to_player := target.global_position - global_position
	var dist := to_player.length()
	var dir := to_player / maxf(dist, 0.001)
	# after a dash it needs to catch its breath before lunging again
	var tired := _dash_cd > 0.0
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	var speed := move_speed * (0.45 if _slow > 0.0 else 1.0)
	if tired:
		speed *= 0.4
	var goal := dir * speed
	# gentle separation so they do not stack on top of each other
	goal += WebEnemyAI.steer(self, dir * speed) * 0.6
	_push = _push.move_toward(Vector2.ZERO, 600.0 * delta)
	velocity = velocity.lerp(goal + _push, clampf(5.0 * delta, 0.0, 1.0))
	move_and_slide()

	if dist <= dash_range and not tired and not Game.player_dead:
		_state = State.CHARGE
		_state_t = 0.0
		Game.sfx("charge", -12.0, 0.95, 1.06)


# Once the player is down the charger just wanders about, like everything else.
func _stroll_step(delta: float) -> void:
	_push = _push.move_toward(Vector2.ZERO, 600.0 * delta)
	var stroll := _brain.wander(move_speed * 0.45, delta)
	var avoid := WebEnemyAI.steer(self, stroll)
	velocity = velocity.lerp(stroll + avoid + _push, clampf(3.0 * delta, 0.0, 1.0))
	move_and_slide()


func _charge(delta: float, target: Node2D) -> void:
	# stand still and wind up
	velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
	_push = _push.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()
	if _state_t >= charge_time:
		_state = State.DASH
		_state_t = 0.0
		_dash_dir = Vector2.RIGHT.rotated(rotation)
		Game.sfx("dash", -7.0, 0.92, 1.1)


func _dash(delta: float) -> void:
	# stop hitting a player that is already down
	if Game.player_dead:
		_state = State.CHASE
		_state_t = 0.0
		velocity = Vector2.ZERO
		return
	velocity = _dash_dir * dash_speed
	move_and_slide()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if other and other.is_in_group("player"):
			if other.has_method("apply_knockback"):
				other.apply_knockback(_dash_dir * knockback_force, stun_time)
			if other.has_method("take_damage"):
				other.take_damage(dash_damage)
	if _state_t >= dash_time:
		_state = State.CHASE
		_state_t = 0.0
		_dash_cd = dash_cooldown
		velocity = _dash_dir * 120.0


func _face(target: Node2D, delta: float) -> void:
	var dir := (target.global_position - global_position).angle()
	rotation = lerp_angle(rotation, dir, 7.0 * delta)


func _cull(delta: float) -> void:
	_cull_acc -= delta
	if _cull_acc > 0.0:
		return
	_cull_acc = 0.1
	var on := WebViewCull.is_on_screen(self)
	if on == _on_screen:
		return
	_on_screen = on
	visible = on
	if on:
		queue_redraw()


func _redraw_if_needed(delta: float) -> void:
	# only redraw while something is actually animating
	var need := _state == State.CHARGE or _state == State.DASH \
		or _burn > 0.0 or _slow > 0.0 or _dash_cd > 0.0
	if need:
		_drew_effects = true
		_redraw_throttled(delta)
	else:
		_redraw_acc = 0.0
		if _drew_effects:
			# the last frame still showed the tell, clear it now
			_drew_effects = false
			queue_redraw()


func _redraw_throttled(delta: float) -> void:
	_redraw_acc -= delta
	if _redraw_acc <= 0.0:
		_redraw_acc = 1.0 / 20.0
		queue_redraw()


func apply_push(impulse: Vector2) -> void:
	if _state == State.DASH:
		return
	_push += impulse
	_push = _push.limit_length(320.0)


func apply_status(burn_stacks: int, freeze_stacks: int) -> void:
	if burn_stacks > 0:
		_burn = maxf(_burn, 2.0 + burn_stacks * 0.5)
		_burn_dmg = (0.6 + burn_stacks * 0.4) * (1.0 + 0.4 * float(Game.upg_inferno))
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
	var n := DAMAGE_NUMBER.instantiate() as WebDamageNumber
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
	# Brittle: frozen targets are softer
	if _slow > 0.0:
		amount *= 1.0 + 0.35 * float(Game.upg_brittle)
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
	var pool := WebCardDB.passives()
	pool.shuffle()
	for i in mini(cards, pool.size()):
		_owned_cards.append(pool[i])
	var mods := WebEliteCards.mods_for(_owned_cards)
	max_hp = int(roundf(max_hp * 2.5)) + int(mods["hp_bonus"])
	hp = max_hp
	contact_damage = int(roundf(contact_damage * float(mods["damage"]))) + 1
	move_speed *= float(mods["move_speed"])
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
	var d := UPGRADE_DROP.instantiate() as WebUpgradeDrop
	d.card = card
	d.global_position = global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 20.0)
	get_tree().current_scene.add_child(d)


func _die() -> void:
	# the host owns the death, the client waits for the message
	if NetEnemy.is_remote(self):
		queue_free()
		return
	var drop := NetEnemy.died(self, 3)
	var boom := preload("res://scenes/explosion.tscn").instantiate() as WebExplosion
	boom.global_position = global_position
	get_tree().current_scene.add_child(boom)
	if Game.upg_lifesteal:
		var pl := get_tree().get_first_node_in_group("player")
		if pl and pl.has_method("heal"):
			pl.heal(1)
	Game.on_enemy_killed()
	if elite:
		drop_elite_card()
	if drop:
		drop_xp(3)
	queue_free()


func drop_xp(amount: int) -> void:
	XP_DROP.drop(get_tree(), global_position, amount)


# -------------------------------------------------------------------------
func _set_hull_tint(winded: bool) -> void:
	if _tint_winded == winded:
		return
	_tint_winded = winded
	var col := HULL_COLOR.darkened(0.22) if winded else HULL_COLOR
	if _ship != null:
		_ship.modulate = col


func _draw() -> void:
	# the hull is a Polygon2D child (mesh cached once) so only the tells and
	# auras are drawn here - and only while they are active.
	if _dash_cd > 0.0:
		_set_hull_tint(true)
	else:
		_set_hull_tint(false)

	# --- charge tell: rings fade in while shrinking into the enemy ---
	if _state == State.CHARGE:
		var t := clampf(_state_t / charge_time, 0.0, 1.0)
		for i in 3:
			var p := clampf(t * 1.6 - float(i) * 0.28, 0.0, 1.0)
			var r := lerpf(78.0, 10.0, p)
			var a := lerpf(0.04, 0.5, p)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(HULL_COLOR.r, HULL_COLOR.g, HULL_COLOR.b, a), 3.0, true)

	# --- dash: wind streaming past the body + motion blur ---
	if _state == State.DASH:
		# air lines: parallel to the travel direction, rushing from in front of
		# the nose to behind the tail (this is what real speed lines look like)
		var scroll := _flame_time * 9.0
		for i in 9:
			var side := 1.0 if i % 2 == 0 else -1.0
			var lane := side * (19.0 + fmod(float(i) * 0.37, 1.0) * 24.0)
			var seg := 22.0 + fmod(float(i) * 0.61, 1.0) * 30.0
			var t := fmod(scroll * (0.85 + 0.04 * float(i)) + float(i) * 0.19, 1.0)
			var x := lerpf(64.0, -80.0, t)
			var wobble := sin(TAU * t + float(i)) * 1.6
			draw_line(Vector2(x - seg, lane + wobble), Vector2(x, lane + wobble),
				Color(0.88, 1.0, 0.92, 0.30 * sin(PI * t)), 2.0, true)
		# the body itself smears backwards
		for i in 4:
			var off := -10.0 - float(i) * 18.0
			var h := 13.0 - float(i) * 2.6
			draw_colored_polygon(PackedVector2Array([
				Vector2(off - 26.0, -h), Vector2(off, 0.0), Vector2(off - 26.0, h)
			]), Color(HULL_COLOR.r, HULL_COLOR.g, HULL_COLOR.b, 0.34 - float(i) * 0.07))
		# air bunching up in front of the nose
		draw_arc(Vector2(34.0, 0.0), 19.0, -1.15, 1.15, 20,
			Color(0.9, 1.0, 0.95, 0.2), 2.0, true)

	# --- winded: panting puffs while it recovers ---
	if _dash_cd > 0.0 and _state == State.CHASE:
		for i in 3:
			var ph := fmod(_flame_time * 1.6 + float(i) * 0.33, 1.0)
			draw_circle(Vector2(-10.0 + float(i) * 12.0, -20.0 - ph * 16.0),
				4.0 + ph * 7.0, Color(0.8, 1.0, 0.85, 0.22 * (1.0 - ph)))

	# --- status auras ---
	if _burn > 0.0:
		draw_circle(Vector2.ZERO, 30.0, Color(1.0, 0.45, 0.1, 0.18 + 0.08 * sin(_flame_time * 18.0)))
	if _slow > 0.0:
		draw_circle(Vector2.ZERO, 30.0, Color(0.4, 0.8, 1.0, 0.18))

