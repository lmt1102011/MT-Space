extends Node2D

# The host: opens a room that speaks websocket, so a browser can join it.
#
# Usage: godot --headless --path <project> res://tools/wshost.tscn

var _frames: int = 0


func _ready() -> void:
	Net.player_name = "WSHOST"
	var ok := Net.host_room("WS ROOM", 27563, true)
	print("host: opened=", ok, " web_mode=", Net.is_web_mode(), " players=", Net.players.size())


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 60:
		print("host: players=", Net.players.size(), " t=%.2f" % (Time.get_ticks_msec() / 1000.0))
	if _frames == 700:
		var names: Array = []
		for p in Net.players:
			names.append(str(p["name"]))
		print("host: joined=", Net.players.size(), " names=", names)
	if _frames > 900:
		get_tree().quit(0)
