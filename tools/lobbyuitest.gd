extends SceneTree

const SfxLibrary := preload("res://scripts/sfx.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	SfxLibrary.enabled = false
	var game := root.get_node("Game")
	var net := root.get_node("Net")
	var original_room_players: Array = net.get("players").duplicate(true)
	var original_wait_for_hello := bool(net.get("_wait_for_hello"))
	var original_ship_color := int(net.get("player_ship_color_index"))
	var original_flame_color := int(net.get("player_flame_color_index"))
	var touch_scroll := TouchScrollContainer.new()
	touch_scroll.size = Vector2(100, 100)
	root.add_child(touch_scroll)
	var touch_scroll_content := Control.new()
	touch_scroll_content.custom_minimum_size = Vector2(100, 400)
	touch_scroll.add_child(touch_scroll_content)
	await process_frame
	var touch_start := touch_scroll.global_position + Vector2(20, 20)
	touch_scroll.call("_begin_touch", touch_start, 0)
	touch_scroll.call("_update_touch_drag", touch_start + Vector2(0, -30))
	_check(touch_scroll.scroll_vertical > 0,
		"dragging vertically scrolls touch-enabled content")
	touch_scroll.call("_clear_touch")
	touch_scroll.queue_free()
	await process_frame
	var joined_signal_received := [false]
	var joined_callback := func() -> void:
		joined_signal_received[0] = true
	net.room_joined.connect(joined_callback, CONNECT_ONE_SHOT)
	net.call("_cli_players", [[2, "REMOTE PILOT", 0, 0]])
	_check(not joined_signal_received[0],
		"does not report a room join until the host sends this client in its roster")
	net.call("_cli_players", [[
		1, "LOCAL PILOT", original_ship_color, original_flame_color,
	]])
	_check(joined_signal_received[0],
		"confirms a multiplayer join after the host acknowledges the local player")
	net.set("players", original_room_players)
	net.set("_wait_for_hello", original_wait_for_hello)
	var identity_path := "user://pilot_identity.cfg"
	var identity_existed := FileAccess.file_exists(identity_path)
	var identity_backup := FileAccess.get_file_as_bytes(identity_path) \
		if identity_existed else PackedByteArray()
	var original_player_name := str(net.get("player_name"))
	net.set("player_name", "IDENTITY TEST")
	net.set("player_ship_color_index", 2)
	net.set("player_flame_color_index", 4)
	var saved_identity := ConfigFile.new()
	var identity_load_error := saved_identity.load(identity_path)
	_check(identity_load_error == OK
		and str(saved_identity.get_value("pilot", "name", "")) == "IDENTITY TEST"
		and int(saved_identity.get_value("pilot", "ship_color", -1)) == 2
		and int(saved_identity.get_value("pilot", "flame_color", -1)) == 4,
		"saves pilot name and color preferences between launches")
	net.set("player_name", original_player_name)
	net.set("player_ship_color_index", original_ship_color)
	net.set("player_flame_color_index", original_flame_color)
	_restore_identity_file(identity_path, identity_existed, identity_backup)
	var original_currency := [
		int(game.get("pilot_cash")),
		int(game.get("pilot_tokens")),
		int(game.get("pilot_level")),
		int(game.get("pilot_xp")),
	]
	game.set("pilot_cash", 321)
	game.set("pilot_tokens", 654)
	game.set("pilot_level", 7)
	game.set("pilot_xp", 89)
	var original_upgrades: Dictionary = game.get(
		"pilot_upgrade_levels"
	).duplicate(true)
	var original_loadouts: Dictionary = game.get(
		"ship_store_loadouts"
	).duplicate(true)
	var original_owned_items: Array[String] = game.get(
		"owned_store_item_ids"
	).duplicate(true)
	var pilot_profile_path := "user://pilot_profile.cfg"
	var pilot_profile_existed := FileAccess.file_exists(pilot_profile_path)
	var pilot_profile_backup := FileAccess.get_file_as_bytes(
		pilot_profile_path
	) if pilot_profile_existed else PackedByteArray()
	game.set("ship_store_loadouts", {})
	var original_selected_ship := str(game.get("selected_ship_id"))
	var original_unlocked_ships: Array = game.get(
		"unlocked_ship_ids"
	).duplicate(true)
	game.set("pilot_upgrade_levels", {
		"phoenix": {
			"afterburner": 2,
			"plasma_core": 1,
			"ignition_array": 3,
		},
	})
	var base_stats: Dictionary = game.call("get_ship_combat_stats", "phoenix")
	var upgraded_stats: Dictionary = game.call(
		"get_effective_ship_combat_stats", "phoenix"
	)
	_check(is_equal_approx(float(base_stats["damage_multiplier"]), 1.0)
		and int(base_stats["max_hp"]) == 6
		and is_equal_approx(float(base_stats["max_speed"]), 380.0)
		and is_equal_approx(
		float(upgraded_stats["max_speed"]),
		float(base_stats["max_speed"]) * 1.10
	) and is_equal_approx(
		float(upgraded_stats["damage_multiplier"]),
		float(base_stats["damage_multiplier"]) * 1.08
	) and is_equal_approx(float(upgraded_stats["fire_rate_multiplier"]), 1.18)
		and int(upgraded_stats["max_hp"]) == 6,
		"Phoenix has base damage 1, weak hull, high speed, and persistent upgrades affect combat stats")
	var ship_scene := load("res://scenes/player.tscn") as PackedScene
	var ship_preview := ship_scene.instantiate() as Node2D
	var ship_sprite := ship_preview.get_node("Sprite2D") as Sprite2D
	_check(ship_sprite.texture_filter == 4
		and ship_sprite.texture.get_width() >= 240
		and ship_sprite.texture.resource_path == "res://assets/ships/phoenix.svg",
		"Phoenix uses a high-resolution mipmapped texture to reduce lobby and gameplay aliasing")
	ship_preview.free()
	game.set("pilot_upgrade_levels", {
		"phoenix": {"afterburner": 2},
	})
	var phoenix_upgrades: Array = game.call(
		"get_pilot_upgrade_definitions", "phoenix"
	)
	var phoenix_stats: Dictionary = game.call(
		"get_effective_ship_combat_stats", "phoenix"
	)
	_check(str(phoenix_upgrades[0]["id"]) == "afterburner"
		and int(game.call(
			"get_pilot_upgrade_level", "afterburner", "phoenix"
		)) == 2
		and is_equal_approx(
			float(phoenix_stats["max_speed"]), 380.0 * 1.10
		),
		"keeps the only ship's upgrade track connected to its real stats")
	game.set("pilot_upgrade_levels", {"phoenix": {"ember_matrix": 3}})
	phoenix_stats = game.call("get_effective_ship_combat_stats", "phoenix")
	_check(int(phoenix_stats["burn_bonus"]) == 3,
		"applies Phoenix's burn upgrade to gameplay stats")
	game.set("pilot_upgrade_levels", original_upgrades)
	game.set("ship_store_loadouts", original_loadouts)
	game.set("ship_store_loadouts", {
		"phoenix": {
			"armor": "reinforced_armor",
			"support": "reactor_tuner",
		},
	})
	game.set("pilot_upgrade_levels", {})
	game.set("ship_store_loadouts", {
		"phoenix": {
			"armor": "reinforced_armor",
			"drone": "hex_guard_drone",
			"support": "reactor_tuner",
		},
	})
	var equipped_stats: Dictionary = game.call(
		"get_effective_ship_combat_stats", "phoenix"
	)
	_check(int(equipped_stats["max_hp"]) == 9
		and is_equal_approx(float(equipped_stats["fire_rate_multiplier"]), 1.08)
		and is_equal_approx(float(equipped_stats["damage_multiplier"]), 1.0)
		and str(game.call("get_active_store_drone", "phoenix"))
			== "hex_guard_drone",
		"applies equipped armor, support, and defensive drone effects to ship stats")
	game.set("ship_store_loadouts", {
		"phoenix": {"support": "targeting_servo"},
	})
	var targeting_stats: Dictionary = game.call(
		"get_effective_ship_combat_stats", "phoenix"
	)
	_check(is_equal_approx(
		float(targeting_stats["damage_multiplier"]), 1.1
	), "applies the targeting servo damage bonus to gameplay stats")
	game.set("pilot_upgrade_levels", original_upgrades)
	game.set("ship_store_loadouts", original_loadouts)
	game.set("owned_store_item_ids", original_owned_items)
	var lobby_scene := load("res://scenes/lobby.tscn") as PackedScene
	if lobby_scene == null:
		_check(false, "loads the active lobby scene")
		_finish()
		return
	var lobby := lobby_scene.instantiate()
	root.add_child(lobby)
	var ui_sound_button := Button.new()
	ui_sound_button.name = "UiSoundHookCheck"
	root.add_child(ui_sound_button)
	await process_frame
	_check(ui_sound_button.has_meta("ui_click_sound_connected")
		and ui_sound_button.pressed.is_connected(
			Callable(game, "_play_ui_click")
		),
		"attaches the shared web-sourced UI click sound to dynamically added buttons")
	ui_sound_button.queue_free()
	var initial_level_label := lobby.find_child(
		"PilotLevelValue", true, false
	) as Label
	var initial_cash_label := lobby.find_child(
		"CurrencyValue_Cash", true, false
	) as Label
	var initial_gem_label := lobby.find_child(
		"CurrencyValue_Gem", true, false
	) as Label
	_check(initial_level_label != null and initial_level_label.visible
		and initial_level_label.text == "LV 7"
		and initial_cash_label != null and initial_cash_label.text == "321"
		and initial_gem_label != null and initial_gem_label.text == "654",
		"initializes pilot level, cash, and gems from profile data immediately")
	game.set("pilot_cash", original_currency[0])
	game.set("pilot_tokens", original_currency[1])
	game.set("pilot_level", original_currency[2])
	game.set("pilot_xp", original_currency[3])
	lobby.call("_refresh_header_values")
	await process_frame
	await process_frame
	var page := lobby.find_child("LobbyPage", true, false) as Control
	var dashboard := lobby.find_child("Dashboard", true, false) as Control
	var desktop_row := lobby.find_child("DesktopLayout", true, false) as Control
	var main_columns := lobby.find_child("MainColumnsDesktop", true, false) as Control
	var page_content := lobby.find_child("PagePopupContent", true, false) \
		as VBoxContainer
	var dashboard_content := lobby.find_child(
		"DashboardContent", true, false
	) as Control
	var daily_scroll := lobby.find_child(
		"DailyMissionScroll", true, false
	) as ScrollContainer
	_check(lobby.find_children(
		"LobbyNav_home", "Button", true, false
	).is_empty(),
		"removes the Home button from the navigation bar")
	var pilot_level_label := lobby.find_child(
		"PilotLevelValue", true, false
	) as Label
	_check(page != null and dashboard != null and desktop_row != null
		and main_columns != null,
		"creates shared lobby navigation, home content, and full-screen page surface")
	_check(daily_scroll != null and daily_scroll.vertical_scroll_mode
		== ScrollContainer.SCROLL_MODE_AUTO and pilot_level_label != null
		and pilot_level_label.text == "LV %d" % int(game.get("pilot_level")),
		"keeps the home missions independently scrollable and pilot level visible")
	if page == null or desktop_row == null or main_columns == null \
			or page_content == null or dashboard_content == null:
		_finish()
		return
	var profile_hitbox := lobby.find_child(
		"PilotProfileHitbox", true, false
	) as Button
	if profile_hitbox != null:
		profile_hitbox.emit_signal("pressed")
	await process_frame
	var profile_popup := lobby.find_child(
		"PilotProfilePopup", true, false
	) as Control
	_check(profile_popup != null and profile_popup.visible
		and profile_popup.find_child(
			"ProfileCombatStats", true, false
		) != null and profile_popup.find_child(
			"ProfileRenameButton", true, false
		) != null,
		"opens a combat profile popup from the pilot header")
	var rename_button := profile_popup.find_child(
		"ProfileRenameButton", true, false
	) as Button if profile_popup != null else null
	if rename_button != null:
		rename_button.emit_signal("pressed")
		await process_frame
	var name_prompt := lobby.find_child("NamePrompt", true, false) as Control
	if name_prompt != null:
		var rename_edit := name_prompt.find_child(
			"NameEdit", true, false
		) as LineEdit
		var rename_confirm := name_prompt.find_child(
			"PlayButton", true, false
		) as Button
		if rename_edit != null and rename_confirm != null:
			rename_edit.text = "RENAME CHECK"
			rename_confirm.emit_signal("pressed")
	await process_frame
	await process_frame
	_check(str(net.get("player_name")) == "RENAME CHECK"
		and str(lobby.find_child(
			"PilotName", true, false
		).text) == "RENAME CHECK",
		"renames the saved pilot from the profile popup")
	net.set("player_name", original_player_name)
	_restore_identity_file(identity_path, identity_existed, identity_backup)
	lobby.call("_refresh_dashboard")

	lobby.call("_open_page", "upgrades")
	await process_frame
	var upgrades := page.find_children("PilotUpgrade_*", "PanelContainer", true, false)
	_check(page.visible and not dashboard.visible and not main_columns.visible
		and upgrades.size() == 4,
		"opens upgrades as a full-screen page covering the lobby")
	if upgrades.size() == 4:
		var valid_segments := true
		for upgrade: Node in upgrades:
			var segments := upgrade.find_child(
				"UpgradeSegments", true, false
			) as HBoxContainer
			valid_segments = valid_segments and segments != null \
				and segments.get_child_count() == 5
		_check(valid_segments, "shows exactly five level segments per upgrade")

	lobby.call("_open_page", "missions")
	await process_frame
	_check(page.visible and page_content.find_children(
		"Mission_*", "HBoxContainer", true, false
	).size() == game.call("get_daily_missions").size(),
		"renders the current saved daily mission data on its own page")

	lobby.call("_open_page", "shop")
	await process_frame
	var shop_cards := page_content.find_children(
		"ShopShip_*", "PanelContainer", true, false
	)
	var shop_grid := page_content.find_child(
		"ShopShipGrid", true, false
	) as GridContainer
	var no_ship_offers_message := false
	for node: Node in page_content.find_children("*", "Label", true, false):
		var label := node as Label
		no_ship_offers_message = no_ship_offers_message \
			or label.text.contains("NO OTHER SHIPS")
	_check(page.visible and shop_grid != null and shop_cards.is_empty()
		and no_ship_offers_message,
		"the unified shop does not offer ships when Phoenix is the only ship")
	var shop_search := page_content.find_child(
		"ShopShipSearch", true, false
	) as LineEdit
	lobby.call("_filter_shop_ships", "phoenix")
	var visible_shop_cards := 0
	for card: Node in page_content.find_children(
			"ShopShip_*", "PanelContainer", true, false):
		if (card as Control).visible:
			visible_shop_cards += 1
	_check(shop_search != null and visible_shop_cards == 0,
		"the shop search cannot reveal removed ship offers")
	lobby.call("_filter_shop_ships", "")
	_check(not lobby.find_children(
		"LobbyNav_store", "Button", true, false
	).is_empty()
		and not lobby.find_children(
			"LobbyNav_ships", "Button", true, false
		).is_empty()
		and lobby.find_children(
			"LobbyNav_equipment", "Button", true, false
		).is_empty(),
		"exposes a single Ships loadout destination alongside the separate Store")

	var equipment_fixture: Array[String] = [
		"reinforced_armor", "hex_guard_drone",
		"reactor_tuner",
		"strike_drone", "repair_drone",
	]
	game.set("owned_store_item_ids", equipment_fixture)
	game.set("ship_store_loadouts", {
		"phoenix": {
			"armor": "reinforced_armor",
			"support": "reactor_tuner",
		},
	})
	lobby.call("_open_page", "ships")
	await process_frame
	var equipment_slots := page_content.find_child(
		"LoadoutShipStage", true, false
	) as Control
	var loadout_grid := page_content.find_child(
		"LoadoutItemsGrid", true, false
	) as GridContainer
	var loadout_image := page_content.find_child(
		"LoadoutShipImage", true, false
	) as TextureRect
	_check(page.visible and equipment_slots != null
		and page_content.find_child("LoadoutCategories", true, false) != null
		and page_content.find_child("EquipmentSlot_armor", true, false) != null
		and page_content.find_child("EquipmentSlot_drone", true, false) != null
		and page_content.find_child("EquipmentSlot_support", true, false) != null
		and page_content.find_child("LoadoutShipPanel", true, false) != null
		and page_content.find_child("LoadoutShipSelector", true, false) != null
		and loadout_image != null
		and loadout_image.texture.resource_path
			== "res://assets/ships/phoenix.svg"
		and loadout_grid != null and loadout_grid.get_child_count() == 5
		and page_content.find_child(
			"LoadoutItemCard_targeting_servo", true, false
		) == null,
		"shows the ship, three real equipment slots, categories, and inventory grid")
	var ship_selector := page_content.find_child(
		"LoadoutShipSelector", true, false
	) as OptionButton
	_check(ship_selector != null
		and ship_selector.get_theme_stylebox("normal") is StyleBoxFlat
		and ship_selector.get_popup().get_theme_stylebox("panel")
			is StyleBoxFlat,
		"styles the ship dropdown and its option list in the sci-fi theme")
	lobby.call("_show_equipment_slot", "drone")
	await process_frame
	var drone_items := page_content.find_children(
		"LoadoutItemCard_*", "Button", true, false
	)
	var only_compatible_drones := drone_items.size() == 3
	for item_card: Node in drone_items:
		if item_card is Button:
			only_compatible_drones = only_compatible_drones \
				and str(item_card.name) in [
					"LoadoutItemCard_strike_drone",
					"LoadoutItemCard_repair_drone",
					"LoadoutItemCard_hex_guard_drone",
				]
	_check(only_compatible_drones and page_content.find_child(
		"LoadoutHint", true, false
	) != null,
		"selecting a drone slot filters the inventory to compatible equipment")
	lobby.call("_select_loadout_category", "weapon")
	await process_frame
	_check(page_content.find_children(
		"LoadoutItemCard_*", "Button", true, false
	).size() == 1
		and page_content.find_child(
			"LoadoutItemCard_strike_drone", true, false
		) != null,
		"left category navigation filters the inventory by real item category")
	lobby.call("_show_equipment_slot", "drone")
	lobby.call("_show_loadout_item_detail", "repair_drone")
	await process_frame
	var item_detail := lobby.get_node_or_null(
		"LoadoutItemDetailsPopup"
	) as Control
	_check(item_detail != null and item_detail.visible
		and item_detail.find_child(
			"LoadoutItemPopupTitle", true, false
		) != null
		and item_detail.find_child(
			"LoadoutItemPopupIcon", true, false
		) != null
		and not str(item_detail.find_child(
			"LoadoutItemPopupTitle", true, false
		).text).is_empty()
		and not str(item_detail.find_child(
			"LoadoutItemPopupAction", true, false
		).text).is_empty()
		and item_detail.find_children(
			"LoadoutItemCard_*", "Button", true, false
		).is_empty()
		and item_detail.find_child(
			"LoadoutItemPopupAction", true, false
		) != null,
		"opens an item detail popup with the compatible equipment action")
	var item_detail_panel := item_detail.find_child(
		"LoadoutItemPopupPanel", true, false
	) as Control if item_detail != null else null
	_check(item_detail_panel != null
		and item_detail_panel.size.x <= 480.0
		and item_detail_panel.size.y <= 260.0,
		"keeps the equipment detail popup compact")
	var loadout_action := item_detail.find_child(
		"LoadoutItemPopupAction", true, false
	) as Button if item_detail != null else null
	var locale := root.get_node_or_null("Locale")
	var equip_text := str(locale.call("translate_text", "EQUIP")) \
		if locale != null else "EQUIP"
	var unequip_text := str(locale.call("translate_text", "UNEQUIP")) \
		if locale != null else "UNEQUIP"
	_check(loadout_action != null and loadout_action.text == equip_text
		and not loadout_action.disabled,
		"owned unequipped item presents a valid equip action")
	if loadout_action != null:
		loadout_action.emit_signal("pressed")
		await process_frame
	_check(str(game.call("get_equipped_store_item", "drone"))
		== "repair_drone",
		"equipping from item details updates the active ship loadout")
	lobby.call("_show_loadout_item_detail", "repair_drone")
	await process_frame
	loadout_action = item_detail.find_child(
		"LoadoutItemPopupAction", true, false
	) as Button if item_detail != null else null
	_check(loadout_action != null and loadout_action.text == unequip_text,
		"equipped item details offer an unequip action")
	if loadout_action != null:
		loadout_action.emit_signal("pressed")
		await process_frame
	_check(str(game.call("get_equipped_store_item", "drone")).is_empty(),
		"unequipping from item details clears the active ship slot")
	if pilot_profile_existed:
		var profile_file := FileAccess.open(pilot_profile_path, FileAccess.WRITE)
		if profile_file == null:
			push_error("Unable to restore pilot profile after loadout UI test")
		else:
			profile_file.store_buffer(pilot_profile_backup)
	else:
		var profile_absolute_path := ProjectSettings.globalize_path(
			pilot_profile_path
		)
		if FileAccess.file_exists(pilot_profile_path):
			var remove_error := DirAccess.remove_absolute(profile_absolute_path)
			if remove_error != OK:
				push_error("Unable to remove temporary pilot profile after UI test")

	lobby.call("_open_page", "store")
	await process_frame
	var store_cards := page_content.find_children(
		"StoreItem_*", "PanelContainer", true, false
	)
	var store_grid := page_content.find_child(
		"StoreItemsGrid", true, false
	) as GridContainer
	_check(page.visible and store_cards.size() == 6 and store_grid != null
		and store_grid.get_parent().name == "StoreItemColumn"
		and page_content.find_child(
			"StoreItemsScroll", true, false
		) == null
		and page_content.find_child(
			"StoreCategory_attack", true, false
		) != null,
		"shows the purchase-only store in the page scroll flow without nested clipping")
	lobby.call("_select_store_category", "attack")
	await process_frame
	_check(page_content.find_children(
		"StoreItem_*", "PanelContainer", true, false
	).size() == 1
		and page_content.find_child("StoreItem_strike_drone", true, false) != null,
		"filters store inventory by the selected equipment category")
	lobby.call("_select_store_category", "all")

	for destination in [
		"missions", "shop", "store", "equipment", "ships",
		"achievements", "events", "settings",
	]:
		lobby.call("_open_page", destination)
		await process_frame
		var close_button := page.find_child(
			"ClosePageButton", true, false
		) as Button
		_check(page.visible and not dashboard.visible and close_button != null
			and close_button.visible,
			"opens %s as a full-screen page with an exit control" % destination)
		if close_button != null:
			close_button.emit_signal("pressed")
			await process_frame
		_check(not page.visible and dashboard.visible,
			"returns from %s to the home dashboard using its exit control" % destination)

	lobby.call("_open_page", "ships")
	await process_frame
	game.set("selected_ship_id", original_selected_ship)
	game.set("unlocked_ship_ids", original_unlocked_ships)

	lobby.call("_open_page", "home")
	await process_frame
	root.size = Vector2i(390, 844)
	lobby.call("_layout_dashboard")
	lobby.call("_layout_header", true)
	await process_frame
	var lobby_scroll := lobby.find_child(
		"LobbyScroll", true, false
	) as ScrollContainer
	var mobile_nav_button := lobby.find_child(
		"LobbyNav_ships", true, false
	) as Button
	var dashboard_content_size := (
		lobby.find_child("DashboardContent", true, false) as Control
	).size.y
	_check(lobby_scroll is TouchScrollContainer,
		"mobile lobby enables swipe scrolling in the main content area")
	_check(mobile_nav_button != null
		and mobile_nav_button.custom_minimum_size.y >= 48.0
		and int(mobile_nav_button.get_meta(
			"mobile_applied_font_size", 0
		)) >= int(mobile_nav_button.get_meta(
			"mobile_base_font_size", 0
		)) + 2,
		"mobile lobby navigation uses larger text and touch-friendly targets")
	_check(lobby_scroll != null
		and dashboard_content_size >= lobby_scroll.size.y,
		"mobile lobby content fills the available page height")
	var compact_level := lobby.find_child(
		"PilotLevelValue", true, false
	) as Label
	var compact_profile := lobby.find_child(
		"PilotProfileCard", true, false
	) as Control
	var compact_xp := lobby.find_child("PilotXPBar", true, false) as Control
	_check(compact_level != null and compact_level.visible
		and compact_level.custom_minimum_size.x >= 42.0
		and compact_profile != null
		and compact_profile.custom_minimum_size.x >= 132.0
		and compact_xp != null and not compact_xp.visible,
		"keeps pilot level visible with reserved header space on narrow screens")
	_check(page.get_parent() == lobby.get_node("UI")
		and is_equal_approx(page.anchor_right, 1.0)
		and is_equal_approx(page.anchor_bottom, 1.0),
		"keeps the full-screen page covering the mobile viewport")
	root.size = Vector2i(1280, 720)
	lobby.call("_layout_dashboard")
	await process_frame
	_check(page.get_parent() == lobby.get_node("UI")
		and is_equal_approx(page.anchor_right, 1.0)
		and is_equal_approx(page.anchor_bottom, 1.0),
		"keeps the full-screen page covering the desktop viewport")

	lobby.call("_open_page", "home")
	await process_frame
	_check(not page.visible and main_columns.visible,
		"Back returns to the home dashboard")
	_check(pilot_level_label.visible
		and pilot_level_label.text == "LV %d" % int(game.get("pilot_level")),
		"keeps the pilot level stable after repeated page navigation")
	lobby.queue_free()
	await process_frame
	game.set("ship_store_loadouts", original_loadouts)
	game.set("owned_store_item_ids", original_owned_items)

	var room_scene := load("res://scenes/room_lobby.tscn") as PackedScene
	_check(room_scene != null, "loads the multiplayer room lobby")
	if room_scene != null:
		var room_lobby := room_scene.instantiate() as Node
		root.add_child(room_lobby)
		await process_frame
		room_lobby.call("_layout_room_interface")
		var room_list_scroll := room_lobby.find_child(
			"RoomsScroll", true, false
		) as ScrollContainer
		var room_panel := room_lobby.find_child(
			"RoomPanel", true, false
		) as Control
		var create_panel := room_lobby.find_child(
			"CreatePanel", true, false
		) as Control
		var start_button := room_lobby.find_child(
			"StartButton", true, false
		) as Button
		var color_button := room_lobby.find_child(
			"ColorOptionsButton", true, false
		) as Button
		_check(room_panel != null and room_panel.size.x >= 800.0
			and room_panel.size.y >= 580.0 and create_panel != null
			and create_panel.size.x >= 600.0
			and start_button != null and color_button != null
			and start_button.offset_top > color_button.offset_top
			and room_list_scroll is TouchScrollContainer
			and room_list_scroll.size.x >= 800.0,
			"widens the room list, enables touch scrolling, and keeps Start below color customization")
		var previous_players: Array = net.get("players").duplicate(true)
		net.set("players", [
			{"id": 1, "ship_color_index": 0},
			{"id": 2, "ship_color_index": 1},
		])
		net.set("player_ship_color_index", 0)
		room_lobby.call("_show_color_popup")
		var ship_choices := room_lobby.find_child(
			"ShipColorChoices", true, false
		) as GridContainer
		var flame_choices := room_lobby.find_child(
			"FlameColorChoices", true, false
		) as GridContainer
		_check(ship_choices != null and ship_choices.get_child_count() == 4
			and (ship_choices.get_child(1) as Button).disabled
			and flame_choices != null and flame_choices.get_child_count() == 6
			and not (flame_choices.get_child(1) as Button).disabled,
			"locks ship colors taken by another player but allows shared flame colors")
		net.set("players", previous_players)
		net.set("player_ship_color_index", original_ship_color)
		net.set("player_flame_color_index", original_flame_color)
		_restore_identity_file(identity_path, identity_existed, identity_backup)
		room_lobby.queue_free()
		await process_frame

	var inventory_scene := load("res://scenes/inventory_ui.tscn") as PackedScene
	_check(inventory_scene != null, "loads the redesigned inventory scene")
	if inventory_scene == null:
		_finish()
		return
	var inventory := inventory_scene.instantiate()
	root.add_child(inventory)
	await process_frame
	var original_stacks: Dictionary = game.get("upg_stacks").duplicate(true)
	var card_definitions: Array = CardDB.all_cards()
	if not card_definitions.is_empty():
		var first_card: Dictionary = card_definitions[0]
		game.set("upg_stacks", {str(first_card["id"]): 2})
	inventory.call("open")
	await process_frame
	var inventory_panel := inventory.get_node("Panel") as Control
	var inventory_grid := inventory.get_node(
		"Panel/MainLayout/WideBody/Left/ScrollContainer/List"
	) as GridContainer
	_check(inventory.visible and inventory_grid.get_child_count()
		== (1 if not card_definitions.is_empty() else 0)
		and inventory_panel.get_theme_stylebox("panel") is StyleBoxFlat,
		"opens a themed inventory with cards in a scrollable grid")
	if inventory_grid.get_child_count() > 0:
		var inventory_card := inventory_grid.get_child(0) as Button
		_check(inventory_card.get_theme_stylebox("normal") is StyleBoxFlat
			and inventory_card.custom_minimum_size.x >= 90.0,
			"styles inventory cards as consistent selectable controls")
	inventory.call(
		"_apply_inventory_layout", true, Vector2(390, 844)
	)
	await process_frame
	var mobile_inventory_scroll := inventory.get_node(
		"Panel/MainLayout/MobileBody/MobileLeft/ScrollContainer"
	) as ScrollContainer
	var mobile_inventory_grid := inventory.get_node(
		"Panel/MainLayout/MobileBody/MobileLeft/ScrollContainer/List"
	) as GridContainer
	var mobile_inventory_card := mobile_inventory_grid.get_child(0) as Button \
		if mobile_inventory_grid.get_child_count() > 0 else null
	_check(inventory.get_node("Panel/MainLayout/MobileBody").visible
		and mobile_inventory_grid == inventory.get("list")
		and mobile_inventory_scroll is TouchScrollContainer
		and (mobile_inventory_card == null
			or mobile_inventory_card.custom_minimum_size.x >= 100.0)
		and (mobile_inventory_card == null
			or mobile_inventory_card.custom_minimum_size.y >= 104.0),
		"reflows inventory into touch-scrollable stacked panels with larger mobile cards")
	inventory.call(
		"_apply_inventory_layout", false, Vector2(1280, 720)
	)
	await process_frame
	_check(inventory.get_node("Panel/MainLayout/WideBody").visible
		and inventory.get_node(
			"Panel/MainLayout/WideBody/Left/ScrollContainer/List"
		) == inventory.get("list"),
		"restores side-by-side inventory panels on desktop")
	inventory.call("close")
	game.set("upg_stacks", original_stacks)
	inventory.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		push_error("FAIL: " + description)


func _restore_identity_file(
		identity_path: String, existed: bool, backup: PackedByteArray) -> void:
	if existed:
		var file := FileAccess.open(identity_path, FileAccess.WRITE)
		if file == null:
			push_error("Unable to restore pilot identity after UI test")
			return
		file.store_buffer(backup)
	elif FileAccess.file_exists(identity_path):
		var absolute_path := ProjectSettings.globalize_path(identity_path)
		var error := DirAccess.remove_absolute(absolute_path)
		if error != OK:
			push_error("Unable to remove temporary pilot identity after UI test")


func _finish() -> void:
	SfxLibrary.shutdown()
	await process_frame
	print("Lobby UI checks: ", _failures, " failure(s)")
	quit(1 if _failures > 0 else 0)
