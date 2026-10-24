extends Node

# Integration check for the in-game level-up hint, its queue badge, dismiss
# behavior, and consecutive upgrade choices.
var _failed: int = 0
var _cards: CanvasLayer = null


func _ready() -> void:
	Game.reset_run()
	var main := load("res://scenes/main.tscn").instantiate() as Node2D
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_cards = main.find_child("UpgradeCards", true, false) as CanvasLayer
	await _run()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failed += 1
		print("  FAIL ", what)


func _wait_frames(count: int = 20) -> void:
	for i in count:
		await get_tree().process_frame


func _choice_screen_visible() -> bool:
	var dim := _cards.get("_dim") as ColorRect
	var quit_btn := _cards.get("_quit_btn") as Button
	return dim != null and dim.visible and quit_btn != null and quit_btn.visible


func _total_upgrade_stacks() -> int:
	var total := 0
	for value in Game.upg_stacks.values():
		total += int(value)
	return total


func _choice_ids() -> Array:
	var ids: Array = []
	for choice in _cards.get("_cards") as Array:
		var card: Dictionary = choice.get("card")
		ids.append(str(card.get("id", "")))
	return ids


func _choose_first_card() -> void:
	var picked: Array = _cards.get("_cards")
	_check(not picked.is_empty(), "upgrade choices are present")
	if picked.is_empty():
		return
	var chosen_card: Dictionary = picked[0].get("card")
	var before := _total_upgrade_stacks()
	_cards.call("_on_card_chosen", chosen_card, picked[0])
	await get_tree().create_timer(0.30).timeout
	_check(_total_upgrade_stacks() > before, "the selected card applied an upgrade")


func _run() -> void:
	print("=== level up screen check ===")
	_check(_cards != null, "the card screen exists in the game scene")
	if _cards == null:
		print("=== done: %d failure(s) ===" % _failed)
		get_tree().quit(1)
		return
	_check(not get_tree().paused, "the tree is not paused to begin with")

	# Simulate three level-up events arriving before the player chooses.
	Game.request_upgrade_choice.emit(2)
	Game.request_upgrade_choice.emit(3)
	Game.request_upgrade_choice.emit(4)
	await _wait_frames(2)

	_check(not get_tree().paused, "the game keeps running after the level up")
	_check(not _choice_screen_visible(), "the full choice screen stays closed until the hint is clicked")

	# the waiting card is on the right hand side
	var hint: Control = _cards.get("_hint") as Control
	var badge: Label = _cards.get("_hint_badge") as Label
	_check(hint != null and hint.visible, "the compact hint card is visible")
	_check(badge != null and badge.text == "3" and badge.visible,
		"the badge counts all three pending upgrade choices")
	if hint != null:
		var vp := get_viewport().get_visible_rect().size
		_check(hint.position.x > vp.x * 0.5, "the hint card is on the right side")
		_check(hint.position.y > vp.y * 0.2 and hint.position.y < vp.y * 0.8,
			"the hint card is vertically centered")

	# Clicking the hint opens the choices; closing them should preserve the queue.
	var hint_button := hint as Button
	_check(hint_button != null, "the compact hint is a button")
	if hint_button == null:
		get_tree().quit(1)
		return
	hint_button.pressed.emit()
	await _wait_frames(3)
	_check(_choice_screen_visible(), "clicking the hint opens the upgrade choices")
	_check(not get_tree().paused, "the game still runs while the cards are open")
	var initial_choice_ids := _choice_ids()

	# the quit button is there
	var quit_btn: Button = _cards.get("_quit_btn") as Button
	_check(quit_btn != null and quit_btn.visible, "the exit button is visible")
	if quit_btn != null:
		quit_btn.pressed.emit()
		await get_tree().create_timer(0.30).timeout
	_check(not _choice_screen_visible(), "the exit button closes the choice screen")
	_check(hint.visible, "closing choices returns to the compact hint card")
	_check(badge.text == "3", "closing choices does not lose pending upgrades")
	hint_button.pressed.emit()
	await _wait_frames(3)
	_check(_choice_ids() == initial_choice_ids,
		"reopening the same upgrade preserves the original card choices")
	quit_btn.pressed.emit()
	await get_tree().create_timer(0.30).timeout

	# Resolve each queued choice and verify the badge tracks what remains.
	hint_button.pressed.emit()
	await _wait_frames(3)
	await _choose_first_card()
	_check(_choice_screen_visible(), "the next upgrade choice opens automatically")
	_check(badge.text == "2", "the badge count drops after the first choice")

	await _choose_first_card()
	_check(_choice_screen_visible(), "the third upgrade choice opens automatically")
	_check(badge.text == "1", "one pending choice remains")

	await _choose_first_card()
	_check(not _choice_screen_visible(), "the choice screen closes after the final upgrade")
	_check(not hint.visible and not badge.visible,
		"the compact hint and counter disappear when all choices are complete")
	_check(not get_tree().paused, "the game was never paused by the level-up flow")

	print("=== done: %d failure(s) ===" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)
