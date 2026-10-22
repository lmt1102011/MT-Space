extends Area2D
class_name UpgradeDrop

var _time: float = 0.0

# When set, picking this up grants this exact card; otherwise it opens the
# level-up card choice screen (legacy behaviour).
var card: Dictionary = {}

const SHAPES := preload("res://scripts/enemy_shapes.gd")

var _card: Sprite2D = null
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
	_card = Sprite2D.new()
	_card.texture = SHAPES.UPGRADE_DROP_TEX
	_card.scale = Vector2(DROP_SCALE, DROP_SCALE)
	add_child(_card)


func _process(delta: float) -> void:
	_time += delta
	# the pulse is a scale change on the glow, nothing is re-drawn
	if _glow != null:
		var pulse := 0.7 + sin(_time * 8.0) * 0.3
		var g := GLOW_RADIUS * pulse / 32.0
		_glow.scale = Vector2(g, g)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or Game.player_dead:
		return
	if not card.is_empty():
		if Game.grant_card(card):
			Game.card_collected.emit(card)
			Game.sfx("cardget", -11.0, 0.95, 1.06)
	else:
		Game.request_upgrade_choice.emit(Game.level)
	queue_free()
