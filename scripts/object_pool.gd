extends Node
class_name Pool

const MAX_POOLED_PER_SCENE := 128

var _available: Dictionary = {}
static var _instance: Pool


func _ready() -> void:
	_instance = self


static func acquire(scene: PackedScene, parent: Node) -> Node:
	if _instance == null:
		push_error("ObjectPool autoload is not available.")
		return null
	return _instance._acquire(scene, parent)


func _acquire(scene: PackedScene, parent: Node) -> Node:
	if scene == null or parent == null:
		push_error("ObjectPool.acquire requires a scene and parent.")
		return null
	var key := scene.resource_path
	var bucket: Array = _available.get(key, [])
	var instance: Node = null
	while not bucket.is_empty() and instance == null:
		var candidate: Node = bucket.pop_back()
		if is_instance_valid(candidate):
			instance = candidate
	if instance == null:
		instance = scene.instantiate()
		instance.set_meta("_pool_scene_key", key)
		instance.hide()
		parent.add_child(instance)
	else:
		instance.reparent(parent)
	_available[key] = bucket
	instance.set_meta("_pool_available", false)
	instance.show()
	instance.set_process(true)
	instance.set_physics_process(true)
	if instance.has_method("pool_activate"):
		instance.call("pool_activate")
	return instance


static func release(instance: Node) -> void:
	if _instance == null:
		push_error("ObjectPool autoload is not available.")
		return
	_instance._release(instance)


func _release(instance: Node) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	if instance.get_meta("_pool_available", false):
		return
	var key := str(instance.get_meta("_pool_scene_key", ""))
	if key.is_empty():
		instance.queue_free()
		return
	instance.set_meta("_pool_available", true)
	if instance.has_method("pool_deactivate"):
		instance.call("pool_deactivate")
	instance.hide()
	instance.set_process(false)
	instance.set_physics_process(false)
	if instance is Area2D:
		var area := instance as Area2D
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
	call_deferred("_store_released", instance, key)


func _store_released(instance: Node, key: String) -> void:
	if not is_instance_valid(instance):
		return
	var bucket: Array = _available.get(key, [])
	if bucket.size() >= MAX_POOLED_PER_SCENE:
		instance.queue_free()
		return
	var parent := instance.get_parent()
	if parent == null:
		add_child(instance)
	elif parent != self:
		instance.reparent(self)
	bucket.append(instance)
	_available[key] = bucket


static func prewarm(scene: PackedScene, count: int, parent: Node) -> void:
	if _instance == null:
		push_error("ObjectPool autoload is not available.")
		return
	_instance._prewarm(scene, count, parent)


func _prewarm(scene: PackedScene, count: int, parent: Node) -> void:
	if scene == null or parent == null or count <= 0:
		return
	var key := scene.resource_path
	var bucket: Array = _available.get(key, [])
	while bucket.size() < mini(count, MAX_POOLED_PER_SCENE):
		var instance := scene.instantiate()
		instance.set_meta("_pool_scene_key", key)
		parent.add_child(instance)
		instance.set_meta("_pool_available", false)
		if instance.has_method("pool_deactivate"):
			instance.call("pool_deactivate")
		instance.hide()
		instance.set_process(false)
		instance.set_physics_process(false)
		if instance is Area2D:
			var area := instance as Area2D
			area.set_deferred("monitoring", false)
			area.set_deferred("monitorable", false)
		instance.set_meta("_pool_available", true)
		_store_released(instance, key)
		bucket = _available.get(key, [])
