extends CanvasLayer

# The level up screen.
#
# The game never stops: when the player levels up a single card shows up in
# the middle of the right hand side. Clicking it opens the usual card choice.
# That way the fight keeps going while the player is deciding.

const CardScript := preload("res://scripts/card.gd")

var _dim: ColorRect
var _title: Label
var _holder: Control
var _cards: Array = []
var _pending: bool = false
# the little card that waits on the right hand side
var _hint: Control = null
var _hint_holder: Control = null
var _quit_btn: Button = null
var _minimap: Control = null

const CARD_W := 200.0
const CARD_H := 280.0
const SPACING := 28.0
const CLICK_DELAY := 1.5   # grace period before the cards can be picked
# where the waiting card sits: the middle of the right hand side
const HINT_X := 0.62
const HINT_Y := 0.5
const HINT_SCALE := 0.42


func _ready() -> void:
	layer = 10
	# must keep working (and receiving input) while the tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_hint()
	visible = false
	var parent := get_parent()
	if parent:
		_minimap = parent.get_node_or_null("HUD/Minimap") as Control
	Game.request_upgrade_choice.connect(_on_request)


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.04, 0.72)
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	# the dim only covers the screen while the cards are open
	_dim.visible = false
	add_child(_dim)

	_title = Label.new()
	_title.text = "LEVEL UP — CHOOSE A CARD"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.anchor_left = 0.5
	_title.anchor_right = 0.5
	_title.anchor_top = 0.5
	_title.anchor_bottom = 0.5
	_title.offset_left = -400.0
	_title.offset_right = 400.0
	_title.offset_top = -260.0
	_title.offset_bottom = -210.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	add_child(_title)

	# plain Control, cards are positioned manually so tweens are not overridden
	_holder = Control.new()
	_holder.anchor_left = 0.5
	_holder.anchor_right = 0.5
	_holder.anchor_top = 0.5
	_holder.anchor_bottom = 0.5
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_holder)

	_quit_btn = Button.new()
	_quit_btn.text = "TO LOBBY"
	_quit_btn.anchor_left = 1.0
	_quit_btn.anchor_right = 1.0
	_quit_btn.anchor_top = 0.0
	_quit_btn.anchor_bottom = 0.0
	_quit_btn.offset_left = -140.0
	_quit_btn.offset_right = -40.0
	# below the minimap, so the two never sit on top of each other
	_quit_btn.offset_top = 158.0
	_quit_btn.offset_bottom = 198.0
	_quit_btn.add_theme_font_size_override("font_size", 15)
	_quit_btn.pressed.connect(_on_quit)
	_quit_btn.visible = false
	add_child(_quit_btn)


# The waiting card: a single card in the middle of the right hand side.
func _build_hint() -> void:
	_hint_holder = Control.new()
	_hint_holder.anchor_left = 0.0
	_hint_holder.anchor_right = 1.0
	_hint_holder.anchor_top = 0.0
	_hint_holder.anchor_bottom = 1.0
	_hint_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_holder.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hint_holder)

	_hint = Control.new()
	_hint.set_script(CardScript)
	_hint.process_mode = Node.PROCESS_MODE_ALWAYS
	_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint_holder.add_child(_hint)
	_hint.position = Vector2.ZERO
	_hint.visible = false
	# clicking the waiting card opens the card choice
	_hint.chosen.connect(_on_hint_chosen)


func _place_hint() -> void:
	var vp := get_viewport().get_visible_rect().size
	# the card keeps its real size, only the drawing is scaled down, so the
	# clickable area stays where the player sees the card
	_hint.size = Vector2(CARD_W, CARD_H)
	_hint.pivot_offset = Vector2(CARD_W, CARD_H) * 0.5
	_hint.scale = Vector2(HINT_SCALE, HINT_SCALE)
	_hint.position = Vector2(vp.x * HINT_X, vp.y * HINT_Y) - Vector2(CARD_W, CARD_H) * 0.5


func _on_request(_level: int) -> void:
	if _pending:
		return
	_pending = true
	_show_hint()


