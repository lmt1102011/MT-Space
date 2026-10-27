extends CanvasLayer

# Lobby dashboard with responsive ship, mission, and launch panels.

const GAME_SCENE := "res://scenes/main.tscn"
const ROOM_LOBBY_SCENE := "res://scenes/room_lobby.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"
const ChamferBox := preload("res://scripts/chamfer_box.gd")
const CardDBScript := preload("res://scripts/card_db.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PLAYER_ICON := preload("res://assets/ships/phoenix.svg")
const NAME_PROMPT := preload("res://scenes/name_prompt.tscn")
const DropdownStyle := preload("res://scripts/dropdown_style.gd")
const PAINT_SCHEMES := [
	{"id": "phoenix", "name": "PHOENIX", "color": Color(1.0, 0.68, 0.37)},
]
const PANEL_BG := Color(0.035, 0.065, 0.11, 0.96)
const CYAN := Color(0.34, 0.84, 0.96)
const MUTED := Color(0.63, 0.72, 0.84)
const NAV_ICONS := {
	"ships": "res://assets/ships/phoenix.svg",
	"upgrades": "res://assets/icons/damage.svg",
	"shop": "res://assets/icons/backpack.svg",
	"store": "res://assets/icons/store.svg",
	"home": "res://assets/ships/phoenix.svg",
	"missions": "res://assets/xp_orb_gem.svg",
	"achievements": "res://assets/icons/trophy.svg",
	"events": "res://assets/icons/elite_hunter.svg",
}

class TechPanel extends PanelContainer:
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var inset := 1.0
		var arm := minf(12.0, minf(size.x, size.y) * 0.18)
		var cyan := Color(0.34, 0.84, 0.96, 0.48)
		var amber := Color(1.0, 0.62, 0.29, 0.55)
		var corners := [
			[Vector2(inset, inset), Vector2(arm, 0.0), Vector2(0.0, arm), cyan],
			[Vector2(size.x - inset, inset), Vector2(-arm, 0.0), Vector2(0.0, arm), cyan],
			[Vector2(inset, size.y - inset), Vector2(arm, 0.0), Vector2(0.0, -arm), cyan],
			[Vector2(size.x - inset, size.y - inset), Vector2(-arm, 0.0), Vector2(0.0, -arm), amber],
		]
		for corner: Array in corners:
			var origin: Vector2 = corner[0]
			var horizontal: Vector2 = corner[1]
			var vertical: Vector2 = corner[2]
			var color: Color = corner[3]
			draw_line(origin, origin + horizontal, color, 1.5, true)
			draw_line(origin, origin + vertical, color, 1.5, true)


class ShipStage extends Control:
	var elapsed := 0.0
	var redraw_accumulator := 0.0
	var backdrop_style := StyleBoxFlat.new()
	const REDRAW_INTERVAL := 1.0 / 20.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		backdrop_style.bg_color = Color(0.025, 0.06, 0.12, 0.25)
		backdrop_style.border_color = Color(0.34, 0.84, 0.96, 0.34)
		backdrop_style.set_border_width_all(1)
		backdrop_style.set_corner_radius_all(12)
		set_process(is_visible_in_tree())

	func _process(delta: float) -> void:
		redraw_accumulator += delta
		if redraw_accumulator < REDRAW_INTERVAL:
			return
		elapsed += redraw_accumulator
		redraw_accumulator = 0.0
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED:
			set_process(is_visible_in_tree())

	func _draw() -> void:
		draw_style_box(backdrop_style, Rect2(Vector2.ZERO, size))
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.34
		draw_circle(center, radius * 1.38, Color(0.07, 0.22, 0.39, 0.13))
		draw_circle(center, radius * 0.92, Color(0.10, 0.31, 0.49, 0.10))
		draw_set_transform(center, 0.0, Vector2(1.18, 0.76))
		draw_arc(Vector2.ZERO, 92.0, 0.0, TAU, 96, Color(0.24, 0.77, 0.9, 0.28), 1.0, true)
		draw_arc(Vector2.ZERO, 138.0, 0.18, TAU - 0.18, 112, Color(0.25, 0.56, 0.72, 0.22), 1.0, true)
		draw_arc(Vector2.ZERO, 178.0, 0.55, 2.55, 64, Color(0.34, 0.81, 0.91, 0.35), 1.5, true)
		draw_arc(Vector2.ZERO, 178.0, 3.72, 5.72, 64, Color(0.34, 0.81, 0.91, 0.35), 1.5, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for index in 24:
			var angle := TAU * float(index) / 24.0
			var inner := Vector2(cos(angle), sin(angle)) * 144.0
			var outer := Vector2(cos(angle), sin(angle)) * (154.0 if index % 3 == 0 else 149.0)
			draw_line(center + inner, center + outer,
				Color(0.42, 0.78, 0.88, 0.42 if index % 3 == 0 else 0.2), 1.0, true)
		for index in 22:
			var seed := float(index)
			var orbit := 0.12 + fposmod(seed * 0.618, 0.82)
			var angle := seed * 2.399 + elapsed * (0.012 if index % 2 == 0 else -0.009)
			var star_pos := center + Vector2(cos(angle) * size.x * orbit * 0.42,
				sin(angle * 0.73) * size.y * orbit * 0.42)
			var twinkle := 0.45 + 0.35 * sin(elapsed * 0.8 + seed)
			draw_circle(star_pos, 0.8 + float(index % 3) * 0.35,
				Color(0.56, 0.82, 1.0, twinkle))
		for scan_y in range(5, int(size.y), 7):
			draw_line(Vector2(8, scan_y), Vector2(size.x - 8, scan_y),
				Color(0.55, 0.82, 1.0, 0.025), 1.0, true)
		var scan_position := fposmod(elapsed * 17.0, maxf(size.y, 1.0))
		draw_line(Vector2(10, scan_position), Vector2(size.x - 10, scan_position),
			Color(0.38, 0.82, 1.0, 0.11), 1.0, true)
		draw_line(Vector2(14, 1), Vector2(size.x - 14, 1),
			Color(0.34, 0.84, 0.96, 0.45), 1.0, true)


class LockGlyph extends Control:
	func _draw() -> void:
		var center := size * 0.5
		draw_arc(center + Vector2(0.0, -3.0), 7.0, PI, TAU, 16,
			Color(0.78, 0.91, 1.0, 0.95), 2.5, true)
		draw_rect(Rect2(center + Vector2(-10.0, -2.0), Vector2(20.0, 16.0)),
			Color(0.78, 0.91, 1.0, 0.95))
		draw_circle(center + Vector2(0.0, 4.0), 2.0,
			Color(0.025, 0.06, 0.1, 1.0))


@onready var ship_anchor: Node2D = $UI/ShipAnchor
@onready var ship: Sprite2D = $UI/ShipAnchor/Ship
@onready var flame1: Polygon2D = $UI/ShipAnchor/Thruster/Flame1
@onready var flame2: Polygon2D = $UI/ShipAnchor/Thruster/Flame2
@onready var flame_core: Polygon2D = $UI/ShipAnchor/Thruster/FlameCore
@onready var parallax: ParallaxBackground = $ParallaxBackground

@onready var mode_btn: Button = $UI/Buttons/ModeButton
@onready var play_btn: Button = $UI/Buttons/PlayButton
@onready var back_btn: Button = $UI/TopBar/BackButton
@onready var test_btn: Button = $UI/TopBar/TestButton

@onready var mode_panel: Panel = $UI/ModePanel
@onready var wave_mode_btn: Button = $UI/ModePanel/VBox/Cards/WaveMode
@onready var test_mode_btn: Button = $UI/ModePanel/VBox/Cards/TestMode
@onready var close_mode_btn: Button = $UI/ModePanel/VBox/CloseMode

@onready var test_panel: Panel = $UI/TestPanel
@onready var wave_spin: SpinBox = $UI/TestPanel/VBox/Grid/WaveSpin
@onready var level_spin: SpinBox = $UI/TestPanel/VBox/Grid/LevelSpin
@onready var spawn_enemy_btn: OptionButton = $UI/TestPanel/VBox/Grid/SpawnEnemyBtn
@onready var spawn_boss_btn: OptionButton = $UI/TestPanel/VBox/Grid/SpawnBossBtn
@onready var give_card_btn: OptionButton = $UI/TestPanel/VBox/Grid/GiveCardBtn
@onready var give_weapon_btn: OptionButton = $UI/TestPanel/VBox/Grid/GiveWeaponBtn
@onready var apply_btn: Button = $UI/TestPanel/VBox/Buttons/ApplyBtn
@onready var close_test_btn: Button = $UI/TestPanel/VBox/Buttons/CloseTest

var game_mode: String = "wave" # wave | test
var time: float = 0.0
var scroll: float = 0.0
var _card_ids: Array = []
var _run_record_panel: Panel
var _run_record_label: Label
var _run_record_scroll: ScrollContainer
var _run_record_close: Button
var _profile_popup: Control
var _profile_name_label: Label
var _profile_stats: VBoxContainer
var _profile_name_prompt: Control
var _dashboard: Control
var _dashboard_content: VBoxContainer
var _desktop_row: HBoxContainer
var _mobile_nav_scroll: ScrollContainer
var _main_columns: HBoxContainer
var _main_columns_mobile: VBoxContainer
var _daily_missions_box: VBoxContainer
var _page_popup: PanelContainer
var _page_popup_title: Label
var _page_popup_content: VBoxContainer
var _page_popup_scroll: ScrollContainer
var _navigation_group: ButtonGroup
var _current_page := "home"
var _ship_fleet_grid: GridContainer
var _fleet_active_horizontal: HBoxContainer
var _fleet_active_vertical: VBoxContainer
var _fleet_active_art_panel: Control
var _fleet_active_stats_panel: Control
var _shop_ship_grid: GridContainer
var _shop_ship_cards: Array[Control] = []
var _shop_search: LineEdit
var _store_search: LineEdit
var _store_items_grid: GridContainer
var _store_category: String = "all"
var _store_category_group: ButtonGroup
var _equipment_slot_id := ""
var _loadout_category := "overview"
var _loadout_category_group: ButtonGroup
var _loadout_search: LineEdit
var _loadout_grid: GridContainer
var _loadout_items_scroll: ScrollContainer
var _loadout_count: Label
var _loadout_hint: Label
var _loadout_inventory_title: Label
var _loadout_page_root: HBoxContainer
var _loadout_stage: HBoxContainer
var _loadout_item_popup: Control
var _loadout_item_popup_panel: PanelContainer
var _loadout_item_popup_title: Label
var _loadout_item_popup_icon: TextureRect
var _loadout_item_popup_description: Label
var _loadout_item_popup_effect: Label
var _loadout_item_popup_status: Label
var _loadout_item_popup_action: Button
var _loadout_selected_item_id := ""
var _loadout_ship_selector: OptionButton
var _ship_detail_dialog: ConfirmationDialog
var _ship_detail_buy_button: Button
var _selected_ship_detail_id := ""
var _selected_play_mode: String = "solo"
var _mode_summary: Label
var _ship_stage: ShipStage
var _ship_preview: TextureRect
var _ship_preview_base_position := Vector2.ZERO
var _preview_ship_index: int = 0
var _ship_swipe_start := Vector2.ZERO
var _ship_gesture_active: bool = false
var _ship_gesture_triggered: bool = false
var _ship_visual_tween: Tween
var _ship_transition_ghost: TextureRect
var _ship_transition_sweep: ColorRect
var _ship_transition_progress: float = 1.0
var _ship_transition_slide_direction: float = 1.0
var _ship_float_time := 0.0
var _ship_transition_direction: int = 1
var _ship_navigation_in_progress: bool = false
var _last_selected_ship_id: String = ""
var _ui_animation_accumulator := 0.0
var _hero_content_row: HBoxContainer
var _hero_content_stack: VBoxContainer
var _ship_stage_row: HBoxContainer
var _ship_stats: VBoxContainer

const ENEMY_LIST := ["shape", "shooter", "double", "railgun", "charger", "orb", "beam_enemy"]
const BOSS_LIST := ["boss", "boss2"]
# weapon archetype ids as the player script matches them
const WEAPON_LIST := ["basic", "machine_gun", "twin_cannon", "shotgun", "railgun", "burst"]


func _ready() -> void:
	if mode_btn:
		mode_btn.pressed.connect(_on_mode_pressed)
	if play_btn:
		play_btn.pressed.connect(_on_play_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if test_btn:
		test_btn.pressed.connect(_on_test_pressed)

	if wave_mode_btn:
		wave_mode_btn.pressed.connect(func(): _select_mode("wave"))
	if test_mode_btn:
		test_mode_btn.pressed.connect(func(): _select_mode("test"))
	if close_mode_btn and mode_panel:
		close_mode_btn.pressed.connect(func(): mode_panel.hide())

	if close_test_btn and test_panel:
		close_test_btn.pressed.connect(func(): test_panel.hide())
	if apply_btn:
		apply_btn.pressed.connect(_on_apply_test)

	_style_buttons()
	_populate_options()
	_update_mode_ui()
	for child: Node in $UI.get_children():
		if child.name != "Dim":
			var legacy_control := child as CanvasItem
			if legacy_control != null:
				legacy_control.hide()
	_create_run_record_panel()
	_build_dashboard()
	_create_ship_detail_dialog()
	Game.lobby_profile_changed.connect(_refresh_dashboard)
	get_viewport().size_changed.connect(_layout_dashboard)
	_layout_dashboard()
	_refresh_header_values()
	call_deferred("_refresh_header_values")
	_start_ani()


func _build_dashboard() -> void:
	var ui := $UI as Control
	_dashboard = Control.new()
	_dashboard.name = "Dashboard"
	_dashboard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dashboard.mouse_filter = Control.MOUSE_FILTER_PASS
	ui.add_child(_dashboard)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	_dashboard.add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	page.add_child(_build_header())

	var scroll := TouchScrollContainer.new()
	scroll.name = "LobbyScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	_dashboard_content = VBoxContainer.new()
	_dashboard_content.name = "DashboardContent"
	_dashboard_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dashboard_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_dashboard_content)

	_desktop_row = HBoxContainer.new()
	_desktop_row.name = "DesktopLayout"
	_desktop_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desktop_row.add_theme_constant_override("separation", 12)
	_dashboard_content.add_child(_desktop_row)

	_mobile_nav_scroll = TouchScrollContainer.new()
	_mobile_nav_scroll.name = "MobileNavigation"
	_mobile_nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_mobile_nav_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mobile_nav_scroll.custom_minimum_size.y = 54
	_mobile_nav_scroll.visible = false
	var mobile_nav := HBoxContainer.new()
	mobile_nav.add_theme_constant_override("separation", 8)
	_mobile_nav_scroll.add_child(mobile_nav)
	_dashboard_content.add_child(_mobile_nav_scroll)

	_navigation_group = ButtonGroup.new()
	_navigation_group.allow_unpress = true
	var nav := _build_navigation(true)
	_desktop_row.add_child(nav)
	_main_columns = _build_content_columns() as HBoxContainer
	_desktop_row.add_child(_main_columns)
	mobile_nav.add_child(_build_navigation(false))
	_main_columns_mobile = VBoxContainer.new()
	_main_columns_mobile.name = "MainColumnsMobile"
	_main_columns_mobile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_columns_mobile.add_theme_constant_override("separation", 12)
	_main_columns_mobile.visible = false
	_dashboard_content.add_child(_main_columns_mobile)

	_page_popup = _build_page_popup()
	ui.add_child(_page_popup)
	_page_popup.hide()
	_last_selected_ship_id = Game.selected_ship_id
	_refresh_dashboard()
	_refresh_header_values()
	if _page_popup.visible and _page_popup_title.text == "SHIPS":
		_open_page("ships")


func _create_ship_detail_dialog() -> void:
	_ship_detail_dialog = ConfirmationDialog.new()
	_ship_detail_dialog.title = "FIGHTER DETAILS"
	_ship_detail_dialog.dialog_text = ""
	_ship_detail_dialog.get_ok_button().text = "CLOSE"
	_ship_detail_dialog.get_cancel_button().hide()
	_ship_detail_buy_button = _ship_detail_dialog.add_button(
		"BUY", true, "buy_ship"
	)
	_ship_detail_buy_button.icon = load(
		"res://assets/icons/gem.svg"
	) as Texture2D
	_ship_detail_buy_button.add_theme_constant_override("icon_max_width", 18)
	_ship_detail_dialog.custom_action.connect(_on_ship_detail_action)
	add_child(_ship_detail_dialog)


func _show_ship_detail(ship_id: String) -> void:
	var stats := Game.get_effective_ship_combat_stats(ship_id)
	var cost := Game.get_ship_token_cost(ship_id)
	var unlock_wave := Game.get_ship_unlock_wave(ship_id)
	_selected_ship_detail_id = ship_id
	_ship_detail_dialog.title = _translate("FIGHTER DETAILS")
	_ship_detail_dialog.dialog_text = "%s\n\n%s %.2f×    %s %d    %s %d\n\n%s %d %s %d %s.\n%s: %d" % [
		ship_id.to_upper(),
		_translate("DMG"),
		float(stats["damage_multiplier"]),
		_translate("SPEED"),
		roundi(float(stats["max_speed"])),
		_translate("HULL"),
		int(stats["max_hp"]),
		_translate("UNLOCK BY REACHING WAVE"),
		unlock_wave,
		_translate("OR PURCHASE FOR"),
		cost,
		_translate("GEMS"),
		_translate("BEST WAVE"),
		int(Game.best_run.get("wave", 0)),
	]
	_ship_detail_buy_button.text = "%s  %d %s" % [
		_translate("BUY"), cost, _translate("GEMS"),
	]
	_ship_detail_buy_button.disabled = Game.is_ship_unlocked(ship_id) \
		or Game.pilot_tokens < cost
	_ship_detail_dialog.popup_centered(Vector2i(440, 300))


func _on_ship_detail_action(action: StringName) -> void:
	if action != &"buy_ship" or _selected_ship_detail_id.is_empty():
		return
	var ship_id := _selected_ship_detail_id
	if not Game.unlock_ship_with_tokens(ship_id):
		return
	_sfx()
	_ship_detail_dialog.hide()
	_open_page("ships")


func _build_header() -> Control:
	var card := _new_panel()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.name = "PilotHeaderRow"
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size.y = 54
	margin.add_child(row)

	var brand := Label.new()
	brand.name = "HeaderBrand"
	brand.text = "MT SPACE"
	brand.add_theme_font_size_override("font_size", 22)
	brand.add_theme_color_override("font_color", Color(0.91, 0.96, 1.0))
	row.add_child(brand)

	var pilot_card := _new_panel()
	pilot_card.name = "PilotProfileCard"
	var pilot_margin := MarginContainer.new()
	pilot_margin.add_theme_constant_override("margin_left", 6)
	pilot_margin.add_theme_constant_override("margin_top", 6)
	pilot_margin.add_theme_constant_override("margin_right", 6)
	pilot_margin.add_theme_constant_override("margin_bottom", 6)
	pilot_card.add_child(pilot_margin)
	var pilot_row := HBoxContainer.new()
	pilot_row.add_theme_constant_override("separation", 8)
	pilot_margin.add_child(pilot_row)
	var avatar := PanelContainer.new()
	avatar.name = "PilotAvatar"
	avatar.custom_minimum_size = Vector2(44, 44)
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = Color(0.10, 0.22, 0.34)
	avatar_style.border_color = Color(CYAN, 0.8)
	avatar_style.set_border_width_all(2)
	avatar_style.set_corner_radius_all(24)
	avatar.add_theme_stylebox_override("panel", avatar_style)
	var initials := Label.new()
	initials.text = _pilot_initials()
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.add_theme_font_size_override("font_size", 15)
	initials.add_theme_color_override("font_color", CYAN)
	avatar.add_child(initials)
	pilot_row.add_child(avatar)

	var profile := VBoxContainer.new()
	profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile.add_theme_constant_override("separation", 2)
	var pilot := Label.new()
	var pilot_name := str(Net.get("player_name")).strip_edges()
	pilot.text = pilot_name if not pilot_name.is_empty() else "PILOT"
	pilot.name = "PilotName"
	pilot.clip_text = true
	pilot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pilot.add_theme_color_override("font_color", Color.WHITE)
	profile.add_child(pilot)
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 6)
	var level_label := Label.new()
	level_label.name = "PilotLevelValue"
	level_label.text = "LV %d" % Game.pilot_level
	level_label.visible = true
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.add_theme_color_override("font_color", Color(0.97, 0.78, 0.38))
	progress_row.add_child(level_label)
	var xp_label := Label.new()
	xp_label.name = "PilotXPValue"
	xp_label.text = "%d / %d XP" % [
		Game.pilot_xp, Game.xp_needed_for(Game.pilot_level),
	]
	xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_label.add_theme_font_size_override("font_size", 9)
	xp_label.add_theme_color_override("font_color", MUTED)
	progress_row.add_child(xp_label)
	profile.add_child(progress_row)
	var xp_bar := ProgressBar.new()
	xp_bar.name = "PilotXPBar"
	xp_bar.max_value = maxf(1.0, float(Game.xp_needed_for(Game.pilot_level)))
	xp_bar.value = Game.pilot_xp
	xp_bar.custom_minimum_size.y = 5
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.show_percentage = false
	var xp_track := StyleBoxFlat.new()
	xp_track.bg_color = Color(0.10, 0.16, 0.23)
	xp_track.set_corner_radius_all(3)
	xp_bar.add_theme_stylebox_override("background", xp_track)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.35, 0.83, 0.94)
	xp_fill.set_corner_radius_all(3)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	profile.add_child(xp_bar)
	pilot_row.add_child(profile)
	row.add_child(pilot_card)
	var profile_hitbox := Button.new()
	profile_hitbox.name = "PilotProfileHitbox"
	profile_hitbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile_hitbox.focus_mode = Control.FOCUS_NONE
	profile_hitbox.tooltip_text = "OPEN PILOT PROFILE"
	profile_hitbox.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	profile_hitbox.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	profile_hitbox.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	profile_hitbox.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	profile_hitbox.pressed.connect(_show_profile_popup)
	for descendant: Node in pilot_card.find_children("*", "Control", true, false):
		(descendant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	pilot_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pilot_card.add_child(profile_hitbox)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	row.add_child(_build_currency_cards())
	var settings := _make_button("SETTINGS", "settings")
	settings.name = "HeaderSettingsButton"
	settings.tooltip_text = "SETTINGS"
	settings.pressed.connect(func(): _open_page("settings"))
	row.add_child(settings)
	return card


func _pilot_initials() -> String:
	var player_name := str(Net.get("player_name")).strip_edges()
	if player_name.is_empty():
		return "P"
	var words := player_name.split(" ", false)
	if words.size() > 1:
		return (words[0].left(1) + words[1].left(1)).to_upper()
	return player_name.left(1).to_upper()


func _ensure_profile_popup() -> void:
	if is_instance_valid(_profile_popup):
		return
	_profile_popup = Control.new()
	_profile_popup.name = "PilotProfilePopup"
	_profile_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_profile_popup.z_index = 80
	_profile_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_profile_popup.hide()
	add_child(_profile_popup)
	var dim := ColorRect.new()
	dim.name = "ProfilePopupDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.005, 0.014, 0.03, 0.78)
	_profile_popup.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile_popup.add_child(center)
	var panel := _new_panel()
	panel.name = "PilotProfilePanel"
	panel.custom_minimum_size = Vector2(460, 420)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var heading_label := Label.new()
	heading_label.text = "PILOT COMBAT PROFILE"
	heading_label.add_theme_font_size_override("font_size", 18)
	heading_label.add_theme_color_override("font_color", CYAN)
	heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(heading_label)
	var close := _make_button("×", "profile_close")
	close.custom_minimum_size = Vector2(40, 36)
	close.pressed.connect(_profile_popup.hide)
	heading.add_child(close)
	_profile_name_label = Label.new()
	_profile_name_label.name = "ProfilePilotName"
	_profile_name_label.add_theme_font_size_override("font_size", 24)
	_profile_name_label.add_theme_color_override("font_color", Color.WHITE)
	layout.add_child(_profile_name_label)
	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 1
	divider.color = Color(CYAN, 0.4)
	layout.add_child(divider)
	_profile_stats = VBoxContainer.new()
	_profile_stats.name = "ProfileCombatStats"
	_profile_stats.add_theme_constant_override("separation", 8)
	_profile_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_profile_stats)
	var rename := _make_button("CHANGE NAME", "profile_rename")
	rename.name = "ProfileRenameButton"
	rename.custom_minimum_size.y = 42
	rename.pressed.connect(_begin_profile_rename)
	layout.add_child(rename)


