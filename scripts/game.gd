extends Node

signal wave_changed(wave: int)
signal wave_cleared(wave: int)
signal countdown_changed(seconds_left: int)
signal xp_changed(xp: int, xp_needed: int)
signal level_changed(level: int)
signal game_over
signal card_collected(card: Dictionary)
signal spectate_changed(target_id: int)

var wave: int = 0
var active: bool = true
var is_game_over: bool = false
var player_dead: bool = false
# true when the player is dead but the game goes on and is being watched
var spectate_mode: bool = false
# the peer that is being watched
var spectate_target: int = 0

var level: int = 1
var xp: int = 0

# --- player upgrade stats (modified by cards) ---
var upg_fire_rate: float = 1.0        # multiplies fire speed (higher = faster)
var upg_bullet_speed: float = 1.0     # multiplies bullet travel speed
var upg_move_speed: float = 1.0       # multiplies player max speed
var upg_damage: float = 1.0           # multiplies bullet damage
var upg_burn: int = 0                 # burn stacks applied on hit
var upg_freeze: int = 0               # freeze stacks applied on hit
var upg_chaos: int = 0                # extra random-angle bullets count (legacy)
var upg_stacks: Dictionary = {}       # card id -> times taken

# newer passive upgrades
var upg_lifesteal: bool = false
var upg_crit: float = 0.0
var upg_extra_shots: int = 0
var upg_magnet: float = 1.0
var upg_bonus_hp: int = 0
var upg_regen: int = 0
var upg_pierce: int = 0
var upg_homing: int = 0
var upg_splash: int = 0
var upg_elite_hunter: int = 0
var upg_bloodthirst: int = 0
var upg_plating: int = 0
var upg_level_heal: int = 0
var upg_xp_greed: int = 0
var upg_inferno: int = 0
var upg_brittle: int = 0
var upg_thorns: int = 0
var upg_pierce_focus: int = 0
var upg_explosive: int = 0
var upg_scavenger: int = 0
var upg_rushed: int = 0
var upg_heavy_caliber: int = 0
var upg_second_chance: int = 0
var upg_cold_blood: int = 0
var upg_range: float = 0.0
var upg_momentum: int = 0
var upg_close_quarters: int = 0

var weapon: String = "basic"          # chosen weapon archetype (from LV5 card)
var weapon_chosen: bool = false
var _burst_left: int = 0              # internal burst counter for player

# --- test mode (set from the lobby TEST MENU) ---
var test_mode: bool = false
var test_data: Dictionary = {}

# --- audio ---
const SfxLib := preload("res://scripts/sfx.gd")
const CARD_RECORDS := preload("res://scripts/card_db.gd")
const FIRE_LOOP_PATH := "res://assets/sfx/fire_loop.mp3"
var _sfx_players: Array[AudioStreamPlayer] = []
var _fire_player: AudioStreamPlayer
var _fire_on: bool = false

# --- run records ---
const RUN_RECORDS_PATH := "user://run_records.cfg"
var latest_run: Dictionary = {}
var best_run: Dictionary = {}
var card_pick_counts: Dictionary = {}
var _run_started_at_msec: int = 0
var _run_damage: int = 0
var _run_bosses_killed: int = 0
var _run_boss_kill_times: Array[float] = []
var _run_boss_started_at: Dictionary = {}
var _run_max_wave: int = 0
var _run_active: bool = false
var _run_finished: bool = false
var _impact_cooldown: float = 0.0
var _camera_shake_time: float = 0.0
var _camera_shake_strength: float = 0.0
var _hitstop_active: bool = false


func _ready() -> void:
	_load_settings()
	_load_run_records()
	for i in SfxLib.POOL:
		var p := AudioStreamPlayer.new()
		# must keep playing while the tree is paused (card screen, game over)
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players.append(p)
	SfxLib.setup(_sfx_players)
	# looping crackle that plays while the player is burning
	var loop_stream := load(FIRE_LOOP_PATH) as AudioStreamMP3
	if loop_stream != null:
		loop_stream.loop = true
		_fire_player = AudioStreamPlayer.new()
		_fire_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_fire_player.stream = loop_stream
		_fire_player.volume_db = -80.0
		add_child(_fire_player)


