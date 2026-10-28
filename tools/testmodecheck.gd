extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var net := root.get_node("Net")
	var pool := root.get_node("PoolRoot")
	var game_singleton := root.get_node("Game")
	net.set("player_name", "")
	var menu_scene := load("res://scenes/menu.tscn") as PackedScene
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	menu.call("_on_play")
	var prompt := menu.get_node_or_null("NamePrompt")
	var menu_play_button := menu.find_child("PlayButton", true, false) as Button
	var menu_settings_button := menu.find_child(
		"SettingsButton", true, false) as Button
	_check(prompt != null and str(current_scene.scene_file_path) == "res://scenes/menu.tscn",
		"Play from the main menu asks for the player name before entering the lobby")
	_check(menu_play_button != null
		and menu_play_button.get_theme_stylebox("normal") is StyleBoxFlat
		and (menu_play_button.get_theme_stylebox("normal") as StyleBoxFlat)
			.bg_color.r > (menu_play_button.get_theme_stylebox("normal")
			as StyleBoxFlat).bg_color.b
		and menu_settings_button != null
		and menu_settings_button.get_theme_stylebox("normal") is StyleBoxFlat
		and (menu_settings_button.get_theme_stylebox("normal") as StyleBoxFlat)
			.border_color.b > (menu_settings_button.get_theme_stylebox("normal")
			as StyleBoxFlat).border_color.r,
		"main menu primary and secondary buttons use the shared amber/cyan sci-fi palette")
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
	_check(record_button == null and record_panel != null
		and record_panel.get_node_or_null("RunRecordScroll") is ScrollContainer
		and record_panel.get_node_or_null("RunRecordScroll/RunRecordLabel") is Label
		and not record_panel.visible,
		"the lobby has no corner trophy button and retains a hidden scrollable records popup")
	var lobby_viewport := lobby.get_viewport()
	var original_resolution: Vector2i = lobby_viewport.size
	lobby_viewport.size = Vector2i(1366, 768)
	lobby.call("_layout_dashboard")
	await process_frame
	var lobby_dashboard := lobby.get_node("UI/Dashboard")
	var primary_play := lobby_dashboard.find_child("PlayNowButton", true, false) as Button
	var ship_preview := lobby_dashboard.find_child(
		"SelectedShipPreview", true, false) as TextureRect
	var navigation_buttons := lobby_dashboard.find_children(
		"*", "Button", true, false)
	var has_home_navigation := false
	for navigation_button: Button in navigation_buttons:
		if navigation_button.text.to_upper() in ["HOME", "HOME PAGE", "TRANG CHÍNH"]:
			has_home_navigation = true
	_check(not has_home_navigation,
		"the home destination is removed from the lobby navigation")
	_check(primary_play != null and primary_play.is_visible_in_tree()
		and Rect2(Vector2.ZERO, lobby_viewport.get_visible_rect().size).encloses(
			primary_play.get_global_rect())
		and ship_preview != null and ship_preview.size.x >= 200.0,
		"the 1366x768 dashboard keeps Play Now visible and presents a large real ship asset")
	var stage := lobby_dashboard.find_child(
		"ShipDisplayStage", true, false) as Control
	var stat_card := lobby_dashboard.find_child(
		"ShipStatCard", true, false) as PanelContainer
	var best_wave_card := lobby_dashboard.find_child(
		"QuickStat_BEST_WAVE", true, false) as PanelContainer
	var lobby_scroll := lobby_dashboard.find_child(
		"LobbyScroll", true, false) as ScrollContainer
	_check(stage != null
		and lobby_dashboard.find_child("PreviousShipButton", true, false) is Button
		and lobby_dashboard.find_child("NextShipButton", true, false) is Button
		and stat_card != null,
		"ship controls and stat card are present")
	_check(best_wave_card != null
		and best_wave_card.get_theme_stylebox("panel") is StyleBoxFlat
		and (best_wave_card.get_theme_stylebox("panel") as StyleBoxFlat)
			.bg_color.b > (best_wave_card.get_theme_stylebox("panel")
			as StyleBoxFlat).bg_color.r
		and best_wave_card.find_child("Value", true, false) is Label,
		"Best Wave and nearby record cards use the cyan/navy dashboard surface instead of gray")
	_check(lobby_dashboard.find_child("ShipHangarScroll", true, false) == null
		and lobby_dashboard.find_child("ShipCarousel", true, false) == null,
		"the lower ship list has been removed")
	var desktop_scroll_overflow := maxf(
		0.0,
		lobby_scroll.get_v_scroll_bar().max_value
			- lobby_scroll.get_v_scroll_bar().page
	) if lobby_scroll != null else -1.0
	_check(desktop_scroll_overflow == 0.0,
		"the 1366x768 home dashboard does not require scrolling (overflow %.1f)"
		% desktop_scroll_overflow)
	for stat in ["DAMAGE", "SPEED", "HP", "BULLET SPEED", "FIRE RATE"]:
		var stat_segments := lobby_dashboard.find_child(
			stat + "Segments", true, false) as HBoxContainer
		_check(stat_segments != null and stat_segments.get_child_count() == 7,
			"%s is presented as seven stat segments" % stat)
	var ship_game := root.get_node("Game")
	var previous_best_ship_run: Dictionary = ship_game.get("best_run").duplicate(true)
	var previous_ship_index := int(lobby.get("_preview_ship_index"))
	ship_game.set("best_run", {"wave": 0})
	ship_game.set("unlocked_ship_ids", ["phoenix"])
	ship_game.set("selected_ship_id", "phoenix")
	var previous_button := lobby_dashboard.find_child(
		"PreviousShipButton", true, false
	) as Button
	var next_button := lobby_dashboard.find_child(
		"NextShipButton", true, false
	) as Button
	_check(str(ship_game.get("selected_ship_id")) == "phoenix"
		and ship_game.get("unlocked_ship_ids") == ["phoenix"]
		and ship_game.call("is_ship_unlocked", "phoenix")
		and not ship_game.call("is_ship_unlocked", "aquila")
		and int(lobby.call("_paint_index", "phoenix")) == 0
		and int(lobby.call("_paint_index", "aquila")) == -1
		and previous_button != null and previous_button.disabled
		and next_button != null and next_button.disabled,
		"Phoenix is the only selectable, unlocked ship")
	lobby.call("_finish_ship_gesture", -80.0)
	lobby.call("_cycle_ship", -1)
	_check(int(lobby.get("_preview_ship_index")) == previous_ship_index,
		"ship navigation does not cycle when Phoenix is the only ship")
	var phoenix_stats: Dictionary = ship_game.call(
		"get_ship_combat_stats", "phoenix"
	)
	var effective_phoenix_stats: Dictionary = ship_game.call(
		"get_effective_ship_combat_stats", "phoenix"
	)
	_check(is_equal_approx(float(phoenix_stats["damage_multiplier"]), 0.8)
		and int(phoenix_stats["max_hp"]) == 8
		and is_equal_approx(float(phoenix_stats["max_speed"]), 350.0)
		and is_equal_approx(float(phoenix_stats["bullet_speed"]), 600.0)
		and is_equal_approx(float(phoenix_stats["fire_rate"]), 4.0),
		"Phoenix uses the configured damage, speed, HP, bullet speed, and firing rate")
	var player_scene_for_stats := load("res://scenes/player.tscn") as PackedScene
	var stat_player := player_scene_for_stats.instantiate() as CharacterBody2D
	var shooter_scene := load("res://scenes/shooter_enemy.tscn") as PackedScene
	var shooter_reference := shooter_scene.instantiate() as CharacterBody2D
	var player_sprite := stat_player.get_node("Sprite2D") as Sprite2D
	var shooter_sprite := shooter_reference.get_node("Sprite2D") as Sprite2D
	var player_art_width := player_sprite.texture.get_width() * player_sprite.scale.x
	var shooter_art_width := shooter_sprite.texture.get_width() * shooter_sprite.scale.x
	shooter_reference.free()
	lobby.add_child(stat_player)
	await process_frame
	stat_player.call("_set_ship_appearance", false)
	_check(is_equal_approx(float(stat_player.get("max_speed")),
			float(effective_phoenix_stats["max_speed"]))
		and int(stat_player.get("max_hp")) == int(effective_phoenix_stats["max_hp"])
		and is_equal_approx(float(stat_player.get("bullet_speed")),
			float(effective_phoenix_stats["bullet_speed"]))
		and is_equal_approx(float(stat_player.get("_ship_damage_multiplier")),
			float(effective_phoenix_stats["damage_multiplier"]))
		and is_equal_approx(
			1.0 / float(stat_player.get("fire_cooldown")),
			float(effective_phoenix_stats["fire_rate"])
		)
		and (stat_player.get_node("Sprite2D") as Sprite2D).texture.resource_path
			== "res://assets/ships/phoenix.svg"
		and (stat_player.get_node("Sprite2D") as Sprite2D).material == null
		and (stat_player.get_node("Sprite2D") as Sprite2D).modulate == Color.WHITE
		and (stat_player.get_node("Sprite2D") as Sprite2D).scale
			.is_equal_approx(Vector2(0.174, 0.174))
		and absf(player_art_width - shooter_art_width) <= 1.0,
		"solo Phoenix keeps its original artwork and matches the red shooter's size (%.2f vs %.2f px)"
			% [player_art_width, shooter_art_width])
	stat_player.call("_set_ship_appearance", true)
	var multiplayer_sprite := stat_player.get_node("Sprite2D") as Sprite2D
	var multiplayer_material := multiplayer_sprite.material as ShaderMaterial
	_check(multiplayer_material != null
		and multiplayer_material.shader.resource_path
			== "res://assets/shaders/ship_multiplayer_palette.gdshader"
		and multiplayer_sprite.modulate == net.call("get_player_ship_color"),
		"multiplayer-only ship palette preserves the selected color over a neutral hull")
	var previous_peer: Variant = net.get("_peer")
	net.set("_peer", ENetMultiplayerPeer.new())
	multiplayer_sprite.modulate = Color.WHITE
	stat_player.call("_on_players_changed")
	_check(multiplayer_sprite.modulate == net.call("get_player_ship_color"),
		"reapplies the selected multiplayer ship color when the room roster updates")
	net.set("_peer", previous_peer)
	stat_player.call("_set_ship_appearance", false)
	var remote_scene := load("res://scenes/remote_player.tscn") as PackedScene
	var remote_player := remote_scene.instantiate()
	lobby.add_child(remote_player)
	await process_frame
	var remote_sprite := remote_player.get_node("Ship") as Sprite2D
	var remote_material := remote_sprite.material as ShaderMaterial
	_check(remote_sprite.texture.resource_path == "res://assets/ships/phoenix.svg"
		and remote_material != null
		and remote_material.shader.resource_path
			== "res://assets/shaders/ship_multiplayer_palette.gdshader",
		"remote multiplayer ships use the grayscale palette without changing lobby art")
	remote_player.queue_free()
	stat_player.queue_free()
	ship_game.set("best_run", previous_best_ship_run)
	ship_game.set("unlocked_ship_ids", ["phoenix"])
	ship_game.call("set_selected_ship", "phoenix")
	await process_frame
	var pilot_card := lobby_dashboard.find_child(
		"PilotProfileCard", true, false) as PanelContainer
	var pilot_avatar := lobby_dashboard.find_child(
		"PilotAvatar", true, false) as PanelContainer
	var cash_card := lobby_dashboard.find_child(
		"CurrencyCard_Cash", true, false) as PanelContainer
	var gem_card := lobby_dashboard.find_child(
		"CurrencyCard_Gem", true, false) as PanelContainer
	_check(pilot_card != null and pilot_avatar != null
		and pilot_avatar.get_theme_stylebox("panel").get_corner_radius(
			CORNER_TOP_LEFT) >= 20
		and lobby_dashboard.find_child("PilotLevelValue", true, false) is Label
		and lobby_dashboard.find_child("PilotXPBar", true, false) is ProgressBar,
		"pilot identity, circular avatar, level, and experience bar live in one card")
	_check(cash_card != null and gem_card != null
		and lobby_dashboard.find_child("CurrencyValue_Cash", true, false) is Label
		and lobby_dashboard.find_child("CurrencyValue_Gem", true, false) is Label
		and lobby_dashboard.find_child("CurrencyCaption_Cash", true, false) == null
		and lobby_dashboard.find_child("CurrencyCaption_Gem", true, false) == null
		and (lobby_dashboard.find_child("CurrencyValue_Cash", true, false)
			as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and (lobby_dashboard.find_child("CurrencyValue_Gem", true, false)
			as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and lobby_dashboard.find_child("TokenStoreButton", true, false) == null,
		"currency chips omit captions and center their values without an old store-plus button")
	_check(cash_card != null and gem_card != null
		and cash_card.get_parent() == gem_card.get_parent()
		and cash_card.get_global_rect().position.y == gem_card.get_global_rect().position.y
		and cash_card.get_global_rect().end.x <= gem_card.get_global_rect().position.x,
		"cash and gem currency cards stay side by side in one horizontal row")
	var locale_singleton := root.get_node("Locale")
	var lobby_locale_before_settings := str(locale_singleton.call("get_locale"))
	lobby.call("_open_page", "settings")
	await process_frame
	var lobby_language_option := lobby_dashboard.find_child(
		"LobbyLanguageOption", true, false) as OptionButton
	if lobby_language_option == null:
		lobby_language_option = lobby.find_child(
			"LobbyLanguageOption", true, false) as OptionButton
	_check(lobby_language_option != null
		and lobby_language_option.item_count == 2
		and lobby_language_option.selected
			== (1 if lobby_locale_before_settings == "vi" else 0),
		"lobby settings expose the currently selected English or Vietnamese language")
	if lobby_language_option != null:
		lobby_language_option.select(1 if lobby_locale_before_settings == "en" else 0)
		lobby_language_option.item_selected.emit(lobby_language_option.selected)
		await process_frame
		_check(str(locale_singleton.call("get_locale"))
			== ("vi" if lobby_locale_before_settings == "en" else "en")
			and lobby.find_child("LobbyLanguageOption", true, false)
				is OptionButton
			and (lobby.find_child(
				"LobbyLanguageLabel", true, false) as Label).text
				== str(locale_singleton.call("translate_text", "LANGUAGE")),
			"changing language in lobby settings applies, translates, and retains the chosen locale")
		lobby_language_option = lobby.find_child(
			"LobbyLanguageOption", true, false) as OptionButton
		if lobby_language_option != null:
			lobby_language_option.select(
				1 if lobby_locale_before_settings == "en" else 0)
			lobby_language_option.item_selected.emit(lobby_language_option.selected)
			await process_frame
	lobby.call("_close_page_popup")
	lobby.call("_open_mode_selector")
	await process_frame
	var page_popup := lobby.find_child("LobbyPage", true, false) as PanelContainer
	var select_coop := lobby.find_child("SelectMode_coop", true, false) as Button
	_check(page_popup != null and page_popup.visible and select_coop != null
		and lobby.find_child("SelectMode_solo", true, false) is Button
		and lobby.find_child("SelectMode_test", true, false) is Button,
		"Choose Mode opens real solo, online co-op, and test choices")
	var popup_style := page_popup.get_theme_stylebox("panel") as StyleBoxFlat
	_check(popup_style != null and popup_style.bg_color.b > popup_style.bg_color.r,
		"mode popup uses a layered navy and cyan sci-fi surface")
	if select_coop != null:
		select_coop.pressed.emit()
	var mode_summary := lobby_dashboard.find_child(
		"SelectedModeSummary", true, false) as Label
	_check(str(lobby.get("_selected_play_mode")) == "coop"
		and mode_summary.text == str(root.get_node("Locale").call(
			"translate_text", "ONLINE CO-OP  /  ROOM BROWSER")),
		"selecting online co-op updates the mode shown beside Play Now")
	lobby.call("_select_play_mode", "solo")
	_check(str(lobby.get("_selected_play_mode")) == "solo"
		and mode_summary.text == str(root.get_node("Locale").call(
			"translate_text", "SOLO  /  WAVE SURVIVAL")),
		"selecting single-player restores the Play Now summary")
	lobby.call("_select_play_mode", "test")
	_check(str(lobby.get("_selected_play_mode")) == "test"
		and mode_summary.text == str(root.get_node("Locale").call(
			"translate_text", "TEST MODE  /  SANDBOX")),
		"test mode becomes the selected Play Now mode")
	lobby.call("_select_play_mode", "solo")
	lobby.call("_close_page_popup")
	lobby_viewport.size = original_resolution
	lobby.call("_layout_dashboard")
	if record_panel != null:
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
		lobby.call("_open_page", "achievements")
		await process_frame
		var achievement_content := lobby.find_child(
			"PagePopupContent", true, false) as VBoxContainer
		var achievement_record := achievement_content.get_child(1) as Label \
			if achievement_content != null and achievement_content.get_child_count() > 1 \
			else null
		_check(not record_panel.visible and record_label.text.contains(
				str(game_singleton.call("build_item_label", "Card 23 x1")))
			and record_label.text.contains("00:24")
			and achievement_record != null
			and achievement_record.text.contains("Card 23 x1")
			and achievement_record.text.contains("00:24"),
			"the career page includes the full latest-run build and boss time")
		lobby.call("_open_page", "store")
		await process_frame
		page_popup = lobby.get_node("UI/LobbyPage") as PanelContainer
		_check(page_popup.visible
			and not bool(lobby.get_node("UI/Dashboard").visible),
			"opening a lobby page presents a dedicated screen")
		lobby.call("_open_page", "achievements")
		await process_frame
		var close_record_button := record_panel.get_node(
			"CloseRunRecordButton") as Button
		lobby.call("_toggle_run_record_popup")
		_check(record_panel.visible
			and close_record_button.mouse_filter == Control.MOUSE_FILTER_STOP,
			"the independent profile close button remains interactive")
		close_record_button.pressed.emit()
		_check(not record_panel.visible,
			"the profile close button dismisses the records panel")
		lobby.call("_open_page", "achievements")
		await process_frame
		lobby.call("_close_page_popup")
		var viewport := lobby.get_viewport()
		var original_size: Vector2i = viewport.size
		viewport.size = Vector2i(320, 568)
		await process_frame
		var mobile_rect := Rect2(Vector2.ZERO, viewport.get_visible_rect().size)
		lobby.call("_toggle_run_record_popup")
		await process_frame
		_check(record_button == null and record_panel.visible
			and mobile_rect.encloses(record_panel.get_global_rect()),
			"the corner trophy is absent and the records popup stays on-screen on mobile")
		lobby.call("_toggle_run_record_popup")
		lobby.call("_layout_dashboard")
		await process_frame
		var dashboard := lobby.get_node("UI/Dashboard")
		var mobile_navigation := dashboard.find_child(
			"MobileNavigation", true, false) as ScrollContainer
		var mobile_columns := dashboard.find_child("MainColumnsMobile", true, false)
		var missions: Array = game_singleton.call("get_daily_missions")
		_check(mobile_navigation != null and mobile_navigation.visible
			and mobile_columns != null and mobile_columns.visible,
			"the lobby stacks its navigation and panels on a narrow phone viewport")
		var compact_header := dashboard.find_child(
			"PilotHeaderRow", true, false) as HBoxContainer
		var compact_settings := dashboard.find_child(
			"HeaderSettingsButton", true, false) as Button
		_check(compact_header != null
			and compact_settings != null
			and mobile_rect.encloses(compact_settings.get_global_rect()),
			"the header compacts and keeps settings within a 320px viewport")
		_check(dashboard.find_child("ShipHangarScroll", true, false) == null
			and dashboard.find_child("ShipCarousel", true, false) == null,
			"the lower ship carousel is removed so the home screen needs less scrolling")
		_check(missions.size() == 3,
			"the lobby displays three persistent daily objectives")
		lobby.call("_open_page", "store")
		await process_frame
		var store_popup := lobby.find_child("LobbyPage", true, false) as PanelContainer
		var store_content := lobby.find_child(
			"PagePopupContent", true, false) as VBoxContainer
		var store_grid := lobby.find_child("StoreItemsGrid", true, false) as GridContainer
		_check(store_popup != null and store_popup.visible
			and store_content != null and store_grid != null
			and store_grid.get_child_count()
				== (game_singleton.call("get_store_items") as Array).size(),
			"the store page lists every real store offer")
		lobby.call("_close_page_popup")
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
	var saved_store_loadouts: Dictionary = game_singleton.get(
		"ship_store_loadouts").duplicate(true)
	game_singleton.set("ship_store_loadouts", {})
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
	var saved_enemy_kills: Dictionary = game.get("_run_enemy_kills").duplicate(true)
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
	game.call("record_enemy_kill", "shooter")
	game.call("register_boss_spawn", -1)
	game.call("record_boss_kill", -1)
	_check(int(game.get("_run_damage")) == 25
		and int(game.get("_run_max_wave")) == 7
		and int(game.get("_run_enemy_kills").get("shooter", 0)) == 1
		and int(game.get("_run_bosses_killed")) == 1
		and not game.get("_run_boss_kill_times").is_empty(),
		"normal runs record applied damage, highest wave, boss kills, and boss time-to-kill")
	game.set("test_mode", saved_test_mode)
	game.set("_run_active", saved_run_active)
	game.set("_run_finished", saved_run_finished)
	game.set("_run_damage", saved_run_damage)
	game.set("_run_max_wave", saved_run_wave)
	game.set("_run_bosses_killed", saved_run_bosses)
	game.set("_run_enemy_kills", saved_enemy_kills)
	var run_boss_times: Array = game.get("_run_boss_kill_times")
	run_boss_times.append_array(saved_boss_times)
	var run_boss_starts: Dictionary = game.get("_run_boss_started_at")
	run_boss_starts.merge(saved_boss_starts)
	var pilot_cash_before_reward := int(game.get("pilot_cash"))
	var pilot_level_before_reward := int(game.get("pilot_level"))
	var pilot_xp_before_reward := int(game.get("pilot_xp"))
	var xp_to_next_pilot_level := int(game.call(
		"xp_needed_for", pilot_level_before_reward)) - pilot_xp_before_reward + 3
	var granted_rewards: bool = game.call(
		"_grant_run_rewards", 7, maxi(xp_to_next_pilot_level, 0))
	var saved_pilot_profile := ConfigFile.new()
	var profile_loaded := saved_pilot_profile.load("user://pilot_profile.cfg") == OK
	_check(granted_rewards
		and int(game.get("pilot_cash")) == pilot_cash_before_reward + 7
		and int(game.get("pilot_level")) == pilot_level_before_reward + 1
		and profile_loaded
		and int(saved_pilot_profile.get_value("pilot", "level", 0))
			== pilot_level_before_reward + 1
		and int(saved_pilot_profile.get_value("pilot", "xp", 0)) == 3,
		"run rewards persist cash and pilot XP progress, including pilot level-ups")
	game.set("pilot_cash", pilot_cash_before_reward)
	game.set("pilot_level", pilot_level_before_reward)
	game.set("pilot_xp", pilot_xp_before_reward)
	game.call("_save_pilot_profile")
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
	var reward_rows: Array = game.call("_build_run_reward_rows", {
		"shooter": 3,
		"boss_1": 1,
	}, 4)
	var expected_reward_total := 0
	var expected_xp_total := 0
	var has_boss_reward_icon := false
	for reward_row: Dictionary in reward_rows:
		expected_reward_total += int(reward_row["reward"])
		expected_xp_total += int(reward_row["xp_reward"])
		if reward_row["id"] == "boss_1":
			has_boss_reward_icon = ResourceLoader.exists(str(reward_row["icon"]))
	_check(expected_reward_total == 74 and has_boss_reward_icon
		and expected_xp_total == 435
		and int(reward_rows[0]["unit_xp"]) == 15
		and int(reward_rows[0]["xp_reward"]) == 45
		and reward_rows.back()["id"] == "waves"
		and int(reward_rows.back()["reward"]) == 40
		and int(reward_rows.back()["unit_xp"]) == 10
		and int(reward_rows.back()["xp_reward"]) == 40,
		"run rewards calculate per-enemy and per-wave cash and XP using real enemy art")
	var results_hud := main.get_node("HUD")
	var previous_latest_run: Dictionary = game.get("latest_run").duplicate(true)
	var all_enemy_kills := {
		"shape_3": 1, "shape_4": 1, "shape_5": 1, "shape_6": 1,
		"shooter": 1, "double": 1, "railgun": 1, "charger": 1, "orb": 1,
		"beam_enemy": 1, "boss_drone": 1, "boss_1": 1, "boss_2": 1,
	}
	var long_reward_rows: Array = game.call("_build_run_reward_rows", all_enemy_kills, 8)
	var long_reward_total := 0
	var long_experience_total := 0
	for reward_row: Dictionary in long_reward_rows:
		long_reward_total += int(reward_row["reward"])
		long_experience_total += int(reward_row["xp_reward"])
	game.set("latest_run", {
		"wave": 4,
		"enemy_kills": {"shooter": 3, "boss_1": 1},
		"reward_rows": long_reward_rows,
		"cash_earned": long_reward_total,
		"xp_earned": long_experience_total,
		"cash_saved": true,
		"xp_saved": true,
	})
	results_hud.call("_on_game_over")
	await process_frame
	var results_panel := results_hud.find_child("RunResultsPanel", true, false) as PanelContainer
	var results_scroll := results_hud.find_child("KillRewardScroll", true, false) as ScrollContainer
	var results_footer := results_hud.find_child("RunRewardBar", true, false) as PanelContainer
	_check(results_panel != null and results_scroll != null
		and results_scroll.get_v_scroll_bar().max_value
			> results_scroll.get_v_scroll_bar().page
		and results_footer != null
		and results_hud.find_child("TotalCashEarned", true, false) is Label
		and results_hud.find_child("TotalExperienceEarned", true, false) is Label
		and results_hud.find_child("CashCalculation_shape_3", true, false) is Label
		and (results_hud.find_child("ExperienceCalculation_shape_3", true, false)
			as Label).text == "1 x 5 XP",
		"the game-over debrief lists per-enemy cash and XP plus totals in its footer")
	_check(results_hud.find_child("RewardIcon_boss_1", true, false) is TextureRect
		and results_hud.find_child("RewardIcon_waves", true, false) is TextureRect
		and results_hud.get("_menu_btn") is Button,
		"the results list displays boss and wave icons with a return action")
	var results_viewport := main.get_viewport()
	var results_viewport_size: Vector2i = results_viewport.size
	results_viewport.size = Vector2i(320, 568)
	results_hud.call("_layout_game_over")
	await process_frame
	var results_screen := Rect2(Vector2.ZERO, results_viewport.get_visible_rect().size)
	_check(results_panel != null
		and results_screen.encloses(results_panel.get_global_rect())
		and results_hud.get("_menu_btn").is_visible_in_tree()
		and results_hud.get("_play_again_btn").is_visible_in_tree(),
		"the results panel and both actions fit on a narrow phone viewport")
	results_viewport.size = results_viewport_size
	results_hud.call("_layout_game_over")
	game.set("latest_run", previous_latest_run)
	var hp_bar_script := load("res://scripts/hp_bar.gd") as GDScript
	var hp_bar := hp_bar_script.new() as Node2D
	main.add_child(hp_bar)
	_check(not hp_bar.visible,
		"HP bars remain hidden until an enemy assigns their world position")
	var hp_bar_position := Vector2(260.0, 180.0)
	hp_bar.call("place_at", hp_bar_position)
	_check(hp_bar.visible
		and hp_bar.global_position.is_equal_approx(hp_bar_position),
		"HP bars appear at the assigned enemy position instead of flashing at the origin")
	hp_bar.queue_free()
	var bullet_scene := load("res://scenes/bullet.tscn") as PackedScene
	var pooled_bullet := pool.call("acquire", bullet_scene, main) as Node
	var bullet_id := pooled_bullet.get_instance_id()
	pooled_bullet.set("damage", 99.0)
	pool.call("release", pooled_bullet)
	await process_frame
	var reused_bullet := pool.call("acquire", bullet_scene, main) as Node
	_check(reused_bullet.get_instance_id() == bullet_id
		and is_equal_approx(float(reused_bullet.get("damage")), 1.0)
		and reused_bullet.is_in_group("player_bullet")
		and not reused_bullet.visible,
		"reused player bullets stay hidden until their firing direction is assigned")
	reused_bullet.set("direction", Vector2.UP)
	reused_bullet.call("prepare_for_flight")
	_check(reused_bullet.visible
		and is_equal_approx(float(reused_bullet.get("rotation")), -PI * 0.5),
		"player bullets are shown already aligned to their firing direction")
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
		and is_equal_approx(reset_enemy_shape.height, 16.0)
		and not reused_enemy_bullet.visible,
		"enemy bullets restore their damage and stay hidden until configured")
	reused_enemy_bullet.set("direction", Vector2.UP)
	reused_enemy_bullet.call("prepare_for_flight")
	_check(reused_enemy_bullet.visible
		and is_equal_approx(float(reused_enemy_bullet.get("rotation")), -PI * 0.5),
		"enemy bullets are shown already aligned to their firing direction")
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
		and reused_orb.is_in_group("orb_projectile")
		and not reused_orb.visible,
		"orb projectiles reset collision state and stay hidden until configured")
	reused_orb.set("direction", Vector2.UP)
	reused_orb.call("prepare_for_flight")
	_check(reused_orb.visible,
		"orb projectiles appear only after launch data is assigned")
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
		and int(reused_missile.get("damage")) == 5
		and not reused_missile.visible,
		"boss missiles reset their damage and stay hidden until configured")
	reused_missile.set("direction", Vector2.UP)
	reused_missile.call("prepare_for_flight")
	_check(reused_missile.visible
		and is_equal_approx(float(reused_missile.get("rotation")), -PI * 0.5),
		"boss missiles appear already aligned to their launch direction")
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
		drone_target.set("_dead", false)
		drone_target.set("hp", int(drone_target.call("max_hp_total")))
		hp_before_drone = int(drone_target.get("hp"))
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
		and current_scene.get_node_or_null("UI/RoomsScroll/RoomsList") != null,
		"wave mode opens the room browser and create-room lobby")
	var room_ui := current_scene.get_node("UI") as Control
	var room_create_button := room_ui.get_node("CreateRoomButton") as Button
	var room_start_button := room_ui.get_node("RoomPanel/StartButton") as Button
	var room_secondary_button := room_ui.get_node("JoinRoomButton") as Button
	var room_slot := room_ui.get_node("RoomPanel/SlotTL") as Panel
	var rooms_scroll := room_ui.get_node("RoomsScroll") as ScrollContainer
	_check(room_ui.get_node_or_null("RoomsScrollGlassSurface") is Panel
		and room_ui.get_node_or_null("CreatePanelGlassSurface") is Panel
		and room_ui.get_node_or_null("AddressPanelGlassSurface") is Panel
		and room_ui.get_node_or_null("RoomPanelGlassSurface") is Panel,
		"room browser, create, address, and player-room views share the sci-fi glass panel treatment")
	_check(rooms_scroll != null
		and rooms_scroll.get_child(0).name == "RoomsList"
		and rooms_scroll.vertical_scroll_mode
			== ScrollContainer.SCROLL_MODE_AUTO,
		"room discovery results are contained in a vertical scroll area")
	var create_button_style := room_create_button.get_theme_stylebox(
		"normal") as StyleBoxFlat
	var start_button_style := room_start_button.get_theme_stylebox(
		"normal") as StyleBoxFlat
	var secondary_button_style := room_secondary_button.get_theme_stylebox(
		"normal") as StyleBoxFlat
	_check(create_button_style != null
		and create_button_style.bg_color.r > create_button_style.bg_color.b,
		"create-room action uses the lobby's amber primary-button palette")
	_check(start_button_style != null
		and start_button_style.bg_color.r > start_button_style.bg_color.b,
		"start-game action uses the lobby's amber primary-button palette")
	_check(secondary_button_style != null
		and secondary_button_style.border_color.b > secondary_button_style.border_color.r,
		"secondary room actions use the lobby's cyan-button palette")
	current_scene.call("_style_slot", room_slot, true)
	_check((room_slot.get_theme_stylebox("panel") as StyleBoxFlat)
		.border_color.b > (room_slot.get_theme_stylebox("panel")
			as StyleBoxFlat).border_color.r,
		"occupied player slots use a cyan-accented panel instead of the legacy gray surface")
	var room_header := current_scene.get_node("UI/Header") as Label
	_check(room_header.text == str(locale.call("translate_text", "ROOM")),
		"the room browser is labeled as a room")
	current_scene.call("_on_create")
	await process_frame
	var create_panel := room_ui.get_node("CreatePanel") as Control
	var create_surface := room_ui.get_node("CreatePanelGlassSurface") as Control
	var rooms_surface := room_ui.get_node("RoomsScrollGlassSurface") as Control
	var address_surface := room_ui.get_node("AddressPanelGlassSurface") as Control
	var room_surface := room_ui.get_node("RoomPanelGlassSurface") as Control
	var create_panel_rect := create_panel.get_global_rect()
	var create_contents_fit := create_panel_rect.encloses(
		(room_ui.get_node("CreatePanel/Title") as Control).get_global_rect()
	) and create_panel_rect.encloses(
		(room_ui.get_node("CreatePanel/NameEdit") as Control).get_global_rect()
	) and create_panel_rect.encloses(
		(room_ui.get_node("CreatePanel/WebModeButton") as Control).get_global_rect()
	) and create_panel_rect.encloses(
		(room_ui.get_node("CreatePanel/CreateConfirm") as Control).get_global_rect()
	) and create_panel_rect.encloses(
		(room_ui.get_node("CreatePanel/CreateCancel") as Control).get_global_rect()
	)
	_check(create_surface.visible and not rooms_surface.visible
		and not address_surface.visible and not room_surface.visible
		and create_contents_fit,
		"create-room view shows only its own backdrop and keeps every control inside the popup")
	current_scene.call("_on_create_cancel")
	await process_frame
	_check(not create_surface.visible
		and (rooms_scroll.visible
			or (room_ui.get_node("EmptyLabel") as Label).visible)
		and not rooms_surface.visible,
		"closing create-room restores the room browser without leaving a backdrop over it")
	current_scene.call("_on_back")
	await create_timer(0.2).timeout
	_check(str(current_scene.scene_file_path) == "res://scenes/lobby.tscn",
		"the room browser back button returns to mode selection")
	var dashboard := current_scene.get_node("UI/Dashboard")
	current_scene.call("_select_play_mode", "coop")
	current_scene.call("_start_selected_mode")
	await create_timer(0.2).timeout
	_check(current_scene != null
		and str(current_scene.scene_file_path) == "res://scenes/room_lobby.tscn",
		"Play Now dispatches the selected online co-op mode to the room browser")
	current_scene.call("_on_back")
	await create_timer(0.2).timeout
	dashboard = current_scene.get_node("UI/Dashboard")
	var play_now := dashboard.find_child("PlayNowButton", true, false) as Button
	_check(play_now != null,
		"the dashboard exposes its primary play action")
	if play_now != null:
		play_now.pressed.emit()
		await create_timer(0.1).timeout
		_check(current_scene != null
			and str(current_scene.scene_file_path) == "res://scenes/main.tscn"
			and not bool(root.get_node("Game").get("test_mode")),
			"Play Now launches a normal solo run directly")

	game_singleton.set("ship_store_loadouts", saved_store_loadouts)
	game_singleton.call("_save_pilot_profile")
	print("=== test-mode check: %d failure(s) ===" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		_failures += 1
		print("FAIL  ", label)