func _show_profile_popup() -> void:
	_ensure_profile_popup()
	_refresh_profile_popup()
	_profile_popup.show()


func _refresh_profile_popup() -> void:
	if _profile_stats == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var profile_panel := _profile_popup.find_child(
		"PilotProfilePanel", true, false
	) as Control
	if profile_panel != null:
		profile_panel.custom_minimum_size = Vector2(
			minf(460.0, maxf(280.0, viewport_size.x - 32.0)),
			minf(420.0, maxf(280.0, viewport_size.y - 32.0))
		)
	var current_name := str(Net.player_name).strip_edges()
	_profile_name_label.text = current_name if not current_name.is_empty() \
		else "PILOT"
	for child: Node in _profile_stats.get_children():
		child.queue_free()
	var best: Dictionary = Game.best_run
	var latest: Dictionary = Game.latest_run
	var total_kills := 0
	for count: Variant in best.get("enemy_kills", {}).values():
		total_kills += int(count)
	var stats := [
		["PILOT LEVEL", str(Game.pilot_level)],
		["BEST WAVE", str(int(best.get("wave", 0)))],
		["BEST-RUN KILLS", str(total_kills)],
		["BOSSES DEFEATED", str(int(best.get("bosses", 0)))],
		["DAMAGE DEALT", _format_count(int(best.get("damage", 0)))],
		["LATEST RUN", "WAVE %d  /  %s" % [
			int(latest.get("wave", 0)),
			_format_time(float(latest.get("seconds", 0.0))),
		]],
	]
	for stat: Array in stats:
		var line := HBoxContainer.new()
		var label := Label.new()
		label.text = str(stat[0])
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Label.new()
		value.text = str(stat[1])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_color_override("font_color", Color.WHITE)
		line.add_child(label)
		line.add_child(value)
		_profile_stats.add_child(line)


func _begin_profile_rename() -> void:
	if is_instance_valid(_profile_name_prompt):
		return
	_profile_popup.hide()
	_profile_name_prompt = NAME_PROMPT.instantiate() as Control
	add_child(_profile_name_prompt)
	_profile_name_prompt.call("show_rename_mode")
	_profile_name_prompt.name_chosen.connect(_on_profile_name_changed)


func _on_profile_name_changed(_new_name: String) -> void:
	_profile_name_prompt = null
	_refresh_dashboard()
	_show_profile_popup()


func _build_currency_cards() -> Control:
	var cards := HBoxContainer.new()
	cards.name = "CurrencyCards"
	cards.size_flags_horizontal = Control.SIZE_SHRINK_END
	cards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cards.add_theme_constant_override("separation", 7)
	cards.add_child(_build_currency_card("cash", str(Game.pilot_cash)))
	cards.add_child(_build_currency_card("gem", str(Game.pilot_tokens)))
	return cards


func _build_currency_card(currency: String, amount: String) -> PanelContainer:
	var card := _new_panel()
	card.name = "CurrencyCard_" + currency.capitalize()
	card.custom_minimum_size = Vector2(116, 46)
	card.size_flags_horizontal = Control.SIZE_SHRINK_END
	var currency_style := card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	currency_style.bg_color = Color(0.055, 0.11, 0.18, 0.88) \
		if currency == "cash" else Color(0.075, 0.09, 0.18, 0.88)
	currency_style.border_color = Color(CYAN, 0.46) \
		if currency == "cash" else Color(0.68, 0.60, 0.94, 0.46)
	card.add_theme_stylebox_override("panel", currency_style)
	var surface := HBoxContainer.new()
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.add_theme_constant_override("separation", 5)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 3)
	card.add_child(margin)
	margin.add_child(surface)
	var plus := Label.new()
	plus.name = "CurrencyPlus_" + currency.capitalize()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(18, 24)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.add_theme_font_size_override("font_size", 17)
	plus.add_theme_color_override("font_color", CYAN)
	surface.add_child(plus)
	var symbol: Control
	if currency == "cash":
		var cash_symbol := Label.new()
		cash_symbol.text = "$"
		cash_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cash_symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cash_symbol.add_theme_font_size_override("font_size", 16)
		cash_symbol.add_theme_color_override("font_color", Color(0.52, 0.91, 0.98))
		symbol = cash_symbol
	else:
		var gem_symbol := TextureRect.new()
		gem_symbol.texture = load("res://assets/icons/gem.svg") as Texture2D
		gem_symbol.modulate = Color(0.74, 0.94, 1.0)
		gem_symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gem_symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		symbol = gem_symbol
	symbol.custom_minimum_size = Vector2(20, 24)
	surface.add_child(symbol)
	var amount_label := Label.new()
	amount_label.name = "CurrencyValue_" + currency.capitalize()
	amount_label.text = amount
	amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_size_override("font_size", 15)
	amount_label.add_theme_color_override(
		"font_color", Color(0.91, 0.96, 1.0) if currency == "cash"
		else Color(0.78, 0.72, 1.0)
	)
	surface.add_child(amount_label)
	return card


func _build_navigation(vertical: bool) -> Control:
	var nav: Control = VBoxContainer.new() if vertical else HBoxContainer.new()
	nav.name = "LobbyNavigation"
	nav.add_theme_constant_override("separation", 7)
	var nav_margin := MarginContainer.new()
	nav_margin.name = "NavigationPadding"
	nav_margin.add_theme_constant_override("margin_left", 8)
	nav_margin.add_theme_constant_override("margin_top", 6)
	nav_margin.add_theme_constant_override("margin_right", 8)
	nav_margin.add_theme_constant_override("margin_bottom", 6)
	nav_margin.add_child(nav)
	if vertical:
		nav_margin.custom_minimum_size.x = 148
		nav_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		nav_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: Array in [
		["SHIPS", "ships"], ["UPGRADES", "upgrades"],
		["SHOP", "shop"], ["STORE", "store"],
		["MISSIONS", "missions"],
		["ACHIEVEMENTS", "achievements"], ["EVENTS", "events"],
	]:
		var button := _make_button(str(entry[0]), str(entry[1]))
		button.name = "LobbyNav_" + str(entry[1])
		button.icon = load(str(NAV_ICONS[str(entry[1])])) as Texture2D
		button.add_theme_constant_override("icon_max_width", 19)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("h_separation", 10)
		button.toggle_mode = true
		button.button_group = _navigation_group
		button.set_meta("lobby_page", str(entry[1]))
		if str(entry[1]) == _current_page:
			button.button_pressed = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0 if vertical else 124, 44)
		button.pressed.connect(_open_page.bind(str(entry[1])))
		nav.add_child(button)
	return nav_margin


func _build_content_columns() -> Control:
	var columns := HBoxContainer.new()
	columns.name = "MainColumnsDesktop"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)

	var center := VBoxContainer.new()
	center.name = "PrimaryColumn"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 12)
	columns.add_child(center)

	var hero := _build_ship_preview()
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(hero)
	center.add_child(_build_quick_stats())

	var side := VBoxContainer.new()
	side.name = "OperationsColumn"
	side.custom_minimum_size.x = 304
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 12)
	columns.add_child(side)
	side.add_child(_build_play_panel())
	side.add_child(_build_daily_panel())
	return columns


func _build_ship_preview() -> Control:
	var section := _create_section("HANGAR / ACTIVE FIGHTER")
	var body := section["body"] as VBoxContainer
	_hero_content_row = HBoxContainer.new()
	_hero_content_row.name = "HeroContentRow"
	_hero_content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hero_content_row.add_theme_constant_override("separation", 12)
	body.add_child(_hero_content_row)

	_ship_stage_row = HBoxContainer.new()
	_ship_stage_row.name = "ShipStageControls"
	_ship_stage_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_stage_row.add_theme_constant_override("separation", 8)
	_hero_content_row.add_child(_ship_stage_row)
	var previous := _make_button("‹", "ship_previous")
	previous.name = "PreviousShipButton"
	previous.custom_minimum_size = Vector2(48, 56)
	previous.add_theme_font_size_override("font_size", 28)
	previous.disabled = PAINT_SCHEMES.size() <= 1
	previous.pressed.connect(_cycle_ship.bind(-1))
	_ship_stage_row.add_child(previous)

	_ship_stage = ShipStage.new()
	_ship_stage.name = "ShipDisplayStage"
	_ship_stage.custom_minimum_size = Vector2(340, 250)
	_ship_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ship_stage.clip_contents = true
	_ship_stage.resized.connect(_layout_ship_stage)
	_ship_stage.gui_input.connect(_on_ship_stage_input)
	_ship_stage_row.add_child(_ship_stage)

	var paint_label := Label.new()
	paint_label.name = "ShipPaintLabel"
	paint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	paint_label.offset_left = 12
	paint_label.offset_top = 10
	paint_label.offset_right = -12
	paint_label.offset_bottom = 32
	paint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paint_label.add_theme_font_size_override("font_size", 10)
	paint_label.add_theme_color_override("font_color", Color(0.84, 0.93, 1.0))
	paint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship_stage.add_child(paint_label)

	var glow := ColorRect.new()
	glow.name = "EngineGlow"
	glow.color = Color(0.2, 0.78, 0.94, 0.12)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship_stage.add_child(glow)

	_ship_preview = TextureRect.new()
	_ship_preview.name = "SelectedShipPreview"
	_ship_preview.texture = PLAYER_ICON
	_ship_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ship_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ship_preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ship_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship_stage.add_child(_ship_preview)
	var locked_overlay := ColorRect.new()
	locked_overlay.name = "LockedOverlay"
	locked_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	locked_overlay.color = Color(0.005, 0.012, 0.025, 0.64)
	locked_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locked_overlay.z_index = 2
	locked_overlay.visible = false
	_ship_stage.add_child(locked_overlay)
	var lock_center := CenterContainer.new()
	lock_center.name = "LockCenter"
	lock_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	locked_overlay.add_child(lock_center)
	var lock_layout := VBoxContainer.new()
	lock_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	lock_layout.add_theme_constant_override("separation", 5)
	lock_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_center.add_child(lock_layout)
	var lock_glyph := LockGlyph.new()
	lock_glyph.custom_minimum_size = Vector2(40, 34)
	lock_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_layout.add_child(lock_glyph)
	var lock_label := Label.new()
	lock_label.name = "LockedLabel"
	lock_label.text = "LOCKED"
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_label.add_theme_font_size_override("font_size", 10)
	lock_label.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_layout.add_child(lock_label)

	_ship_transition_sweep = ColorRect.new()
	_ship_transition_sweep.name = "ShipTransitionSweep"
	_ship_transition_sweep.color = Color(0.45, 0.88, 1.0, 0.0)
	_ship_transition_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship_transition_sweep.z_index = 4
	_ship_stage.add_child(_ship_transition_sweep)
	_layout_ship_stage()

	var next := _make_button("›", "ship_next")
	next.name = "NextShipButton"
	next.custom_minimum_size = Vector2(48, 56)
	next.add_theme_font_size_override("font_size", 28)
	next.disabled = PAINT_SCHEMES.size() <= 1
	next.pressed.connect(_cycle_ship.bind(1))
	_ship_stage_row.add_child(next)

	var stats_panel := _new_panel()
	stats_panel.name = "ShipStatCard"
	stats_panel.custom_minimum_size.x = 230
	stats_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hero_content_row.add_child(stats_panel)
	var stat_margin := MarginContainer.new()
	stat_margin.add_theme_constant_override("margin_left", 12)
	stat_margin.add_theme_constant_override("margin_top", 12)
	stat_margin.add_theme_constant_override("margin_right", 12)
	stat_margin.add_theme_constant_override("margin_bottom", 12)
	stats_panel.add_child(stat_margin)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 10)
	stat_margin.add_child(details)
	var stat_title := Label.new()
	stat_title.text = "FRAME SYSTEMS"
	stat_title.add_theme_font_size_override("font_size", 11)
	stat_title.add_theme_color_override("font_color", CYAN)
	details.add_child(stat_title)
	_ship_stats = details
	stat_title.name = "ShipStatsTitle"
	_refresh_ship_stats(Game.selected_ship_id)

	_hero_content_stack = VBoxContainer.new()
	_hero_content_stack.name = "HeroContentStack"
	_hero_content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_content_stack.add_theme_constant_override("separation", 10)
	_hero_content_stack.visible = false
	body.add_child(_hero_content_stack)
	_update_ship_preview(false)
	return section["panel"] as Control


