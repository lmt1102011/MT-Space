extends Node2D

# A tiny client that joins a room and then reports what it sees.
# It is started by the net test with the address of the host.
# Usage: godot --headless --path <project> res://tools/netclient.tscn -- <address> <port>

var _addr: String = "127.0.0.1"
var _port: int = 27562
var _frames: int = 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_port = int(a)
		elif a.contains("."):
			_addr = a
	Net.player_name = "CLIENT"
	print("client: joining %s:%d" % [_addr, _port])
	Net.join_room(_addr, _port)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 200:
		print("client: connected=%s players=%d" % [Net.is_online(), Net.players.size()])
		for p in Net.players:
			print("   ", p)
	if _frames == 700:
		# still online after a while, and we know the names of everybody
		print("client: still online=%s names=%s" % [Net.is_online(), _names()])
	if _frames == 1200:
		print("client: late online=%s names=%s" % [Net.is_online(), _names()])
	if _frames > 1500:
		get_tree().quit(0)


func _names() -> String:
	var out: Array = []
	for p in Net.players:
		out.append(str(p["name"]))
	return str(out)
