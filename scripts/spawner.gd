extends Node2D

@export var min_spawn_dist: float = 500.0
@export var max_spawn_dist: float = 950.0
@export var spawn_interval: float = 0.7
# Dead players stay spectating during this full rest period. They are revived
# only when the next wave is actually announced, never immediately on death.
@export var intermission: float = 20.0

# The swarm shapes are ambient: they are not part of a wave, they keep
# trickling in on their own and only the amount alive on the map is capped.
const MAX_SHAPE := 12
const SHAPE_INTERVAL := 1.6
# hard cap on the wave enemies so a busy wave never floods the screen
const MAX_TOTAL := 20

const SHAPE_SCENE := preload("res://scenes/enemy.tscn")
const SHOOTER_SCENE := preload("res://scenes/shooter_enemy.tscn")
const DOUBLE_SCENE := preload("res://scenes/double_enemy.tscn")
const RAILGUN_SCENE := preload("res://scenes/railgun_enemy.tscn")
const CHARGER_SCENE := preload("res://scenes/charger_enemy.tscn")
const ORB_ENEMY_SCENE := preload("res://scenes/orb_enemy.tscn")
const BOSS_SCENE := preload("res://scenes/boss_1.tscn")
const BOSS2_SCENE := preload("res://scenes/boss_2.tscn")
const BEAM_ENEMY_SCENE := preload("res://scenes/beam_enemy.tscn")
const BOSS_DRONE_SCENE := preload("res://scenes/boss_drone.tscn")
const BOSS_WAVE_INTERVAL := 10

signal wave_cleared_text(show: bool)

var _phase: String = "waiting"   # waiting | spawning | clearing | countdown
var _spawn_queue: Array = []
var _spawn_timer: float = 0.0
var _countdown: float = 0.0
var _shape_timer: float = 0.0


func _ready() -> void:
	# the host runs the waves, a client only follows what the host says
	if _is_client():
		return
	await get_tree().create_timer(0.5).timeout
	_start_next_wave()


# True when this machine is a client in a network game.
func _is_client() -> bool:
	return Net.is_online() and not Net.is_host()


func _process(delta: float) -> void:
	# a client does not think for itself, the host tells it what to show
	if _is_client():
		return
	# the swarm shapes keep coming on their own, they are not part of a wave
	_spawn_shapes(delta)
	match _phase:
		"spawning":
			_spawn_timer -= delta
			if _spawn_timer <= 0.0 and not _spawn_queue.is_empty():
				_spawn_timer = spawn_interval
				_spawn_from_queue()
			if _spawn_queue.is_empty():
				_phase = "clearing"

		"clearing":
			# the wave only ends once every wave enemy is dead, the ambient
			# shapes do not count
			if get_tree().get_nodes_in_group("monster").is_empty():
				_phase = "countdown"
				_countdown = intermission
				Game.wave_cleared.emit(Game.wave)
				wave_cleared_text.emit(true)
				_revive_dead_players()

		"countdown":
			_countdown -= delta
			Game.countdown_changed.emit(int(ceil(maxf(_countdown, 0.0))))
			if _countdown <= 0.0:
				wave_cleared_text.emit(false)
				_start_next_wave()


# Trickles in the ambient swarm shapes, up to the cap on how many are alive.
func _spawn_shapes(delta: float) -> void:
	if Game.wave > 0 and Game.wave % BOSS_WAVE_INTERVAL == 0:
		return
	_shape_timer -= delta
	if _shape_timer > 0.0:
		return
	_shape_timer = SHAPE_INTERVAL
	if _shape_count_alive() >= MAX_SHAPE:
		return
	_spawn_enemy("shape")


func _shape_count_alive() -> int:
	return get_tree().get_nodes_in_group("shape_enemy").size()


func _revive_dead_players() -> void:
	var local_player := get_tree().current_scene.get_node_or_null("Player")
	if local_player != null and local_player.get("_dead") == true \
			and local_player.has_method("revive_for_wave"):
		local_player.call("revive_for_wave")
	var world := get_tree().get_first_node_in_group("net_world")
	if world != null and world.has_method("revive_remote_players"):
		world.call("revive_remote_players")
	Net.send_revive_dead_players()


func _start_next_wave() -> void:
	var local_player := get_tree().current_scene.get_node_or_null("Player")
	if local_player != null and local_player.has_method("revive_for_wave"):
		local_player.call("revive_for_wave")
	var world := get_tree().get_first_node_in_group("net_world")
	if world != null and world.has_method("revive_remote_players"):
		world.call("revive_remote_players")
	Game.wave += 1
	Game.wave_changed.emit(Game.wave)
	Game.sfx("alert", -17.0, 0.97, 1.05)
	_build_queue(Game.wave)
	_spawn_timer = 0.25
	_phase = "spawning"
	# tell the clients which wave it is
	Net.send_wave(Game.wave)


