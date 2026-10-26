extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var net := root.get_node("Net")
	var pool := root.get_node("PoolRoot")
	net.set("player_name", "")
	var menu_scene := load("res://scenes/menu.tscn") as PackedScene
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	menu.call("_on_play")
	var prompt := menu.get_node_or_null("NamePrompt")
	_check(prompt != null and str(current_scene.scene_file_path) == "res://scenes/menu.tscn",
		"Play from the main menu asks for the player name before entering the lobby")
	if prompt != null:
		prompt.get_node("Panel/NameEdit").text = "Test Pilot"
		prompt.get_node("Panel/PlayButton").pressed.emit()
		await create_timer(0.1).timeout
	var lobby := current_scene
	_check(str(lobby.scene_file_path) == "res://scenes/lobby.tscn"
		and str(net.get("player_name")) == "Test Pilot",
		"the chosen player name is saved before opening the mode lobby")
	await process_frame
	var record_button := lobby.get_node_or_null("UI/RunRecordButton") as Button
	var record_panel := lobby.get_node_or_null("UI/RunRecordPanel") as Panel
	_check(record_button != null and record_panel != null
		and record_panel.get_node_or_null("RunRecordScroll") is ScrollContainer
		and record_panel.get_node_or_null("RunRecordScroll/RunRecordLabel") is Label
		and not record_panel.visible,
		"the lobby has a trophy button and a hidden scrollable records popup")
	if record_panel != null and record_button != null:
		var game_singleton := root.get_node("Game")
		var previous_latest: Dictionary = game_singleton.get("latest_run").duplicate(true)
		var previous_best: Dictionary = game_singleton.get("best_run").duplicate(true)
		var long_build: Array[String] = []
		for index in 24:
			long_build.append("Card %d x1" % index)
		game_singleton.set("latest_run", {
			"wave": 3,
			"bosses": 1,
			"damage": 2400,
			"seconds": 95.0,
			"average_boss_kill_seconds": 24.0,
			"build": long_build,
		})
		game_singleton.set("best_run", game_singleton.get("latest_run").duplicate(true))
		lobby.call("_refresh_run_record")
		var record_label := record_panel.get_node(
			"RunRecordScroll/RunRecordLabel") as Label
		_check(not record_panel.visible and record_label.text.contains(
				str(game_singleton.call("build_item_label", "Card 23 x1")))
			and record_label.text.contains("00:24"),
			"the records popup content includes the complete build and boss time")
		record_button.pressed.emit()
		await process_frame
		var record_scroll := record_panel.get_node("RunRecordScroll") as ScrollContainer
		_check(record_panel.visible and record_scroll.get_v_scroll_bar().max_value > 0.0,
			"the trophy button opens the popup and long records can scroll vertically")
		var viewport := lobby.get_viewport()
		var original_size: Vector2i = viewport.size
		viewport.size = Vector2i(320, 568)
		await process_frame
		var mobile_rect := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
		_check(mobile_rect.encloses(record_button.get_global_rect())
			and mobile_rect.encloses(record_panel.get_global_rect()),
			"the trophy button and records popup stay inside a narrow mobile viewport")
		viewport.size = original_size
		await process_frame
		game_singleton.set("latest_run", previous_latest)
		game_singleton.set("best_run", previous_best)
		lobby.call("_refresh_run_record")
	lobby.call("_select_mode", "wave")
	var lobby_test_button := lobby.get_node_or_null("UI/TopBar/TestButton") as Button
	_check(lobby_test_button != null and not lobby_test_button.visible
		and not bool(lobby.get_node("UI/TestPanel").visible),
		"test settings are not shown in the mode lobby")
	lobby.call("_select_mode", "test")
	_check(lobby_test_button != null and not lobby_test_button.visible
		and not bool(lobby.get_node("UI/TestPanel").visible),
		"test mode does not show the lobby test-settings button")
	lobby.call("_on_test_pressed")
	_check(not bool(lobby.get_node("UI/TestPanel").visible),
		"the removed lobby test-settings panel cannot be opened")
	lobby.call("_on_play_pressed")
	await create_timer(2.5).timeout

	var main := current_scene
	var game := root.get_node("Game")
	_check(str(main.scene_file_path) == "res://scenes/main.tscn"
		and bool(game.get("test_mode")),
		"test mode starts the match directly without opening the room lobby")
	var local_player := main.get_node("Player")
	var player_hp_before: int = local_player.get("hp")
	var player_invuln_before: float = local_player.get("invuln")
	var player_stun_before: float = local_player.get("_stun_t")
	local_player.set("invuln", 0.0)
	local_player.set("_stun_t", 1.0)
	local_player.call("_take_whole_damage", 1)
	_check(int(local_player.get("hp")) == player_hp_before - 1
		and int(local_player.get("_hp_drawn")) == int(local_player.get("hp"))
		and float(local_player.get("_stun_t")) > 0.0,
		"player HP bar refreshes immediately when damage lands during stun")
	local_player.set("hp", player_hp_before)
	local_player.set("invuln", player_invuln_before)
	local_player.set("_stun_t", player_stun_before)
	local_player.call("_refresh_hp_bar")
	var test_damage_before := int(game.get("_run_damage"))
	var test_wave_before := int(game.get("_run_max_wave"))
	var test_bosses_before := int(game.get("_run_bosses_killed"))
	game.call("record_damage", 100)
	game.call("record_wave", 50)
	game.call("record_boss_kill", 0)
	_check(int(game.get("_run_damage")) == test_damage_before
		and int(game.get("_run_max_wave")) == test_wave_before
		and int(game.get("_run_bosses_killed")) == test_bosses_before,
		"test mode does not contribute damage, wave, or boss records")
	var saved_test_mode: bool = game.get("test_mode")
	var saved_run_active: bool = game.get("_run_active")
	var saved_run_finished: bool = game.get("_run_finished")
	var saved_run_damage: int = game.get("_run_damage")
	var saved_run_wave: int = game.get("_run_max_wave")
	var saved_run_bosses: int = game.get("_run_bosses_killed")
	var saved_boss_times: Array[float] = game.get("_run_boss_kill_times").duplicate()
	var saved_boss_starts: Dictionary = game.get("_run_boss_started_at").duplicate()
	game.set("test_mode", false)
	game.set("_run_active", true)
	game.set("_run_finished", false)
	game.set("_run_damage", 0)
	game.set("_run_max_wave", 0)
	game.set("_run_bosses_killed", 0)
	(game.get("_run_boss_kill_times") as Array).clear()
	(game.get("_run_boss_started_at") as Dictionary).clear()
	game.call("record_damage", 25)
	game.call("record_wave", 7)
	game.call("register_boss_spawn", -1)
	game.call("record_boss_kill", -1)
	_check(int(game.get("_run_damage")) == 25
		and int(game.get("_run_max_wave")) == 7
		and int(game.get("_run_bosses_killed")) == 1
		and not game.get("_run_boss_kill_times").is_empty(),
		"normal runs record applied damage, highest wave, boss kills, and boss time-to-kill")
	game.set("test_mode", saved_test_mode)
	game.set("_run_active", saved_run_active)
	game.set("_run_finished", saved_run_finished)
	game.set("_run_damage", saved_run_damage)
	game.set("_run_max_wave", saved_run_wave)
	game.set("_run_bosses_killed", saved_run_bosses)
	var run_boss_times: Array = game.get("_run_boss_kill_times")
	run_boss_times.append_array(saved_boss_times)
	var run_boss_starts: Dictionary = game.get("_run_boss_started_at")
	run_boss_starts.merge(saved_boss_starts)
	var summary := str(main.get_node("HUD").call("_format_run_summary", {
		"wave": 4,
		"bosses": 1,
		"damage": 1234,
		"seconds": 125.0,
		"average_boss_kill_seconds": 20.0,
		"build": ["weapon_basic", "Rapid Fire x2"],
	}))
	var locale := root.get_node("Locale")
	var expected_wave := str(locale.call("translate_text", "WAVE 4"))
	var expected_bosses := "%s 1" % str(locale.call("translate_text", "BOSSES"))
	var expected_damage := "%s 1234" % str(locale.call("translate_text", "DAMAGE"))
	var expected_card := str(game.call("build_item_label", "Rapid Fire x2"))
	_check(summary.contains(expected_wave) and summary.contains(expected_bosses)
		and summary.contains(expected_damage) and summary.contains(expected_card)
		and summary.contains("00:20"),
		"the game-over summary formats wave, boss, damage, survival, and build stats")
	var bullet_scene := load("res://scenes/bullet.tscn") as PackedScene
	var pooled_bullet := pool.call("acquire", bullet_scene, main) as Node
	var bullet_id := pooled_bullet.get_instance_id()
	pooled_bullet.set("damage", 99.0)
	pool.call("release", pooled_bullet)
	await process_frame
	var reused_bullet := pool.call("acquire", bullet_scene, main) as Node
	_check(reused_bullet.get_instance_id() == bullet_id
		and is_equal_approx(float(reused_bullet.get("damage")), 1.0)
		and reused_bullet.is_in_group("player_bullet"),
		"player bullets are reused from the pool with fresh state")
	pool.call("release", reused_bullet)
	var damage_number_scene := load("res://scenes/damage_number.tscn") as PackedScene
	var pooled_number := pool.call("acquire", damage_number_scene, main) as Node
	var number_id := pooled_number.get_instance_id()
	pool.call("release", pooled_number)
	await process_frame
	var reused_number := pool.call("acquire", damage_number_scene, main) as Node
	_check(reused_number.get_instance_id() == number_id
		and reused_number.is_in_group("damage_number"),
		"floating damage numbers are recycled instead of recreated")
	pool.call("release", reused_number)
	var explosion_scene := load("res://scenes/explosion.tscn") as PackedScene
	var pooled_explosion := pool.call("acquire", explosion_scene, main) as Node
	var explosion_id := pooled_explosion.get_instance_id()
	pool.call("release", pooled_explosion)
	await process_frame
	var reused_explosion := pool.call("acquire", explosion_scene, main) as Node
	_check(reused_explosion.get_instance_id() == explosion_id
		and reused_explosion.visible,
		"explosion visuals are recycled and reactivated")
	pool.call("release", reused_explosion)
	await process_frame
	var enemy_bullet_scene := load("res://scenes/enemy_bullet.tscn") as PackedScene
	var pooled_enemy_bullet := pool.call("acquire", enemy_bullet_scene, main) as Node
	var enemy_bullet_id := pooled_enemy_bullet.get_instance_id()
	pooled_enemy_bullet.set("damage", 99)
	var laser_shape := pooled_enemy_bullet.get_node(
		"CollisionShape2D").shape as CapsuleShape2D
	laser_shape.height = 180.0
	pool.call("release", pooled_enemy_bullet)
	await process_frame
	var reused_enemy_bullet := pool.call("acquire", enemy_bullet_scene, main) as Node
	var reset_enemy_shape := reused_enemy_bullet.get_node(
		"CollisionShape2D").shape as CapsuleShape2D
	_check(reused_enemy_bullet.get_instance_id() == enemy_bullet_id
		and int(reused_enemy_bullet.get("damage")) == 1
		and is_equal_approx(reset_enemy_shape.height, 16.0),
		"enemy bullets restore their damage and hitbox when reused")
	pool.call("release", reused_enemy_bullet)
	await process_frame
	var pooled_orb_scene := load("res://scenes/orb_projectile.tscn") as PackedScene
	var pooled_orb := pool.call("acquire", pooled_orb_scene, main) as Node
	var orb_id := pooled_orb.get_instance_id()
	pooled_orb.set("damage", 99.0)
	pool.call("release", pooled_orb)
	await process_frame
	var reused_orb := pool.call("acquire", pooled_orb_scene, main) as Node
	_check(reused_orb.get_instance_id() == orb_id
		and is_equal_approx(float(reused_orb.get("damage")), 1.0)
		and reused_orb.is_in_group("orb_projectile"),
		"orb projectiles are recycled with collision state and damage reset")
	pool.call("release", reused_orb)
	await process_frame
	var missile_scene := load("res://scenes/boss_missile.tscn") as PackedScene
	var pooled_missile := pool.call("acquire", missile_scene, main) as Node
	var missile_id := pooled_missile.get_instance_id()
	pooled_missile.set("damage", 99)
	pool.call("release", pooled_missile)
	await process_frame
	var reused_missile := pool.call("acquire", missile_scene, main) as Node
	_check(reused_missile.get_instance_id() == missile_id
		and int(reused_missile.get("damage")) == 5,
		"boss missiles are recycled and reset their damage")
	pool.call("release", reused_missile)
	_check(main.get_tree().get_nodes_in_group("monster").is_empty()
		and main.get_tree().get_nodes_in_group("enemy").is_empty(),
		"test mode does not spawn the normal wave or ambient enemies")
	var spawner := main.get_node("Spawner")
	_check(str(spawner.get("_phase")) == "test_idle",
		"test mode waits for manual test controls instead of starting normal waves")
	var test_button := main.get_node_or_null("HUD/TestMenu/TestControlsButton") as Button
	_check(test_button != null and test_button.visible,
		"test mode shows the in-game test controls button")
	var test_menu := main.get_node_or_null("HUD/TestMenu")
	if test_button != null and test_menu != null:
		test_button.pressed.emit()
		_check(bool(test_menu.get_node("TestControlsPanel").visible),
			"in-game test button opens the adjustment panel")
		var button_rect := test_button.get_global_rect()
		var viewport_rect := Rect2(Vector2.ZERO, main.get_viewport().get_visible_rect().size)
		_check(viewport_rect.encloses(button_rect),
			"in-game test controls button stays inside the screen")
		var test_panel := test_menu.get_node("TestControlsPanel") as Control
		var panel_rect := test_panel.get_global_rect()
		_check(viewport_rect.encloses(panel_rect),
			"in-game test panel fits inside the screen")
		var viewport := main.get_viewport()
		var original_viewport_size: Vector2i = viewport.size
		viewport.size = Vector2i(320, 568)
		await process_frame
		var phone_rect := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
		_check(phone_rect.encloses(test_panel.get_global_rect()),
			"in-game test panel remains on screen at a narrow mobile resolution")
		viewport.size = original_viewport_size
		await process_frame
		_check(not test_menu.get_node("TestControlsPanel").find_children(
			"*", "SpinBox", true, false).is_empty(),
			"in-game test panel provides wave adjustment controls")
		_check(test_panel.get_node_or_null("ControlsScroll") != null
			and test_panel.find_child("ClearAllButton", true, false) != null,
			"in-game test panel scrolls and provides a clear-all action")
		var enemy_option := test_menu.get("_enemy_opt") as OptionButton
		var old_enemy: int = enemy_option.selected
		enemy_option.select(1)
		test_menu.call("_on_spawn_enemy")
		await create_timer(1.0).timeout
		_check(not main.get_tree().get_nodes_in_group("enemy").is_empty(),
			"test controls can manually spawn an enemy")
		var moving_enemy: Node2D = null
		for candidate in main.get_tree().get_nodes_in_group("monster"):
			if candidate.has_method("_get_player"):
				moving_enemy = candidate as Node2D
				break
		_check(moving_enemy != null
			and moving_enemy.call("_get_player") == main.get_node("Player")
			and moving_enemy.velocity.length() > 0.0,
			"spawned enemies acquire the solo player and move")
		enemy_option.select(old_enemy)
		var orb_scene := load("res://scenes/xp_orb.tscn") as PackedScene
		var xp_orb := orb_scene.instantiate()
		main.add_child(xp_orb)
		await process_frame
		game.set("xp", 12)
		test_menu.call("_on_clear_all")
		await process_frame
		_check(main.get_tree().get_nodes_in_group("enemy").is_empty(),
			"clear-all removes all spawned enemies")
		_check(main.get_tree().get_nodes_in_group("xp_orb").is_empty(),
			"clear-all removes XP orbs")
		_check(int(game.get("xp")) == 0,
			"clear-all resets carried XP")
		enemy_option.select(6)
		test_menu.call("_on_spawn_enemy")
		await process_frame
		var beam_enemy := main.get_tree().get_first_node_in_group("beam_enemy") as Node2D
		var player := main.get_node("Player") as Node2D
		if beam_enemy != null:
			beam_enemy.global_position = player.global_position - Vector2(500.0, 0.0)
			beam_enemy.rotation = 0.0
			beam_enemy.call("_start_fire")
			beam_enemy.set("_phase_time", 0.3)
			beam_enemy.call("_hit_players_with_beam")
		var beam_knockback: Vector2 = player.get("_knock_vel")
		_check(beam_enemy != null and float(player.get("_stun_t")) > 0.0
			and beam_knockback.x > 0.0,
			"the beam attack applies knockback to a player it hits")
		test_menu.call("_on_clear_all")
		var boss_option := test_menu.get("_boss_opt") as OptionButton
		boss_option.select(1)
		test_menu.call("_on_spawn_boss")
		await process_frame
		var boss2 := main.get_tree().get_first_node_in_group("boss2") as Node2D
		_check(boss2 != null
			and boss2.get_node_or_null("SonicCannon/MuzzleGlow") != null,
			"boss 2 has a dedicated sonic cannon")
		if boss2 != null:
			boss2.call("_start_warning", main.get_node("Player").global_position)
			_check(float(boss2.get("wave_duration")) <= 0.4
				and float(boss2.get("wave_radius")) > 520.0
				and float(boss2.get("wave_half_angle_degrees")) > 32.0,
				"boss 2's shockwave is faster, larger, and wider")
			var muzzle: Vector2 = boss2.call("_cannon_muzzle_position")
			var warning_center: Vector2 = boss2.get("_warning_center")
			_check(warning_center.distance_to(muzzle) < 0.1,
				"boss 2 telegraphs and emits its sonic wave from the cannon")
			var warning := boss2.get("_warning_ring") as Polygon2D
			_check(warning != null and warning.color.r > 0.9
				and warning.polygon.size() > 24,
				"boss 2 previews its forward attack with a red fan-shaped zone")
			boss2.call("_update_warning", true, 0.5, warning_center,
				boss2.get("_warning_direction"))
			var warning_direction: Vector2 = boss2.get("_warning_direction")
			var expected_rotation := warning_direction.angle()
			_check(is_equal_approx(warning.global_rotation, expected_rotation),
				"boss 2 warning fan stays aligned with its locked firing direction")
		var wave_script := load("res://scripts/boss_sonic_wave.gd") as Script
		var sonic_wave := wave_script.new() as Node2D
		sonic_wave.set("direction", Vector2.RIGHT)
		sonic_wave.set("half_angle_degrees",
			float(boss2.get("wave_half_angle_degrees")))
		_check(is_equal_approx(
			float(sonic_wave.get("half_angle_degrees")),
			float(boss2.get("wave_half_angle_degrees"))),
			"the active shockwave and red warning zone use the same width")
		main.add_child(sonic_wave)
		await process_frame
		_check(bool(sonic_wave.call("_crossed_sector",
			Vector2(100.0, 0.0), 18.0, 0.0, 150.0))
			and not bool(sonic_wave.call("_crossed_sector",
				Vector2(-100.0, 0.0), 18.0, 0.0, 150.0)),
			"boss 2's sound wave only hits the area in front")
		sonic_wave.call("_update_visual", 100.0, 0.25)
		var sonic_sector := sonic_wave.get("_sector") as Polygon2D
		_check(sonic_sector != null and is_equal_approx(sonic_sector.color.a, 0.125),
			"the sound wave fades as it travels and dissipates")
		var freed_target := Node2D.new()
		sonic_wave.set("_players", [freed_target])
		sonic_wave.set("_enemies", [freed_target])
		freed_target.free()
		sonic_wave.call("_apply_crossing_hits", 0.0, 150.0)
		_check(true, "sonic waves safely skip freed player and enemy references")
		sonic_wave.queue_free()
		var drone_scene := load("res://scenes/boss_drone.tscn") as PackedScene
		var drone := drone_scene.instantiate()
		drone.global_position = Vector2(5000.0, 5000.0)
		main.add_child(drone)
		await process_frame
		var drone_texture := drone.get_node("Sprite2D").get("texture") as Texture2D
		_check(drone_texture != null
			and drone_texture.resource_path.ends_with("boss_drone.svg"),
			"boss drones use their redesigned art")
		boss2.call("_ignore_own_drones")
		_check((boss2 as PhysicsBody2D).get_collision_exceptions().has(drone)
			and (drone as PhysicsBody2D).get_collision_exceptions().has(boss2),
			"boss 2 and its drones ignore each other's physical collision")
		drone.queue_free()
		var drone_target := main.get_node("Player")
		var hp_before_drone := int(drone_target.get("hp"))
		drone_target.set("invuln", 0.5)
		var damage_drone := drone_scene.instantiate()
		main.add_child(damage_drone)
		damage_drone.global_position = drone_target.global_position
		damage_drone.call("_detonate", true, false)
		_check(int(drone_target.get("hp")) < hp_before_drone,
			"drone explosion applies its damage immediately, even during normal hit immunity")
		drone_target.set("invuln", 0.0)
		drone_target.set("hp", hp_before_drone)
		var charger_scene := load("res://scenes/charger_enemy.tscn") as PackedScene
		var charger := charger_scene.instantiate()
		main.add_child(charger)
		await process_frame
		charger.set("_dash_dir", Vector2.RIGHT)
		charger.call("_hit_player", drone_target)
		_check(int(drone_target.get("hp")) < hp_before_drone
			and float(drone_target.get("_stun_t")) > 0.0,
			"charger damage is applied before its stun and knockback")
		drone_target.set("hp", hp_before_drone)
		drone_target.set("invuln", 0.0)
		drone_target.set("_orb_damage_remainder", 0.0)
		drone_target.set("_stun_t", 0.0)
		var orb_projectile_scene := load("res://scenes/orb_projectile.tscn") as PackedScene
		var orb_projectile := orb_projectile_scene.instantiate()
		orb_projectile.set("damage", 0.1)
		orb_projectile.global_position = Vector2(5000.0, 5000.0)
		main.add_child(orb_projectile)
		await process_frame
		orb_projectile.call("_damage_player", drone_target)
		_check(is_equal_approx(float(drone_target.get("_orb_damage_remainder")),
			float(orb_projectile.get("damage")))
			and float(drone_target.get("_stun_t")) > 0.0,
			"orb projectile applies its fractional damage before knockback and slow")
		orb_projectile.queue_free()
		main.get_node("HUD").call("_on_settings_quit")
		await create_timer(0.2).timeout
		_check(str(current_scene.scene_file_path) == "res://scenes/lobby.tscn",
			"leaving a test match returns to the mode-selection lobby")

	var lobby_scene := load("res://scenes/lobby.tscn") as PackedScene
	var wave_lobby := lobby_scene.instantiate()
	root.add_child(wave_lobby)
	current_scene = wave_lobby
	await process_frame
	wave_lobby.call("_select_mode", "wave")
	wave_lobby.call("_on_play_pressed")
	await process_frame
	_check(str(current_scene.scene_file_path) == "res://scenes/room_lobby.tscn"
		and current_scene.get_node_or_null("UI/RoomsList") != null,
		"wave mode opens the room browser and create-room lobby")
	var room_header := current_scene.get_node("UI/Header") as Label
	_check(room_header.text == str(locale.call("translate_text", "ROOM")),
		"the room browser is labeled as a room")
	current_scene.call("_on_back")
	await create_timer(0.2).timeout
	_check(str(current_scene.scene_file_path) == "res://scenes/lobby.tscn",
		"the room browser back button returns to mode selection")

	print("=== test-mode check: %d failure(s) ===" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		_failures += 1
		print("FAIL  ", label)