func _layout_ship_stage() -> void:
	if _ship_stage == null or _ship_preview == null:
		return
	var stage_size := _ship_stage.size
	var texture_size := PLAYER_ICON.get_size()
	var ratio := texture_size.x / maxf(texture_size.y, 1.0)
	var image_width := minf(stage_size.x * 0.76, stage_size.y * 0.72 * ratio)
	var image_height := image_width / ratio
	_ship_preview.size = Vector2(image_width, image_height)
	_ship_preview_base_position = (stage_size - _ship_preview.size) * 0.5
	_ship_preview.pivot_offset = _ship_preview.size * 0.5
	var transition_active := _ship_visual_tween != null \
		and _ship_visual_tween.is_running()
	if transition_active:
		_apply_ship_transition(
			_ship_transition_progress, _ship_transition_slide_direction)
	else:
		_ship_preview.position = _ship_preview_base_position
		_ship_preview.rotation = 0.0
		_ship_preview.scale = Vector2.ONE
		_ship_preview.modulate.a = 1.0
	var glow := _ship_stage.get_node("EngineGlow") as ColorRect
	glow.size = Vector2(28.0, 11.0)
	glow.position = Vector2(_ship_preview.position.x - 9.0,
		stage_size.y * 0.5 - glow.size.y * 0.5)
	glow.pivot_offset = glow.size * 0.5
	glow.rotation = _ship_preview.rotation
	var locked_overlay := _ship_stage.get_node_or_null("LockedOverlay") as ColorRect
	if locked_overlay != null:
		locked_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _ship_transition_sweep != null:
		_ship_transition_sweep.position = Vector2.ZERO
		_ship_transition_sweep.size = Vector2(8.0, stage_size.y)


func _add_ship_stat(parent: VBoxContainer, title: String, value: float,
		scale_max: float, value_text: String, tint: Color) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label_row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", MUTED)
	label_row.add_child(name_label)
	var value_label := Label.new()
	value_label.name = title + "Value"
	value_label.text = value_text
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	label_row.add_child(value_label)
	row.add_child(label_row)
	var segments := HBoxContainer.new()
	segments.name = title + "Segments"
	segments.add_theme_constant_override("separation", 4)
	var lit_count := clampi(
		roundi(clampf(value / maxf(scale_max, 0.001), 0.0, 1.0) * 5.0), 0, 5
	)
	for index in 5:
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(0, 7)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.color = tint if index < lit_count else Color(0.13, 0.20, 0.28)
		segments.add_child(segment)
	row.add_child(segments)
	parent.add_child(row)


func _refresh_ship_stats(ship_id: String) -> void:
	if _ship_stats == null:
		return
	for child in _ship_stats.get_children():
		if child.name == "ShipStatsTitle":
			continue
		_ship_stats.remove_child(child)
		child.free()
	var stats := Game.get_effective_ship_combat_stats(ship_id)
	var damage := float(stats["damage_multiplier"])
	var speed := float(stats["max_speed"])
	var hp := float(stats["max_hp"])
	var projectile_speed := float(stats["bullet_speed"])
	_add_ship_stat(_ship_stats, "DAMAGE", damage, 1.25,
		"%.2f×" % damage, CYAN)
	_add_ship_stat(_ship_stats, "SPEED", speed, 450.0,
		"%d" % roundi(speed), Color(0.36, 0.72, 1.0))
	_add_ship_stat(_ship_stats, "HP", hp, 16.0,
		"%d" % roundi(hp), Color(0.47, 0.89, 0.70))
	_add_ship_stat(_ship_stats, "BULLET SPEED", projectile_speed, 750.0,
		"%d" % roundi(projectile_speed), Color(0.95, 0.72, 0.39))


func _build_quick_stats() -> Control:
	var section := _create_section("FLIGHT RECORD", "YOUR RECENT PERFORMANCE")
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	for item: Array in [
		["BEST WAVE", str(int(Game.best_run.get("wave", 0)))],
		["BOSSES", str(int(Game.best_run.get("bosses", 0)))],
		["DAMAGE", _format_count(int(Game.best_run.get("damage", 0)))],
	]:
		var stat := _new_panel()
		stat.name = "QuickStat_" + str(item[0]).replace(" ", "_")
		stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat.custom_minimum_size.y = 62
		var content := VBoxContainer.new()
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 2)
		stat.add_child(content)
		var title := Label.new()
		title.text = str(item[0])
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 10)
		title.add_theme_color_override("font_color", MUTED)
		content.add_child(title)
		var value := Label.new()
		value.name = "Value"
		value.text = str(item[1])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 18)
		value.add_theme_color_override("font_color", CYAN)
		content.add_child(value)
		stats.add_child(stat)
	(section["body"] as VBoxContainer).add_child(stats)
	return section["panel"] as Control


func _build_play_panel() -> Control:
	var section := _create_section("LAUNCH CONTROL", "SELECT A FLIGHT MODE")
	var body := section["body"] as VBoxContainer
	_mode_summary = Label.new()
	_mode_summary.name = "SelectedModeSummary"
	_mode_summary.text = "SOLO  /  WAVE SURVIVAL"
	_mode_summary.add_theme_font_size_override("font_size", 12)
	_mode_summary.add_theme_color_override("font_color", CYAN)
	body.add_child(_mode_summary)
	var play := _make_button("PLAY NOW", "play")
	play.name = "PlayNowButton"
	play.custom_minimum_size.y = 58
	play.add_theme_font_size_override("font_size", 22)
	play.pressed.connect(_start_selected_mode)
	body.add_child(play)
	var choose_mode := _make_button("CHOOSE MODE", "choose_mode")
	choose_mode.name = "ChooseModeButton"
	choose_mode.custom_minimum_size.y = 42
	choose_mode.pressed.connect(_open_mode_selector)
	body.add_child(choose_mode)
	return section["panel"] as Control


func _build_daily_panel() -> Control:
	var section := _create_section("DAILY MISSIONS", "REWARDS RESET EACH DAY")
	_daily_missions_box = VBoxContainer.new()
	_daily_missions_box.name = "DailyMissionRows"
	_daily_missions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_missions_box.add_theme_constant_override("separation", 6)
	var mission_scroll := TouchScrollContainer.new()
	mission_scroll.name = "DailyMissionScroll"
	mission_scroll.custom_minimum_size.y = 124
	mission_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mission_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mission_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	mission_scroll.add_child(_daily_missions_box)
	(section["body"] as VBoxContainer).add_child(mission_scroll)
	var all := _make_button("VIEW ALL MISSIONS", "missions")
	all.name = "ViewAllMissionsButton"
	all.pressed.connect(_open_page.bind("missions"))
	(section["body"] as VBoxContainer).add_child(all)
	return section["panel"] as Control


func _build_page_popup() -> PanelContainer:
	var popup := PanelContainer.new()
	popup.name = "LobbyPage"
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.clip_contents = true
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.z_index = 40
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.025, 0.045, 0.095, 0.99)
	popup_style.border_color = Color(0.30, 0.68, 0.88, 0.9)
	popup_style.set_border_width_all(1)
	popup_style.set_corner_radius_all(0)
	popup.add_theme_stylebox_override("panel", popup_style)
	var margin := MarginContainer.new()
	margin.name = "PageMargin"
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	popup.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var heading_panel := PanelContainer.new()
	var heading_style := StyleBoxFlat.new()
	heading_style.bg_color = Color(0.055, 0.12, 0.20, 0.96)
	heading_style.border_color = Color(0.23, 0.56, 0.74, 0.62)
	heading_style.set_border_width_all(1)
	heading_style.set_corner_radius_all(8)
	heading_panel.add_theme_stylebox_override("panel", heading_style)
	layout.add_child(heading_panel)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	heading_panel.add_child(heading)
	_page_popup_title = Label.new()
	_page_popup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_popup_title.add_theme_font_size_override("font_size", 20)
	_page_popup_title.add_theme_color_override("font_color", Color.WHITE)
	_page_popup_title.custom_minimum_size.y = 40
	_page_popup_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(_page_popup_title)
	var close := _make_button("CLOSE", "close")
	close.name = "ClosePageButton"
	close.custom_minimum_size = Vector2(104, 40)
	close.pressed.connect(_close_page_popup)
	heading.add_child(close)
	var accent := ColorRect.new()
	accent.custom_minimum_size.y = 2
	accent.color = Color(0.31, 0.77, 0.95, 0.84)
	layout.add_child(accent)
	_page_popup_scroll = TouchScrollContainer.new()
	_page_popup_scroll.name = "PagePopupScroll"
	_page_popup_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_popup_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(_page_popup_scroll)
	_page_popup_content = VBoxContainer.new()
	_page_popup_content.name = "PagePopupContent"
	_page_popup_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_popup_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_popup_content.add_theme_constant_override("separation", 8)
	_page_popup_scroll.add_child(_page_popup_content)
	popup.hide()
	return popup


func _create_section(title: String, subtitle: String = "") -> Dictionary:
	var panel := _new_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	body.add_child(title_label)
	if not subtitle.is_empty():
		var subtitle_label := Label.new()
		subtitle_label.text = subtitle
		subtitle_label.add_theme_font_size_override("font_size", 9)
		subtitle_label.add_theme_color_override("font_color", MUTED)
		body.add_child(subtitle_label)
	return {"panel": panel, "body": body}


func _new_panel() -> PanelContainer:
	var panel := TechPanel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.09, 0.15, 0.84)
	style.border_color = Color(0.28, 0.58, 0.76, 0.56)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.005, 0.018, 0.04, 0.32)
	style.shadow_size = 10
	style.expand_margin_left = 1.0
	style.expand_margin_top = 1.0
	style.expand_margin_right = 1.0
	style.expand_margin_bottom = 1.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _style_loadout_ship_selector(selector: OptionButton) -> void:
	DropdownStyle.apply(selector)


func _make_button(text: String, action: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.105, 0.16, 0.98)
	normal.border_color = Color(0.20, 0.40, 0.57, 0.8)
	normal.content_margin_left = 10
	normal.content_margin_top = 5
	normal.content_margin_right = 10
	normal.content_margin_bottom = 5
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.18, 0.25, 1.0)
	hover.border_color = CYAN
	var selected := normal.duplicate() as StyleBoxFlat
	selected.bg_color = Color(0.08, 0.20, 0.27, 1.0)
	selected.border_color = Color(CYAN, 0.85)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.045, 0.075, 0.11, 0.9)
	disabled.border_color = Color(0.17, 0.25, 0.33, 0.55)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.87, 0.94, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.43, 0.52, 0.61))
	if action != "play":
		button.add_theme_stylebox_override("pressed", selected)
	if action == "play":
		var play_style := StyleBoxFlat.new()
		play_style.bg_color = Color(0.78, 0.48, 0.22)
		play_style.border_color = Color(0.94, 0.68, 0.38)
		play_style.set_border_width_all(1)
		play_style.set_corner_radius_all(8)
		var play_hover := play_style.duplicate() as StyleBoxFlat
		play_hover.bg_color = Color(0.88, 0.57, 0.28)
		var play_pressed := play_style.duplicate() as StyleBoxFlat
		play_pressed.bg_color = Color(0.66, 0.39, 0.18)
		button.add_theme_stylebox_override("normal", play_style)
		button.add_theme_stylebox_override("hover", play_hover)
		button.add_theme_stylebox_override("pressed", play_pressed)
		button.add_theme_color_override("font_color", Color(0.08, 0.09, 0.12))
		button.add_theme_color_override("font_hover_color", Color(0.08, 0.09, 0.12))
	return button


func _layout_dashboard() -> void:
	if _dashboard_content == null:
		return
	var current_viewport := get_viewport()
	if current_viewport == null:
		return
	var viewport_size := current_viewport.get_visible_rect().size
	var narrow := viewport_size.x < 940.0 \
		or viewport_size.x / maxf(viewport_size.y, 1.0) < 1.0
	_scale_mobile_controls(_dashboard, narrow)
	_scale_mobile_controls(_page_popup, narrow)
	_layout_header(viewport_size.x < 430.0)
	var page_margin := _page_popup.get_node_or_null("PageMargin") as MarginContainer
	if page_margin != null:
		var horizontal_margin := 12 if narrow else 28
		var vertical_margin := 12 if narrow else 22
		page_margin.add_theme_constant_override("margin_left", horizontal_margin)
		page_margin.add_theme_constant_override("margin_right", horizontal_margin)
		page_margin.add_theme_constant_override("margin_top", vertical_margin)
		page_margin.add_theme_constant_override("margin_bottom", vertical_margin)
	_set_hero_layout(narrow)
	var mobile_nav := _mobile_nav_scroll
	var mobile_columns := _main_columns_mobile
	if narrow:
		if _main_columns.get_parent() == _desktop_row:
			_desktop_row.remove_child(_main_columns)
		while _main_columns.get_child_count() > 0:
			var column := _main_columns.get_child(0)
			_main_columns.remove_child(column)
			_main_columns_mobile.add_child(column)
		_dashboard_content.move_child(mobile_nav, 0)
		_dashboard_content.move_child(mobile_columns, 1)
	else:
		while _main_columns_mobile.get_child_count() > 0:
			var column := _main_columns_mobile.get_child(0)
			_main_columns_mobile.remove_child(column)
			_main_columns.add_child(column)
		if _main_columns.get_parent() != _desktop_row:
			_desktop_row.add_child(_main_columns)
		_dashboard_content.move_child(_desktop_row, 0)
	_main_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dashboard_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desktop_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_columns_mobile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_columns.custom_minimum_size.x = 0
	_main_columns.custom_minimum_size.y = 0
	var operations: Node = _main_columns_mobile.get_child(1) if narrow \
		else _main_columns.get_child(1)
	if operations is Control:
		operations.custom_minimum_size.x = 0 if narrow else 286
	var nav := _desktop_row.get_node_or_null("LobbyNavigation") as Control
	if nav != null:
		nav.visible = not narrow
	if _ship_fleet_grid != null:
		_ship_fleet_grid.columns = 2 if narrow else 3
		_layout_fleet_active_ship(narrow)
	if _loadout_grid != null:
		_loadout_grid.columns = _loadout_columns()
	_mobile_nav_scroll.visible = narrow
	_main_columns.visible = _current_page == "home"
	_main_columns_mobile.visible = narrow and _current_page == "home"
	_desktop_row.visible = not narrow
	_dashboard.visible = _current_page == "home"
	if _page_popup != null:
		_page_popup.visible = _current_page != "home"
	_layout_run_record_panel()


func _scale_mobile_controls(root_control: Control, mobile: bool) -> void:
	if root_control == null:
		return
	for node: Node in root_control.find_children("*", "Control", true, false):
		var control := node as Control
		if control is Label or control is Button or control is LineEdit \
				or control is OptionButton or control is TextEdit \
				or control is RichTextLabel:
			if not control.has_meta("mobile_base_font_size"):
				control.set_meta(
					"mobile_base_font_size",
					control.get_theme_font_size("font_size")
				)
				control.set_meta(
					"mobile_base_minimum_size", control.custom_minimum_size
				)
			var base_size := int(control.get_meta("mobile_base_font_size"))
			var mobile_font_size := maxi(
				1, base_size + (2 if mobile else 0)
			)
			control.set_meta("mobile_applied_font_size", mobile_font_size)
			control.add_theme_font_size_override(
				"font_size", mobile_font_size
			)
			var base_minimum_size: Vector2 = control.get_meta(
				"mobile_base_minimum_size"
			)
			if mobile and control is Button:
				control.custom_minimum_size.y = maxf(
					control.custom_minimum_size.y, 48.0
				)
			elif not mobile:
				control.custom_minimum_size = base_minimum_size


func _layout_header(compact: bool) -> void:
	if _dashboard == null:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	var brand := _dashboard.find_child("HeaderBrand", true, false) as Label
	var settings := _dashboard.find_child(
		"HeaderSettingsButton", true, false) as Button
	var row := _dashboard.find_child("PilotHeaderRow", true, false) as HBoxContainer
	var currency_cards := _dashboard.find_child(
		"CurrencyCards", true, false) as HBoxContainer
	var profile_card := _dashboard.find_child(
		"PilotProfileCard", true, false) as PanelContainer
	if brand != null:
		brand.visible = not compact or viewport_width >= 380.0
		brand.text = "MT" if compact else "MT SPACE"
		brand.add_theme_font_size_override("font_size", 14 if compact else 22)
	if settings != null:
		settings.text = "" if compact else "SETTINGS"
		settings.icon = load("res://assets/icons/settings.svg") as Texture2D \
			if compact else null
		settings.add_theme_constant_override("icon_max_width", 18)
		settings.custom_minimum_size.x = 30.0 if compact else 0.0
	if row != null:
		row.add_theme_constant_override("separation", 4 if compact else 12)
	if profile_card != null:
		profile_card.custom_minimum_size.x = (
			116.0 if viewport_width < 380.0 else 132.0
		) if compact else 220.0
	var pilot_name := _dashboard.find_child("PilotName", true, false) as Label
	if pilot_name != null:
		var full_name := str(Net.get("player_name")).strip_edges()
		pilot_name.text = full_name.left(7) if compact and full_name.length() > 7 \
			else (full_name if not full_name.is_empty() else "PILOT")
	var avatar := _dashboard.find_child("PilotAvatar", true, false) as Control
	if avatar != null:
		avatar.custom_minimum_size = Vector2(34, 34) if compact else Vector2(44, 44)
	var level_label := _dashboard.find_child(
		"PilotLevelValue", true, false
	) as Label
	var xp_label := _dashboard.find_child(
		"PilotXPValue", true, false
	) as Label
	var xp_bar := _dashboard.find_child("PilotXPBar", true, false) as ProgressBar
	if level_label != null:
		level_label.visible = true
		level_label.custom_minimum_size.x = 42.0
	if xp_label != null:
		xp_label.visible = not compact
	if xp_bar != null:
		xp_bar.visible = not compact
	for currency in ["Cash", "Gem"]:
		var currency_card := _dashboard.find_child(
			"CurrencyCard_" + currency, true, false) as PanelContainer
		var plus := _dashboard.find_child(
			"CurrencyPlus_" + currency, true, false) as Label
		if currency_card != null:
			currency_card.custom_minimum_size.x = 62.0 if compact else 116.0
		if plus != null:
			plus.visible = not compact
	if currency_cards != null:
		currency_cards.add_theme_constant_override("separation", 4 if compact else 7)


