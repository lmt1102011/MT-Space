extends Node2D

# Purely visual pickup: the actual collection is done with a distance check in
# _process, so this node never needs to be a physics body. Keeping it out of
# the physics space removes a lot of cost once dozens of them are lying around.

@export var xp_value: int = 1
@export var magnet_radius: float = 220.0
@export var magnet_speed: float = 520.0
@export var pickup_radius: float = 18.0

var _vel: Vector2 = Vector2.ZERO
var _player: Node2D = null
var _time: float = 0.0
var _on_screen: bool = true
var _cull_acc: float = 0.0

const SHAPES := preload("res://scripts/enemy_shapes.gd")
var _gem: Sprite2D = null
var _glow: Sprite2D = null
var _visual_scale: float = 1.0

# the glow disc has a radius of 30 in a 64px box, the gem a radius of 16
const GLOW_RADIUS := 7.0
const GEM_RADIUS := 4.0


func _ready() -> void:
	add_to_group("xp_orb")
	_vel = Vector2.from_angle(randf() * TAU) * randf_range(90.0, 200.0)
	# the glow sits behind, the gem on top - the same sizes as the old circles
	_glow = Sprite2D.new()
	_glow.texture = SHAPES.XP_ORB_GLOW_TEX
	_glow.modulate = Color(0.3, 1.0, 0.5, 1.0)
	var s := GLOW_RADIUS / 30.0
	_glow.scale = Vector2(s, s)
	add_child(_glow)
	_gem = Sprite2D.new()
	_gem.texture = SHAPES.XP_ORB_GEM_TEX
	var g := GEM_RADIUS / 16.0
	_gem.scale = Vector2(g, g)
	add_child(_gem)
	_refresh_visual_tier()


func add_xp_value(amount: int) -> void:
	xp_value += amount
	_refresh_visual_tier()


func _refresh_visual_tier() -> void:
	if _glow == null or _gem == null:
		return
	var merged := xp_value >= 20
	_visual_scale = 1.25 if merged else 1.0
	_glow.modulate = Color(0.2, 0.65, 1.0, 1.0) if merged else Color(0.3, 1.0, 0.5, 1.0)
	_gem.modulate = Color(0.6, 0.85, 1.0, 1.0) if merged else Color.WHITE
	_glow.scale = Vector2.ONE * GLOW_RADIUS * _visual_scale / 30.0
	_gem.scale = Vector2.ONE * GEM_RADIUS * _visual_scale / 16.0


func _process(delta: float) -> void:
	_time += delta
	_cull(delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	if _player:
		var to_player := _player.global_position - global_position
		var dist := to_player.length()
		var mr := magnet_radius * Game.upg_magnet
		if dist < mr:
			# accelerate toward player
			_vel = _vel.lerp(to_player.normalized() * magnet_speed, 8.0 * delta)
			if dist < pickup_radius:
				Game.add_xp(xp_value)
				Game.sfx("blip", -16.0, 0.94, 1.06)
				queue_free()
				return
		else:
			_vel = _vel.move_toward(Vector2.ZERO, 220.0 * delta)

	position += _vel * delta
	# the pulse is a scale change on the node, nothing is re-drawn
	var pulse := 0.7 + sin(_time * 8.0) * 0.3
	if _glow != null:
		var g := GLOW_RADIUS * pulse * _visual_scale / 30.0
		_glow.scale = Vector2(g, g)


func _cull(delta: float) -> void:
	# orbs far from the view are not rendered (the minimap still shows them)
	_cull_acc -= delta
	if _cull_acc > 0.0:
		return
	_cull_acc = 0.2
	var on := WebViewCull.is_on_screen(self, 60.0)
	if on == _on_screen:
		return
	_on_screen = on
	visible = on


func _draw() -> void:
	pass
