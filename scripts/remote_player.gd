extends Node2D

# Another player's ship. It does not think for itself: it chases the position
# the network told it about, which keeps the movement smooth even though the
# updates only arrive a few times a second.

# how fast the ship catches up with the position it was told about
const FOLLOW_SPEED := 14.0
# the rotation is followed a bit slower so it does not snap
const FOLLOW_TURN := 10.0

var net_id: int = 0
var net_name: String = ""
var net_color: Color = Color.WHITE
var net_hp: float = 1.0
var net_alive: bool = true

var _net_target: Vector2 = Vector2.ZERO
var _net_rot: float = 0.0
var _sprite: Sprite2D = null
var _name_label: Label = null


func _ready() -> void:
	_sprite = $Ship
	_sprite.modulate = net_color
	_name_label = $Name
	_refresh_name()
	_name_label.add_theme_color_override("font_color", net_color)
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_name_label.add_theme_constant_override("outline_size", 3)


# The name can arrive after the ship was made, so it is set here too.
func _refresh_name() -> void:
	if _name_label != null:
		_name_label.text = net_name


func _process(delta: float) -> void:
	# walk towards the position the network gave us, never jump to it
	var t := clampf(FOLLOW_SPEED * delta, 0.0, 1.0)
	var to := _net_target - global_position
	var step := to * t
	# never move further in one frame than the ship could travel, so a long
	# distance is walked over instead of teleported
	var limit := 900.0 * minf(delta, 1.0 / 60.0)
	if step.length() > limit:
		step = step.normalized() * limit
	global_position += step
	rotation = lerp_angle(rotation, _net_rot, clampf(FOLLOW_TURN * delta, 0.0, 1.0))
	# the ship fades out when its owner dies
	var want := 1.0 if net_alive else 0.25
	_sprite.modulate.a = lerpf(_sprite.modulate.a, want, 0.1)
