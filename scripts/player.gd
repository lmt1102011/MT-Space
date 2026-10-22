extends CharacterBody2D

@export var acceleration: float = 1400.0
@export var max_speed: float = 340.0
@export var friction: float = 900.0
@export var turn_speed: float = 14.0
@export var fire_cooldown: float = 0.14
@export var bullet_speed: float = 640.0
@export var bullet_spread: float = 0.0
@export var max_hp: int = 10
@export var push_force: float = 180.0

const BULLET_SCENE := preload("res://scenes/bullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
const DAMAGE_NUMBER := preload("res://scenes/damage_number.tscn")
const MAX_BULLETS := 36          # hard cap on live player bullets
const BULLET_LIFE := 2.0

var hp: int = 10
var invuln: float = 0.0
var _dead: bool = false
var _shake_t: float = 0.0
var _burn: float = 0.0
var _burn_tick: float = 0.0
var _burn_dps: float = 0.0
var _slow: float = 0.0
var _stun_t: float = 0.0
var _knock_vel: Vector2 = Vector2.ZERO
var _shield_t: float = 0.0
var _flame_out: Polygon2D = null
var _flame_in: Polygon2D = null
var _hp_drawn: int = -1

var _base_max_speed: float = 340.0
var _base_bullet_speed: float = 640.0
var _base_fire_cooldown: float = 0.14

var _cooldown: float = 0.0
var _thrust: float = 0.0
var _flame_time: float = 0.0
var _regen_acc: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_base_max_speed = max_speed
	_base_bullet_speed = bullet_speed
	_base_fire_cooldown = fire_cooldown
	hp = max_hp
	_flame_out = _make_flame(5.0)
	_flame_in = _make_flame(2.5)
	_make_name_label()
	# the name can still arrive after the ship was made
	Net.players_changed.connect(_on_players_changed)


func _on_players_changed() -> void:
	_refresh_name_label()


# The name of the player, shown under the ship so everyone knows who is who.
func _make_name_label() -> void:
	if Net.player_name == "":
		return
	var lbl := Label.new()
	lbl.name = "NameLabel"
	lbl.text = Net.player_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0, 0.85))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.size = Vector2(160, 16)
	lbl.position = Vector2(-80, 18)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)


func _refresh_name_label() -> void:
	var lbl := get_node_or_null("NameLabel") as Label
	if lbl == null:
		return
	lbl.text = Net.player_name if Net.player_name != "" else "YOU"


func max_hp_total() -> int:
	return max_hp + Game.upg_bonus_hp


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp_total())


func apply_status(burn: int, freeze: int) -> void:
	if _dead:
		return
	if burn > 0:
		_burn = maxf(_burn, 3.0 + burn * 0.5)
		_burn_dps = 1.0 + burn * 0.6
		Game.sfx("sizzle", -14.0, 0.92, 1.1)
	if freeze > 0:
		_slow = maxf(_slow, 1.5 + freeze * 0.5)
		Game.sfx("frost", -15.0, 0.93, 1.08)


# Knocked back by a charger: flies away and cannot act for a moment.
func apply_knockback(impulse: Vector2, stun_time: float = 0.5) -> void:
	if _dead:
		return
	_knock_vel = impulse
	_stun_t = maxf(_stun_t, stun_time)


