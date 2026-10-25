extends Node

var _queue: Array = []
var _active: bool = false

func enqueue(card_def: Dictionary) -> void:
	if card_def.is_empty():
		return
	_queue.append(card_def)
	if not _active:
		call_deferred("_process_next")


func _process_next() -> void:
	if _queue.is_empty():
		_active = false
		return
	_active = true
	var scene := get_tree().current_scene
	if scene == null:
		_active = false
		return
	var def: Dictionary = _queue.pop_front()
	var up_cards := scene.get_node_or_null("UpgradeCards")
	if up_cards != null and up_cards.has_method("show_single_card"):
		up_cards.show_single_card(def, _on_done)
		return
	if up_cards != null and up_cards.has_method("show_cards"):
		up_cards.show_cards([def], _on_done)
		return
	_on_done({})


func _on_done(_choice: Dictionary = {}) -> void:
	call_deferred("_process_next")
