extends Node

# Integration check for the in-game level-up hint, its queue badge, dismiss
# behavior, and consecutive upgrade choices.
var _failed: int = 0
var _cards: CanvasLayer = null


func _ready() -> void:
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


func _choose_first_card() -> void:
	var picked: Array = _cards.get("_cards")
	_check(not picked.is_empty(), "upgrade choices are present")
	if picked.is_empty():
		return
	var chosen_card: Dictionary = picked[0].get("card")
	var before := Game.upg_stacks.size()
	_cards.call("_on_card_chosen", chosen_card, picked[0])
	await _wait_frames(20)
	_check(Game.upg_stacks.size() > before, "the selected card applied an upgrade")


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

	_check(not get_tree().paused, "the game keeps running after a level up")
	_check(not _cards.visible, "the full choice screen stays closed until the hint is clicked")
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
	hint.emit_signal("chosen", {})
	await _wait_frames(3)
	_check(_cards.visible, "clicking the hint opens the upgrade choices")
	_check(not get_tree().paused, "the game continues while choices are open")
	var quit_btn: Button = _cards.get("_quit_btn") as Button
	_check(quit_btn != null and quit_btn.visible, "the exit button is visible")
	if quit_btn != null:
		quit_btn.pressed.emit()
		await _wait_frames(20)
	_check(not _cards.visible, "the exit button closes the choice screen")
	_check(hint.visible, "closing choices returns to the compact hint card")
	_check(badge.text == "3", "closing choices does not lose pending upgrades")

	# Reopen and choose once. There must immediately be another choice screen.
	hint.emit_signal("chosen", {})
	await _wait_frames(3)
	await _choose_first_card()
	_check(_cards.visible, "the next upgrade choice opens automatically")
	_check(badge.text == "2", "the badge count drops after the first choice")

	await _choose_first_card()
	_check(_cards.visible, "the third upgrade choice opens automatically")
	_check(badge.text == "1", "one pending choice remains")

	await _choose_first_card()
	_check(not _cards.visible, "the choice screen closes after the final upgrade")
	_check(not hint.visible and not badge.visible,
		"the compact hint and counter disappear when all choices are complete")
	_check(not get_tree().paused, "the game was never paused by the level-up flow")

	print("=== done: %d failure(s) ===" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)