func _set_hero_layout(narrow: bool) -> void:
	if _hero_content_row == null or _hero_content_stack == null \
		or _ship_stage_row == null or _ship_stats == null:
		return
	var hero_body := _hero_content_row.get_parent() as Container
	if hero_body == null:
		hero_body = _hero_content_stack.get_parent() as Container
	if hero_body == null:
		return
	if narrow and _ship_stage_row.get_parent() == _hero_content_row:
		_hero_content_row.remove_child(_ship_stage_row)
		_hero_content_row.remove_child(_ship_stats.get_parent().get_parent())
		_hero_content_stack.add_child(_ship_stage_row)
		_hero_content_stack.add_child(_ship_stats.get_parent().get_parent())
		_hero_content_row.visible = false
		_hero_content_stack.visible = true
	elif not narrow and _ship_stage_row.get_parent() == _hero_content_stack:
		_hero_content_stack.remove_child(_ship_stage_row)
		_hero_content_stack.remove_child(_ship_stats.get_parent().get_parent())
		_hero_content_row.add_child(_ship_stage_row)
		_hero_content_row.add_child(_ship_stats.get_parent().get_parent())
		_hero_content_stack.visible = false
		_hero_content_row.visible = true
	_ship_stage.custom_minimum_size = Vector2(
		0.0 if narrow else 340.0,
		210.0 if narrow else 250.0
	)
	_ship_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stats_panel := _ship_stats.get_parent().get_parent() as Control
	stats_panel.custom_minimum_size.x = 0.0 if narrow else 230.0
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL \
		if narrow else Control.SIZE_FILL
	_layout_ship_stage()


func _close_page_popup() -> void:
	_open_page("home")


func _open_page_popup() -> void:
	_page_popup.show()
	_dashboard.hide()
	_page_popup.modulate.a = 0.0
	call_deferred("_layout_dashboard")
	create_tween().tween_property(_page_popup, "modulate:a", 1.0, 0.18)


func _refresh_dashboard() -> void:
	if _dashboard == null:
		return
	var selection_changed := Game.selected_ship_id != _last_selected_ship_id
	if _ship_navigation_in_progress:
		_last_selected_ship_id = Game.selected_ship_id
	elif selection_changed:
		_last_selected_ship_id = Game.selected_ship_id
		var selected_index := _paint_index(Game.selected_ship_id)
		if selected_index >= 0:
			_preview_ship_index = selected_index
			_update_ship_preview(true, _ship_transition_direction)
	elif _ship_visual_tween == null or not _ship_visual_tween.is_running():
		_update_ship_preview(false)
	if _daily_missions_box != null:
		for child: Node in _daily_missions_box.get_children():
			child.queue_free()
		for mission: Dictionary in Game.get_daily_missions():
			_add_mission_row(_daily_missions_box, mission)
	_translate_subtree(_dashboard)
	_refresh_run_record()
	call_deferred("_refresh_header_values")


func _refresh_header_values() -> void:
	if _dashboard == null:
		return
	var pilot_name_label := _dashboard.find_child(
		"PilotName", true, false
	) as Label
	if pilot_name_label != null:
		var pilot_name := str(Net.player_name).strip_edges()
		if pilot_name.is_empty():
			pilot_name = "PILOT"
		pilot_name_label.text = pilot_name
		pilot_name_label.set_meta("locale_source_text", pilot_name)
	var initials_label := _dashboard.find_child(
		"PilotAvatar", true, false
	)
	if initials_label != null:
		var initials := initials_label.get_child(0) as Label \
			if initials_label.get_child_count() > 0 else null
		if initials != null:
			initials.text = _pilot_initials()
	var cash_label := _dashboard.find_child(
		"CurrencyValue_Cash", true, false) as Label
	if cash_label != null:
		cash_label.text = str(Game.pilot_cash)
		cash_label.visible = true
	var gem_label := _dashboard.find_child(
		"CurrencyValue_Gem", true, false) as Label
	if gem_label != null:
		gem_label.text = str(Game.pilot_tokens)
		gem_label.visible = true
	var level_label := _dashboard.find_child(
		"PilotLevelValue", true, false) as Label
	var xp_label := _dashboard.find_child("PilotXPValue", true, false) as Label
	var xp_bar := _dashboard.find_child("PilotXPBar", true, false) as ProgressBar
	if level_label != null:
		level_label.text = "LV %d" % Game.pilot_level
		level_label.visible = true
	if xp_label != null:
		xp_label.text = "%d / %d XP" % [
			Game.pilot_xp, Game.xp_needed_for(Game.pilot_level),
		]
	if xp_bar != null:
		xp_bar.max_value = maxf(1.0, float(Game.xp_needed_for(Game.pilot_level)))
		xp_bar.value = Game.pilot_xp


func _paint_index(ship_id: String) -> int:
	for index in PAINT_SCHEMES.size():
		if str(PAINT_SCHEMES[index]["id"]) == ship_id:
			return index
	return -1


func _sorted_ship_schemes() -> Array[Dictionary]:
	var ships: Array[Dictionary] = []
	for paint: Dictionary in PAINT_SCHEMES:
		ships.append(paint.duplicate(true))
	ships.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_id := str(first["id"])
		var second_id := str(second["id"])
		var first_rank := 0 if first_id == Game.selected_ship_id \
			else (1 if Game.is_ship_unlocked(first_id) else 2)
		var second_rank := 0 if second_id == Game.selected_ship_id \
			else (1 if Game.is_ship_unlocked(second_id) else 2)
		if first_rank != second_rank:
			return first_rank < second_rank
		return _paint_index(first_id) < _paint_index(second_id)
	)
	return ships


