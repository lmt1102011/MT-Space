extends Node

# Checks the level up screen of the real game scene: the game does not stop,
# a single card waits on the right hand side, clicking it opens the card
# choice and there is a quit button.

var _failed: int = 0
var _cards: CanvasLayer = null


func _ready() -> void:
	# the card screen lives in the real game scene, so we use that one
	var main := load("res://scenes/main.tscn").instantiate() as Node2D
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_cards = main.find_child("UpgradeCards", true, false) as CanvasLayer
	_run()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_failed += 1
		print("  FAIL ", what)


func _run() -> void:
	print("=== level up screen check ===")
	_check(_cards != null, "the card screen exists in the game scene")
	if _cards == null:
		print("=== done: %d failure(s) ===" % _failed)
		get_tree().quit(1)
		return
	_check(get_tree().paused == false, "the tree is not paused to begin with")

	# ask for a card, like the game does when the player levels up
	Game.request_upgrade_choice.emit(2)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(get_tree().paused == false, "the game keeps running after the level up")
	_check(_cards.visible == false, "the card choice is not open yet")

	# the waiting card is on the right hand side
	var hint: Control = _cards.get("_hint") as Control
	_check(hint != null, "there is a waiting card")
	if hint != null:
		_check(hint.visible, "the waiting card is visible")
		var vp := get_viewport().get_visible_rect().size
		_check(hint.position.x > vp.x * 0.5, "the waiting card is on the right side")
		_check(hint.position.y > vp.y * 0.2 and hint.position.y < vp.y * 0.8,
			"the waiting card is in the middle height")

	# clicking it opens the card choice
	hint.emit_signal("chosen", {}, hint)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_cards.visible, "the card choice opened")
	_check(get_tree().paused == false, "the game still runs while the cards are open")

	# the quit button is there
	var quit_btn: Button = _cards.get("_quit_btn") as Button
	_check(quit_btn != null, "there is a quit button")
	if quit_btn != null:
		_check(quit_btn.visible, "the quit button is visible")

	# picking a card closes the screen and gives the upgrade
	var picked: Array = _cards.get("_cards")
	_check(picked.size() > 0, "cards are shown")
	if picked.size() > 0:
		var card: Dictionary = picked[0].get("card")
		var before := Game.upg_stacks.size()
		_cards.call("_on_card_chosen", card, picked[0])
		# the screen fades out, so give it a moment
		for i in 30:
			await get_tree().process_frame
		_check(Game.upg_stacks.size() > before, "the card gave an upgrade")
		_check(_cards.visible == false, "the card choice closed")
		_check(get_tree().paused == false, "the game never got paused")

	print("=== done: %d failure(s) ===" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)