func _build_queue(wave: int) -> int:
	_spawn_queue.clear()
	if wave % 20 == 0:
		for i in randi_range(1, 3):
			_spawn_queue.append("boss2")
		return _spawn_queue.size()
	if wave % BOSS_WAVE_INTERVAL == 0:
		_spawn_queue.append("boss")
		return _spawn_queue.size()
	for i in _shooter_count(wave):
		_spawn_queue.append("shooter")
	for i in _double_count(wave):
		_spawn_queue.append("double")
	for i in _railgun_count(wave):
		_spawn_queue.append("railgun")
	for i in _charger_count(wave):
		_spawn_queue.append("charger")
	for i in _orb_count(wave):
		_spawn_queue.append("orb")
	for i in _beam_count(wave):
		_spawn_queue.append("beam_enemy")
	_spawn_queue.shuffle()
	return _spawn_queue.size()


func _spawn_from_queue() -> void:
	if _spawn_queue.is_empty():
		return
	# if the live cap is reached the enemy waits in the queue instead of
	# being dropped, so the wave always ends with every enemy dead
	if get_tree().get_nodes_in_group("monster").size() >= MAX_TOTAL:
		return
	var kind: String = _spawn_queue.pop_front()
	_spawn_enemy(kind)


func _shooter_count(wave: int) -> int:
	return clampi(2 + (wave - 1) / 2, 2, 5)


func _double_count(wave: int) -> int:
	if wave < 3:
		return 0
	return clampi(1 + (wave - 3) / 2, 1, 4)


func _railgun_count(wave: int) -> int:
	# shows up from wave 4, at most 3 at a time
	return clampi((wave - 2) / 2, 0, 3)


func _charger_count(wave: int) -> int:
	# shows up from wave 3, at most 3 at a time
	return clampi((wave - 1) / 2, 0, 3)


func _orb_count(wave: int) -> int:
	if wave < 4:
		return 0
	# Orb enemies scale with the later waves as well, instead of staying capped
	# at two while the other elite types continue increasing.
	return clampi(1 + (wave - 4) / 2, 1, 5)


func _beam_count(wave: int) -> int:
	if wave < 6:
		return 0
	return clampi(1 + (wave - 6) / 5, 1, 3)


func _total_count(wave: int) -> int:
	if wave % 20 == 0:
		return 2
	if wave % BOSS_WAVE_INTERVAL == 0:
		return 1
	# only the wave enemies, the shapes are ambient
	return _shooter_count(wave) + _double_count(wave) \
		+ _railgun_count(wave) + _charger_count(wave) + _orb_count(wave) \
		+ _beam_count(wave)


func _spawn_enemy(kind: String, boss_minion: bool = false) -> void:
	# the host owns the world, the clients get the enemies from it
	if Net.is_online() and not Net.is_host():
		return
	# never let the live enemy count run away
	if kind == "shape":
		# the ambient swarm has its own cap, the wave does not limit it
		if _shape_count_alive() >= MAX_SHAPE:
			return
	elif get_tree().get_nodes_in_group("monster").size() >= MAX_TOTAL:
		return
	var targets: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group("player"):
		var player := candidate as Node2D
		if player == null or not is_instance_valid(player):
			continue
		if player.get("_dead") == true or player.get("net_alive") == false:
			continue
		targets.append(player)
	var target: Node2D = targets[randi_range(0, targets.size() - 1)] if not targets.is_empty() else null
	var center: Vector2 = target.global_position if target else Vector2.ZERO

	# the ambient swarm shows up closer, it is the constant background
	# pressure rather than a set piece
	var near := min_spawn_dist
	var far := max_spawn_dist
	if kind == "shape":
		near = 260.0
		far = 560.0

	var pos := center
	for tries in range(20):
		var angle := randf() * TAU
		var dist := randf_range(near, far)
		pos = center + Vector2.from_angle(angle) * dist
		pos = pos.clamp(Vector2(-2630, -1530), Vector2(2630, 1530))
		if pos.distance_to(center) >= near:
			break

	var speed_mult := Game.enemy_speed_mult()
	var dmg_bonus := Game.enemy_damage_bonus()
	var fire_mult := Game.enemy_fire_mult()
	var hp_mult := 1.0 + (Game.wave - 1) * 0.1

	# the shape enemies vary a little, the others are all the same
	var sides := randi_range(3, 6)
	var radius := randf_range(16.0, 40.0)
	var params := {
		"speed_mult": speed_mult,
		"dmg_bonus": dmg_bonus,
		"fire_mult": fire_mult,
		"hp_mult": hp_mult,
		"sides": sides,
		"radius": radius,
	}
	var enemy: Node2D = null
	if Net.is_online():
		# the host spawns it and tells the clients
		enemy = _net_world().spawn_enemy(kind, pos, params) if _net_world() != null else null
		if enemy == null:
			return
	else:
		enemy = _spawn_local(kind, pos, params)
		if enemy == null:
			return

	# the shape enemies need their own collision shape, the scene shares one
	if kind == "shape":
		var cs := enemy.get_node("CollisionShape2D") as CollisionShape2D
		var shape := cs.shape.duplicate() as CircleShape2D
		shape.radius = radius
		cs.shape = shape
	if kind != "shape" and kind != "boss":
		_maybe_elite(enemy)
	if boss_minion:
		enemy.add_to_group("boss_minion")


