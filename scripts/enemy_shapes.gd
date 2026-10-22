extends RefCounted

# The two reference drawings are used directly as textures, exactly like
# player.svg and double_enemy.svg. That way the enemies look precisely like
# the artwork - every bezier curve, and the fins of the charger overlapping
# the body, are rendered by the SVG importer itself.
# Shared by the enemies and the menu diorama so both always look identical.
# Deliberately no class_name: referenced through a plain preload so it never
# depends on the editor's global class cache.

const RAILGUN_TEX := preload("res://assets/railgun_enemy.svg")
const CHARGER_TEX := preload("res://assets/charger_enemy.svg")

# the shape enemies are regular polygons, one image per side count
const SHAPE_TEX := {
	3: preload("res://assets/shape_3.svg"),
	4: preload("res://assets/shape_4.svg"),
	5: preload("res://assets/shape_5.svg"),
	6: preload("res://assets/shape_6.svg"),
}
const XP_ORB_GLOW_TEX := preload("res://assets/xp_orb_glow.svg")
const XP_ORB_GEM_TEX := preload("res://assets/xp_orb_gem.svg")
const UPGRADE_DROP_TEX := preload("res://assets/upgrade_drop.svg")
const UPGRADE_GLOW_TEX := preload("res://assets/upgrade_glow.svg")

# The artwork is 75.66 x 31.12 units (railgun) and 75.80 x 23.06 (charger).
# The textures are imported at 8x, so these scales give the ships the size
# they had when the art was first drawn.
const RAILGUN_SCALE := 0.15
const CHARGER_SCALE := 0.1375

# the drawn width of each ship, in pixels
const RAILGUN_WIDTH := 90.8
const CHARGER_WIDTH := 83.4

# the distance from the centre to the nose, in pixels
const RAILGUN_NOSE := 45.4
const CHARGER_NOSE := 41.7

const SHOOTER_SCALE := 0.2
const DOUBLE_SCALE := 0.22
const SHOOTER_COLOR := Color(1, 0.15, 0.15, 1)
const DOUBLE_COLOR := Color(1, 0.6, 0.15, 1)
const RAILGUN_COLOR := Color(0.6, 0.4, 1.0)
const CHARGER_COLOR := Color(0.408, 1.0, 0.2)
const HULL_EDGE := Color(0.05, 0.05, 0.08, 0.85)
const ELITE_EDGE := Color(0.95, 0.8, 0.3, 0.95)


# Builds the sprite for one of the two ships. The artwork is centred on the
# sprite so the ship rotates around its middle.
static func make_ship(tex: Texture2D, scale: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(scale, scale)
	return sprite


# The shape enemy's hull, drawn from the image that matches its side count.
# The images are 64x64 with a polygon of radius 29 in the middle, so the
# sprite is scaled to turn that into the wanted radius.
static func make_shape(sides: int, radius: float, color: Color) -> Sprite2D:
	var tex: Texture2D = SHAPE_TEX.get(sides, SHAPE_TEX[5])
	var sprite := Sprite2D.new()
	sprite.texture = tex
	var s := radius / 29.0
	sprite.scale = Vector2(s, s)
	sprite.modulate = color
	return sprite


static func shape_color(sides: int) -> Color:
	var hue := float(sides - 3) / 4.0
	return Color.from_hsv(0.45 + hue * 0.25, 0.65, 0.85)


# ---------------------------------------------------------------------------
# Baked drawing helpers.
# A Polygon2D / Line2D triangulates and caches its mesh once, so the per frame
# cost drops to a single mesh draw instead of re-triangulating every frame.
# ---------------------------------------------------------------------------
static func make_poly(path: Array, scl: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for p: Vector2 in path:
		pts.append(p * scl)
	poly.polygon = pts
	poly.color = color
	return poly


static func make_outline(path: Array, scl: float, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	var pts := PackedVector2Array()
	for p: Vector2 in path:
		pts.append(p * scl)
	line.points = pts
	line.closed = true
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	return line