# Shows the small waiting card with the first offer on it.
func _show_hint() -> void:
	var picks := _pick_cards()
	if picks.is_empty():
		_pending = false
		return
	_hint.call("setup", picks[0], 0)
	_place_hint()
	_hint.visible = true
	Game.sfx("card", -15.0, 0.95, 1.08)
	# a small pulse so the eye notices it
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(_hint, "scale", Vector2(HINT_SCALE * 1.06, HINT_SCALE * 1.06), 0.7)\
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_hint, "scale", Vector2(HINT_SCALE, HINT_SCALE), 0.7)\
		.set_trans(Tween.TRANS_SINE)


# The waiting card was clicked: open the real card choice.
func _on_hint_chosen(_card: Dictionary, _source: Control) -> void:
	if not _pending:
		return
	_show()


func _show() -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()

	var picks := _pick_cards()
	if picks.size() > 0 and picks[0].get("cat", 0) == CardDB.Category.WEAPON:
		_title.text = "LEVEL 5 — CHOOSE YOUR WEAPON"
	else:
		_title.text = "LEVEL UP — CHOOSE A CARD"
	var total_w := picks.size() * CARD_W + (picks.size() - 1) * SPACING
	var start_x := -total_w / 2.0

	for i in picks.size():
		var c: Control = Control.new()
		c.set_script(CardScript)
		c.process_mode = Node.PROCESS_MODE_ALWAYS
		c.setup(picks[i], i)
		# not clickable yet: protects against mis-clicking while the cards fly in
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.chosen.connect(_on_card_chosen.bind(c))
		_holder.add_child(c)
		var fx := start_x + i * (CARD_W + SPACING)
		c.position = Vector2(fx, -CARD_H / 2.0)
		_cards.append(c)

	visible = true
	# the modal covers the HUD; hiding the minimap keeps the title clear on
	# narrow screens where it would otherwise sit under the minimap
	if is_instance_valid(_minimap):
		_minimap.visible = false
	# the waiting card steps aside, the real choice takes over
	_hint.visible = false
	_dim.visible = true
	_dim.modulate.a = 0.0
	_title.modulate.a = 0.0
	_quit_btn.visible = true
	Game.sfx("card", -15.0, 0.95, 1.08)

	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_title, "modulate:a", 1.0, 0.25)

	# slide each card up from below the screen, staggered
	for i in _cards.size():
		var c: Control = _cards[i]
		var final_y := c.position.y
		c.modulate.a = 0.0
		c.position.y = final_y + 520.0
		var t := create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_interval(i * 0.12)
		t.tween_property(c, "modulate:a", 1.0, 0.20)
		t.parallel().tween_property(c, "position:y", final_y, 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# cards become clickable only after a short grace period
	var lock := create_tween()
	lock.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	lock.tween_interval(CLICK_DELAY)
	lock.tween_callback(_unlock_cards)


func _unlock_cards() -> void:
	for c in _cards:
		if is_instance_valid(c):
			c.mouse_filter = Control.MOUSE_FILTER_STOP


func _pick_cards() -> Array:
	# LV5 and no weapon yet: offer every weapon archetype at once
	if Game.level >= 5 and not Game.weapon_chosen:
		return CardDB.weapon_cards()

	var pool: Array = CardDB.passives().filter(func(card):
		var taken: int = int(Game.upg_stacks.get(card.id, 0))
		return taken < int(card.max))
	pool.shuffle()
	var out: Array = []
	for i in mini(3, pool.size()):
		out.append(pool[i])
	if out.is_empty():
		var any_pool: Array = CardDB.passives()
		any_pool.shuffle()
		out = any_pool.slice(0, 3)
	return out


func _on_card_chosen(card: Dictionary, _source: Control) -> void:
	if not _pending:
		return
	_pending = false
	Game.sfx("click", -14.0, 0.95, 1.1)
	Game.grant_card(card)
	_close()


func _close() -> void:
	# stop accepting input immediately
	for c in _cards:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quit_btn.visible = false
	_dim.visible = false
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_dim, "modulate:a", 0.0, 0.2)
	tw.parallel().tween_property(_title, "modulate:a", 0.0, 0.2)
	for c in _cards:
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		visible = false
		if is_instance_valid(_minimap):
			_minimap.visible = true
		for c in _cards:
			c.queue_free()
		_cards.clear())


func _on_quit() -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	# leaving a match goes back to the lobby, it does not close the game
	Game.set_fire(false)
	Game.reset_run()
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
