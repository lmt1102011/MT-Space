extends RefCounted
class_name WebEnemyBrain

# A small behavior state machine that makes enemies manoeuvre like a player:
# they approach, strafe at a comfortable range, occasionally flank, retreat when
# hurt or crowded, and always avoid obstacles / dodge bullets (via WebEnemyAI).
#
# The output velocity is damped over time so movement feels smooth and carries
# momentum instead of snapping between directions.

enum State { APPROACH, STRAFE, FLANK, RETREAT }

var state: int = State.APPROACH
var _timer: float = 0.0
var _strafe_dir: float = 1.0
var _flank_point: Vector2 = Vector2.ZERO
var _vel: Vector2 = Vector2.ZERO          # smoothed velocity
var _strafe_bias: float = 1.0             # eases between -1..1 for gentle turns
var _wander_dir: Vector2 = Vector2.ZERO
var _wander_t: float = 0.0

const APPROACH_DIST := 360.0    # comfortable orbit radius
const MIN_DIST := 210.0         # back off closer than this
const FAR_DIST := 620.0         # re-approach beyond this
const ACCEL := 3.2              # how quickly velocity chases the goal

# Idle strolling, used once the player is down: the enemies just walk about.
func wander(speed: float, delta: float) -> Vector2:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.2, 3.2)
		_wander_dir = Vector2.from_angle(randf() * TAU)
	# slow down a bit every now and then, like a living thing ambling about
	var factor := 0.55 if randf() < 0.3 else 1.0
	return _wander_dir * speed * 0.5 * factor


func _decide(dist: float) -> void:
	var pick := randf()
	if dist < MIN_DIST:
		state = State.RETREAT
		_timer = randf_range(0.6, 1.1)
	elif dist > FAR_DIST:
		state = State.APPROACH
		_timer = randf_range(0.6, 1.2)
	elif pick < 0.28:
		state = State.FLANK
		_flank_point = Vector2.ZERO
		_timer = randf_range(0.9, 1.6)
	else:
		state = State.STRAFE
		_timer = randf_range(1.0, 1.8)
	# pick a new strafe direction, but ease into it rather than snapping
	if randf() < 0.6:
		_strafe_dir = -_strafe_dir


func _goal(self_pos: Vector2, player_pos: Vector2, speed: float) -> Vector2:
	var to_player := player_pos - self_pos
	var dist := to_player.length()
	var dir := to_player / maxf(dist, 0.001)

	match state:
		State.APPROACH:
			var sway := dir.orthogonal() * sin(Time.get_ticks_msec() * 0.0022) * 0.22
			return (dir + sway).normalized() * speed
		State.RETREAT:
			return (-dir + dir.orthogonal() * 0.35 * _strafe_dir).normalized() * speed
		State.FLANK:
			if _flank_point == Vector2.ZERO:
				_flank_point = player_pos + Vector2.from_angle(randf() * TAU) * randf_range(260.0, 420.0)
			var to_pt := _flank_point - self_pos
			if to_pt.length() < 50.0:
				_flank_point = Vector2.ZERO
				return dir.orthogonal() * _strafe_dir * speed
			return to_pt.normalized() * speed
		_:  # STRAFE
			var tangent := dir.orthogonal() * _strafe_dir
			var radial := dir * ((dist - APPROACH_DIST) / APPROACH_DIST)
			return (tangent + radial * 0.7).normalized() * speed


# Returns a smoothed desired velocity (direction * speed) for this frame.
func move(self_pos: Vector2, player_pos: Vector2, speed: float, delta: float) -> Vector2:
	var to_player := player_pos - self_pos
	var dist := to_player.length()

	_timer -= delta
	if _timer <= 0.0:
		_decide(dist)

	# ease the strafe bias toward the chosen direction for gentle turns
	_strafe_bias = lerpf(_strafe_bias, _strafe_dir, clampf(4.0 * delta, 0.0, 1.0))

	var goal := _goal(self_pos, player_pos, speed)
	_vel = _vel.lerp(goal, clampf(ACCEL * delta, 0.0, 1.0))
	return _vel
