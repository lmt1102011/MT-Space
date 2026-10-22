extends Control

const IconBank := preload("res://scripts/icon_bank.gd")

signal chosen(card: Dictionary)

var card: Dictionary = {}
var _index: int = 0
var _hovered: bool = false

const CARD_SIZE := Vector2(200.0, 280.0)
const CORNER := 14.0
const PAD := 16.0
const PLATE_SIZE := 88.0
const TEXT_BOTTOM := 252.0

# --- palette -------------------------------------------------------------
const BODY := Color(0.082, 0.090, 0.115, 1.0)
const INK := Color(0.93, 0.95, 0.97)
const INK_DIM := Color(0.56, 0.61, 0.68)
const INK_FAINT := Color(1.0, 1.0, 1.0, 0.07)
const GOOD := Color(0.52, 0.84, 0.60)
const BAD := Color(0.95, 0.48, 0.48)

# --- semantic icon palette (colour tells you what the card does) ---------
const C_GOLD := Color(1.0, 0.84, 0.36)     # energy, precision
const C_FIRE := Color(1.0, 0.48, 0.13)     # heat
const C_ICE := Color(0.46, 0.80, 1.0)      # cold, speed
const C_STEEL := Color(0.64, 0.74, 0.92)   # metal, piercing
const C_LIFE := Color(0.45, 0.90, 0.58)    # healing, xp
const C_BLOOD := Color(0.96, 0.34, 0.44)    # impact, lifesteal

static var _font_bold: FontVariation = null
static var _font_label: FontVariation = null


static func title_font() -> FontVariation:
	if _font_bold == null:
		_font_bold = FontVariation.new()
		_font_bold.base_font = ThemeDB.fallback_font
		_font_bold.variation_embolden = 0.3
	return _font_bold


static func label_font() -> FontVariation:
	if _font_label == null:
		_font_label = FontVariation.new()
		_font_label.base_font = ThemeDB.fallback_font
		_font_label.spacing_glyph = 2
	return _font_label


func setup(data: Dictionary, index: int) -> void:
	card = data
	_index = index
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _set_hovered(true))
	mouse_exited.connect(func(): _set_hovered(false))
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_emit()


func _emit() -> void:
	chosen.emit(card)


func _set_hovered(value: bool) -> void:
	if _hovered != value:
		_hovered = value
		queue_redraw()


func _ready() -> void:
	queue_redraw()