func _add_mission_row(parent: VBoxContainer, mission: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "Mission_" + str(mission["id"])
	row.custom_minimum_size.y = 68
	row.add_theme_constant_override("separation", 8)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.text = str(mission["title"])
	title.add_theme_font_size_override("font_size", 12)
	detail.add_child(title)
	var description := Label.new()
	description.text = str(mission.get("description", ""))
	description.add_theme_font_size_override("font_size", 10)
	description.add_theme_color_override("font_color", MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.clip_text = true
	detail.add_child(description)
	var progress := Label.new()
	progress.text = "%d / %d" % [
		int(mission["progress"]), int(mission["target"])
	]
	progress.add_theme_font_size_override("font_size", 10)
	progress.add_theme_color_override("font_color", MUTED)
	detail.add_child(progress)
	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size.y = 4
	progress_bar.max_value = int(mission["target"])
	progress_bar.value = int(mission["progress"])
	progress_bar.show_percentage = false
	detail.add_child(progress_bar)
	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 4)
	var reward := Label.new()
	reward.text = "REWARD"
	reward.add_theme_font_size_override("font_size", 9)
	reward.add_theme_color_override("font_color", MUTED)
	reward_row.add_child(reward)
	var reward_amount := Label.new()
	reward_amount.text = "+%d" % int(mission["reward"])
	reward_amount.add_theme_font_size_override("font_size", 9)
	reward_amount.add_theme_color_override("font_color", MUTED)
	reward_row.add_child(reward_amount)
	var token_unit := Label.new()
	token_unit.text = "GEMS"
	token_unit.add_theme_font_size_override("font_size", 9)
	token_unit.add_theme_color_override("font_color", MUTED)
	reward_row.add_child(token_unit)
	detail.add_child(reward_row)
	row.add_child(detail)
	if bool(mission["claimed"]):
		var claimed := Label.new()
		claimed.text = "CLAIMED"
		claimed.add_theme_font_size_override("font_size", 9)
		claimed.add_theme_color_override("font_color", MUTED)
		row.add_child(claimed)
	elif int(mission["progress"]) >= int(mission["target"]):
		var claim := _make_button("CLAIM", "mission_claim")
		claim.custom_minimum_size.x = 78
		claim.pressed.connect(_claim_mission.bind(str(mission["id"])))
		row.add_child(claim)
	else:
		var in_progress := Label.new()
		in_progress.text = "IN PROGRESS"
		in_progress.add_theme_font_size_override("font_size", 9)
		in_progress.add_theme_color_override("font_color", MUTED)
		row.add_child(in_progress)
	parent.add_child(row)


func _select_ship(ship_id: String) -> void:
	if not Game.is_ship_unlocked(ship_id):
		_show_ship_detail(ship_id)
		return
	if ship_id == Game.selected_ship_id:
		var selected_index := _paint_index(ship_id)
		if selected_index >= 0:
			_preview_ship_index = selected_index
			_update_ship_preview(false)
		return
	if not Game.set_selected_ship(ship_id):
		return
	_sfx()
	if _current_page == "ships":
		_open_page("ships")


func _cycle_ship(direction: int) -> void:
	if PAINT_SCHEMES.size() <= 1:
		return
	var travel_direction := signi(direction)
	if travel_direction == 0:
		return
	var next_index := posmod(
		_preview_ship_index + travel_direction, PAINT_SCHEMES.size()
	)
	var paint_id := str(PAINT_SCHEMES[next_index]["id"])
	_ship_transition_direction = travel_direction
	if Game.is_ship_unlocked(paint_id) and paint_id != Game.selected_ship_id:
		_ship_navigation_in_progress = true
		var selection_saved := Game.set_selected_ship(paint_id)
		_ship_navigation_in_progress = false
		if not selection_saved:
			return
	_preview_ship_index = next_index
	_update_ship_preview(true, travel_direction)
	_sfx()


func _on_ship_stage_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_ship_swipe_start = event.position
			_ship_gesture_active = true
			_ship_gesture_triggered = false
		elif _ship_gesture_active:
			var travel: float = event.position.x - _ship_swipe_start.x
			_finish_ship_gesture(travel)
	elif event is InputEventScreenDrag and _ship_gesture_active:
		var travel: float = event.position.x - _ship_swipe_start.x
		if absf(travel) >= 40.0 and not _ship_gesture_triggered:
			_ship_gesture_triggered = true
			_finish_ship_gesture(travel)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_ship_swipe_start = event.position
			_ship_gesture_active = true
			_ship_gesture_triggered = false
		elif _ship_gesture_active:
			var travel: float = event.position.x - _ship_swipe_start.x
			_finish_ship_gesture(travel)


func _finish_ship_gesture(travel: float) -> void:
	_ship_gesture_active = false
	_ship_gesture_triggered = true
	_ship_swipe_start = Vector2.ZERO
	if absf(travel) >= 40.0:
		_cycle_ship(-1 if travel > 0.0 else 1)
	else:
		_select_ship(str(PAINT_SCHEMES[_preview_ship_index]["id"]))


func _update_ship_preview(animate: bool, direction: int = 1) -> void:
	if _ship_preview == null or _ship_stage == null \
		or PAINT_SCHEMES.is_empty():
		return
	if _ship_visual_tween != null and _ship_visual_tween.is_running():
		_ship_visual_tween.kill()
	if is_instance_valid(_ship_transition_ghost):
		_ship_transition_ghost.queue_free()
		_ship_transition_ghost = null
	if animate:
		_ship_transition_ghost = _ship_preview.duplicate() as TextureRect
		_ship_transition_ghost.name = "ShipTransitionGhost"
		_ship_transition_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ship_transition_ghost.z_index = _ship_preview.z_index + 1
		_ship_stage.add_child(_ship_transition_ghost)
	_preview_ship_index = clampi(_preview_ship_index, 0, PAINT_SCHEMES.size() - 1)
	var paint: Dictionary = PAINT_SCHEMES[_preview_ship_index]
	var paint_id := str(paint["id"])
	var unlocked := Game.is_ship_unlocked(paint_id)
	var selected := Game.selected_ship_id == paint_id
	var paint_name := str(paint["name"])
	_ship_preview.modulate = Game.get_ship_tint(paint_id)
	var locked_overlay := _ship_stage.get_node("LockedOverlay") as ColorRect
	var lock_center := locked_overlay.get_node("LockCenter") as Control
	var target_locked := not unlocked
	if not animate:
		locked_overlay.visible = target_locked
		locked_overlay.color.a = 0.64
		lock_center.modulate.a = 1.0 if target_locked else 0.0
	elif target_locked and not locked_overlay.visible:
		locked_overlay.color.a = 0.0
		lock_center.modulate.a = 0.0
		lock_center.scale = Vector2.ONE * 0.82
	var paint_label := _ship_stage.get_node_or_null("ShipPaintLabel") as Label
	if paint_label != null:
		paint_label.text = "%s  /  %s" % [
			paint_name,
			"EQUIPPED" if selected else ("UNLOCKED" if unlocked else "LOCKED"),
		]
	_ship_stage.backdrop_style.border_color = Color(paint["color"], 0.38)
	_ship_stage.queue_redraw()
	_refresh_ship_stats(paint_id)
	if animate:
		var travel := _ship_stage.size.x + _ship_preview.size.x
		var slide_direction := float(signi(direction))
		var old_position := _ship_transition_ghost.position
		var old_rotation := _ship_transition_ghost.rotation
		var old_scale := _ship_transition_ghost.scale
		var old_alpha := _ship_transition_ghost.modulate.a
		_ship_transition_ghost.position = old_position
		_ship_transition_ghost.rotation = old_rotation
		_ship_transition_ghost.scale = old_scale
		_ship_transition_ghost.modulate.a = old_alpha
		_ship_transition_progress = 0.0
		_ship_transition_slide_direction = slide_direction
		_apply_ship_transition(0.0, slide_direction)
		locked_overlay.visible = locked_overlay.visible or target_locked
		_ship_visual_tween = create_tween()
		_ship_visual_tween.set_trans(Tween.TRANS_CUBIC)
		_ship_visual_tween.set_parallel(true)
		_ship_visual_tween.tween_method(
			_apply_ship_transition.bind(slide_direction), 0.0, 1.0, 0.42
		).set_ease(Tween.EASE_OUT)
		_ship_visual_tween.tween_property(
			locked_overlay, "color:a", 0.64 if target_locked else 0.0, 0.34
		).set_ease(Tween.EASE_IN_OUT)
		_ship_visual_tween.tween_property(
			lock_center, "modulate:a", 1.0 if target_locked else 0.0, 0.30
		).set_ease(Tween.EASE_IN_OUT)
		if target_locked:
			_ship_visual_tween.tween_property(
				lock_center, "scale", Vector2.ONE, 0.30
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if _ship_transition_sweep != null:
			_ship_transition_sweep.position = Vector2(
				-_ship_transition_sweep.size.x if direction > 0 else _ship_stage.size.x,
				0.0
			)
			_ship_transition_sweep.color.a = 0.0
			_ship_visual_tween.tween_property(
				_ship_transition_sweep, "position:x",
				_ship_stage.size.x if direction > 0 else -_ship_transition_sweep.size.x,
				0.40
			).set_ease(Tween.EASE_IN_OUT)
			_ship_visual_tween.tween_property(
				_ship_transition_sweep, "color:a", 0.28, 0.12
			).set_ease(Tween.EASE_OUT)
			_ship_visual_tween.chain().tween_property(
				_ship_transition_sweep, "color:a", 0.0, 0.18
			)
		_ship_visual_tween.chain().tween_callback(
			_finish_ship_transition.bind(target_locked)
		)
	elif _ship_visual_tween == null or not _ship_visual_tween.is_running():
		_ship_preview.position = _ship_preview_base_position
		_ship_preview.rotation = 0.0
		_ship_preview.scale = Vector2.ONE
		_ship_preview.modulate.a = 1.0


func _apply_ship_transition(progress: float, slide_direction: float) -> void:
	_ship_transition_progress = clampf(progress, 0.0, 1.0)
	_ship_transition_slide_direction = slide_direction
	if _ship_preview == null or _ship_stage == null:
		return
	var travel := _ship_stage.size.x + _ship_preview.size.x
	var remaining := 1.0 - _ship_transition_progress
	_ship_preview.position = _ship_preview_base_position \
		+ Vector2(slide_direction * travel * remaining, 0.0)
	_ship_preview.rotation = -slide_direction * 0.055 * remaining
	_ship_preview.scale = Vector2.ONE * lerpf(1.0, 0.9, remaining)
	_ship_preview.modulate.a = lerpf(1.0, 0.25, remaining)
	if is_instance_valid(_ship_transition_ghost):
		_ship_transition_ghost.position = _ship_preview_base_position \
			- Vector2(slide_direction * travel * _ship_transition_progress, 0.0)
		_ship_transition_ghost.rotation = slide_direction * 0.055 \
			* _ship_transition_progress
		_ship_transition_ghost.scale = Vector2.ONE \
			* lerpf(1.0, 0.94, _ship_transition_progress)
		_ship_transition_ghost.modulate.a = 1.0 - _ship_transition_progress


func _claim_mission(mission_id: String) -> void:
	if Game.claim_daily_mission(mission_id):
		_sfx()
		if _page_popup.visible and _page_popup_title.text == "MISSIONS":
			_open_page("missions")


func _start_solo_run() -> void:
	_sfx()
	Net.leave()
	if Game.has_method("reset_run"):
		Game.reset_run()
	Game.test_mode = false
	Game.test_data = {}
	get_tree().change_scene_to_file(GAME_SCENE)


func _start_selected_mode() -> void:
	match _selected_play_mode:
		"coop":
			_start_coop_run()
		"test":
			game_mode = "test"
			_start_test_run()
		_:
			_start_solo_run()


func _start_coop_run() -> void:
	_sfx()
	game_mode = "wave"
	_on_play_pressed()


func _open_mode_selector() -> void:
	_sfx()
	_show_mode_selector()


func _show_mode_selector() -> void:
	_current_page = "mode"
	_set_navigation_page("home")
	_page_popup_title.text = "CHOOSE MODE"
	for child: Node in _page_popup_content.get_children():
		child.queue_free()
	_add_page_text("Choose what Play Now will launch.")
	_add_mode_option(
		"SINGLE PLAYER",
		"Start a solo wave-survival run immediately.",
		"solo"
	)
	_add_mode_option(
		"ONLINE CO-OP",
		"Open the room browser to host or join a multiplayer run.",
		"coop"
	)
	_add_mode_option(
		"TEST MODE",
		"Start a sandbox with no normal waves and manual enemy controls.",
		"test"
	)
	_translate_subtree(_page_popup)
	_set_page_visibility(true)
	_layout_dashboard()
	_open_page_popup()


func _add_mode_option(title: String, description: String, mode_id: String) -> void:
	var option := _new_panel()
	option.name = "ModeOption_" + mode_id
	option.custom_minimum_size.y = 104
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	option.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	var heading := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(heading)
	heading.add_child(name_label)
	var state := Label.new()
	state.text = "SELECTED" if mode_id == _selected_play_mode else "AVAILABLE"
	state.add_theme_font_size_override("font_size", 9)
	state.add_theme_color_override(
		"font_color", Color(0.97, 0.78, 0.38)
		if mode_id == _selected_play_mode else CYAN
	)
	heading.add_child(state)
	var description_label := Label.new()
	description_label.text = description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_color_override("font_color", MUTED)
	content.add_child(description_label)
	var choose := _make_button(
		"CURRENT MODE" if mode_id == _selected_play_mode else "SELECT MODE",
		"mode_option"
	)
	choose.name = "SelectMode_" + mode_id
	choose.custom_minimum_size.y = 42
	choose.disabled = mode_id == _selected_play_mode
	choose.pressed.connect(_select_play_mode.bind(mode_id))
	content.add_child(choose)
	_page_popup_content.add_child(option)


func _select_play_mode(mode_id: String) -> void:
	if mode_id != "solo" and mode_id != "coop" and mode_id != "test":
		return
	_selected_play_mode = mode_id
	match mode_id:
		"solo":
			_mode_summary.text = "SOLO  /  WAVE SURVIVAL"
		"coop":
			_mode_summary.text = "ONLINE CO-OP  /  ROOM BROWSER"
		"test":
			_mode_summary.text = "TEST MODE  /  SANDBOX"
	_mode_summary.set_meta("locale_source_text", _mode_summary.text)
	_sfx()
	_translate_subtree(_dashboard)
	_show_mode_selector()


func _open_page(page: String) -> void:
	if page == "equipment":
		page = "ships"
	if _run_record_panel != null:
		_run_record_panel.hide()
	if is_instance_valid(_loadout_item_popup):
		_loadout_item_popup.hide()
	_current_page = page
	_set_navigation_page(page)
	_shop_ship_grid = null
	_shop_ship_cards.clear()
	_shop_search = null
	_store_search = null
	_store_items_grid = null
	_ship_fleet_grid = null
	_loadout_search = null
	_loadout_grid = null
	_loadout_items_scroll = null
	_loadout_count = null
	_loadout_hint = null
	_loadout_inventory_title = null
	_loadout_page_root = null
	_loadout_stage = null
	_loadout_category_group = null
	_loadout_ship_selector = null
	_fleet_active_horizontal = null
	_fleet_active_vertical = null
	_fleet_active_art_panel = null
	_fleet_active_stats_panel = null
	_page_popup_title.text = page.to_upper()
	for child: Node in _page_popup_content.get_children():
		child.queue_free()
	match page:
		"home":
			_set_page_visibility(false)
			return
		"ships":
			_loadout_category = "overview"
			_page_popup_content.add_child(_build_ship_loadout_page())
		"missions":
			_add_page_text("DAILY MISSIONS / Progress and rewards are saved with your pilot profile.")
			for mission: Dictionary in Game.get_daily_missions():
				_add_mission_row(_page_popup_content, mission)
		"achievements":
			_refresh_run_record()
			_add_page_text("PILOT CAREER / Your latest and best run records.")
			_add_page_text(_run_record_label.text if _run_record_label != null
				else "NO RUNS RECORDED")
		"upgrades":
			_add_page_text("PERMANENT SHIP SYSTEMS / Upgrade levels apply to the pilot's ship in future runs.")
			var upgrade_layout: BoxContainer = HBoxContainer.new() \
				if get_viewport().get_visible_rect().size.x >= 940.0 \
				else VBoxContainer.new()
			upgrade_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			upgrade_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
			upgrade_layout.add_theme_constant_override("separation", 12)
			var showcase := _build_ship_showcase()
			showcase.custom_minimum_size = Vector2(
				260.0 if upgrade_layout is HBoxContainer else 0.0, 210.0
			)
			upgrade_layout.add_child(showcase)
			var upgrade_list := VBoxContainer.new()
			upgrade_list.name = "PilotUpgradeList"
			upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			upgrade_list.add_theme_constant_override("separation", 8)
			for definition: Dictionary in Game.get_pilot_upgrade_definitions():
				_add_pilot_upgrade_row(definition, upgrade_list)
			upgrade_layout.add_child(upgrade_list)
			_page_popup_content.add_child(upgrade_layout)
		"shop":
			var balance := HBoxContainer.new()
			var balance_title := Label.new()
			balance_title.text = "GEMS"
			balance.add_child(balance_title)
			var balance_icon := TextureRect.new()
			balance_icon.texture = load("res://assets/icons/gem.svg") as Texture2D
			balance_icon.custom_minimum_size = Vector2(18, 18)
			balance_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			balance_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			balance.add_child(balance_icon)
			var balance_value := Label.new()
			balance_value.text = str(Game.pilot_tokens)
			balance_value.add_theme_color_override("font_color", CYAN)
			balance.add_child(balance_value)
			_page_popup_content.add_child(balance)
			_add_page_text("SHIP UNLOCKS / Unlock fighters with gems or earn them by reaching their best-wave requirement.")
			_shop_search = LineEdit.new()
			_shop_search.name = "ShopShipSearch"
			_shop_search.placeholder_text = "SEARCH FIGHTERS"
			_shop_search.set_meta("locale_source_placeholder", "SEARCH FIGHTERS")
			_shop_search.clear_button_enabled = true
			_shop_search.custom_minimum_size.y = 40
			_shop_search.text_changed.connect(_filter_shop_ships)
			_page_popup_content.add_child(_shop_search)
			_shop_ship_grid = GridContainer.new()
			_shop_ship_grid.name = "ShopShipGrid"
			_shop_ship_grid.columns = 1 \
				if get_viewport().get_visible_rect().size.x < 700.0 else 2
			_shop_ship_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_shop_ship_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_shop_ship_grid.add_theme_constant_override("h_separation", 10)
			_shop_ship_grid.add_theme_constant_override("v_separation", 10)
			_page_popup_content.add_child(_shop_ship_grid)
			var ship_offers := 0
			for paint: Dictionary in PAINT_SCHEMES:
				var ship_id := str(paint["id"])
				if Game.is_ship_unlocked(ship_id):
					continue
				_add_store_ship(paint)
				ship_offers += 1
			if ship_offers == 0:
				_add_page_text(
					"PHOENIX IS YOUR ACTIVE SHIP. NO OTHER SHIPS ARE AVAILABLE."
				)
		"store":
			_build_store_page()
		"settings":
			_add_settings_controls()
		_:
			_add_page_text("No active limited-time event is running. Daily missions are available in Pilot Services.")
	if page == "shop":
		var current_stats: Dictionary = Game.get_effective_ship_combat_stats()
		_add_page_text("%s: %s   /   %s %.2f×   /   %s %d   /   %s %d" % [
			_translate("ACTIVE SHIP"),
			Game.selected_ship_id.to_upper(),
			_translate("DMG"),
			float(current_stats["damage_multiplier"]),
			_translate("SPEED"),
			roundi(float(current_stats["max_speed"])),
			_translate("HULL"),
			int(current_stats["max_hp"]),
		])
	_translate_subtree(_page_popup)
	_set_page_visibility(true)
	_open_page_popup()


func _set_navigation_page(page: String) -> void:
	for node: Node in _dashboard.find_children("*", "Button", true, false):
		var button := node as Button
		if button.has_meta("lobby_page"):
			button.button_pressed = str(button.get_meta("lobby_page")) == page


func _set_page_visibility(show_page: bool) -> void:
	if _page_popup == null:
		return
	_page_popup.visible = show_page
	_dashboard.visible = not show_page
	_main_columns.visible = not show_page
	_main_columns_mobile.visible = not show_page


func _add_page_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(0.80, 0.88, 0.96))
	_page_popup_content.add_child(label)


func _build_store_page() -> void:
	var header := HBoxContainer.new()
	header.name = "StoreBalance"
	header.add_theme_constant_override("separation", 6)
	var heading := Label.new()
	heading.text = "CREDITS"
	header.add_child(heading)
	var balance_icon := Label.new()
	balance_icon.text = "$"
	balance_icon.add_theme_color_override("font_color", CYAN)
	header.add_child(balance_icon)
	var amount := Label.new()
	amount.name = "StoreCashValue"
	amount.text = str(Game.pilot_cash)
	amount.add_theme_color_override("font_color", CYAN)
	header.add_child(amount)
	_page_popup_content.add_child(header)
	_add_page_text("BUY EQUIPMENT WITH CREDITS / Owned items can be equipped from Equipment.")

	var store_layout: BoxContainer = HBoxContainer.new() \
		if get_viewport().get_visible_rect().size.x >= 900.0 \
		else VBoxContainer.new()
	store_layout.name = "StoreLayout"
	store_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	store_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	store_layout.add_theme_constant_override("separation", 12)
	_page_popup_content.add_child(store_layout)

	var category_panel := _new_panel()
	category_panel.name = "StoreCategories"
	category_panel.custom_minimum_size.x = 170.0 if store_layout is HBoxContainer else 0.0
	store_layout.add_child(category_panel)
	var category_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		category_margin.add_theme_constant_override("margin_" + side, 10)
	category_panel.add_child(category_margin)
	var category_content := VBoxContainer.new()
	category_content.add_theme_constant_override("separation", 8)
	category_margin.add_child(category_content)
	var category_list: Control = GridContainer.new() \
		if store_layout is VBoxContainer else VBoxContainer.new()
	if category_list is GridContainer:
		(category_list as GridContainer).columns = 2
	category_list.add_theme_constant_override("separation", 6)
	category_content.add_child(category_list)
	var category_title := Label.new()
	category_title.text = "CATEGORIES"
	category_title.add_theme_color_override("font_color", CYAN)
	category_content.add_child(category_title)
	category_content.move_child(category_title, 0)
	_store_category_group = ButtonGroup.new()
	var categories := [
		["ALL ITEMS", "all"], ["ARMOR", "armor"],
		["ATTACK DRONES", "attack"], ["REPAIR", "repair"],
		["DEFENSE", "defense"], ["SUPPORT", "support"],
	]
	for entry: Array in categories:
		var category_button := _make_button(
			str(entry[0]), "store_category"
		)
		category_button.name = "StoreCategory_" + str(entry[1])
		category_button.toggle_mode = true
		category_button.button_group = _store_category_group
		category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_button.button_pressed = str(entry[1]) == _store_category
		category_button.pressed.connect(
			_select_store_category.bind(str(entry[1]))
		)
		category_list.add_child(category_button)

	var item_column := VBoxContainer.new()
	item_column.name = "StoreItemColumn"
	item_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_column.add_theme_constant_override("separation", 8)
	store_layout.add_child(item_column)
	_store_search = LineEdit.new()
	_store_search.name = "StoreSearch"
	_store_search.placeholder_text = "SEARCH EQUIPMENT"
	_store_search.clear_button_enabled = true
	_store_search.custom_minimum_size.y = 38
	_store_search.text_changed.connect(_refresh_store_items)
	item_column.add_child(_store_search)
	_store_items_grid = GridContainer.new()
	_store_items_grid.name = "StoreItemsGrid"
	_store_items_grid.columns = 1 \
		if get_viewport().get_visible_rect().size.x < 700.0 else 2
	_store_items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_store_items_grid.add_theme_constant_override("h_separation", 10)
	_store_items_grid.add_theme_constant_override("v_separation", 10)
	item_column.add_child(_store_items_grid)
	_refresh_store_items()


func _select_store_category(category: String) -> void:
	_store_category = category
	_refresh_store_items()


func _refresh_store_items(_query: String = "") -> void:
	if _store_items_grid == null or not is_instance_valid(_store_items_grid):
		return
	for child in _store_items_grid.get_children():
		_store_items_grid.remove_child(child)
		child.free()
	var search := _store_search.text.strip_edges().to_lower() \
		if _store_search != null else ""
	var count := 0
	for item: Dictionary in Game.get_store_items():
		var item_id := str(item["id"])
		var searchable := ("%s %s %s" % [
			item["name"], item["description"], item["category"],
		]).to_lower()
		if _store_category != "all" \
				and str(item["category"]) != _store_category:
			continue
		if not search.is_empty() and not searchable.contains(search):
			continue
		_add_store_item_card(item)
		count += 1
	if count == 0:
		var empty := Label.new()
		empty.text = "NO MATCHING EQUIPMENT"
		empty.add_theme_color_override("font_color", MUTED)
		_store_items_grid.add_child(empty)
	_translate_subtree(_store_items_grid)


func _add_store_item_card(item: Dictionary) -> void:
	var item_id := str(item["id"])
	var item_slot := str(item["slot"])
	var owned := Game.owns_store_item(item_id)
	var equipped_id := Game.get_equipped_store_item(item_slot)
	var equipped := equipped_id == item_id
	var card := _new_panel()
	card.name = "StoreItem_" + item_id
	card.custom_minimum_size = Vector2(210, 218)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 9)
	content.add_child(top)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/%s.svg" % str(item["icon"])) \
		as Texture2D
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(icon)
	var name_label := Label.new()
	name_label.text = str(item["name"])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", Color.WHITE)
	top.add_child(name_label)
	var description := Label.new()
	description.text = str(item["description"])
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", MUTED)
	content.add_child(description)
	var effect := Label.new()
	effect.text = str(item["effect"])
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_font_size_override("font_size", 10)
	effect.add_theme_color_override("font_color", Color(0.54, 0.85, 0.91))
	content.add_child(effect)
	var action_text := "EQUIPPED" if equipped else (
		"OWNED" if owned else "BUY  %d CREDITS" % int(item["price"])
	)
	var action := _make_button(action_text, "store_purchase")
	action.name = "StoreAction_" + item_id
	action.custom_minimum_size.y = 38
	action.disabled = owned or Game.pilot_cash < int(item["price"])
	if not owned:
		action.pressed.connect(_store_item_action.bind(item_id))
	content.add_child(action)
	_store_items_grid.add_child(card)


func _store_item_action(item_id: String) -> void:
	var success := Game.purchase_store_item(item_id)
	if success:
		_sfx()
	else:
		push_warning("Store purchase failed for item: %s" % item_id)
	_open_page("store")


func _build_loadout_ship_panel() -> Control:
	var panel := _new_panel()
	panel.name = "LoadoutShipPanel"
	panel.custom_minimum_size = Vector2(260, 205)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	var ship_selector := OptionButton.new()
	ship_selector.name = "LoadoutShipSelector"
	ship_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_loadout_ship_selector(ship_selector)
	var selected_index := 0
	for paint: Dictionary in PAINT_SCHEMES:
		var ship_id := str(paint["id"])
		if not Game.is_ship_unlocked(ship_id):
			continue
		ship_selector.add_item(str(paint["name"]))
		ship_selector.set_item_metadata(ship_selector.item_count - 1, ship_id)
		if ship_id == Game.selected_ship_id:
			selected_index = ship_selector.item_count - 1
	ship_selector.select(selected_index)
	ship_selector.item_selected.connect(_on_loadout_ship_selected)
	_loadout_ship_selector = ship_selector
	content.add_child(ship_selector)
	var image_holder := CenterContainer.new()
	image_holder.custom_minimum_size = Vector2(0, 112)
	image_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(image_holder)
	var image := TextureRect.new()
	image.name = "LoadoutShipImage"
	image.texture = PLAYER_ICON
	image.custom_minimum_size = Vector2(220, 132)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = Game.get_ship_tint(Game.selected_ship_id)
	image_holder.add_child(image)
	var stats := Game.get_effective_ship_combat_stats(Game.selected_ship_id)
	var stats_label := Label.new()
	stats_label.name = "LoadoutShipStats"
	stats_label.text = "DMG %.2f×   /   SPEED %d   /   HULL %d" % [
		float(stats["damage_multiplier"]),
		roundi(float(stats["max_speed"])),
		int(stats["max_hp"]),
	]
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_color_override("font_color", MUTED)
	content.add_child(stats_label)
	return panel


