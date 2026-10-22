extends Node2D

# Checks the parts of the network layer that work inside one process:
#  - the host opens a room and finds it on the network
#  - the player list knows who is in the room
#  - the names and colours of the players are looked up correctly
#
# The real connection is checked by tools/nethost.tscn and tools/netclient.tscn,
# which run as two separate processes.
#
# Usage: godot --headless --path <project> res://tools/nettest.tscn

var _fails := 0


func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS  ", label)
	else:
		_fails += 1
		print("FAIL  ", label)


func _ready() -> void:
	print("=== net check ===")
	await _check_discovery()
	await _check_players()
	print("=== done: %d failure(s) ===" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


# The host answers the client that asks around.
func _check_discovery() -> void:
	Net.player_name = "HOST"
	_ok(Net.host_room("TEST ROOM", 27555), "the host can open a port")
	_ok(Net.is_host(), "the host knows it is the host")
	# give the discovery a moment to answer
	for i in 30:
		await get_tree().process_frame
	_ok(Net.rooms.size() > 0, "the host sees its own room on the network")
	# a client asking around finds it
	var asker := PacketPeerUDP.new()
	asker.bind(0)
	asker.set_dest_address("127.0.0.1", Net.DISCOVERY_PORT)
	asker.put_packet("MTDISC?".to_utf8_buffer())
	for i in 30:
		await get_tree().process_frame
		if asker.get_available_packet_count() > 0:
			var text := asker.get_packet().get_string_from_utf8()
			if text.begins_with("MTROOM:"):
				_ok(text.contains("TEST ROOM"), "the client receives the room info")
				break
	asker.close()


# The player list knows who is in the room.
func _check_players() -> void:
	_ok(Net.players.size() == 1, "the host is alone in the room")
	_ok(Net.player_name_of(Net.my_id()) == "HOST", "the host knows its own name")
	_ok(Net.player_color_of(Net.my_id()).a > 0.0, "the host has a colour")

	# a second player joins
	Net.players.append({"id": 4242, "name": "GUEST", "color": Color.RED})
	_ok(Net.players.size() == 2, "the guest is in the room")
	_ok(Net.player_name_of(4242) == "GUEST", "the guest name is looked up")
	_ok(Net.player_name_of(9999) == "?", "an unknown player has no name")

	# the host leaves, the room is gone
	Net.leave()
	_ok(Net.players.is_empty(), "leaving clears the player list")
	_ok(not Net.is_online(), "leaving ends the session")