func _process(delta: float) -> void:
	_impact_cooldown = maxf(_impact_cooldown - delta, 0.0)
	if _camera_shake_time <= 0.0:
		return
	_camera_shake_time = maxf(_camera_shake_time - delta, 0.0)
	var viewport := get_viewport()
	if viewport == null:
		return
	var camera := viewport.get_camera_2d()
	if camera == null:
		return
	if _camera_shake_time <= 0.0:
		camera.offset = Vector2.ZERO
		return
	var falloff := clampf(_camera_shake_time / 0.2, 0.0, 1.0)
	camera.offset = Vector2(
		randf_range(-_camera_shake_strength, _camera_shake_strength),
		randf_range(-_camera_shake_strength, _camera_shake_strength)
	) * falloff


# Play a sound effect (see res://scripts/sfx.gd)
func sfx(sound: String, volume_db: float = 0.0,
		pitch_lo: float = 0.93, pitch_hi: float = 1.09) -> void:
	SfxLib.play(sound, volume_db, pitch_lo, pitch_hi)


func _load_run_records() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUN_RECORDS_PATH) != OK:
		return
	var latest: Variant = cfg.get_value("records", "latest_run", {})
	var best: Variant = cfg.get_value("records", "best_run", {})
	var picks: Variant = cfg.get_value("records", "card_pick_counts", {})
	latest_run = latest if latest is Dictionary else {}
	best_run = best if best is Dictionary else {}
	card_pick_counts = picks if picks is Dictionary else {}


func _save_run_records() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "latest_run", latest_run)
	cfg.set_value("records", "best_run", best_run)
	cfg.set_value("records", "card_pick_counts", card_pick_counts)
	var error := cfg.save(RUN_RECORDS_PATH)
	if error != OK:
		push_error("Could not save run records: %s" % error_string(error))


func start_run() -> void:
	if _run_active:
		return
	_run_active = true
	_run_finished = false
	_run_started_at_msec = Time.get_ticks_msec()
	_run_damage = 0
	_run_bosses_killed = 0
	_run_boss_kill_times.clear()
	_run_boss_started_at.clear()
	_run_max_wave = maxi(wave, 0)


func record_damage(amount: int) -> void:
	if not _run_active or _run_finished or test_mode or amount <= 0:
		return
	_run_damage += amount


func record_wave(wave_number: int) -> void:
	if not _run_active or _run_finished or test_mode:
		return
	_run_max_wave = maxi(_run_max_wave, wave_number)


func register_boss_spawn(boss_instance_id: int) -> void:
	if not _run_active or _run_finished or test_mode:
		return
	if Net.is_online() and not Net.is_host():
		return
	_run_boss_started_at[boss_instance_id] = Time.get_ticks_msec()


func record_boss_kill(boss_instance_id: int) -> void:
	if not _run_active or _run_finished or test_mode:
		return
	_run_bosses_killed += 1
	if not _run_boss_started_at.has(boss_instance_id):
		return
	var started_at := int(_run_boss_started_at[boss_instance_id])
	_run_boss_started_at.erase(boss_instance_id)
	_run_boss_kill_times.append(
		maxf(float(Time.get_ticks_msec() - started_at) / 1000.0, 0.0)
	)


func finish_run() -> void:
	if not _run_active or _run_finished:
		return
	_run_finished = true
	_run_active = false
	if test_mode:
		return
	var elapsed := maxf(
		float(Time.get_ticks_msec() - _run_started_at_msec) / 1000.0, 0.0)
	var build_ids: Array = upg_stacks.keys()
	build_ids.sort()
	var build: Array[String] = []
	if not weapon.is_empty():
		build.append("weapon_" + weapon)
	var card_names: Dictionary = {}
	for card: Dictionary in CARD_RECORDS.passives():
		card_names[str(card.get("id", ""))] = str(card.get("name", ""))
	for card_id: Variant in build_ids:
		var count := int(upg_stacks[card_id])
		var card_name := str(card_names.get(str(card_id), str(card_id)))
		build.append("%s x%d" % [card_name, count])
	var average_boss_kill_time := 0.0
	if not _run_boss_kill_times.is_empty():
		var total_boss_kill_time := 0.0
		for kill_time in _run_boss_kill_times:
			total_boss_kill_time += kill_time
		average_boss_kill_time = total_boss_kill_time \
			/ float(_run_boss_kill_times.size())
	latest_run = {
		"wave": _run_max_wave,
		"bosses": _run_bosses_killed,
		"boss_kill_times": _run_boss_kill_times.duplicate(),
		"average_boss_kill_seconds": average_boss_kill_time,
		"damage": _run_damage,
		"seconds": elapsed,
		"build": build,
		"cards": upg_stacks.duplicate(true),
	}
	var latest_wave := int(latest_run.get("wave", 0))
	var best_wave := int(best_run.get("wave", 0))
	if latest_wave > best_wave \
			or (latest_wave == best_wave
				and elapsed > float(best_run.get("seconds", 0.0))):
		best_run = latest_run.duplicate(true)
	_save_run_records()