func _build_ship_loadout_page() -> Control:
	var root := HBoxContainer.new()
	root.name = "ShipLoadoutPage"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	_loadout_page_root = root

	var sidebar := _new_panel()
	sidebar.name = "LoadoutCategories"
	sidebar.custom_minimum_size.x = 184
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sidebar)
	var sidebar_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		sidebar_margin.add_theme_constant_override("margin_" + side, 10)
	sidebar.add_child(sidebar_margin)
	var sidebar_layout := VBoxContainer.new()
	sidebar_layout.add_theme_constant_override("separation", 7)
	sidebar_margin.add_child(sidebar_layout)
	var sidebar_title := Label.new()
	sidebar_title.text = "LOADOUT CATEGORIES"
	sidebar_title.add_theme_font_size_override("font_size", 11)
	sidebar_title.add_theme_color_override("font_color", CYAN)
	sidebar_layout.add_child(sidebar_title)

	_loadout_category_group = ButtonGroup.new()
	_loadout_category_group.allow_unpress = false
	var categories := [
		["OVERVIEW", "overview", "res://assets/icons/backpack.svg"],
		["ARMOR", "armor", "res://assets/icons/store_armor.svg"],
		["DRONES", "drone", "res://assets/icons/store_defense_drone.svg"],
		["WEAPONS", "weapon", "res://assets/icons/store_attack_drone.svg"],
		["SUPPORT", "support", "res://assets/icons/store_reactor.svg"],
	]
	for category: Array in categories:
		var category_button := _make_button(
			str(category[0]), "loadout_category"
		)
		category_button.name = "LoadoutCategory_" + str(category[1])
		category_button.icon = load(str(category[2])) as Texture2D
		category_button.add_theme_constant_override("icon_max_width", 22)
		category_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		category_button.toggle_mode = true
		category_button.button_group = _loadout_category_group
		category_button.button_pressed = str(category[1]) == _loadout_category
		category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_button.custom_minimum_size.y = 42
		category_button.pressed.connect(
			_select_loadout_category.bind(str(category[1]))
		)
		sidebar_layout.add_child(category_button)
	var sidebar_spacer := Control.new()
	sidebar_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_layout.add_child(sidebar_spacer)
	var owned_count := 0
	for item: Dictionary in Game.get_store_items():
		if Game.owns_store_item(str(item["id"])):
			owned_count += 1
	var owned_summary := Label.new()
	owned_summary.name = "LoadoutOwnedSummary"
	owned_summary.text = "%d  /  %d OWNED" % [
		owned_count, Game.get_store_items().size(),
	]
	owned_summary.add_theme_font_size_override("font_size", 10)
	owned_summary.add_theme_color_override("font_color", MUTED)
	owned_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sidebar_layout.add_child(owned_summary)

	var content := VBoxContainer.new()
	content.name = "LoadoutMainContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	root.add_child(content)

	var stage_panel := _new_panel()
	stage_panel.name = "LoadoutShipStage"
	stage_panel.custom_minimum_size.y = 218
	stage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(stage_panel)
	var stage_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		stage_margin.add_theme_constant_override("margin_" + side, 10)
	stage_panel.add_child(stage_margin)
	_loadout_stage = HBoxContainer.new()
	_loadout_stage.add_theme_constant_override("separation", 10)
	stage_margin.add_child(_loadout_stage)
	_loadout_stage.add_child(_build_equipment_slot_card(
		"armor", "ARMOR", "store_armor"
	))
	_loadout_stage.add_child(_build_loadout_ship_panel())
	var drone_support := VBoxContainer.new()
	drone_support.name = "LoadoutRightSlots"
	drone_support.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drone_support.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drone_support.add_theme_constant_override("separation", 8)
	_loadout_stage.add_child(drone_support)
	drone_support.add_child(_build_equipment_slot_card(
		"drone", "DRONE", "store_defense_drone"
	))
	drone_support.add_child(_build_equipment_slot_card(
		"support", "SUPPORT", "store_reactor"
	))

	var inventory := _new_panel()
	inventory.name = "LoadoutInventory"
	inventory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(inventory)
	var inventory_margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		inventory_margin.add_theme_constant_override("margin_" + side, 12)
	inventory.add_child(inventory_margin)
	var inventory_layout := VBoxContainer.new()
	inventory_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_layout.add_theme_constant_override("separation", 7)
	inventory_margin.add_child(inventory_layout)
	var inventory_header := HBoxContainer.new()
	inventory_header.add_theme_constant_override("separation", 10)
	inventory_layout.add_child(inventory_header)
	_loadout_inventory_title = Label.new()
	_loadout_inventory_title.name = "LoadoutInventoryTitle"
	_loadout_inventory_title.add_theme_font_size_override("font_size", 15)
	_loadout_inventory_title.add_theme_color_override("font_color", Color.WHITE)
	_loadout_inventory_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_header.add_child(_loadout_inventory_title)
	_loadout_count = Label.new()
	_loadout_count.name = "LoadoutItemCount"
	_loadout_count.add_theme_font_size_override("font_size", 10)
	_loadout_count.add_theme_color_override("font_color", MUTED)
	_loadout_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inventory_header.add_child(_loadout_count)
	_loadout_search = LineEdit.new()
	_loadout_search.name = "LoadoutSearch"
	_loadout_search.placeholder_text = "SEARCH EQUIPMENT"
	_loadout_search.set_meta("locale_source_placeholder", "SEARCH EQUIPMENT")
	_loadout_search.custom_minimum_size = Vector2(220, 36)
	_loadout_search.clear_button_enabled = true
	_loadout_search.text_changed.connect(_refresh_loadout_items)
	inventory_header.add_child(_loadout_search)
	_loadout_hint = Label.new()
	_loadout_hint.name = "LoadoutHint"
	_loadout_hint.text = "SELECT A SLOT OR BROWSE YOUR EQUIPMENT"
	_loadout_hint.add_theme_font_size_override("font_size", 10)
	_loadout_hint.add_theme_color_override("font_color", MUTED)
	inventory_layout.add_child(_loadout_hint)
	_loadout_items_scroll = TouchScrollContainer.new()
	_loadout_items_scroll.name = "LoadoutItemsScroll"
	_loadout_items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loadout_items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_loadout_items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_loadout_items_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inventory_layout.add_child(_loadout_items_scroll)
	_loadout_grid = GridContainer.new()
	_loadout_grid.name = "LoadoutItemsGrid"
	_loadout_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loadout_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_loadout_grid.add_theme_constant_override("h_separation", 9)
	_loadout_grid.add_theme_constant_override("v_separation", 9)
	_loadout_items_scroll.add_child(_loadout_grid)
	_refresh_loadout_items()
	_translate_subtree(root)
	return root


func _build_equipment_slot_card(slot: String, title: String, icon_name: String) -> Control:
	var panel := _new_panel()
	panel.name = "EquipmentSlot_" + slot
	panel.custom_minimum_size = Vector2(150, 88)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var selected_style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if _equipment_slot_id == slot:
		selected_style.bg_color = Color(0.065, 0.145, 0.205, 0.98)
		selected_style.border_color = CYAN
		selected_style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", selected_style)
	var button := Button.new()
	button.name = "EquipmentSlotButton_" + slot
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_show_equipment_slot.bind(slot))
	button.tooltip_text = title
	panel.add_child(button)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	button.add_child(margin)
	var content := HBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var equipped_id := Game.get_equipped_store_item(slot)
	var equipped_item := Game.get_store_item(equipped_id) if not equipped_id.is_empty() else {}
	var displayed_icon := str(equipped_item.get("icon", icon_name))
	icon.texture = load("res://assets/icons/%s.svg" % displayed_icon) as Texture2D
	content.add_child(icon)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 3)
	content.add_child(details)
	var slot_title := Label.new()
	slot_title.text = title
	slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	slot_title.add_theme_color_override("font_color", CYAN)
	details.add_child(slot_title)
	var item_name := Label.new()
	item_name.name = "EquipmentSlotItem_" + slot
	item_name.text = str(equipped_item.get("name", "+"))
	item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_name.clip_text = true
	item_name.add_theme_color_override("font_color", Color.WHITE)
	details.add_child(item_name)
	return panel


func _show_equipment_slot(slot: String) -> void:
	_equipment_slot_id = slot
	_loadout_category = "overview"
	if _loadout_hint != null:
		_loadout_hint.text = _translate(
			"SELECT AN ITEM TO EQUIP IN THE %s SLOT" % slot.to_upper()
		)
	_refresh_loadout_slots()
	_refresh_loadout_items()


func _select_loadout_category(category: String) -> void:
	_loadout_category = category
	_equipment_slot_id = ""
	if _loadout_hint != null:
		_loadout_hint.text = _translate("SELECT A SLOT OR BROWSE YOUR EQUIPMENT")
	_refresh_loadout_slots()
	_refresh_loadout_items()


func _on_loadout_ship_selected(index: int) -> void:
	if _loadout_ship_selector == null or index < 0 \
			or index >= _loadout_ship_selector.item_count:
		return
	var ship_id := str(_loadout_ship_selector.get_item_metadata(index))
	if ship_id == Game.selected_ship_id:
		return
	if not Game.set_selected_ship(ship_id):
		push_error("Unable to select ship for loadout: %s" % ship_id)
		return
	_equipment_slot_id = ""
	_refresh_loadout_ship_details()
	_refresh_loadout_slots()
	_refresh_loadout_items()
	_sfx()


func _refresh_loadout_ship_details() -> void:
	var image := _loadout_page_root.find_child(
		"LoadoutShipImage", true, false
	) as TextureRect if _loadout_page_root != null else null
	if image != null:
		image.modulate = Game.get_ship_tint(Game.selected_ship_id)
	var stats_label := _loadout_page_root.find_child(
		"LoadoutShipStats", true, false
	) as Label if _loadout_page_root != null else null
	if stats_label != null:
		var stats := Game.get_effective_ship_combat_stats(Game.selected_ship_id)
		stats_label.text = "DMG %.2f×   /   SPEED %d   /   HULL %d" % [
			float(stats["damage_multiplier"]),
			roundi(float(stats["max_speed"])),
			int(stats["max_hp"]),
		]


func _refresh_loadout_slots() -> void:
	if _loadout_stage == null:
		return
	for slot_data: Array in [
		["armor", "ARMOR", "store_armor"],
		["drone", "DRONE", "store_defense_drone"],
		["support", "SUPPORT", "store_reactor"],
	]:
		var old_slot := _loadout_stage.find_child(
			"EquipmentSlot_" + str(slot_data[0]), true, false
		) as Control
		if old_slot == null:
			continue
		var parent := old_slot.get_parent() as Container
		if parent == null:
			continue
		var position := old_slot.get_index()
		parent.remove_child(old_slot)
		old_slot.free()
		var new_slot := _build_equipment_slot_card(
			str(slot_data[0]), str(slot_data[1]), str(slot_data[2])
		)
		parent.add_child(new_slot)
		parent.move_child(new_slot, position)
	_translate_subtree(_loadout_stage)


func _loadout_item_matches_filters(item: Dictionary, query: String) -> bool:
	var item_id := str(item.get("id", ""))
	if not Game.owns_store_item(item_id):
		return false
	var slot := str(item.get("slot", ""))
	if not _equipment_slot_id.is_empty() and slot != _equipment_slot_id:
		return false
	match _loadout_category:
		"armor":
			if slot != "armor":
				return false
		"drone":
			if slot != "drone":
				return false
		"weapon":
			if str(item.get("category", "")) != "attack":
				return false
		"support":
			if slot != "support" and str(item.get("category", "")) != "defense":
				return false
	var searchable := ("%s %s %s %s" % [
		item_id, item.get("name", ""), item.get("description", ""),
		item.get("effect", ""),
	]).to_lower()
	return query.is_empty() or searchable.contains(query)


func _refresh_loadout_items(_query: String = "") -> void:
	if _loadout_grid == null or not is_instance_valid(_loadout_grid):
		return
	var previous_scroll := _loadout_items_scroll.scroll_vertical \
		if _loadout_items_scroll != null else 0
	for child: Node in _loadout_grid.get_children():
		_loadout_grid.remove_child(child)
		child.free()
	var query := _loadout_search.text.strip_edges().to_lower() \
		if _loadout_search != null else ""
	var filtered: Array[Dictionary] = []
	for item: Dictionary in Game.get_store_items():
		if _loadout_item_matches_filters(item, query):
			filtered.append(item)
	_loadout_grid.columns = _loadout_columns()
	for item: Dictionary in filtered:
		_loadout_grid.add_child(_build_loadout_item_card(item))
	if _loadout_inventory_title != null:
		var title := "EQUIPMENT"
		if not _equipment_slot_id.is_empty():
			title = "%s SLOT" % _equipment_slot_id.to_upper()
		else:
			match _loadout_category:
				"armor": title = "ARMOR"
				"drone": title = "DRONES"
				"weapon": title = "WEAPONS"
				"support": title = "SUPPORT"
				_: title = "EQUIPMENT"
		_loadout_inventory_title.text = title
	if _loadout_count != null:
		_loadout_count.text = "%d ITEMS  /  %d OWNED" % [
			filtered.size(), filtered.size(),
		]
	if filtered.is_empty():
		var empty := Label.new()
		empty.name = "LoadoutEmptyState"
		empty.text = "NO OWNED ITEMS FOR THIS SLOT. VISIT STORE TO BUY EQUIPMENT."
		empty.custom_minimum_size.y = 90
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", MUTED)
		_loadout_grid.add_child(empty)
	if _loadout_items_scroll != null:
		_loadout_items_scroll.set_deferred("scroll_vertical", previous_scroll)
	_translate_subtree(_loadout_grid)


func _loadout_columns() -> int:
	var width := _loadout_items_scroll.size.x \
		if _loadout_items_scroll != null and _loadout_items_scroll.size.x > 0.0 \
		else get_viewport().get_visible_rect().size.x - 240.0
	if width >= 820.0:
		return 3
	if width >= 500.0:
		return 2
	return 1


func _build_loadout_item_card(item: Dictionary) -> Control:
	var item_id := str(item.get("id", ""))
	var owned := Game.owns_store_item(item_id)
	var equipped := Game.get_equipped_store_item(
		str(item.get("slot", ""))
	) == item_id
	var card := Button.new()
	card.name = "LoadoutItemCard_" + item_id
	card.custom_minimum_size = Vector2(170, 116)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.focus_mode = Control.FOCUS_NONE
	card.tooltip_text = str(item.get("name", item_id))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.075, 0.12, 0.98)
	normal.border_color = Color(0.19, 0.38, 0.52, 0.75)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 9
	normal.content_margin_top = 8
	normal.content_margin_right = 9
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.055, 0.12, 0.18, 1.0)
	hover.border_color = CYAN
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.07, 0.16, 0.22, 1.0)
	pressed.border_color = Color(CYAN, 0.95)
	if equipped:
		normal.border_color = Color(0.35, 0.82, 0.70, 0.95)
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", pressed)
	card.add_theme_color_override("font_color", Color.WHITE)
	card.pressed.connect(_show_loadout_item_detail.bind(item_id))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 3)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 4)
	margin.add_child(body)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 7)
	body.add_child(header)
	var icon := TextureRect.new()
	icon.name = "LoadoutItemIcon_" + item_id
	icon.texture = load("res://assets/icons/%s.svg" % str(item["icon"])) as Texture2D
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon)
	var title := Label.new()
	title.text = str(item.get("name", item_id))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)
	var effect := Label.new()
	effect.text = str(item.get("effect", ""))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_font_size_override("font_size", 9)
	effect.add_theme_color_override("font_color", MUTED)
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(effect)
	var state := Label.new()
	state.name = "LoadoutItemState_" + item_id
	state.text = "EQUIPPED" if equipped else (
		"OWNED" if owned else "LOCKED  /  $%d" % int(item.get("price", 0))
	)
	state.add_theme_font_size_override("font_size", 9)
	state.add_theme_color_override(
		"font_color",
		Color(0.43, 0.88, 0.73) if equipped else (CYAN if owned else MUTED)
	)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(state)
	return card