func spawn_boss_minions() -> void:
	if _is_client():
		return
	if not get_tree().get_nodes_in_group("boss_minion").is_empty():
		return
	var minion_kinds := ["shooter", "double", "railgun", "charger", "orb"]
	var minion_count := randi_range(2, 4)
	for i in minion_count:
		var kind: String = minion_kinds.pick_random()
		_spawn_enemy(kind, true)


func spawn_boss_drones(origin: Vector2) -> void:
	if _is_client() or not get_tree().get_nodes_in_group("boss_drone").is_empty():
		return
	var count := randi_range(2, 4)
	var params := {
		"speed_mult": Game.enemy_speed_mult(),
		"dmg_bonus": Game.enemy_damage_bonus(),
		"fire_mult": Game.enemy_fire_mult(),
		"hp_mult": 1.0 + (Game.wave - 1) * 0.1,
	}
	for index in count:
		if get_tree().get_nodes_in_group("monster").size() >= MAX_TOTAL:
			return
		var pos := origin + Vector2.from_angle(randf() * TAU) * randf_range(24.0, 44.0)
		if Net.is_online():
			var world := _net_world()
			if world != null:
				world.call("spawn_enemy", "boss_drone", pos, params)
		else:
			var drone := BOSS_DRONE_SCENE.instantiate() as Node2D
			drone.global_position = pos
			add_child(drone)
			drone.call("setup", float(params["speed_mult"]),
				int(params["dmg_bonus"]), float(params["fire_mult"]),
				float(params["hp_mult"]))


func _net_world() -> Node:
	var n := get_tree().get_first_node_in_group("net_world")
	return n


func _spawn_local(kind: String, pos: Vector2, params: Dictionary) -> Node2D:
	var scene: PackedScene = null
	match kind:
		"shape":
			scene = SHAPE_SCENE
		"shooter":
			scene = SHOOTER_SCENE
		"double":
			scene = DOUBLE_SCENE
		"railgun":
			scene = RAILGUN_SCENE
		"charger":
			scene = CHARGER_SCENE
		"orb":
			scene = ORB_ENEMY_SCENE
		"boss":
			scene = BOSS_SCENE
		"boss2":
			scene = BOSS2_SCENE
		"beam_enemy":
			scene = BEAM_ENEMY_SCENE
		"boss_drone":
			scene = BOSS_DRONE_SCENE
	if scene == null:
		return null
	var enemy := scene.instantiate() as Node2D
	enemy.global_position = pos
	add_child(enemy)
	match kind:
		"shape":
			enemy.call("setup", int(params["sides"]), float(params["radius"]),
				float(params["speed_mult"]), int(params["dmg_bonus"]))
		_:
			enemy.call("setup", float(params["speed_mult"]), int(params["dmg_bonus"]),
				float(params["fire_mult"]), float(params["hp_mult"]))
	return enemy


func _maybe_elite(enemy: Node) -> void:
	if randf() >= _elite_chance():
		return
	if not enemy.has_method("make_elite"):
		return
	enemy.make_elite(randi_range(1, _elite_max_cards()))
	Game.sfx("elite", -14.0, 0.96, 1.05)


func _elite_chance() -> float:
	return clampf(0.05 + Game.wave * 0.02, 0.0, 0.35)


func _elite_max_cards() -> int:
	return clampi(1 + (Game.wave - 1) / 3, 1, 6)
