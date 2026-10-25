extends Node2D

const SPAWNER_SCRIPT := preload("res://scripts/spawner.gd")
const BOSS_SCENE := preload("res://scenes/boss_1.tscn")

var _fails := 0


func _ready() -> void:
	print("=== boss check ===")
	_check_wave_queue()
	await _check_boss()
	print("=== done: %d failure(s) ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check_wave_queue() -> void:
	var spawner: Object = SPAWNER_SCRIPT.new()
	_check(spawner._build_queue(10) == 1, "wave 10 queues a single boss")
	_check(spawner._spawn_queue == ["boss"], "wave 10 does not queue regular enemies")
	_check(spawner._total_count(10) == 1, "wave 10 count includes only the boss")
	_check(spawner._total_count(11) > 1, "wave 11 returns to normal wave composition")
	spawner.free()


func _check_boss() -> void:
	var boss := BOSS_SCENE.instantiate() as Node2D
	add_child(boss)
	await get_tree().process_frame
	_check(boss.is_in_group("monster"), "boss blocks wave completion while alive")
	boss.call("setup", 1.0, 0, 1.0, 1.9)
	_check(int(boss.get("max_hp")) > 1000, "boss health scales to a tanky wave-10 value")
	var hp_before := int(boss.get("hp"))
	boss.call("take_damage", 25.0)
	_check(int(boss.get("hp")) == hp_before - 25,
		"boss takes damage through the enemy damage system")
	boss.queue_free()
	await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		_fails += 1
		print("FAIL  ", label)