func _ensure_loadout_item_popup() -> void:
	if is_instance_valid(_loadout_item_popup):
		return
	_loadout_item_popup = Control.new()
	_loadout_item_popup.name = "LoadoutItemDetailsPopup"
	_loadout_item_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loadout_item_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_loadout_item_popup.z_index = 50
	_loadout_item_popup.hide()
	add_child(_loadout_item_popup)
	var dim := ColorRect.new()
	dim.name = "LoadoutItemPopupDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.005, 0.014, 0.03, 0.78)
	_loadout_item_popup.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loadout_item_popup.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "LoadoutItemPopupPanel"
	panel.custom_minimum_size = Vector2(480, 260)
	_loadout_item_popup_panel = panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.095, 0.99)
	style.border_color = Color(0.30, 0.68, 0.88, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	layout.add_child(main)
	var icon_panel := _new_panel()
	icon_panel.custom_minimum_size = Vector2(88, 88)
	var icon_center := CenterContainer.new()
	icon_panel.add_child(icon_center)
	_loadout_item_popup_icon = TextureRect.new()
	_loadout_item_popup_icon.name = "LoadoutItemPopupIcon"
	_loadout_item_popup_icon.custom_minimum_size = Vector2(56, 56)
	_loadout_item_popup_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_loadout_item_popup_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_center.add_child(_loadout_item_popup_icon)
	main.add_child(icon_panel)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	main.add_child(details)
	_loadout_item_popup_title = Label.new()
	_loadout_item_popup_title.name = "LoadoutItemPopupTitle"
	_loadout_item_popup_title.add_theme_font_size_override("font_size", 17)
	_loadout_item_popup_title.add_theme_color_override("font_color", Color.WHITE)
	details.add_child(_loadout_item_popup_title)
	_loadout_item_popup_status = Label.new()
	_loadout_item_popup_status.add_theme_font_size_override("font_size", 10)
	_loadout_item_popup_status.add_theme_color_override("font_color", CYAN)
	details.add_child(_loadout_item_popup_status)
	_loadout_item_popup_description = Label.new()
	_loadout_item_popup_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loadout_item_popup_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loadout_item_popup_description.add_theme_color_override("font_color", Color(0.82, 0.89, 0.96))
	details.add_child(_loadout_item_popup_description)
	_loadout_item_popup_effect = Label.new()
	_loadout_item_popup_effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loadout_item_popup_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loadout_item_popup_effect.add_theme_color_override("font_color", Color(0.48, 0.83, 0.88))
	details.add_child(_loadout_item_popup_effect)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	layout.add_child(actions)
	_loadout_item_popup_action = _make_button("EQUIP", "loadout_item_action")
	_loadout_item_popup_action.name = "LoadoutItemPopupAction"
	_loadout_item_popup_action.custom_minimum_size = Vector2(132, 36)
	_loadout_item_popup_action.pressed.connect(_loadout_item_action)
	actions.add_child(_loadout_item_popup_action)
	var close := _make_button("CLOSE", "loadout_item_close")
	close.custom_minimum_size = Vector2(84, 36)
	close.pressed.connect(_loadout_item_popup.hide)
	actions.add_child(close)


func _show_loadout_item_detail(item_id: String) -> void:
	var item := Game.get_store_item(item_id)
	if item.is_empty():
		push_warning("Loadout item does not exist: %s" % item_id)
		return
	_loadout_selected_item_id = item_id
	_ensure_loadout_item_popup()
	_loadout_item_popup_title.text = str(item["name"])
	_loadout_item_popup_icon.texture = load(
		"res://assets/icons/%s.svg" % str(item["icon"])
	) as Texture2D
	_loadout_item_popup_description.text = str(item["description"])
	_loadout_item_popup_effect.text = str(item["effect"])
	var slot := str(item["slot"])
	var owned := Game.owns_store_item(item_id)
	var equipped := Game.get_equipped_store_item(slot) == item_id
	var slot_labels := {
		"armor": "ARMOR SLOT",
		"drone": "DRONE SLOT",
		"support": "SUPPORT SLOT",
	}
	var status := "EQUIPPED" if equipped else ("OWNED" if owned else "NOT OWNED")
	_loadout_item_popup_status.text = "%s  /  %s" % [
		_translate(str(slot_labels.get(slot, "EQUIPMENT SLOT"))),
		_translate(status),
	]
	var action_text: String
	if equipped:
		action_text = "UNEQUIP"
		_loadout_item_popup_action.disabled = false
	elif owned:
		action_text = "EQUIP"
		_loadout_item_popup_action.disabled = false
	else:
		action_text = "BUY  %d CREDITS" % int(item["price"])
		_loadout_item_popup_action.disabled = Game.pilot_cash < int(item["price"])
	_loadout_item_popup_action.text = action_text
	_loadout_item_popup_action.set_meta("locale_source_text", action_text)
	_translate_subtree(_loadout_item_popup)
	var viewport_size := get_viewport().get_visible_rect().size
	_loadout_item_popup_panel.custom_minimum_size = Vector2(
		minf(480.0, maxf(200.0, viewport_size.x - 32.0)),
		minf(260.0, maxf(180.0, viewport_size.y - 32.0))
	)
	_loadout_item_popup.show()


func _loadout_item_action() -> void:
	var item := Game.get_store_item(_loadout_selected_item_id)
	if item.is_empty():
		push_warning("Cannot apply missing loadout item: %s" % _loadout_selected_item_id)
		return
	var item_id := _loadout_selected_item_id
	var slot := str(item["slot"])
	var owned := Game.owns_store_item(item_id)
	if not owned:
		if not Game.purchase_store_item(item_id):
			push_warning("Unable to purchase loadout item: %s" % item_id)
			return
		_sfx()
		_refresh_loadout_items()
		_show_loadout_item_detail(item_id)
		return
	if not _equipment_slot_id.is_empty() and _equipment_slot_id != slot:
		push_warning("Loadout item is incompatible with selected slot: %s" % item_id)
		return
	if not Game.equip_store_item(item_id):
		push_warning("Unable to equip loadout item: %s" % item_id)
		return
	_sfx()
	_loadout_item_popup.hide()
	_refresh_loadout_slots()
	_refresh_loadout_items()


func _build_ship_showcase() -> Control:
	var panel := _new_panel()
	panel.name = "ActiveShipShowcase"
	panel.custom_minimum_size = Vector2(0, 205)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)
	var ship_id := Game.selected_ship_id
	var ship_name := Label.new()
	ship_name.text = ship_id.to_upper()
	ship_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ship_name.add_theme_font_size_override("font_size", 17)
	ship_name.add_theme_color_override("font_color", Color.WHITE)
	layout.add_child(ship_name)
	var image_holder := CenterContainer.new()
	image_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image_holder.custom_minimum_size.y = 96
	layout.add_child(image_holder)
	var image := TextureRect.new()
	image.texture = PLAYER_ICON
	image.custom_minimum_size = Vector2(150, 100)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = Game.get_ship_tint(ship_id)
	image_holder.add_child(image)
	var stats := Game.get_effective_ship_combat_stats(ship_id)
	var stats_label := Label.new()
	stats_label.text = "DMG %.2f×   /   SPEED %d   /   HULL %d" % [
		float(stats["damage_multiplier"]),
		roundi(float(stats["max_speed"])),
		int(stats["max_hp"]),
	]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 10)
	stats_label.add_theme_color_override("font_color", MUTED)
	layout.add_child(stats_label)
	return panel


func _build_fleet_active_ship() -> Control:
	var panel := _new_panel()
	panel.name = "FleetActiveShipPanel"
	panel.custom_minimum_size.y = 220
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	content.add_child(heading)
	var ship_id := Game.selected_ship_id
	var title := Label.new()
	title.name = "FleetActiveShipName"
	title.text = ship_id.to_upper()
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var equipped := Label.new()
	equipped.name = "FleetActiveShipStatus"
	equipped.text = "CURRENTLY EQUIPPED"
	equipped.add_theme_font_size_override("font_size", 10)
	equipped.add_theme_color_override("font_color", CYAN)
	equipped.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(equipped)

	_fleet_active_horizontal = HBoxContainer.new()
	_fleet_active_horizontal.name = "FleetActiveShipDetailsWide"
	_fleet_active_horizontal.add_theme_constant_override("separation", 14)
	content.add_child(_fleet_active_horizontal)
	_fleet_active_vertical = VBoxContainer.new()
	_fleet_active_vertical.name = "FleetActiveShipDetailsCompact"
	_fleet_active_vertical.add_theme_constant_override("separation", 10)
	content.add_child(_fleet_active_vertical)

	_fleet_active_art_panel = PanelContainer.new()
	_fleet_active_art_panel.name = "FleetActiveShipArt"
	_fleet_active_art_panel.custom_minimum_size = Vector2(280, 150)
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color(0.018, 0.045, 0.085, 0.96)
	art_style.border_color = Color(0.30, 0.68, 0.88, 0.38)
	art_style.set_border_width_all(1)
	art_style.set_corner_radius_all(10)
	_fleet_active_art_panel.add_theme_stylebox_override("panel", art_style)
	var art_center := CenterContainer.new()
	art_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fleet_active_art_panel.add_child(art_center)
	var image := TextureRect.new()
	image.name = "FleetActiveShipImage"
	image.texture = PLAYER_ICON
	image.custom_minimum_size = Vector2(220, 132)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = Game.get_ship_tint(ship_id)
	art_center.add_child(image)

	_fleet_active_stats_panel = _new_panel()
	_fleet_active_stats_panel.name = "FleetActiveShipStats"
	_fleet_active_stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", 14)
	stats_margin.add_theme_constant_override("margin_top", 12)
	stats_margin.add_theme_constant_override("margin_right", 14)
	stats_margin.add_theme_constant_override("margin_bottom", 12)
	_fleet_active_stats_panel.add_child(stats_margin)
	var stats_column := VBoxContainer.new()
	stats_column.add_theme_constant_override("separation", 8)
	stats_margin.add_child(stats_column)
	var stats_title := Label.new()
	stats_title.name = "FleetStatsTitle"
	stats_title.text = "FRAME SYSTEMS"
	stats_title.add_theme_font_size_override("font_size", 11)
	stats_title.add_theme_color_override("font_color", CYAN)
	stats_column.add_child(stats_title)
	var stats := Game.get_effective_ship_combat_stats(ship_id)
	_add_ship_stat(
		stats_column, "DAMAGE",
		float(stats["damage_multiplier"]), 1.25,
		"%.2f×" % float(stats["damage_multiplier"]), CYAN
	)
	_add_ship_stat(
		stats_column, "SPEED",
		float(stats["max_speed"]), 450.0,
		"%d" % roundi(float(stats["max_speed"])),
		Color(0.36, 0.72, 1.0)
	)
	_add_ship_stat(
		stats_column, "HP",
		float(stats["max_hp"]), 16.0,
		"%d" % int(stats["max_hp"]), Color(0.47, 0.89, 0.70)
	)
	_add_ship_stat(
		stats_column, "BULLET SPEED",
		float(stats["bullet_speed"]), 750.0,
		"%d" % roundi(float(stats["bullet_speed"])),
		Color(0.95, 0.72, 0.39)
	)

	_layout_fleet_active_ship(
		get_viewport().get_visible_rect().size.x < 940.0
	)
	return panel


func _layout_fleet_active_ship(narrow: bool) -> void:
	if _fleet_active_horizontal == null or _fleet_active_vertical == null \
			or _fleet_active_art_panel == null \
			or _fleet_active_stats_panel == null:
		return
	var target: BoxContainer = _fleet_active_vertical \
		if narrow else _fleet_active_horizontal
	for section: Control in [
		_fleet_active_art_panel, _fleet_active_stats_panel,
	]:
		if section.get_parent() != target:
			var previous_parent := section.get_parent() as Container
			if previous_parent != null:
				previous_parent.remove_child(section)
			target.add_child(section)
	_fleet_active_horizontal.visible = not narrow
	_fleet_active_vertical.visible = narrow
	_fleet_active_stats_panel.custom_minimum_size.x = 0.0 if narrow else 300.0
	if narrow:
		_fleet_active_art_panel.custom_minimum_size = Vector2(0, 144)
		_fleet_active_art_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		_fleet_active_art_panel.custom_minimum_size = Vector2(280, 150)
		_fleet_active_art_panel.size_flags_horizontal = Control.SIZE_FILL


func _add_pilot_upgrade_row(
		definition: Dictionary, parent: VBoxContainer) -> void:
	var upgrade_id := str(definition["id"])
	var level := Game.get_pilot_upgrade_level(upgrade_id)
	var cost := Game.get_pilot_upgrade_cost(upgrade_id)
	var item := _new_panel()
	item.name = "PilotUpgrade_" + upgrade_id
	item.custom_minimum_size.y = 112
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	item.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(
		"res://assets/icons/%s.svg" % str(definition["icon"])
	) as Texture2D
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = CYAN
	row.add_child(icon)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 3)
	var name := Label.new()
	name.text = "%s  /  %s %d/5" % [
		_translate(str(definition["name"])), _translate("LEVEL"), level,
	]
	name.add_theme_color_override("font_color", Color.WHITE)
	details.add_child(name)
	var description := Label.new()
	description.text = str(definition["description"])
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", MUTED)
	details.add_child(description)
	var segments := HBoxContainer.new()
	segments.name = "UpgradeSegments"
	segments.add_theme_constant_override("separation", 4)
	for index in 5:
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(0, 6)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.color = CYAN if index < level else Color(0.12, 0.20, 0.28)
		segments.add_child(segment)
	details.add_child(segments)
	var next_level := mini(level + 1, 5)
	var current_value := _pilot_upgrade_value(upgrade_id, level)
	var next_value := _pilot_upgrade_value(upgrade_id, next_level)
	var stat := Label.new()
	stat.text = "%s %s   →   %s %s" % [
		_translate("CURRENT"), current_value, _translate("NEXT"), next_value,
	]
	stat.add_theme_font_size_override("font_size", 10)
	stat.add_theme_color_override("font_color", Color(0.78, 0.89, 0.97))
	details.add_child(stat)
	row.add_child(details)
	var purchase := _make_button(
		_translate("MAX") if level >= 5
		else "%s  %d" % [_translate("UPGRADE"), cost],
		"upgrade_purchase"
	)
	if level < 5:
		purchase.icon = load("res://assets/icons/gem.svg") as Texture2D
		purchase.add_theme_constant_override("icon_max_width", 18)
	purchase.custom_minimum_size = Vector2(142, 42)
	purchase.disabled = level >= 5 or Game.pilot_tokens < cost
	purchase.tooltip_text = _translate("NOT ENOUGH GEMS") \
		if level < 5 and Game.pilot_tokens < cost else ""
	purchase.pressed.connect(_buy_pilot_upgrade.bind(upgrade_id))
	row.add_child(purchase)
	parent.add_child(item)


func _filter_shop_ships(query: String) -> void:
	var search := query.strip_edges().to_lower()
	for card: Control in _shop_ship_cards:
		card.visible = search.is_empty() \
			or str(card.get_meta("ship_search_text", "")).contains(search)


func _pilot_upgrade_value(upgrade_id: String, level: int) -> String:
	for definition: Dictionary in Game.get_pilot_upgrade_definitions():
		if str(definition["id"]) != upgrade_id:
			continue
		var amount := Game.get_pilot_upgrade_effect(upgrade_id) \
			* float(level)
		var stats := Game.get_ship_combat_stats()
		match str(definition.get("stat", "")):
			"max_speed":
				return "%d %s" % [
					roundi(float(stats["max_speed"]) * (1.0 + amount)),
					_translate("SPEED"),
				]
			"damage_multiplier":
				return "%.2f× %s" % [
					float(stats["damage_multiplier"]) * (1.0 + amount),
					_translate("DMG"),
				]
			"fire_rate_multiplier":
				return "%.0f%% %s" % [
					100.0 + amount * 100.0, _translate("RATE"),
				]
			"bullet_speed_multiplier":
				return "%d %s" % [
					roundi(float(stats["bullet_speed"])
						* (1.0 + amount)),
					_translate("BULLET SPEED"),
				]
			"crit_chance":
				return "%.1f%% %s" % [
					amount * 100.0, _translate("CRIT"),
				]
			"pierce_bonus":
				return "%d %s" % [roundi(amount), _translate("PIERCE")]
			"burn_bonus":
				return "%d %s" % [roundi(amount), _translate("BURN")]
			"max_hp":
				return "%d %s" % [
					int(stats["max_hp"]) + roundi(amount),
					_translate("HP"),
				]
	return "—"


func _buy_pilot_upgrade(upgrade_id: String) -> void:
	if Game.purchase_pilot_upgrade(upgrade_id):
		_sfx()
		_open_page("upgrades")


func _add_paint_option(paint: Dictionary) -> void:
	var paint_id := str(paint["id"])
	var unlocked := Game.is_ship_unlocked(paint_id)
	var item := _new_panel()
	item.name = "ShipCard_" + paint_id
	item.custom_minimum_size = Vector2(160, 194)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	item.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	var image_frame := PanelContainer.new()
	image_frame.name = "ShipCardImageFrame"
	image_frame.custom_minimum_size.y = 88
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.018, 0.045, 0.085, 0.96)
	frame_style.border_color = Color(0.30, 0.68, 0.88, 0.38)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(8)
	image_frame.add_theme_stylebox_override("panel", frame_style)
	content.add_child(image_frame)
	var image_surface := Control.new()
	image_surface.custom_minimum_size.y = 86
	image_frame.add_child(image_surface)
	var image := TextureRect.new()
	image.name = "ShipCardImage"
	image.texture = PLAYER_ICON
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = paint["color"] if unlocked else Color(0.54, 0.62, 0.70)
	image_surface.add_child(image)
	if not unlocked:
		var shade := ColorRect.new()
		shade.name = "ShipCardLockShade"
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(0.01, 0.025, 0.045, 0.38)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image_surface.add_child(shade)
		var lock := LockGlyph.new()
		lock.name = "ShipCardLockIcon"
		lock.custom_minimum_size = Vector2(30, 30)
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lock.offset_left = -15
		lock.offset_top = -15
		lock.offset_right = 15
		lock.offset_bottom = 15
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image_surface.add_child(lock)

	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 3)
	content.add_child(details)
	var name_label := Label.new()
	name_label.name = "ShipCardName"
	name_label.text = str(paint["name"])
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.clip_text = true
	details.add_child(name_label)
	var state := Label.new()
	state.name = "ShipCardState"
	state.text = "CURRENTLY EQUIPPED" \
		if paint_id == Game.selected_ship_id \
		else ("OWNED" if unlocked else "BEST WAVE %d OR %d GEMS" % [
			Game.get_ship_unlock_wave(paint_id),
			Game.get_ship_token_cost(paint_id),
		])
	state.add_theme_font_size_override("font_size", 9)
	state.add_theme_color_override("font_color", CYAN if unlocked else MUTED)
	state.clip_text = true
	details.add_child(state)
	var stats := Game.get_effective_ship_combat_stats(paint_id)
	var combat_stats := Label.new()
	combat_stats.name = "ShipCardStats"
	combat_stats.text = "DMG %.2f×   SPD %d   HP %d" % [
		float(stats["damage_multiplier"]),
		roundi(float(stats["max_speed"])),
		int(stats["max_hp"]),
	]
	combat_stats.add_theme_font_size_override("font_size", 9)
	combat_stats.add_theme_color_override("font_color", MUTED)
	details.add_child(combat_stats)

	var select := Button.new()
	select.name = "PaintCardSelect_" + paint_id
	select.flat = true
	select.focus_mode = Control.FOCUS_NONE
	select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	select.tooltip_text = "SELECT SHIP" if unlocked else "VIEW SHIP"
	if unlocked:
		select.pressed.connect(_select_ship.bind(paint_id))
	else:
		select.pressed.connect(_show_ship_detail.bind(paint_id))
	item.add_child(select)
	if _ship_fleet_grid != null:
		_ship_fleet_grid.add_child(item)
	else:
		_page_popup_content.add_child(item)


func _translate_subtree(node: Node) -> void:
	var locale := get_node_or_null("/root/Locale")
	if locale != null and locale.has_method("translate_tree"):
		locale.call("translate_tree", node)


func _add_store_ship(ship: Dictionary) -> void:
	var ship_id := str(ship["id"])
	var item := _new_panel()
	item.name = "ShopShip_" + ship_id
	item.custom_minimum_size.y = 142
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.set_meta(
		"ship_search_text",
		("%s %s" % [ship_id, str(ship["name"])]).to_lower()
	)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	item.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	margin.add_child(layout)
	var name_label := Label.new()
	name_label.text = str(ship["name"])
	name_label.add_theme_color_override("font_color", Color.WHITE)
	layout.add_child(name_label)
	var details := HBoxContainer.new()
	details.add_theme_constant_override("separation", 5)
	var cost_label := Label.new()
	cost_label.text = "COST"
	details.add_child(cost_label)
	var amount := Label.new()
	amount.text = str(Game.get_ship_token_cost(ship_id))
	details.add_child(amount)
	var token_icon := TextureRect.new()
	token_icon.texture = load("res://assets/icons/gem.svg") as Texture2D
	token_icon.custom_minimum_size = Vector2(16, 16)
	token_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	token_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	details.add_child(token_icon)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(spacer)
	var unlock_label := Label.new()
	unlock_label.text = "FREE AT WAVE"
	details.add_child(unlock_label)
	var unlock_wave := Label.new()
	unlock_wave.text = str(Game.get_ship_unlock_wave(ship_id))
	details.add_child(unlock_wave)
	layout.add_child(details)
	var buy := _make_button(
		"UNLOCKED" if Game.is_ship_unlocked(ship_id) else "UNLOCK",
		"buy_ship"
	)
	buy.disabled = Game.is_ship_unlocked(ship_id) \
		or Game.pilot_tokens < Game.get_ship_token_cost(ship_id)
	buy.pressed.connect(_buy_ship.bind(ship_id))
	layout.add_child(buy)
	if _shop_ship_grid != null:
		_shop_ship_grid.add_child(item)
		_shop_ship_cards.append(item)
	else:
		_page_popup_content.add_child(item)