# -------------------------------------------------------------------------
# drawing helpers
# -------------------------------------------------------------------------
func _round(color: Color, radius: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(int(radius))
	return s


func _soft_rect(rect: Rect2, color: Color, radius: float) -> void:
	draw_style_box(_round(color, radius), rect)


# -------------------------------------------------------------------------
func _draw() -> void:
	var rarity: int = card.get("rarity", CardDB.Rarity.COMMON)
	var col: Color = CardDB.rarity_color(rarity)
	var body := Rect2(Vector2.ZERO, CARD_SIZE)

	# --- card surface -----------------------------------------------------
	draw_style_box(_round(BODY, CORNER), body)
	draw_style_box(_round_transparent(col.lightened(0.1), CORNER, 1.0), body)

	var card_name: String = card.get("name", "")
	var desc: String = card.get("desc", "")
	var pros: String = card.get("pros", "")
	var cons: String = card.get("cons", "")

	var text_font := ThemeDB.fallback_font
	var text_w := CARD_SIZE.x - PAD * 2.0
	var desc_h := 0.0
	if desc != "":
		desc_h = text_font.get_multiline_string_size(
			desc, HORIZONTAL_ALIGNMENT_LEFT, text_w, 13, 3).y

	# --- vertical flow: text block is bottom aligned ----------------------
	var block_h := 25.0 + desc_h
	if desc != "":
		block_h += 6.0
	if pros != "":
		block_h += 17.0
	if cons != "":
		block_h += 17.0
	var name_y := TEXT_BOTTOM - block_h

	# --- rarity tag --------------------------------------------------------
	var rname: String = CardDB.RARITY_NAMES.get(rarity, "")
	draw_circle(Vector2(PAD + 3.0, 19.0), 3.0, col)
	draw_string(label_font(), Vector2(PAD + 12.0, 23.0), rname,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col.lightened(0.25))

	# --- icon plate --------------------------------------------------------
	var icon_col := _icon_color(card.get("id", ""), col)
	var plate_top := 32.0
	var plate_bottom := name_y - 18.0
	var plate_h := minf(PLATE_SIZE, maxf(0.0, plate_bottom - plate_top))
	var plate_y := plate_top + maxf(0.0, (plate_bottom - plate_top - plate_h) * 0.5)
	var plate := Rect2(Vector2((CARD_SIZE.x - PLATE_SIZE) * 0.5, plate_y),
		Vector2(PLATE_SIZE, PLATE_SIZE))
	_soft_rect(plate, Color(icon_col.r, icon_col.g, icon_col.b, 0.11), 18.0)
	draw_style_box(_round_transparent(Color(icon_col.r, icon_col.g, icon_col.b, 0.24), 18.0, 1.0), plate)

	var icon_c := plate.position + plate.size * 0.5
	_draw_icon(icon_c, icon_col)

	# --- name --------------------------------------------------------------
	draw_string(title_font(), Vector2(PAD, name_y), card_name,
		HORIZONTAL_ALIGNMENT_LEFT, text_w, 20, INK)

	# --- description -------------------------------------------------------
	var y := name_y + 25.0
	if desc != "":
		draw_multiline_string(text_font, Vector2(PAD, y), desc,
			HORIZONTAL_ALIGNMENT_LEFT, text_w, 13, 3, INK_DIM)
		y += desc_h + 6.0

	# --- pros / cons -------------------------------------------------------
	if pros != "" or cons != "":
		draw_line(Vector2(PAD, y - 6.0), Vector2(CARD_SIZE.x - PAD, y - 6.0), INK_FAINT, 1.0)
	if pros != "":
		draw_circle(Vector2(PAD + 3.0, y + 1.0), 2.5, GOOD)
		draw_string(text_font, Vector2(PAD + 12.0, y + 5.0), pros,
			HORIZONTAL_ALIGNMENT_LEFT, text_w - 12.0, 12, GOOD)
		y += 17.0
	if cons != "":
		draw_circle(Vector2(PAD + 3.0, y + 1.0), 2.5, BAD)
		draw_string(text_font, Vector2(PAD + 12.0, y + 5.0), cons,
			HORIZONTAL_ALIGNMENT_LEFT, text_w - 12.0, 12, BAD)
		y += 17.0


func _round_transparent(color: Color, radius: float, width: float) -> StyleBoxFlat:
	var s := _round(color, radius)
	s.draw_center = false
	s.border_color = color
	s.set_border_width_all(int(width))
	return s


func _icon_color(id: String, rarity_col: Color) -> Color:
	match id:
		"fire_rate", "crit", "weapon_shotgun", "weapon_burst":
			return C_GOLD
		"bullet_speed", "burn", "weapon_twin_cannon":
			return C_FIRE
		"move_speed", "freeze", "weapon_railgun":
			return C_ICE
		"damage", "lifesteal":
			return C_BLOOD
		"orb_magnet", "max_hp", "regen":
			return C_LIFE
		"pierce", "weapon_machine_gun":
			return C_STEEL
		# --- new cards ---
		"homing":
			return C_ICE
		"splash":
			return C_GOLD
		"elite_hunter":
			return C_GOLD
		"bloodthirst":
			return C_BLOOD
		"plating":
			return C_STEEL
		"level_heal":
			return C_LIFE
		"xp_greed":
			return C_LIFE
		"inferno":
			return C_FIRE
		"brittle":
			return C_ICE
		"thorns":
			return C_STEEL
		"pierce_focus":
			return C_GOLD
		"explosive":
			return C_FIRE
		"scavenger":
			return C_GOLD
		"rushed":
			return C_ICE
		"heavy_caliber":
			return C_STEEL
		"second_chance":
			return C_LIFE
		"cold_blood":
			return C_BLOOD
	return rarity_col


# -------------------------------------------------------------------------
# illustrations - the pictograms are real images, tinted to the card colour
# -------------------------------------------------------------------------
func _draw_icon(c: Vector2, col: Color) -> void:
	var tex := IconBank.get_icon(card.get("id", ""))
	if tex == null:
		return
	# the icons are drawn in a 64x64 box
	var s := 64.0
	var rect := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
	draw_texture_rect(tex, rect, false, col)