func build_item_label(item: String) -> String:
	var item_name := item
	var count_suffix := ""
	var count_separator := item.rfind(" x")
	if count_separator > 0 and item.substr(count_separator + 2).is_valid_int():
		item_name = item.substr(0, count_separator)
		count_suffix = " x" + item.substr(count_separator + 2)
	var resolved_name := ""
	if item_name.begins_with("weapon_"):
		for card: Dictionary in CARD_RECORDS.weapon_cards():
			if str(card.get("id", "")) == item_name:
				resolved_name = str(card.get("name", ""))
				break
	else:
		for card: Dictionary in CARD_RECORDS.passives():
			if str(card.get("name", "")) == item_name \
					or str(card.get("id", "")) == item_name:
				resolved_name = str(card.get("name", ""))
				break
	if resolved_name.is_empty():
		resolved_name = item_name.replace("_", " ").capitalize()
	var locale := get_node_or_null("/root/Locale")
	if locale != null:
		resolved_name = str(locale.call("translate_text", resolved_name))
	return resolved_name + count_suffix


func combat_impact(strength: float = 1.0) -> void:
	if _impact_cooldown > 0.0:
		return
	var impact := clampf(strength, 0.0, 1.0)
	if impact <= 0.0:
		return
	_impact_cooldown = lerpf(0.12, 0.075, impact)
	_camera_shake_strength = maxf(_camera_shake_strength, impact * 2.2)
	_camera_shake_time = maxf(_camera_shake_time, 0.16)
	if _hitstop_active or impact < 0.9:
		return
	_hitstop_active = true
	Engine.time_scale = 0.12
	var timer := get_tree().create_timer(0.035, true, false, true)
	timer.timeout.connect(_end_hitstop, CONNECT_ONE_SHOT)


func _end_hitstop() -> void:
	Engine.time_scale = 1.0
	_hitstop_active = false


func spawn_boss_death_effect(position: Vector2, tint: Color,
		size_scale: float) -> void:
	if not is_inside_tree():
		return
	var world := get_tree().current_scene
	if world == null:
		return
	var burst_count := 5
	for index in burst_count:
		var timer := get_tree().create_timer(0.14 * float(index), true, false, true)
		timer.timeout.connect(
			_spawn_boss_death_burst.bind(position, tint, size_scale, index),
			CONNECT_ONE_SHOT
		)


func _spawn_boss_death_burst(position: Vector2, tint: Color,
		size_scale: float, index: int) -> void:
	if not is_inside_tree():
		return
	var world := get_tree().current_scene
	if world == null:
		return
	var burst_count := 5
	var explosion := Pool.acquire(
		preload("res://scenes/explosion.tscn"), world) as Explosion
	if explosion != null:
		var angle := TAU * float(index) / float(burst_count)
		var radius := 22.0 + 18.0 * float(index)
		explosion.global_position = position + Vector2.from_angle(angle) * radius
		var scale := (0.8 if index < burst_count - 1 else 3.0) * size_scale
		explosion.setup(scale, tint)
	if index == burst_count - 1:
		sfx("boom_big", -7.0, 0.78, 0.9)


func spawn_hit_effect(position: Vector2, tint: Color) -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	var effect := Pool.acquire(
		preload("res://scenes/explosion.tscn"), world) as Explosion
	if effect == null:
		return
	effect.global_position = position
	effect.setup(0.32, tint)


# The volume of the player, from 0 to 1.
func get_master_volume() -> float:
	return SfxLib.master_volume


func set_master_volume(value: float) -> void:
	SfxLib.master_volume = clampf(value, 0.0, 1.0)
	# the burning loop follows the volume too
	if _fire_player != null and _fire_on:
		_fire_player.volume_db = SfxLib._master_db() - 20.0
	_save_settings()


# --- how the game is played --------------------------------------------------
# 0 means the keyboard and the mouse, 1 means the two sticks on a phone
const CONTROL_PC := 0
const CONTROL_MOBILE := 1

var control_mode: int = CONTROL_PC


func is_mobile_mode() -> bool:
	return control_mode == CONTROL_MOBILE


func set_control_mode(mode: int) -> void:
	control_mode = CONTROL_MOBILE if mode == CONTROL_MOBILE else CONTROL_PC


