extends CanvasLayer

# Lobby: the ship sits on the left, buttons on the right (like the sketch).
# PLAY has a chamfered top-left corner via chamfer_box.gd.

const GAME_SCENE := "res://scenes/main.tscn"
const ROOM_LOBBY_SCENE := "res://scenes/room_lobby.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"
const ChamferBox := preload("res://scripts/chamfer_box.gd")
const CardDBScript := preload("res://scripts/card_db.gd")
const TROPHY_ICON := preload("res://assets/icons/trophy.svg")

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
var _run_record_button: Button
var _run_record_panel: Panel
var _run_record_label: Label
var _run_record_scroll: ScrollContainer
var _run_record_close: Button

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
	_create_run_record_panel()
	_start_ani()


func _create_run_record_panel() -> void:
	var ui := get_node_or_null("UI") as Control
	if ui == null:
		return
	_run_record_button = Button.new()
	_run_record_button.name = "RunRecordButton"
	_run_record_button.tooltip_text = "RUN RECORD"
	_run_record_button.icon = TROPHY_ICON
	_run_record_button.custom_minimum_size = Vector2(52.0, 52.0)
	_run_record_button.size = Vector2(52.0, 52.0)
	_run_record_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_run_record_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_run_record_button.add_theme_constant_override("icon_max_width", 32)
	_run_record_button.pressed.connect(_toggle_run_record_popup)
	ui.add_child(_run_record_button)

	_run_record_panel = Panel.new()
	_run_record_panel.name = "RunRecordPanel"
	_run_record_panel.visible = false
	_run_record_panel.z_index = 10
	_run_record_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.09, 0.97)
	style.border_color = Color(0.32, 0.58, 0.82, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	_run_record_panel.add_theme_stylebox_override("panel", style)
	ui.add_child(_run_record_panel)

	var title := Label.new()
	title.name = "RunRecordTitle"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_run_record_panel.add_child(title)

	_run_record_close = Button.new()
	_run_record_close.name = "CloseRunRecordButton"
	_run_record_close.text = "X"
	_run_record_close.pressed.connect(_toggle_run_record_popup)
	_run_record_panel.add_child(_run_record_close)

	_run_record_scroll = ScrollContainer.new()
	_run_record_scroll.name = "RunRecordScroll"
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


func _layout_run_record_panel() -> void:
	if _run_record_panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var margin := 20.0
	_run_record_button.position = Vector2(
		maxf(viewport_size.x - margin - 52.0, margin), margin
	)
	var panel_size := Vector2(
		minf(440.0, viewport_size.x - margin * 2.0),
		minf(520.0, viewport_size.y - margin * 2.0)
	)
	_run_record_panel.size = panel_size
	_run_record_panel.position = (viewport_size - panel_size) * 0.5
	var width := panel_size.x
	var height := panel_size.y
	var title := _run_record_panel.get_node("RunRecordTitle") as Label
	title.position = Vector2(16.0, 12.0)
	title.size = Vector2(width - 70.0, 32.0)
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
		var tw := create_tween()
		if tw != null:
			var t := tw.tween_property(ui, "modulate:a", 1.0, 0.35)
			if t:
				t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# flame flicker: stretch along -X (the exhaust direction)
	if flame1 != null:
		var tw3 := create_tween()
		if tw3 != null:
			tw3.set_loops()
			var f1 := tw3.tween_property(flame1, "scale:x", 1.35, 0.1)
			if f1:
				f1.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			var f2 := tw3.tween_property(flame1, "scale:x", 0.75, 0.1)
			if f2:
				f2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if flame2 != null:
		var tw3b := create_tween()
		if tw3b != null:
			tw3b.set_loops()
			var g1 := tw3b.tween_property(flame2, "scale:x", 1.25, 0.08)
			if g1:
				g1.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			var g2 := tw3b.tween_property(flame2, "scale:x", 0.8, 0.08)
			if g2:
				g2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if flame_core != null:
		var tw3c := create_tween()
		if tw3c != null:
			tw3c.set_loops()
			var h1 := tw3c.tween_property(flame_core, "scale:x", 1.5, 0.06)
			if h1:
				h1.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			var h2 := tw3c.tween_property(flame_core, "scale:x", 0.7, 0.06)
			if h2:
				h2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# gentle float of the ship (keeps its tilt)
	if ship_anchor != null:
		var base_y: float = ship_anchor.position.y
		var tw4 := create_tween()
		if tw4 != null:
			tw4.set_loops()
			var s1 := tw4.tween_property(ship_anchor, "position:y", base_y + 14.0, 2.2)
			if s1:
				s1.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			var s2 := tw4.tween_property(ship_anchor, "position:y", base_y, 2.2)
			if s2:
				s2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	time += delta
	# background drifts gently on the diagonal
	scroll += delta * 14.0
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