func _physics_process(delta: float) -> void:
	invuln = maxf(invuln - delta, 0.0)
	# regen
	if Game.upg_regen > 0 and hp < max_hp_total():
		_regen_acc += delta
		if _regen_acc >= 8.0 / float(Game.upg_regen):
			_regen_acc = 0.0
			heal(1)
	# burn damage over time (ignores invulnerability)
	if _burn > 0.0:
		_burn -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			_dot_damage(_burn_dps)
		Game.set_fire(true)
	elif Game.player_dead == false:
		Game.set_fire(false)
	if _slow > 0.0:
		_slow -= delta

	# stunned by a knockback: no control, no shooting
	if _stun_t > 0.0:
		_stun_t -= delta
		velocity = _knock_vel
		_knock_vel = _knock_vel.move_toward(Vector2.ZERO, 1100.0 * delta)
		_flame_time += delta
		_update_flame()
		move_and_slide()
		_push_enemies()
		return

	var slow_factor := 0.55 if _slow > 0.0 else 1.0
	var eff_max_speed := _base_max_speed * Game.upg_move_speed * slow_factor
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir.length() > 0.01:
		velocity += input_dir * acceleration * delta
		if velocity.length() > eff_max_speed:
			velocity = velocity.normalized() * eff_max_speed
		_thrust = move_toward(_thrust, 1.0, delta * 8.0)
	else:
		var speed := velocity.length()
		if speed > 0.0:
			velocity = velocity.normalized() * maxf(speed - friction * delta, 0.0)
		_thrust = move_toward(_thrust, 0.0, delta * 6.0)

	# aim toward mouse
	var mouse := get_global_mouse_position()
	var aim := (mouse - global_position).angle()
	_sprite.rotation = lerp_angle(_sprite.rotation, aim, turn_speed * delta)

	_flame_time += delta
	if _shield_t > 0.0:
		_shield_t = maxf(_shield_t - delta, 0.0)
	_update_flame()
	# only redraw the HUD when something actually changed
	if hp != _hp_drawn:
		_hp_drawn = hp
		queue_redraw()
	elif _burn > 0.0 or _slow > 0.0 or _shield_t > 0.0:
		queue_redraw()

	move_and_slide()
	_push_enemies()
	_shoot(delta)
	# tell the others where we are, so their ships follow along smoothly
	if Net.is_online():
		Net.send_player_state(global_position, _sprite.rotation,
			float(hp) / float(max_hp_total()), not _dead)


func _push_enemies() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if other and other.is_in_group("enemy") and other.has_method("apply_push"):
			other.apply_push(-c.get_normal() * push_force * (1.0 + velocity.length() / max_speed))
			if other.has_method("touch_player"):
				other.touch_player()