# The controls are picked by the device the game runs on: a phone gets the
# two sticks, a computer the keyboard. A touchscreen laptop is still a
# computer, only a real phone build or a phone browser gets the sticks.
func _detect_control_mode() -> void:
	var mobile := false
	if OS.has_feature("web"):
		mobile = _web_is_phone()
	else:
		mobile = OS.has_feature("mobile")
	control_mode = CONTROL_MOBILE if mobile else CONTROL_PC


func _web_is_phone() -> bool:
	if not ClassDB.class_exists("JavaScriptBridge"):
		return DisplayServer.is_touchscreen_available()
	var js := """
	(function() {
		try { return /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent); }
		catch (e) { return false; }
	})();
	"""
	return bool(JavaScriptBridge.eval(js, true))


# The settings are kept, so the player does not have to do it again.
const SETTINGS_PATH := "user://settings.cfg"


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_detect_control_mode()
		return
	SfxLib.master_volume = clampf(float(cfg.get_value("audio", "volume", 1.0)), 0.0, 1.0)
	_detect_control_mode()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", SfxLib.master_volume)
	cfg.save(SETTINGS_PATH)


# Start/stop the burning loop
func set_fire(on: bool) -> void:
	if _fire_player == null or _fire_on == on:
		return
	_fire_on = on
	if on:
		_fire_player.volume_db = -80.0
		_fire_player.play()
		var tw := create_tween()
		tw.tween_property(_fire_player, "volume_db", -20.0, 0.25)
	else:
		var tw := create_tween()
		tw.tween_property(_fire_player, "volume_db", -80.0, 0.4)
		tw.tween_callback(_fire_player.stop)

func reset_upgrades() -> void:
	upg_fire_rate = 1.0
	upg_bullet_speed = 1.0
	upg_move_speed = 1.0
	upg_damage = 1.0
	upg_burn = 0
	upg_freeze = 0
	upg_chaos = 0
	upg_stacks = {}
	upg_lifesteal = false
	upg_crit = 0.0
	upg_extra_shots = 0
	upg_magnet = 1.0
	upg_bonus_hp = 0
	upg_regen = 0
	upg_pierce = 0
	upg_homing = 0
	upg_splash = 0
	upg_elite_hunter = 0
	upg_bloodthirst = 0
	upg_plating = 0
	upg_level_heal = 0
	upg_xp_greed = 0
	upg_inferno = 0
	upg_brittle = 0
	upg_thorns = 0
	upg_pierce_focus = 0
	upg_explosive = 0
	upg_scavenger = 0
	upg_rushed = 0
	upg_heavy_caliber = 0
	upg_second_chance = 0
	upg_cold_blood = 0
	upg_range = 0.0
	upg_momentum = 0
	upg_close_quarters = 0
	weapon = "basic"
	weapon_chosen = false
	_burst_left = 0


func reset_run() -> void:
	reset_upgrades()
	wave = 0
	level = 1
	xp = 0
	active = true
	is_game_over = false
	player_dead = false
	spectate_mode = false
	spectate_target = 0
	_run_active = false
	_run_finished = false
	_run_started_at_msec = 0
	_run_damage = 0
	_run_bosses_killed = 0
	_run_boss_kill_times.clear()
	_run_boss_started_at.clear()
	_run_max_wave = 0
	Engine.time_scale = 1.0
	_hitstop_active = false
	_camera_shake_time = 0.0
	_camera_shake_strength = 0.0
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		camera.offset = Vector2.ZERO


func notify_player_died() -> void:
	if is_game_over:
		return
	# when somebody else is still playing the game goes on and the dead
	# player watches them
	var alive := alive_peers()
	if not alive.is_empty():
		spectate_mode = true
		spectate_target = int(alive[0])
		spectate_changed.emit(spectate_target)
		return
	is_game_over = true
	game_over.emit()


# The players that are still in the game, the host does not count.
func alive_peers() -> Array:
	var out: Array = []
	if Net.world == null:
		return out
	if not Net.world.has_method("alive_peers"):
		return out
	for id in Net.world.call("alive_peers"):
		out.append(int(id))
	return out


# The name of the player that is being watched.
func spectate_name() -> String:
	if spectate_target == 0:
		return ""
	return Net.player_name_of(spectate_target)


# True when the game is played in a room with other people.
func in_a_room() -> bool:
	return Net.is_online()


