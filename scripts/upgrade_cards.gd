extends CanvasLayer

# Level-up flow: show one compact card during combat, then let the player
# choose an upgrade. Extra levels stay queued and each choice opens the next.
const CardScript := preload("res://scripts/card.gd")

var _dim: ColorRect
var _title: Label
var _holder: Control
var _cards: Array = []
var _pending: bool = false
var _closing_after_choice: bool = false
var _upgrade_queue: Array = []
var _hint: Control = null
var _hint_holder: Control = null
var _hint_badge: Label = null
var _hint_badge_bg: Panel = null
var _hint_tween: Tween = null
var _quit_btn: Button = null
var _minimap: Control = null
var _current_upgrade_level: int = 0

const CARD_W := 200.0
const CARD_H := 280.0
const SPACING := 28.0
const CLICK_DELAY := 1.5
const HINT_X := 0.80
const HINT_Y := 0.50
const HINT_SCALE := 0.56


func _ready() -> void:
	layer = 10
	# The choice UI must keep animating and receiving input during combat.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_build_hint()
	visible = false

	var parent := get_parent()
	if parent:
		_minimap = parent.get_node_or_null("HUD/Minimap") as Control

	if not Game.request_upgrade_choice.is_connected(_on_request):
		Game.request_upgrade_choice.connect(_on_request)


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.04, 0.72)
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.process_mode = Node.PROCESS_MODE_ALWAYS
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

	# Position cards manually so the entrance animation remains smooth.
	_holder = Control.new()
	_holder.anchor_left = 0.5
	_holder.anchor_right = 0.5
	_holder.anchor_top = 0.5
	_holder.anchor_bottom = 0.5
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_holder)

	_quit_btn = Button.new()
	_quit_btn.text = "THOÁT"
	_quit_btn.anchor_left = 1.0
	_quit_btn.anchor_right = 1.0
	_quit_btn.anchor_top = 0.0
	_quit_btn.anchor_bottom = 0.0
	_quit_btn.offset_left = -140.0
	_quit_btn.offset_right = -40.0
	_quit_btn.offset_top = 158.0
	_quit_btn.offset_bottom = 198.0
	_quit_btn.add_theme_font_size_override("font_size", 15)
	_quit_btn.pressed.connect(_dismiss_choices)
	_quit_btn.visible = false
	add_child(_quit_btn)


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
	_hint.chosen.connect(_on_hint_chosen)

	# High-contrast counter pinned to the card's upper-right corner.
	_hint_badge_bg = Panel.new()
	_hint_badge_bg.anchor_left = 1.0
	_hint_badge_bg.anchor_right = 1.0
	_hint_badge_bg.anchor_top = 0.0
	_hint_badge_bg.anchor_bottom = 0.0
	_hint_badge_bg.offset_left = -52.0
	_hint_badge_bg.offset_right = -8.0
	_hint_badge_bg.offset_top = 8.0
	_hint_badge_bg.offset_bottom = 52.0
	_hint_badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.055, 0.075, 0.10, 0.98)
	badge_style.border_color = Color(1.0, 0.76, 0.30, 1.0)
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(12)
	_hint_badge_bg.add_theme_stylebox_override("panel", badge_style)
	_hint.add_child(_hint_badge_bg)

	_hint_badge = Label.new()
	_hint_badge.anchor_right = 1.0
	_hint_badge.anchor_bottom = 1.0
	_hint_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_badge.add_theme_font_size_override("font_size", 22)
	_hint_badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.46))
	_hint_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hint_badge.add_theme_constant_override("outline_size", 2)
	_hint_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_badge_bg.add_child(_hint_badge)
	_hint_badge_bg.visible = false


func _pending_upgrade_count() -> int:
	return (1 if _pending else 0) + _upgrade_queue.size()


func _update_hint_badge() -> void:
	if not is_instance_valid(_hint_badge) or not is_instance_valid(_hint_badge_bg):
		return

	var count := _pending_upgrade_count()
	_hint_badge.text = str(count)
	_hint_badge.visible = count > 0
	_hint_badge_bg.visible = count > 0


func _place_hint() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_hint.size = Vector2(CARD_W, CARD_H)
	_hint.pivot_offset = Vector2(CARD_W, CARD_H) * 0.5
	_hint.scale = Vector2(HINT_SCALE, HINT_SCALE)
	_hint.position = Vector2(
		viewport_size.x * HINT_X,
		viewport_size.y * HINT_Y
	) - Vector2(CARD_W, CARD_H) * 0.5


func _on_request(level: int) -> void:
	# Requests can arrive while the player is choosing or while the old cards
	# are animating away. Queue them rather than opening overlapping screens.
	if _pending or _closing_after_choice:
		_upgrade_queue.append(level)
		_update_hint_badge()
		return

	_pending = true
	_current_upgrade_level = level
	_show_hint(level)


func _show_hint(level: int) -> void:
	_current_upgrade_level = level
	var picks := _pick_cards_for_level(level)
	if picks.is_empty():
		_pending = false
		_update_hint_badge()
		_hint.visible = false
		return

	_hint.call("setup", picks[0], 0)
	_place_hint()
	_hint.visible = true
	_update_hint_badge()
	_start_hint_pulse()
	Game.sfx("card", -15.0, 0.95, 1.08)


func _start_hint_pulse() -> void:
	_stop_hint_pulse()
	if not is_instance_valid(_hint) or not _hint.visible:
		return
	_hint_tween = create_tween()
	_hint_tween.set_loops()
	_hint_tween.tween_property(
		_hint, "scale", Vector2(HINT_SCALE * 1.04, HINT_SCALE * 1.04), 0.8
	).set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(
		_hint, "scale", Vector2(HINT_SCALE, HINT_SCALE), 0.8
	).set_trans(Tween.TRANS_SINE)


