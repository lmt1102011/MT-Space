extends Area2D
class_name UpgradeDrop

var _time: float = 0.0

# When set, picking this up grants this exact card; otherwise it opens the
# level-up card choice screen (legacy behaviour).
var card: Dictionary = {}
var _thrown_owner_id: int = 0
var network_drop_id: int = 0
var _pickup_delay: float = 0.0
var _throw_velocity: Vector2 = Vector2.ZERO

const SHAPES := preload("res://scripts/enemy_shapes.gd")

var _glow: Sprite2D = null

# the card in the image is 28px wide, the old drawing was 18px
const DROP_SCALE := 18.0 / 28.0
# the glow disc has a radius of 32 in a 64px box
const GLOW_RADIUS := 17.0


func _ready() -> void:
	add_to_group("upgrade_drop")
	body_entered.connect(_on_body_entered)
	# the glow is behind, the card on top
	_glow = Sprite2D.new()
	_glow.texture = SHAPES.UPGRADE_GLOW_TEX
	var g := GLOW_RADIUS / 32.0
	_glow.scale = Vector2(g, g)
	_glow.modulate = Color(0.95, 0.8, 0.3, 1.0)
	add_child(_glow)
	var card_sprite := Sprite2D.new()
	card_sprite.texture = SHAPES.UPGRADE_DROP_TEX
	card_sprite.scale = Vector2(DROP_SCALE, DROP_SCALE)
	add_child(card_sprite)


func configure_thrown(owner_id: int, direction: Vector2) -> void:
	_thrown_owner_id = owner_id
	_pickup_delay = 1.25
	_throw_velocity = direction.normalized() * 560.0


func _process(delta: float) -> void:
	_time += delta
	_pickup_delay = maxf(_pickup_delay - delta, 0.0)
	# the pulse is a scale change on the glow, nothing is re-drawn
	if _glow != null:
		var pulse := 0.7 + sin(_time * 8.0) * 0.3
		var g := GLOW_RADIUS * pulse / 32.0
		_glow.scale = Vector2(g, g)


func _physics_process(delta: float) -> void:
	if _throw_velocity.is_zero_approx():
		return
	global_position += _throw_velocity * delta
	_throw_velocity = _throw_velocity.move_toward(Vector2.ZERO, 850.0 * delta)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var local_player := get_tree().current_scene.get_node_or_null("Player")
	if body == local_player:
		if Game.player_dead:
			return
	elif body.get("net_alive") == false:
		return
	if _pickup_delay > 0.0:
		return
	if network_drop_id > 0 and Net.is_online():
		if not Net.is_host():
			return
		var player_id := Net.my_id() if body == local_player else int(body.get("net_id"))
		Net.claim_discarded_card(network_drop_id, player_id)
		return
	if _thrown_owner_id > 0:
		if body != local_player or Net.my_id() != _thrown_owner_id:
			return
	if not card.is_empty():
		if Game.grant_card(card):
			Game.card_collected.emit(card)
		Game.sfx("cardget", -11.0, 0.95, 1.06)
	else:
		Game.request_upgrade_choice.emit(Game.level)
	queue_free()