# Directly grant a card to the player (used by elite drops). Returns false if maxed.
func grant_card(card: Dictionary) -> bool:
	var id: String = card.get("id", "")
	if id == "":
		return false
	var taken := int(upg_stacks.get(id, 0))
	if taken >= int(card.get("max", 1)):
		return false
	upg_stacks[id] = taken + 1
	if card.has("apply"):
		card.apply.call(self)
	if _run_active and not _run_finished and not test_mode:
		card_pick_counts[id] = int(card_pick_counts.get(id, 0)) + 1
	return true


func remove_card(card: Dictionary) -> bool:
	var id := str(card.get("id", ""))
	var taken := int(upg_stacks.get(id, 0))
	if id.is_empty() or taken <= 0:
		return false

	match id:
		"fire_rate":
			upg_fire_rate /= 1.18
		"bullet_speed":
			upg_bullet_speed /= 1.20
		"move_speed":
			upg_move_speed /= 1.14
		"damage":
			upg_damage /= 1.20
		"burn":
			upg_burn -= 1
		"freeze":
			upg_freeze -= 1
		"lifesteal":
			upg_lifesteal = false
		"crit":
			upg_crit -= 0.12
		"orb_magnet":
			upg_magnet /= 1.4
		"max_hp":
			upg_bonus_hp -= 2
			var player := get_tree().get_first_node_in_group("player")
			if player and player.has_method("max_hp_total"):
				player.set("hp", mini(int(player.get("hp")),
					int(player.call("max_hp_total"))))
		"regen":
			upg_regen -= 1
		"pierce":
			upg_pierce -= 1
		"homing":
			upg_homing -= 1
		"splash":
			upg_splash -= 1
		"elite_hunter":
			upg_elite_hunter -= 1
		"bloodthirst":
			upg_bloodthirst -= 1
		"plating":
			upg_plating -= 1
		"level_heal":
			upg_level_heal -= 1
		"xp_greed":
			upg_xp_greed -= 1
		"inferno":
			upg_inferno -= 1
		"brittle":
			upg_brittle -= 1
		"thorns":
			upg_thorns -= 1
		"pierce_focus":
			upg_pierce_focus -= 1
		"explosive":
			upg_explosive -= 1
		"scavenger":
			upg_scavenger -= 1
		"rushed":
			upg_rushed -= 1
		"heavy_caliber":
			upg_heavy_caliber -= 1
		"second_chance":
			upg_second_chance -= 1
		"cold_blood":
			upg_cold_blood -= 1
		"longshot":
			upg_range -= 0.15
		"momentum":
			upg_momentum -= 1
		"point_blank":
			upg_close_quarters -= 1
		_:
			if id.begins_with("weapon_"):
				weapon = "basic"
				weapon_chosen = false

	if taken == 1:
		upg_stacks.erase(id)
	else:
		upg_stacks[id] = taken - 1
	return true


func xp_needed_for(level_num: int) -> int:
	# gentler curve: steady growth that stays approachable
	return int(round(6 + (level_num - 1) * 5 + pow(level_num - 1, 1.9) * 1.2)) * 5

func xp_needed() -> int:
	return xp_needed_for(level)

func add_xp(amount: int) -> void:
	var gained := int(round(float(amount) * (1.0 + 0.2 * float(upg_xp_greed))))
	xp += gained
	var levels_gained: Array[int] = []
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		level_changed.emit(level)
		levels_gained.append(level)
		if upg_level_heal > 0:
			var pl := get_tree().get_first_node_in_group("player")
			if pl and pl.has_method("heal"):
				pl.heal(upg_level_heal)
	xp_changed.emit(xp, xp_needed())
	if not levels_gained.is_empty():
		SfxLib.play("chime", -11.0, 0.96, 1.05)
		# Grant one upgrade choice per level, even when one XP pickup crosses
		# several thresholds at once.
		for gained_level: int in levels_gained:
			request_upgrade_choice.emit(gained_level)


# Called by enemies when they die - Bloodthirst may heal the player.
func on_enemy_killed() -> void:
	if upg_bloodthirst <= 0:
		return
	if randf() >= 0.12 * float(upg_bloodthirst):
		return
	var pl := get_tree().get_first_node_in_group("player")
	if pl and pl.has_method("heal"):
		pl.heal(1)


signal request_upgrade_choice(level: int)

# per-wave scaling helpers
func enemy_speed_mult() -> float:
	return 1.0 + (wave - 1) * 0.12

func enemy_damage_bonus() -> int:
	# capped so a single hit can never take the whole health bar
	return mini((wave - 1) / 2, 4)

func enemy_fire_mult() -> float:
	return maxf(1.0 - (wave - 1) * 0.08, 0.35)
