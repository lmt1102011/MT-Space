extends RefCounted

# Real sound effects (CC0) from res://assets/sfx - one sound per event.
# Files are loaded at runtime so a pending editor import can never break
# parsing.

const POOL := 16
const MASTER_DB := 0.0

# Minimum gap between two plays of the same sound, in seconds. Without this a
# rapid fire weapon turns into an endless "tick tick tick" that gets painful.
const MIN_GAP := {
	"shoot": 0.13,
	"hit": 0.05,
	"blip": 0.045,
	"boom": 0.06,
	"shatter": 0.06,
	"crunch": 0.06,
	"frost": 0.15,
	"click": 0.08,
}

const BANK_PATHS := {
	"alert": ["res://assets/sfx/alert.mp3"],
	"blip": ["res://assets/sfx/blip.mp3"],
	"boom": ["res://assets/sfx/boom.ogg"],
	"boom_big": ["res://assets/sfx/boom_big.ogg"],
	"card": ["res://assets/sfx/card.mp3"],
	"cardget": ["res://assets/sfx/cardget.ogg"],
	"charge": ["res://assets/sfx/charge.ogg"],
	"chime": ["res://assets/sfx/chime.mp3"],
	"click": ["res://assets/sfx/click.mp3"],
	"crunch": ["res://assets/sfx/crunch.ogg"],
	"dash": ["res://assets/sfx/dash.mp3"],
	"elite": ["res://assets/sfx/elite.ogg"],
	"fanfare": ["res://assets/sfx/fanfare.mp3"],
	"frost": ["res://assets/sfx/frost.mp3"],
	"hit": ["res://assets/sfx/hit.ogg"],
	"laser": ["res://assets/sfx/laser.ogg"],
	"shatter": ["res://assets/sfx/shatter.ogg"],
	"shoot": ["res://assets/sfx/shoot.ogg"],
	"sizzle": ["res://assets/sfx/sizzle.mp3"],
}

static var enabled: bool = true
# the volume the player picked in the settings, from 0 to 1
static var master_volume: float = 1.0
static var _players: Array = []
static var _idx: int = 0
static var _bank: Dictionary = {}
static var _last: Dictionary = {}


# Called by Game once the player pool exists.
static func setup(players: Array) -> void:
	_players = players
	if _bank.is_empty():
		_load_bank()


static func _load_bank() -> void:
	for key in BANK_PATHS.keys():
		var arr: Array = []
		var paths: Array = BANK_PATHS[key]
		for p in paths:
			var res: Resource = load(str(p))
			if res != null:
				arr.append(res)
		_bank[key] = arr


static func play(sound: String, volume_db: float = 0.0,
		pitch_lo: float = 0.93, pitch_hi: float = 1.09) -> void:
	if not enabled or _players.is_empty():
		return
	# rate limit: a machine gun must not machine-gun the sound
	var gap := int(float(MIN_GAP.get(sound, 0.0)) * 1000.0)
	if gap > 0:
		var now := Time.get_ticks_msec()
		var last: int = int(_last.get(sound, -100000))
		if now - last < gap:
			return
		_last[sound] = now
	if _bank.is_empty():
		_load_bank()
	var list: Array = _bank.get(sound, [])
	if list.is_empty():
		return
	var p: AudioStreamPlayer = _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = list[0]
	p.volume_db = volume_db + _master_db()
	# only a tiny pitch jitter so rapid repeats never phase match
	var mid := (pitch_lo + pitch_hi) * 0.5
	var half := (pitch_hi - pitch_lo) * 0.18
	p.pitch_scale = randf_range(mid - half, mid + half)
	p.play()


# The volume of the player, turned into the decibel the players use.
static func _master_db() -> float:
	if master_volume <= 0.001:
		return -80.0
	return linear_to_db(clampf(master_volume, 0.0, 1.0))
