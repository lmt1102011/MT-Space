
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
var _cull_acc: float = 0.0
var _dash_visual_time: float = 0.0
var _brain := EnemyBrain.new()
var _hulls: Array = []
var _ship: Sprite2D = null
var _elite_ship: Sprite2D = null
var _charge_effects: Array[Sprite2D] = []
var _dash_effect: Sprite2D
var _status_visual: Node2D

const SHAPES := preload("res://scripts/enemy_shapes.gd")
const NetEnemy := preload("res://scripts/net_enemy.gd")
const HULL_COLOR := SHAPES.CHARGER_COLOR
const HULL_EDGE := SHAPES.HULL_EDGE
const HULL_SCALE := SHAPES.CHARGER_SCALE
const MUZZLE := Vector2(SHAPES.CHARGER_NOSE, 0.0)

const UPGRADE_DROP := preload("res://scenes/upgrade_drop.tscn")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.tscn")
const XP_DROP := preload("res://scripts/xp_pickup.gd")
const STATUS_VISUAL := preload("res://scripts/status_effect_visual.gd")
const CHARGE_TEXTURE := preload("res://assets/charger_charge.png")
const DASH_TEXTURE := preload("res://assets/charger_dash.png")

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
	add_to_group("charger_enemy")
	collision_layer = 8
	collision_mask = 13
	hp = max_hp
	_build_hull()
	_status_visual = STATUS_VISUAL.new()
	_status_visual.set("radius", 34.0)
	_status_visual.z_index = 2
	add_child(_status_visual)
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
	for i in 3:
		var ring := Sprite2D.new()
		ring.texture = CHARGE_TEXTURE
		ring.z_index = -1
		ring.visible = false
		add_child(ring)
		_charge_effects.append(ring)
	_dash_effect = Sprite2D.new()
	_dash_effect.texture = DASH_TEXTURE
	_dash_effect.scale = Vector2(0.48, 0.16)
	_dash_effect.z_index = -1
	_dash_effect.visible = false
	add_child(_dash_effect)


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
	if Net.is_online() and not Net.is_host():
		return null
	_player = Net.target_player(global_position)
	return _player


func _physics_process(delta: float) -> void:
	# on a client this enemy is only a copy of the host's one
	if NetEnemy.is_remote(self):
		# a copy of a host enemy just walks to where the host says it is
		NetEnemy.follow(self, delta)
		_tick_status(delta, false)
		_update_charge_dash_visuals(delta)
		_bar.place_at(global_position + Vector2(0, 30.0))
		return
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
	if not Net.any_player_alive():
		# the player is down: no hunting, no charging, just ambling about
		_stroll_step(delta)
		_update_charge_dash_visuals(delta)
		_bar.place_at(global_position + Vector2(0, radius + 18.0))
		return

	match _state:
		State.CHASE:
			_chase(delta, target)
		State.CHARGE:
			_charge(delta, target)
		State.DASH:
			_dash(delta)

	# always look at the player, except while dashing (direction is locked)
	if _state != State.DASH and Net.any_player_alive():
		_face(target, delta)

	_update_charge_dash_visuals(delta)
	_bar.place_at(global_position + Vector2(0, radius + 18.0))


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
	goal += EnemyAI.steer(self, dir * speed) * 0.6
	_push = _push.move_toward(Vector2.ZERO, 600.0 * delta)
	velocity = velocity.lerp(goal + _push, clampf(5.0 * delta, 0.0, 1.0))
	move_and_slide()

	if dist <= dash_range and not tired and Net.any_player_alive():
		_state = State.CHARGE
		_state_t = 0.0
		Game.sfx("charge", -12.0, 0.95, 1.06)


# Once the player is down the charger just wanders about, like everything else.
func _stroll_step(delta: float) -> void:
	_push = _push.move_toward(Vector2.ZERO, 600.0 * delta)
	var stroll := _brain.wander(move_speed * 0.45, delta)
	var avoid := EnemyAI.steer(self, stroll)
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
	if not Net.any_player_alive():
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
			_hit_player(other)
	if _state_t >= dash_time:
		_state = State.CHASE
		_state_t = 0.0
		_dash_cd = dash_cooldown
		velocity = _dash_dir * 120.0


func _hit_player(player: Node) -> void:
	if player.has_method("apply_hit"):
		player.call("apply_hit", dash_damage, 0, 0,
			_dash_dir * knockback_force, stun_time)
		return
	if player.has_method("take_damage"):
		player.take_damage(dash_damage)
	if player.has_method("apply_knockback"):
		player.apply_knockback(_dash_dir * knockback_force, stun_time)


func _face(target: Node2D, delta: float) -> void:
	var dir := (target.global_position - global_position).angle()
	rotation = lerp_angle(rotation, dir, 7.0 * delta)


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


func apply_push(impulse: Vector2) -> void:
	if _state == State.DASH:
		return
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
	_elite_burn = int(mods["burn"])
	_elite_freeze = int(mods["freeze"])
	_elite_crit = float(mods["crit"])
	_elite_regen = int(mods["regen"])
	_add_elite_mark()
	if _elite_ship != null:
		_elite_ship.visible = true


func apply_network_elite(network_max_hp: int) -> void:
	if not elite:
		elite = true
		add_to_group("elite")
		_add_elite_mark()
	if _elite_ship != null:
		_elite_ship.visible = true
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
	if _owned_cards.is_empty() or randf() >= 0.5:
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
	var drop := NetEnemy.died(self, xp)
	var boom := Pool.acquire(preload("res://scenes/explosion.tscn"),
		get_tree().current_scene) as Explosion
	if boom == null:
		return
	boom.global_position = global_position
	if Game.upg_lifesteal:
		var pl := get_tree().get_first_node_in_group("player")
		if pl and pl.has_method("heal"):
			pl.heal(1)
	boom.setup(1.0, Color(1.0, 0.75, 0.3))
	Game.combat_impact(0.8)
	Game.on_enemy_killed("charger")
	if elite:
		drop_elite_card()
	if drop:
		drop_xp(xp)
	queue_free()


func drop_xp(amount: int) -> void:
	XP_DROP.drop(get_tree(), global_position, amount)


func _update_charge_dash_visuals(delta: float) -> void:
	var charging := _state == State.CHARGE
	var dashing := _state == State.DASH
	_dash_effect.visible = dashing
	if dashing:
		_dash_visual_time += delta
		var pulse := 0.5 + 0.5 * sin(_dash_visual_time * 34.0)
		var slide := fposmod(_dash_visual_time * 70.0, 18.0)
		_dash_effect.position = Vector2(-10.0 - slide, sin(_dash_visual_time * 22.0) * 2.0)
		_dash_effect.scale = Vector2(0.46 + pulse * 0.06, 0.16)
		_dash_effect.modulate.a = 0.58 + pulse * 0.34
	else:
		_dash_effect.position = Vector2.ZERO
		_dash_effect.scale = Vector2(0.48, 0.16)
		_dash_effect.modulate.a = 1.0
	var progress := clampf(_state_t / charge_time, 0.0, 1.0)
	for i in _charge_effects.size():
		var ring := _charge_effects[i]
		ring.visible = charging
		if charging:
			var ring_progress := clampf(progress * 1.6 - float(i) * 0.28, 0.0, 1.0)
			var ring_radius := lerpf(78.0, 10.0, ring_progress)
			ring.scale = Vector2.ONE * ring_radius / 174.0
			ring.modulate.a = lerpf(0.04, 0.5, ring_progress)