func _stop_hint_pulse() -> void:
	if is_instance_valid(_hint_tween):
		_hint_tween.kill()
	_hint_tween = null


func _pick_cards_for_level(level: int) -> Array:
	# The first weapon choice is offered at level 5.
	if level >= 5 and not Game.weapon_chosen:
		return CardDB.weapon_cards()

	var pool: Array = CardDB.passives().filter(func(card):
		var taken: int = int(Game.upg_stacks.get(card.id, 0))
		return taken < int(card.max)
	)
	pool.shuffle()

	var picks: Array = []
	for i in mini(3, pool.size()):
		picks.append(pool[i])

	if picks.is_empty():
		var any_pool: Array = CardDB.passives()
		any_pool.shuffle()
		picks = any_pool.slice(0, 3)

	return picks


func _on_hint_chosen(_card: Dictionary) -> void:
	if not _pending:
		return
	_show()


func _show() -> void:
	_stop_hint_pulse()
	_hint.visible = false
	_hint.scale = Vector2(HINT_SCALE, HINT_SCALE)
	_update_hint_badge()

	for card in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()

	var picks := _pick_cards_for_level(_current_upgrade_level)
	if picks.is_empty():
		_pending = false
		_update_hint_badge()
		return

	if not picks.is_empty() and picks[0].get("cat", 0) == CardDB.Category.WEAPON:
		_title.text = "LEVEL 5 — CHOOSE YOUR WEAPON"
	else:
		_title.text = "LEVEL UP — CHOOSE A CARD"

	var total_width: float = picks.size() * CARD_W + (picks.size() - 1) * SPACING
	var start_x: float = -total_width / 2.0

	for i in picks.size():
		var card: Control = Control.new()
		card.set_script(CardScript)
		card.process_mode = Node.PROCESS_MODE_ALWAYS
		card.setup(picks[i], i)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.chosen.connect(_on_card_chosen.bind(card))
		_holder.add_child(card)

		var final_x: float = start_x + i * (CARD_W + SPACING)
		card.position = Vector2(final_x, -CARD_H / 2.0)
		_cards.append(card)

	visible = true
	if is_instance_valid(_minimap):
		_minimap.visible = false
	_dim.visible = true
	_dim.modulate.a = 0.0
	_title.modulate.a = 0.0
	_quit_btn.visible = true
	Game.sfx("card", -15.0, 0.95, 1.08)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(_title, "modulate:a", 1.0, 0.25)

	# Slide cards into place with a short stagger before allowing clicks.
	for i in _cards.size():
		var card: Control = _cards[i]
		var final_y: float = card.position.y
		card.modulate.a = 0.0
		card.position.y = final_y + 520.0
		var card_tween := create_tween()
		card_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		card_tween.tween_interval(i * 0.12)
		card_tween.tween_property(card, "modulate:a", 1.0, 0.20)
		card_tween.parallel().tween_property(
			card, "position:y", final_y, 0.40
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var lock_tween := create_tween()
	lock_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	lock_tween.tween_interval(CLICK_DELAY)
	lock_tween.tween_callback(_unlock_cards)


func _unlock_cards() -> void:
	for card in _cards:
		if is_instance_valid(card):
			card.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_card_chosen(card: Dictionary, _source: Control) -> void:
	if not _pending:
		return

	Game.sfx("click", -14.0, 0.95, 1.1)
	if not Game.grant_card(card):
		# If an option became unavailable, refresh choices without consuming a level.
		_close(_show.bind(), true)
		return

	if not _upgrade_queue.is_empty():
		_current_upgrade_level = int(_upgrade_queue.pop_front())
		_update_hint_badge()
		# Keep the battle UI tucked away during the short transition.
		_close(_show.bind(), true)
		return

	_pending = false
	_closing_after_choice = true
	_current_upgrade_level = 0
	_update_hint_badge()
	_close(_after_choice_closed.bind(), true)


func _dismiss_choices() -> void:
	if not _pending:
		return
	_close(_return_to_hint.bind())


func _return_to_hint() -> void:
	if not _pending:
		_hint.visible = false
		_update_hint_badge()
		return

	_hint.visible = true
	_place_hint()
	_update_hint_badge()
	_start_hint_pulse()


func _after_choice_closed() -> void:
	_closing_after_choice = false
	if not _upgrade_queue.is_empty():
		_pending = true
		_current_upgrade_level = int(_upgrade_queue.pop_front())
		_update_hint_badge()
		_show()
		return

	_pending = false
	_current_upgrade_level = 0
	_hint.visible = false
	_update_hint_badge()
	if is_instance_valid(_minimap):
		_minimap.visible = true


func _close(callback: Callable = Callable(), keep_minimap_hidden: bool = false) -> void:
	# Disable all cards immediately while they animate away.
	for card in _cards:
		if is_instance_valid(card):
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_quit_btn.visible = false
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_dim, "modulate:a", 0.0, 0.20)
	tween.parallel().tween_property(_title, "modulate:a", 0.0, 0.20)
	for card in _cards:
		if is_instance_valid(card):
			tween.parallel().tween_property(card, "modulate:a", 0.0, 0.20)

	tween.tween_callback(func():
		visible = false
		_dim.visible = false
		if not keep_minimap_hidden and is_instance_valid(_minimap):
			_minimap.visible = true

		for card in _cards:
			if is_instance_valid(card):
				card.queue_free()
		_cards.clear()

		if callback.is_valid():
			callback.call()
	)