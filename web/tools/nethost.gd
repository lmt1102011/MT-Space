extends Node2D

# A tiny host that opens a room and waits for a client to join.
# It is started by the net test.
# Usage: godot --headless --path <project> res://tools/nethost.tscn

var _frames: int = 0


func _ready() -> void:
	Net.player_name = "HOST"
	var ok := Net.host_room("TEST ROOM", 27562)
	print("host: opened=%s players=%d" % [ok, Net.players.size()])


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 60:
		print("host: players=%d t=%.2f" % [Net.players.size(), Time.get_ticks_msec()/1000.0])
		for p in Net.players:
			print("   ", p)
	if _frames == 700:
		print("host: joined=%d names=%s t=%.2f" % [Net.players.size(), _names(), Time.get_ticks_msec()/1000.0])
	if _frames == 1600:
		print("host: late joined=%d names=%s t=%.2f" % [Net.players.size(), _names(), Time.get_ticks_msec()/1000.0])
	if _frames > 2400:
		get_tree().quit(0)


func _names() -> String:
	var out: Array = []
	for p in Net.players:
		out.append(str(p["name"]))
	return str(out)