func _buy_ship(ship_id: String) -> void:
	if Game.unlock_ship_with_tokens(ship_id):
		_sfx()
		_open_page("shop")


func _add_settings_controls() -> void:
	var locale := get_node_or_null("/root/Locale")
	var language_row := HBoxContainer.new()
	language_row.name = "LobbyLanguageRow"
	language_row.add_theme_constant_override("separation", 12)
	var language_label := Label.new()
	language_label.name = "LobbyLanguageLabel"
	language_label.text = _translate("LANGUAGE")
	language_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	language_label.add_theme_color_override("font_color", Color(0.80, 0.88, 0.96))
	language_row.add_child(language_label)
	var language_option := OptionButton.new()
	language_option.name = "LobbyLanguageOption"
	language_option.custom_minimum_size = Vector2(150, 40)
	language_option.add_item("English")
	language_option.add_item("Tiếng Việt")
	language_option.select(
		1 if locale != null and str(locale.call("get_locale")) == "vi" else 0
	)
	language_option.item_selected.connect(_on_lobby_language_selected)
	language_row.add_child(language_option)
	_page_popup_content.add_child(language_row)

	var master := HSlider.new()
	master.min_value = 0.0
	master.max_value = 1.0
	master.step = 0.05
	master.value = Game.get_master_volume()
	var volume_label := Label.new()
	volume_label.name = "LobbyMasterVolumeLabel"
	volume_label.text = "%s  %d%%" % [
		_translate("MASTER VOLUME"), int(master.value * 100.0),
	]
	volume_label.add_theme_color_override("font_color", Color(0.80, 0.88, 0.96))
	_page_popup_content.add_child(volume_label)
	master.value_changed.connect(func(value: float):
		Game.set_master_volume(value)
		volume_label.text = "%s  %d%%" % [
			_translate("MASTER VOLUME"), int(value * 100.0),
		]
	)
	_page_popup_content.add_child(master)


func _on_lobby_language_selected(index: int) -> void:
	var locale := get_node_or_null("/root/Locale")
	if locale == null or not locale.has_method("set_locale"):
		push_error("Lobby language selector cannot access the Locale autoload")
		return
	locale.call("set_locale", "vi" if index == 1 else "en")
	call_deferred("_open_page", "settings")


func _translate(text: String) -> String:
	var locale := get_node_or_null("/root/Locale")
	return str(locale.call("translate_text", text)) if locale else text


func _format_count(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.1fK" % (float(value) / 1000.0)
	return str(value)


func _format_time(seconds: float) -> String:
	var total_seconds := maxi(0, roundi(seconds))
	return "%02d:%02d" % [
		total_seconds / 60,
		total_seconds % 60,
	]


func _create_run_record_panel() -> void:
	var ui := get_node_or_null("UI") as Control
	if ui == null:
		return
	_run_record_panel = Panel.new()
	_run_record_panel.name = "RunRecordPanel"
	_run_record_panel.visible = false
	_run_record_panel.z_index = 10
	_run_record_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.095, 0.99)
	style.border_color = Color(0.32, 0.69, 0.88, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.02, 0.06, 0.72)
	style.shadow_size = 18
	_run_record_panel.add_theme_stylebox_override("panel", style)
	ui.add_child(_run_record_panel)

	var header_bar := Panel.new()
	header_bar.name = "RunRecordHeaderBar"
	header_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.055, 0.12, 0.20, 0.98)
	header_style.border_color = Color(0.23, 0.56, 0.74, 0.6)
	header_style.set_border_width_all(1)
	header_style.set_corner_radius_all(9)
	header_bar.add_theme_stylebox_override("panel", header_style)
	_run_record_panel.add_child(header_bar)

	var title := Label.new()
	title.name = "RunRecordTitle"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_run_record_panel.add_child(title)

	_run_record_close = _make_button("X", "close")
	_run_record_close.name = "CloseRunRecordButton"
	_run_record_close.custom_minimum_size = Vector2(36, 36)
	_run_record_close.z_index = 2
	_run_record_close.mouse_filter = Control.MOUSE_FILTER_STOP
	_run_record_close.pressed.connect(_toggle_run_record_popup)
	_run_record_panel.add_child(_run_record_close)

	_run_record_scroll = ScrollContainer.new()
	_run_record_scroll.set_script(
		load("res://scripts/touch_scroll_container.gd")
	)
	_run_record_scroll.name = "RunRecordScroll"
	_run_record_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_run_record_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_run_record_panel.add_child(_run_record_scroll)

	_run_record_label = Label.new()
	_run_record_label.name = "RunRecordLabel"
	_run_record_label.add_theme_font_size_override("font_size", 13)
	_run_record_label.add_theme_color_override("font_color", Color(0.78, 0.87, 1.0))
	_run_record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_run_record_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_run_record_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_record_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_run_record_scroll.add_child(_run_record_label)
	get_viewport().size_changed.connect(_layout_run_record_panel)
	var locale := get_node_or_null("/root/Locale")
	if locale != null and locale.has_signal("locale_changed"):
		locale.locale_changed.connect(_refresh_run_record)
	_layout_run_record_panel()
	_refresh_run_record()


func _toggle_run_record_popup() -> void:
	if _run_record_panel == null:
		return
	_run_record_panel.visible = not _run_record_panel.visible
	if _run_record_panel.visible:
		if _page_popup != null:
			_page_popup.hide()
			_main_columns.visible = true
			_main_columns_mobile.visible = true
		_run_record_panel.z_index = 30
		_run_record_panel.move_to_front()
		_run_record_close.move_to_front()
	else:
		_set_navigation_page("home")


func _free_ship_transition_ghost() -> void:
	if is_instance_valid(_ship_transition_ghost):
		_ship_transition_ghost.queue_free()
	_ship_transition_ghost = null


func _finish_ship_transition(target_locked: bool) -> void:
	_free_ship_transition_ghost()
	var locked_overlay := _ship_stage.get_node_or_null("LockedOverlay") as ColorRect
	if locked_overlay == null:
		return
	locked_overlay.color.a = 0.64
	locked_overlay.visible = target_locked


func _layout_run_record_panel() -> void:
	if _run_record_panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var margin := 20.0
	var panel_size := Vector2(
		minf(440.0, viewport_size.x - margin * 2.0),
		minf(520.0, viewport_size.y - margin * 2.0)
	)
	_run_record_panel.size = panel_size
	_run_record_panel.position = (viewport_size - panel_size) * 0.5
	var width := panel_size.x
	var height := panel_size.y
	var title := _run_record_panel.get_node("RunRecordTitle") as Label
	var header_bar := _run_record_panel.get_node("RunRecordHeaderBar") as Panel
	header_bar.position = Vector2(10.0, 8.0)
	header_bar.size = Vector2(width - 20.0, 44.0)
	title.position = Vector2(16.0, 12.0)
	title.size = Vector2(width - 70.0, 36.0)
	_run_record_close.position = Vector2(width - 48.0, 8.0)
	_run_record_close.size = Vector2(36.0, 36.0)
	_run_record_scroll.position = Vector2(16.0, 56.0)
	_run_record_scroll.size = Vector2(width - 32.0, height - 72.0)
	_run_record_label.custom_minimum_size.x = _run_record_scroll.size.x - 12.0


func _refresh_run_record(_locale: String = "") -> void:
	if _run_record_label == null or _run_record_panel == null:
		return
	var latest: Dictionary = Game.latest_run
	var best: Dictionary = Game.best_run
	var locale := get_node_or_null("/root/Locale")
	var title := str(locale.call("translate_text", "RUN RECORD")) \
		if locale else "RUN RECORD"
	_run_record_panel.get_node("RunRecordTitle").text = title
	var lines := PackedStringArray()
	if not latest.is_empty():
		lines.append(_format_lobby_record("LAST RUN", latest, locale, true))
	if not best.is_empty():
		lines.append(_format_lobby_record("BEST RUN", best, locale, false))
	if not Game.card_pick_counts.is_empty():
		var most_picked_id := ""
		var most_picked_count := 0
		for card_id: Variant in Game.card_pick_counts:
			var count := int(Game.card_pick_counts[card_id])
			if count > most_picked_count:
				most_picked_id = str(card_id)
				most_picked_count = count
		var picks_label := str(locale.call("translate_text", "MOST PICKED")) \
			if locale else "MOST PICKED"
		lines.append("%s: %s" % [
			picks_label,
			Game.build_item_label("%s x%d" % [most_picked_id, most_picked_count]),
		])
	if lines.is_empty():
		lines.append(str(locale.call("translate_text", "NO RUNS RECORDED"))
			if locale else "NO RUNS RECORDED")
	_run_record_label.text = "\n".join(lines)
	_run_record_scroll.scroll_vertical = 0


func _format_lobby_record(heading: String, run: Dictionary,
		locale: Variant, include_build: bool) -> String:
	var title := str(locale.call("translate_text", heading)) if locale else heading
	var wave_label := str(locale.call("translate_text", "WAVE")) if locale else "WAVE"
	var bosses_label := str(locale.call("translate_text", "BOSSES")) if locale else "BOSSES"
	var damage_label := str(locale.call("translate_text", "DAMAGE")) if locale else "DAMAGE"
	var time_label := str(locale.call("translate_text", "TIME")) if locale else "TIME"
	var ttk_label := str(locale.call("translate_text", "BOSS TTK")) if locale else "BOSS TTK"
	var seconds := int(run.get("seconds", 0.0))
	var boss_kill_seconds := int(run.get("average_boss_kill_seconds", 0.0))
	var text := "%s: %s %d | %s %d\n%s %d | %s %02d:%02d\n%s %02d:%02d" % [
		title,
		wave_label,
		int(run.get("wave", 0)),
		bosses_label,
		int(run.get("bosses", 0)),
		damage_label,
		int(run.get("damage", 0)),
		time_label,
		seconds / 60,
		seconds % 60,
		ttk_label,
		boss_kill_seconds / 60,
		boss_kill_seconds % 60,
	]
	if include_build:
		var all_build: Array = run.get("build", [])
		var build := PackedStringArray()
		for index in all_build.size():
			build.append(Game.build_item_label(str(all_build[index])))
		if not build.is_empty():
			var build_label := str(locale.call("translate_text", "BUILD")) if locale else "BUILD"
			text += "\n%s: %s" % [build_label, ", ".join(build)]
	return text


func _style_buttons() -> void:
	# PLAY gets the chamfered (cut top-left) style from the sketch.
	if play_btn:
		var box = ChamferBox.new()
		box.bg_color = Color(0.95, 0.95, 0.95)
		box.border_color = Color(0.02, 0.02, 0.02)
		box.border_width = 2.0
		box.chamfer = 26.0
		play_btn.add_theme_stylebox_override("normal", box)
		var hover = ChamferBox.new()
		hover.bg_color = Color(1.0, 0.98, 0.6)
		hover.border_color = Color(0.02, 0.02, 0.02)
		hover.border_width = 2.0
		hover.chamfer = 26.0
		play_btn.add_theme_stylebox_override("hover", hover)
		var press = ChamferBox.new()
		press.bg_color = Color(0.8, 0.78, 0.45)
		press.border_color = Color(0.02, 0.02, 0.02)
		press.border_width = 2.0
		press.chamfer = 26.0
		play_btn.add_theme_stylebox_override("pressed", press)
		play_btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))

	# mode illustrations taken straight from the game sprites
	if wave_mode_btn:
		var icon1: Texture2D = load("res://assets/shape_3.svg")
		if icon1:
			wave_mode_btn.icon = icon1
			wave_mode_btn.expand_icon = true
	if test_mode_btn:
		var icon2: Texture2D = load("res://assets/railgun_enemy.svg")
		if icon2:
			test_mode_btn.icon = icon2
			test_mode_btn.expand_icon = true


func _start_ani() -> void:
	var ui: Control = get_node_or_null("UI")
	if ui != null:
		ui.modulate.a = 0.0
		create_tween().tween_property(ui, "modulate:a", 1.0, 0.32) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	call_deferred("_animate_ship_display")


func _animate_ship_display() -> void:
	if not is_instance_valid(_ship_preview):
		return
	var glow := _ship_stage.get_node("EngineGlow") as ColorRect
	var glow_tween := create_tween().set_loops()
	glow_tween.tween_property(glow, "modulate:a", 0.65, 1.4)
	glow_tween.tween_property(glow, "modulate:a", 1.0, 1.4)


func _process(delta: float) -> void:
	_ui_animation_accumulator += delta
	if _ui_animation_accumulator < 1.0 / 30.0:
		return
	var animation_delta := _ui_animation_accumulator
	_ui_animation_accumulator = 0.0
	time += animation_delta
	_ship_float_time += animation_delta
	if _ship_preview != null and _ship_stage != null \
			and (_ship_visual_tween == null or not _ship_visual_tween.is_running()):
		_ship_preview.position.y = _ship_preview_base_position.y \
			+ sin(_ship_float_time * 1.15) * 2.5
	scroll += animation_delta * 1.1
	if parallax != null:
		parallax.scroll_offset = Vector2(scroll, scroll * 0.7)


func _populate_options() -> void:
	if spawn_enemy_btn != null:
		spawn_enemy_btn.clear()
		spawn_enemy_btn.add_item("NONE")
		for e in ENEMY_LIST:
			spawn_enemy_btn.add_item(e.to_upper())

	if spawn_boss_btn != null:
		spawn_boss_btn.clear()
		spawn_boss_btn.add_item("NONE")
		for b in BOSS_LIST:
			spawn_boss_btn.add_item(b.to_upper())

	if give_card_btn != null:
		give_card_btn.clear()
		_card_ids.clear()
		give_card_btn.add_item("NONE")
		for c in CardDBScript.all_cards():
			if typeof(c) == TYPE_DICTIONARY and c.has("id"):
				_card_ids.append(str(c.get("id")))
				give_card_btn.add_item(str(c.get("name", c.get("id"))))

	if give_weapon_btn != null:
		give_weapon_btn.clear()
		give_weapon_btn.add_item("NONE")
		for w in WEAPON_LIST:
			give_weapon_btn.add_item(w.to_upper())


func _on_mode_pressed() -> void:
	_sfx()
	if mode_panel != null:
		mode_panel.show()


func _select_mode(mode: String) -> void:
	_sfx()
	game_mode = mode
	_update_mode_ui()
	if mode_panel != null:
		mode_panel.hide()


func _update_mode_ui() -> void:
	if mode_btn:
		mode_btn.text = "TEST MODE" if game_mode == "test" else "WAVE SURVIVAL"
	if test_btn:
		test_btn.hide()
	if test_panel:
		test_panel.hide()


func _on_test_pressed() -> void:
	_sfx()
	if test_panel != null:
		test_panel.hide()


func _on_apply_test() -> void:
	_sfx()
	_start_test_run()


func _start_test_run() -> void:
	var gm = get_node_or_null("/root/Game")
	if gm != null:
		if gm.has_method("reset_run"):
			gm.reset_run()
		var lvl := int(level_spin.value) if level_spin != null else 1
		gm.set("wave", (int(wave_spin.value) - 1) if wave_spin != null else 0)
		gm.set("level", lvl)
		var test_data := {
			"wave": int(wave_spin.value) if wave_spin != null else 1,
			"level": lvl,
			"spawn_enemy": _get_selected_enemy(),
			"spawn_boss": _get_selected_boss(),
			"give_card": _get_selected_card(),
			"give_weapon": _get_selected_weapon(),
		}
		gm.set("test_mode", true)
		gm.set("test_data", test_data)
		var weapon: String = test_data["give_weapon"]
		if weapon != "":
			gm.set("weapon", weapon)
			gm.set("weapon_chosen", true)
		var card_id: String = test_data["give_card"]
		if card_id != "":
			for c in CardDBScript.all_cards():
				if typeof(c) == TYPE_DICTIONARY and str(c.get("id")) == card_id:
					gm.grant_card(c)
					break
		# let the HUD and the player know the starting level
		if gm.has_signal("level_changed"):
			gm.level_changed.emit(lvl)
	Net.leave()
	get_tree().change_scene_to_file(GAME_SCENE)


func _get_selected_enemy() -> String:
	if spawn_enemy_btn == null:
		return ""
	var idx := spawn_enemy_btn.selected
	if idx <= 0:
		return ""
	return ENEMY_LIST[idx - 1]


func _get_selected_boss() -> String:
	if spawn_boss_btn == null:
		return ""
	var idx := spawn_boss_btn.selected
	if idx <= 0:
		return ""
	return BOSS_LIST[idx - 1]


func _get_selected_card() -> String:
	if give_card_btn == null:
		return ""
	var idx := give_card_btn.selected
	if idx <= 0 or idx > _card_ids.size():
		return ""
	return _card_ids[idx - 1]


func _get_selected_weapon() -> String:
	if give_weapon_btn == null:
		return ""
	var idx := give_weapon_btn.selected
	if idx <= 0:
		return ""
	return WEAPON_LIST[idx - 1]


func _on_play_pressed() -> void:
	_sfx()
	if game_mode == "test":
		_start_test_run()
		return
	Net.leave()
	var gm = get_node_or_null("/root/Game")
	if gm != null:
		if gm.has_method("reset_run"):
			gm.reset_run()
		gm.set("test_mode", false)
		gm.set("test_data", {})
	get_tree().change_scene_to_file(ROOM_LOBBY_SCENE)


func _on_back_pressed() -> void:
	_sfx()
	get_tree().change_scene_to_file(MENU_SCENE)


func _sfx() -> void:
	var gm = get_node_or_null("/root/Game")
	if gm != null and gm.has_method("sfx"):
		gm.sfx("click", -10.0, 0.95, 1.05)
