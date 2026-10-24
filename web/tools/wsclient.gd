extends Node2D

# The client: joins the websocket room.
#
# Usage: godot --headless --path <project> res://tools/wsclient.tscn

var _frames: int = 0


func _ready() -> void:
	Net.player_name = "WSCLIENT"
	var ok := Net.join_room("127.0.0.1", 27563, true)
	print("client: joining ok=", ok)
	# the udp discovery is not needed for this test
	if Net._discovery != null:
		Net._discovery.close()
		Net._discovery = null
		print("client: discovery turned off")


func _process(_delta: float) -> void:
	_frames += 1
	if _frames % 30 == 0:
		print("client: t=", _frames, " online=", Net.is_online(), " status=", Net._peer.get_connection_status() if Net._peer != null else -1)
	if _frames == 200:
		print("client: online=", Net.is_online(), " players=", Net.players.size())
	if _frames == 700:
		var names: Array = []
		for p in Net.players:
			names.append(str(p["name"]))
		print("client: online=", Net.is_online(), " names=", names)
	if _frames > 900:
		get_tree().quit(0)
