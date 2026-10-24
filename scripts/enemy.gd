extends CharacterBody2D

@export var sides: int = 3
@export var radius: float = 26.0
@export var max_hp: int = 3
@export var base_speed: float = 30.0

var hp: int = 3
var contact_damage: int = 1
var _push: Vector2 = Vector2.ZERO
var _drift: Vector2 = Vector2.ZERO
var _burn: float = 0.0
var _burn_tick: float = 0.0
var _burn_dmg: float = 0.0
var _slow: float = 0.0
var _anim_t: float = 0.0
var _on_screen: bool = true
var _ai_acc: float = 0.0
var _steer: Vector2 = Vector2.ZERO
var _cull_acc: float = 0.0
var _wander_t: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _hull: Sprite2D = null
var _hull_rim: Sprite2D = null
var _tint_burn: bool = false
var _tint_slow: bool = false
var _status_visual: Node2D

const DAMAGE_NUMBER := preload("res://scenes/damage_number.tscn")
const NetEnemy := preload("res://scripts/net_enemy.gd")
const XP_DROP := preload("res://scripts/xp_pickup.gd")
const SHAPES := preload("res://scripts/enemy_shapes.gd")
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


func _ready() -> void:
	add_to_group("enemy")
	# the swarm shapes are ambient: they are not part of a wave, so they get
	# their own group and never hold a wave back
	add_to_group("shape_enemy")
	collision_layer = 8
	collision_mask = 13   # player(1) + obstacle(4) + enemy(8)
	hp = max_hp
	_status_visual = STATUS_VISUAL.new()
	_status_visual.set("radius", radius)
	_status_visual.z_index = 2
	add_child(_status_visual)
	queue_redraw()
	_update_bar()


func setup(p_sides: int, p_radius: float, speed_mult: float = 1.0, dmg_bonus: int = 0) -> void:
	sides = p_sides
	radius = p_radius
	var edge_hp: int = maxi(p_sides - 2, 1)
	var size_hp: int = int(round(radius / 12.0))
	max_hp = edge_hp + size_hp
	hp = max_hp
	base_speed *= speed_mult
	contact_damage = 1 + dmg_bonus
	_drift = Vector2.from_angle(randf() * TAU) * base_speed
	_update_bar()
	_build_hull()


# The hull is an image: one sprite instead of a polygon plus an outline.
# The dark rim is a second, slightly larger sprite behind the hull.
func _build_hull() -> void:
	if _hull != null:
		_hull.queue_free()
	if _hull_rim != null:
		_hull_rim.queue_free()
	# the rim goes in first, so the hull is drawn on top of it
	_hull_rim = SHAPES.make_shape(sides, radius + 1.5, Color(0.05, 0.05, 0.08, 0.85))
	add_child(_hull_rim)
	_hull = SHAPES.make_shape(sides, radius, SHAPES.shape_color(sides))
	add_child(_hull)


func _set_hull_color(col: Color) -> void:
	if _hull != null:
		_hull.modulate = col


# Burn / freeze tint the hull by changing the node colour - no redraw needed.
func _update_hull_tint() -> void:
	var burning := _burn > 0.0
	var frozen := _slow > 0.0
	if burning == _tint_burn and frozen == _tint_slow:
		return
	_tint_burn = burning
	_tint_slow = frozen
	var col := SHAPES.shape_color(sides)
	if burning:
		col = col.lerp(Color(1.0, 0.5, 0.15), 0.55)
	if frozen:
		col = col.lerp(Color(0.4, 0.8, 1.0), 0.55)
	_set_hull_color(col)


func _update_bar() -> void:
	var t := float(hp) / float(max_hp)
	var col := Color(0.3 + 0.7 * (1.0 - t), 0.9 * t + 0.2, 0.25)
	_bar.set_ratio(t, col)


func _physics_process(delta: float) -> void:
	# on a client this enemy is only a copy of the host's one
	if NetEnemy.is_remote(self):
		# Remote shapes are visual replicas. If they keep a local collision
		# shape, the local player's move_and_slide() collides with a position
		# that is also being network-interpolated, which causes visible jitter.
		# Put visual-only remote shapes on the bullet-only layer. This lets a
		# client bullet detect/report the hit while the player body can never
		# physically collide with the interpolated shape.
		collision_layer = 2
		collision_mask = 0
		# a copy of a host enemy just walks to where the host says it is
		NetEnemy.follow(self, delta)
		_tick_status(delta, false)
		_bar.global_position = global_position + Vector2(0, 30.0)
		_bar.global_rotation = 0.0
		return
	_anim_t += delta
	_cull(delta)
	_tick_status(delta)
	# slow drift, no chasing
	var slow_factor := 0.45 if _slow > 0.0 else 1.0
	_push = _push.move_toward(Vector2.ZERO, 600.0 * delta)
	rotation += delta * 0.4 * slow_factor

	# steer around obstacles and other enemies (the expensive part runs at 20Hz)
	_ai_acc -= delta
	if _ai_acc <= 0.0:
		_ai_acc = 0.05
		_steer = EnemyAI.steer(self, _drift)
	# blend steering into drift while keeping rough speed
	var target_vel := _drift * slow_factor + _steer * slow_factor + _push
	if not Net.any_player_alive():
		# the player is down: wander about instead of drifting in a straight line
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(1.3, 3.2)
			_wander_dir = Vector2.from_angle(randf() * TAU)
		target_vel = _wander_dir * base_speed * 0.45 + _steer * 0.5
	velocity = target_vel
	var collided := move_and_slide()

	# bounce off walls / solid things we hit
	if collided:
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var col := c.get_collider()
			if col and col.is_in_group("player"):
				if col.has_method("take_damage"):
					col.take_damage(contact_damage)
				continue
			_drift = _drift.bounce(c.get_normal())
			break

	_bar.global_position = global_position + Vector2(0, radius + 14.0)
	_bar.global_rotation = 0.0


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
	_update_hull_tint()
	_status_visual.call("set_status", _burn > 0.0, _slow > 0.0)


func touch_player() -> void:
	if not Net.any_player_alive():
		return
	var target := Net.target_player(global_position)
	if target and target.has_method("take_damage"):
		target.take_damage(contact_damage)


func _spawn_damage_number(amount: float, kind: String) -> void:
	var n := DAMAGE_NUMBER.instantiate() as DamageNumber
	n.global_position = global_position + Vector2(randf_range(-24.0, 24.0), -radius - randf_range(8.0, 34.0))
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
		_flash()


func _flash() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(2, 2, 2, 1), 0.05)
	tw.tween_property(self, "modulate", Color.WHITE, 0.12)


func _die() -> void:
	# the host owns the death, the client waits for the message
	if NetEnemy.is_remote(self):
		queue_free()
		return
	var xp := (1 + maxi(sides - 3, 0)) * 5
	var drop := NetEnemy.died(self, xp)
	var boom := preload("res://scenes/explosion.tscn").instantiate() as Explosion
	boom.global_position = global_position
	get_tree().current_scene.add_child(boom)
	Game.on_enemy_killed()
	Game.sfx("shatter", -15.0, 0.85, 1.2)
	_on_kill()
	if drop:
		drop_xp(xp)
	queue_free()


func _on_kill() -> void:
	if Game.upg_lifesteal:
		var pl := get_tree().get_first_node_in_group("player")
		if pl and pl.has_method("heal"):
			pl.heal(1)


func drop_xp(amount: int) -> void:
	XP_DROP.drop(get_tree(), global_position, amount)