func _shoot(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var mouse := get_global_mouse_position()
	var dir := (mouse - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	# burst continuation: fire the queued rounds quickly regardless of held input
	if Game._burst_left > 0 and _cooldown <= 0.0:
		_cooldown = 0.06
		Game._burst_left -= 1
		_spawn_bullet(dir, _base_bullet_speed * Game.upg_bullet_speed, Game.upg_damage, 0, 0, 0.0)
		velocity -= dir * 30.0
		return

	if not Input.is_action_pressed("shoot") or _cooldown > 0.0:
		return

	var base_speed := _base_bullet_speed * Game.upg_bullet_speed * (1.0 - 0.12 * float(Game.upg_rushed))
	var dmg := Game.upg_damage * (1.0 + 0.25 * float(Game.upg_heavy_caliber))
	var burn := Game.upg_burn
	var freeze := Game.upg_freeze
	var rate := Game.upg_fire_rate \
		* (1.0 + 0.20 * float(Game.upg_rushed)) \
		* (1.0 - 0.12 * float(Game.upg_heavy_caliber))

	match Game.weapon:
		"machine_gun":
			_cooldown = (_base_fire_cooldown * 0.8) / maxf(rate, 0.01)
			_spawn_bullet(dir.rotated(randf_range(-0.17, 0.17)), base_speed, dmg * 0.6, burn, freeze, 0.0)
		"twin_cannon":
			_cooldown = (_base_fire_cooldown * 1.25) / maxf(rate, 0.01)
			var off := dir.orthogonal() * 10.0
			_spawn_bullet(dir, base_speed, dmg, burn, freeze, 0.0, off)
			_spawn_bullet(dir, base_speed, dmg, burn, freeze, 0.0, -off)
		"shotgun":
			_cooldown = (_base_fire_cooldown * 4.0) / maxf(rate, 0.01)
			for i in 7:
				var a := randf_range(-0.32, 0.32)
				_spawn_bullet(dir.rotated(a), base_speed * 0.75, dmg * 0.5, burn, freeze, 0.0, Vector2.ZERO, 0.35, 0, 12.0, 4.0, Color(1.0, 0.7, 0.2))
		"railgun":
			_cooldown = (_base_fire_cooldown * 2.2) / maxf(rate, 0.01)
			_spawn_bullet(dir, base_speed * 1.7, dmg * 2.6, burn, freeze, 0.0, Vector2.ZERO, 1.4, 2, 42.0, 8.0, Color(0.6, 0.8, 1.0))
		"burst":
			_cooldown = (_base_fire_cooldown * 1.3) / maxf(rate, 0.01)
			Game._burst_left = 2
			_spawn_bullet(dir, base_speed, dmg, burn, freeze, 0.0)
		_:  # basic
			_cooldown = _base_fire_cooldown / maxf(rate, 0.01)
			_spawn_bullet(dir, base_speed, dmg, burn, freeze, 0.0)

		# passive upgrade extras (split still stacks on top of any weapon)
	if Game.upg_extra_shots > 0 and Game.weapon != "shotgun":
		for i in Game.upg_extra_shots:
			var sp := 0.10 * (float(i) + 1.0)
			_spawn_bullet(dir.rotated(sp), base_speed, dmg, burn, freeze, 0.0)
			_spawn_bullet(dir.rotated(-sp), base_speed, dmg, burn, freeze, 0.0)

	velocity -= dir * 30.0


func _spawn_bullet(dir: Vector2, spd: float, dmg: float, burn: int, freeze: int,
		_spread: float, offset: Vector2 = Vector2.ZERO, life_mult: float = 1.0,
		pierce: int = 0, length: float = 26.0, width: float = 5.0, col: Color = Color(1.0, 0.9, 0.2)) -> void:
	var bullet := BULLET_SCENE.instantiate()
	bullet.global_position = global_position + dir * 26.0 + offset
	bullet.direction = dir.rotated(randf_range(-bullet_spread, bullet_spread))
	bullet.speed = spd
	# crit
	var final_dmg := dmg
	var is_crit := false
	var crit_chance := Game.upg_crit
	# Cold Blood: the closer to death, the sharper the shots
	if Game.upg_cold_blood > 0:
		crit_chance += 0.08 * float(Game.upg_cold_blood) * (1.0 - float(hp) / float(max_hp_total()))
	if crit_chance > 0.0 and randf() < crit_chance:
		final_dmg *= 2.0
		col = Color(1.0, 0.35, 0.35)
		is_crit = true
	bullet.damage = final_dmg
	bullet.crit = is_crit
	bullet.burn = burn
	bullet.freeze = freeze
	bullet.lifetime = BULLET_LIFE * life_mult
	bullet.pierce = pierce + Game.upg_pierce
	bullet.beam_length = length
	bullet.beam_width = width * (1.7 if is_crit else 1.0)
	bullet.beam_color = col
	_limit_bullets()
	get_tree().current_scene.add_child(bullet)
	Game.sfx("shoot", -14.0, 0.97, 1.04)


# Keeps the amount of live bullets (and therefore the physics work) bounded.
func _limit_bullets() -> void:
	var live := get_tree().get_nodes_in_group("player_bullet")
	if live.size() < MAX_BULLETS:
		return
	# drop the oldest one (it has the most life left)
	var oldest: Node = null
	var best := -1.0
	for b in live:
		var lt: float = b.lifetime
		if lt > best:
			best = lt
			oldest = b
	if oldest != null:
		oldest.queue_free()


func _process(delta: float) -> void:
	if _shake_t <= 0.0:
		return
	_shake_t = maxf(_shake_t - delta, 0.0)
	var amount := 5.0 * clampf(_shake_t, 0.0, 1.0)
	_sprite.position = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
	if _shake_t <= 0.0:
		_sprite.position = Vector2.ZERO


func take_damage(amount: int) -> void:
	if invuln > 0.0 or _dead:
		return
	# Hull Plating: soften every incoming hit a little
	amount = maxi(1, amount - Game.upg_plating)
	hp -= amount
	# Thorns: being hit hurts whatever is standing close
	if Game.upg_thorns > 0:
		_damage_nearby(float(amount) * 0.3, 80.0 + 15.0 * float(Game.upg_thorns))
	_spawn_damage_number(amount, Color(1.0, 0.45, 0.45))
	Game.sfx("hurt", -15.0, 0.9, 1.15)
	invuln = 0.6
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(2, 0.4, 0.4, 1), 0.06)
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.18)
	if hp <= 0:
		hp = 0
		_die()


