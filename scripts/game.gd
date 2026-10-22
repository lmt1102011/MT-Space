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

var weapon: String = "basic"          # chosen weapon archetype (from LV5 card)
var weapon_chosen: bool = false
var _burst_left: int = 0              # internal burst counter for player

# --- audio ---
const SfxLib := preload("res://scripts/sfx.gd")
const FIRE_LOOP_PATH := "res://assets/sfx/fire_loop.mp3"
var _sfx_players: Array[AudioStreamPlayer] = []
var _fire_player: AudioStreamPlayer
var _fire_on: bool = false


func _ready() -> void:
	_load_settings()
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


# Play a sound effect (see res://scripts/sfx.gd)
func sfx(sound: String, volume_db: float = 0.0,
		pitch_lo: float = 0.93, pitch_hi: float = 1.09) -> void:
	SfxLib.play(sound, volume_db, pitch_lo, pitch_hi)


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
	_save_settings()


# The settings are kept, so the player does not have to do it again.
const SETTINGS_PATH := "user://settings.cfg"


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	SfxLib.master_volume = clampf(float(cfg.get_value("audio", "volume", 1.0)), 0.0, 1.0)
	control_mode = int(cfg.get_value("game", "control_mode", CONTROL_PC))
	if control_mode != CONTROL_MOBILE:
		control_mode = CONTROL_PC


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", SfxLib.master_volume)
	cfg.set_value("game", "control_mode", control_mode)
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
	return true

func xp_needed_for(level_num: int) -> int:
	# gentler curve: steady growth that stays approachable
	return int(round(6 + (level_num - 1) * 5 + pow(level_num - 1, 1.9) * 1.2))

func xp_needed() -> int:
	return xp_needed_for(level)

func add_xp(amount: int) -> void:
	var gained := int(round(float(amount) * (1.0 + 0.2 * float(upg_xp_greed))))
	xp += gained
	var leveled := false
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		level_changed.emit(level)
		leveled = true
		if upg_level_heal > 0:
			var pl := get_tree().get_first_node_in_group("player")
			if pl and pl.has_method("heal"):
				pl.heal(upg_level_heal)
	xp_changed.emit(xp, xp_needed())
	if leveled:
		SfxLib.play("chime", -11.0, 0.96, 1.05)
		request_upgrade_choice.emit(level)


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