func _spawn_damage_number(amount: float, color: Color, font_size: int = 24) -> void:
	var n := DAMAGE_NUMBER.instantiate() as DamageNumber
	n.global_position = global_position + Vector2(randf_range(-26.0, 26.0), randf_range(-34.0, -12.0))
	n.setup(amount, color, font_size)
	get_tree().current_scene.add_child(n)


func _damage_nearby(amount: float, radius: float) -> void:
	var r2 := radius * radius
	for e in get_tree().get_nodes_in_group("enemy"):
		var n := e as Node2D
		if n == null or not is_instance_valid(n):
			continue
		if n.global_position.distance_squared_to(global_position) > r2:
			continue
		if n.has_method("take_damage"):
			n.take_damage(amount, "normal")


func _dot_damage(amount: float) -> void:
	if _dead:
		return
	var dmg: float = ceilf(amount)
	hp -= int(dmg)
	_spawn_damage_number(dmg, Color(1.0, 0.6, 0.2), 18)
	if hp <= 0:
		hp = 0
		_die()


func _die() -> void:
	# Second Chance: come back once with half of the health
	if Game.upg_second_chance > 0:
		Game.upg_second_chance -= 1
		hp = maxi(1, int(round(float(max_hp_total()) * 0.5)))
		invuln = 1.5
		_shield_t = 1.2
		Game.sfx("cardget", -8.0, 0.98, 1.05)
		return
	_dead = true
	Game.player_dead = true
	Game.set_fire(false)
	# clear the last drawn frame (HP bar / flame) now that physics has stopped
	queue_redraw()
	velocity = Vector2.ZERO
	set_physics_process(false)
	_shake_t = 1.0
	await get_tree().create_timer(1.0).timeout
	var boom := EXPLOSION_SCENE.instantiate() as Explosion
	boom.setup(3.0)
	boom.global_position = global_position
	get_tree().current_scene.add_child(boom)
	Game.sfx("boom_big", -8.0, 0.85, 1.02)
	_sprite.visible = false
	Game.notify_player_died()


func _draw() -> void:
	if _dead:
		return
	# the engine flame is a node (see _update_flame), only the HUD bits are drawn

	# HP bar fixed under the ship (world space, never rotates)
	var bar_w := 46.0
	var bar_h := 6.0
	var y := 30.0
	var t := float(hp) / float(max_hp_total())
	draw_rect(Rect2(-bar_w / 2.0, y, bar_w, bar_h), Color(0.05, 0.07, 0.06, 0.85))
	draw_rect(Rect2(-bar_w / 2.0 + 1.0, y + 1.0, (bar_w - 2.0) * t, bar_h - 2.0), Color(1.0 - t, 0.3 + 0.6 * t, 0.35))

	# status auras
	if _burn > 0.0:
		var f := 0.18 + 0.1 * sin(_flame_time * 20.0)
		draw_circle(Vector2.ZERO, 24.0, Color(1.0, 0.45, 0.1, f))
	if _slow > 0.0:
		draw_circle(Vector2.ZERO, 24.0, Color(0.4, 0.8, 1.0, 0.18))
	# Second Chance shield flash
	if _shield_t > 0.0:
		var a := _shield_t / 1.2
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 48, Color(0.9, 0.95, 1.0, 0.75 * a), 4.0, true)


func _make_flame(width: float) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(0, width), Vector2(-1, 0), Vector2(0, -width)])
	add_child(poly)
	return poly


# The flame is animated by moving and scaling nodes - no drawing per frame.
func _update_flame() -> void:
	if _flame_out == null:
		return
	var back := Vector2(-15, 0).rotated(_sprite.rotation)
	var flicker := 0.8 + sin(_flame_time * 40.0) * 0.2
	var length := (6.0 + _thrust * 22.0) * flicker
	var lit := _thrust > 0.02
	_flame_out.position = back
	_flame_out.rotation = _sprite.rotation
	_flame_out.scale = Vector2(length, 1.0)
	_flame_out.color = Color(1.0, 0.75, 0.25, 0.35 + 0.5 * _thrust)
	_flame_out.visible = lit
	_flame_in.position = back
	_flame_in.rotation = _sprite.rotation
	_flame_in.scale = Vector2(length * 0.55, 1.0)
	_flame_in.color = Color(1.0, 1.0, 0.8, 0.6 + 0.4 * _thrust)
	_flame_in.visible = lit

