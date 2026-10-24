extends Node

# The network layer for the co-op mode.
#
# The player who creates a room is the host: their machine runs the ENet
# server and owns the world (waves, enemies, damage). Everybody else joins
# as a client and receives the state of the world from the host.
#
# Rooms are found on the local network with a small UDP broadcast: a client
# asks around, the host answers directly, so several instances can run on
# one machine without fighting over a port.

const DEFAULT_PORT := 27015
const DISCOVERY_PORT := 27016
const MAX_PLAYERS := 4
const XP_DROP := preload("res://scripts/xp_pickup.gd")
# a room that stopped answering is dropped after this many seconds
const ROOM_TTL := 15.0
# how often the local player sends its position
const NET_TICK := 1.0 / 20.0
# how often the host sends the enemy positions
const ENEMY_TICK := 1.0 / 15.0

const PLAYER_COLORS := [
	Color(0.45, 0.85, 1.0), Color(1.0, 0.6, 0.35),
	Color(0.6, 1.0, 0.55), Color(1.0, 0.55, 0.9),
]

signal players_changed()
signal room_joined()
signal room_left()
signal rooms_changed()
signal session_failed(reason: String)
signal player_name_taken()

# --- local state ------------------------------------------------------------
# the name of the local player, empty until they are asked for it
var player_name: String = ""
var room_name: String = ""
# the players of the current room: {id, name, color}
var players: Array = []
# the rooms found on the network: {name, address, port, count, seen}
var rooms: Array = []
# the world node, set by the game scene
var world: Node = null

var _peer: MultiplayerPeer = null
# the multiplayer api of the scene tree, the net node uses it for the rpcs
var _api: MultiplayerAPI = null
var _hosting: bool = false
var _room_port: int = DEFAULT_PORT
# true when the room speaks websocket instead of enet
var _web_mode: bool = false
var _discovery: PacketPeerUDP = null
var _disc_timer: float = 0.0
var _unicast_scan_timer: float = 0.0
var _unicast_scan_targets: Array[String] = []
var _unicast_scan_index: int = 0
var _net_timer: float = 0.0
var _enemy_timer: float = 0.0
var _next_enemy_id: int = 1
# how often the client says hello again until the host knows it
var _hello_timer: float = 0.0
# true while a session is being torn down, the old callbacks are ignored
var _closing: bool = false
# true while the client is still waiting to be let into the room
var _wait_for_hello: bool = false
var name_change_required: bool = false
# the room this client wants to be in, so it can come back after a drop
var _last_address: String = ""
var _last_port: int = DEFAULT_PORT
var _last_web: bool = false
# how long to wait before trying to get back into the room
const RECONNECT_WAIT := 3.0
var _reconnect_timer: float = 0.0
# true while the client is trying to get back into the room
var _reconnecting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# Puts the peer into the multiplayer api of the scene tree.
#
# The api of the tree is used on purpose: the Net node is an autoload and has
# already grabbed the api of the tree when it was added, so swapping the api
# would leave the rpcs pointing at an api nobody polls.
func _new_api(peer: MultiplayerPeer) -> void:
	_api = get_tree().get_multiplayer()
	_api.multiplayer_peer = peer
	_api.peer_connected.connect(_on_peer_connected)
	_api.peer_disconnected.connect(_on_peer_disconnected)
	_api.connected_to_server.connect(_on_connected_to_server)
	_api.connection_failed.connect(_on_connection_failed)
	_api.server_disconnected.connect(_on_server_disconnected)
	# the peer is live again, its callbacks count from now on
	_closing = false


# Unhooks the api of the session that is about to end, so its late callbacks
# cannot disturb the session that replaces it.
func _drop_api() -> void:
	if _api == null:
		return
	if _api.peer_connected.is_connected(_on_peer_connected):
		_api.peer_connected.disconnect(_on_peer_connected)
	if _api.peer_disconnected.is_connected(_on_peer_disconnected):
		_api.peer_disconnected.disconnect(_on_peer_disconnected)
	if _api.connected_to_server.is_connected(_on_connected_to_server):
		_api.connected_to_server.disconnect(_on_connected_to_server)
	if _api.connection_failed.is_connected(_on_connection_failed):
		_api.connection_failed.disconnect(_on_connection_failed)
	if _api.server_disconnected.is_connected(_on_server_disconnected):
		_api.server_disconnected.disconnect(_on_server_disconnected)
	_api = null


# --- queries ----------------------------------------------------------------
func is_online() -> bool:
	return _peer != null


func is_host() -> bool:
	return _hosting


# True when this build cannot talk to the network: the web has no raw udp
# sockets, so only one player can play there.
func is_network_available() -> bool:
	return not OS.has_feature("web")


# A browser cannot listen on a port, so a room always needs a desktop host.
func can_host() -> bool:
	return not OS.has_feature("web")


# A browser can still be a player, it just needs a room that speaks websocket.
func can_join() -> bool:
	return true


func browse_rooms() -> void:
	if is_online() or OS.has_feature("web"):
		return
	if _discovery == null:
		_start_discovery(false)


func refresh_rooms() -> void:
	if is_online() or OS.has_feature("web"):
		return
	rooms.clear()
	rooms_changed.emit()
	_start_discovery(false)


# True when the room uses websocket instead of the faster enet.
func is_web_mode() -> bool:
	return _web_mode


func my_id() -> int:
	# the peer is the only thing that knows our number
	if _peer != null:
		return _peer.get_unique_id()
	return 1


# --- hosting / joining ------------------------------------------------------
# Creates a room. The caller becomes the host and owns the world.
#
# The room speaks enet by default, that is the fast one. A room that speaks
# websocket can be joined from a browser, because a browser cannot open a
# udp port.
func host_room(name: String, port: int = DEFAULT_PORT, web_mode: bool = false) -> bool:
	if not can_host():
		session_failed.emit("a browser cannot host a room")
		return false
	_reset_session()
	var peer: MultiplayerPeer = null
	if web_mode:
		var ws := WebSocketMultiplayerPeer.new()
		# the default of three seconds is too tight for a slow network
		ws.set_handshake_timeout(30.0)
		var werr := ws.create_server(port, "0.0.0.0", null)
		if werr != OK:
			session_failed.emit("could not open port %d" % port)
			return false
		peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		var eerr := enet.create_server(port, MAX_PLAYERS)
		if eerr != OK:
			session_failed.emit("could not open port %d" % port)
			return false
		peer = enet
	_peer = peer
	_web_mode = web_mode
	_room_port = port
	# the flag is set before the api, so nothing thinks it is a client
	_hosting = true
	_new_api(peer)
	room_name = name
	players = [{"id": my_id(), "name": _my_name(), "color": _color_for(0)}]
	_start_discovery(true)
	room_joined.emit()
	_broadcast_players()
	_add_own_room()
	players_changed.emit()
	return true


# Joins a room on the given address.
func join_room(address: String, port: int = DEFAULT_PORT, web_mode: bool = false) -> bool:
	if not can_join():
		session_failed.emit("multiplayer is not available here")
		return false
	_reset_session()
	# the address is remembered, so the game can come back after a drop
	_last_address = address
	_last_port = port
	_last_web = web_mode
	var peer: MultiplayerPeer = null
	if web_mode:
		var ws := WebSocketMultiplayerPeer.new()
		ws.set_handshake_timeout(30.0)
		var werr := ws.create_client(_ws_url(address, port), null)
		if werr != OK:
			session_failed.emit("cannot reach %s" % address)
			return false
		peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		var eerr := enet.create_client(address, port)
		if eerr != OK:
			session_failed.emit("cannot reach %s:%d" % [address, port])
			return false
		peer = enet
	_peer = peer
	_web_mode = web_mode
	# the flag is set before the api, so nothing thinks it is a host
	_hosting = false
	_new_api(peer)
	room_name = ""
	players = []
	_start_discovery(false)
	return true


# The address of a websocket room, the scheme is added when it is missing.
func _ws_url(address: String, port: int) -> String:
	if address.begins_with("ws://") or address.begins_with("wss://"):
		return address
	return "ws://%s:%d" % [address, port]


# Tries to get back into the room after the connection broke.
func _reconnect() -> void:
	if _last_address == "" or _hosting:
		return
	var address := _last_address
	var port := _last_port
	var web := _last_web
	_reset_session()
	_last_address = address
	_last_port = port
	_last_web = web
	# the flag is set before the api, so nothing thinks it is a host
	_hosting = false
	var peer: MultiplayerPeer = null
	if web:
		var ws := WebSocketMultiplayerPeer.new()
		ws.set_handshake_timeout(30.0)
		if ws.create_client(_ws_url(address, port), null) != OK:
			return
		peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		if enet.create_client(address, port) != OK:
			return
		peer = enet
	_peer = peer
	_web_mode = web
	_new_api(peer)
	_wait_for_hello = true
	_hello_timer = 0.0
	_start_discovery(false)


# Leaves the room the player asked to leave.
func leave() -> void:
	_reconnecting = false
	name_change_required = false
	_last_address = ""
	_reset_session()
	rooms.clear()
	rooms_changed.emit()
	players_changed.emit()
	room_left.emit()
	# the callbacks of the peer that just went away are ignored, the session
	# is really over: the flag is cleared a frame later
	_closing = false


# Drops the current session without telling anybody. Used when a new session
# is about to start, so the old peer cannot fire its late callbacks.
func _reset_session() -> void:
	# the callbacks of the peer that is going away are ignored from now on
	_closing = true
	if _peer != null:
		_peer.close()
		_peer = null
	# the old api goes away with it, its signals cannot disturb anything
	_drop_api()
	_hosting = false
	_web_mode = false
	name_change_required = false
	room_name = ""
	players = []
	if _discovery != null:
		_discovery.close()
		_discovery = null


# --- room discovery ---------------------------------------------------------
func _start_discovery(hosting: bool) -> void:
	# the web has no udp sockets, so there is nothing to look for there
	if not is_network_available():
		_discovery = null
		return
	if _discovery != null:
		_discovery.close()
	_discovery = PacketPeerUDP.new()
	var err := OK
	if hosting:
		# the host listens on the well known port and answers the clients
		err = _discovery.bind(DISCOVERY_PORT)
	else:
		# a client listens on any free port and asks around
		err = _discovery.bind(0)
	if err != OK:
		_discovery = null
		return
	# a socket may not send to a broadcast address unless it is allowed to
	_discovery.set_broadcast_enabled(true)
	_disc_timer = 0.0
	_unicast_scan_timer = 0.0
	_unicast_scan_index = 0
	_unicast_scan_targets = _local_subnet_targets() if not hosting else []


func _local_subnet_targets() -> Array[String]:
	var targets: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.contains(":") or ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		var parts := ip.split(".")
		if parts.size() != 4:
			continue
		var prefix := "%s.%s.%s." % [parts[0], parts[1], parts[2]]
		for host in range(1, 255):
			var target := prefix + str(host)
			if not targets.has(target):
				targets.append(target)
	return targets


# Every address a discovery packet should go to. The global broadcast works on
# most networks, the subnet ones get around routers that drop it.
func _broadcast_targets() -> Array:
	var out: Array = ["255.255.255.255"]
	for ip in IP.get_local_addresses():
		if ip.contains(":") or ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		var parts := ip.split(".")
		if parts.size() != 4:
			continue
		var base := "%s.%s.%s" % [parts[0], parts[1], parts[2]]
		var subnet := base + ".255"
		if not out.has(subnet):
			out.append(subnet)
		# a /16 network uses this one, it does no harm on a /24
		var wide := "%s.%s.255.255" % [parts[0], parts[1]]
		if not out.has(wide):
			out.append(wide)
	return out


# The ip the other devices on the local network can use to reach this one.
func local_lan_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.contains(":") or ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		if ip.begins_with("10.") or ip.begins_with("192.168."):
			return ip
	for ip in IP.get_local_addresses():
		if not ip.contains(":") and not ip.begins_with("127.") \
				and not ip.begins_with("169.254."):
			return ip
	return "127.0.0.1"


func _process(delta: float) -> void:
	# a heartbeat keeps the connection alive even when nothing else is sent
	if _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_net_timer -= delta
		if _net_timer <= 0.0:
			_net_timer = NET_TICK
			if not _hosting:
				rpc_id(1, "_srv_ping")
	# keep saying hello until the host has us in the room
	if not _hosting and is_online() and _wait_for_hello:
		_hello_timer -= delta
		if _hello_timer <= 0.0:
			_hello_timer = 1.0
			_send_hello()
	# a dropped room is looked for again
	if _reconnecting:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0.0:
			_reconnect_timer = RECONNECT_WAIT
			_reconnect()
	if _discovery == null:
		return
	_disc_timer -= delta
	if _disc_timer <= 0.0:
		_disc_timer = 0.5
		if _hosting:
			# answer everyone who is looking for a room
			while _discovery.get_available_packet_count() > 0:
				var ip := _discovery.get_packet_ip()
				var port := _discovery.get_packet_port()
				var text := _discovery.get_packet().get_string_from_utf8()
				if text.begins_with("MTDISC?"):
					_discovery.set_dest_address(ip, port)
					_discovery.put_packet(_room_packet().to_utf8_buffer())
			_discovery.set_dest_address("255.255.255.255", DISCOVERY_PORT)
		else:
			# ask the network for rooms. The global broadcast is not always
			# passed by a router, so the subnet addresses are tried too.
			for target in _broadcast_targets():
				_discovery.set_dest_address(target, DISCOVERY_PORT)
				_discovery.put_packet("MTDISC?".to_utf8_buffer())
	if not _hosting and not _unicast_scan_targets.is_empty():
		_unicast_scan_timer -= delta
		if _unicast_scan_timer <= 0.0:
			_unicast_scan_timer = 0.025
			_discovery.set_dest_address(_unicast_scan_targets[_unicast_scan_index], DISCOVERY_PORT)
			_discovery.put_packet("MTDISC?".to_utf8_buffer())
			_unicast_scan_index += 1
			if _unicast_scan_index >= _unicast_scan_targets.size():
				_unicast_scan_index = 0
	# read the answers
	while _discovery.get_available_packet_count() > 0:
		var ip := _discovery.get_packet_ip()
		var port := _discovery.get_packet_port()
		var text := _discovery.get_packet().get_string_from_utf8()
		if text.begins_with("MTROOM:"):
			_add_room(ip, port, text)
	# drop the rooms that stopped answering
	var now := Time.get_ticks_msec() / 1000.0
	var changed := false
	for i in range(rooms.size() - 1, -1, -1):
		if now - float(rooms[i]["seen"]) > ROOM_TTL:
			rooms.remove_at(i)
			changed = true
	if changed:
		rooms_changed.emit()


func _room_packet() -> String:
	# the last part says how the room talks, so the players know what to use
	return "MTROOM:%s:%d:%d:%d" % [room_name, _room_port, players.size(),
		1 if _web_mode else 0]


# The host keeps its own room in the list too, so it can see it before joining.
func _add_own_room() -> void:
	if not _hosting:
		return
	var ip := "127.0.0.1"
	for r in rooms:
		if str(r["address"]) == ip and int(r["port"]) == _room_port:
			r["count"] = players.size()
			r["web"] = _web_mode
			r["seen"] = Time.get_ticks_msec() / 1000.0
			rooms_changed.emit()
			return
	rooms.append({
		"name": room_name,
		"address": ip,
		"port": _room_port,
		"count": players.size(),
		"web": _web_mode,
		"seen": Time.get_ticks_msec() / 1000.0,
	})
	rooms_changed.emit()


func _add_room(ip: String, port: int, text: String) -> void:
	var parts := text.split(":")
	if parts.size() < 4:
		return
	var name := parts[1]
	var game_port := int(parts[2])
	var count := int(parts[3])
	# the room tells how it talks, a browser can only join a websocket room
	var web := parts.size() >= 5 and int(parts[4]) == 1
	for r in rooms:
		if str(r["address"]) == ip and int(r["port"]) == game_port:
			r["count"] = count
			r["web"] = web
			r["seen"] = Time.get_ticks_msec() / 1000.0
			rooms_changed.emit()
			return
	rooms.append({
		"name": name,
		"address": ip,
		"port": game_port,
		"count": count,
		"web": web,
		"seen": Time.get_ticks_msec() / 1000.0,
	})
	rooms_changed.emit()


# --- player registry --------------------------------------------------------
func _color_for(slot: int) -> Color:
	return PLAYER_COLORS[slot % PLAYER_COLORS.size()]


func _on_peer_connected(_id: int) -> void:
	# the new player sends their name right after connecting
	pass


func _on_peer_disconnected(id: int) -> void:
	if _closing:
		return
	var i := _find_player(id)
	if i >= 0:
		players.remove_at(i)
	if _hosting:
		_broadcast_players()
		_add_own_room()
	players_changed.emit()


func _on_connected_to_server() -> void:
	# the room is back
	_reconnecting = false
	# tell the host who we are, and keep saying it until the host answers:
	# the very first message can still be too early for the rpc channels
	_hello_timer = 0.0
	_wait_for_hello = true
	_send_hello()


# Sends our name to the host. It is repeated a few times, because the first
# message can arrive before the connection is really ready.
func _send_hello() -> void:
	if not is_online() or _hosting:
		return
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	rpc_id(1, "_srv_hello", _my_name())


func retry_hello() -> void:
	if _hosting or not is_online():
		return
	_wait_for_hello = true
	_hello_timer = 0.0
	_send_hello()


func is_player_name_taken(candidate: String) -> bool:
	var normalized := candidate.strip_edges().to_lower()
	if normalized == "":
		return false
	for player in players:
		if str(player.get("name", "")).strip_edges().to_lower() == normalized:
			return true
	return false


# The name of the local player, with a fallback for the ones who skipped it.
func _my_name() -> String:
	if player_name != "":
		return player_name
	return "PLAYER %d" % (randi() % 900 + 100)


func _on_connection_failed() -> void:
	session_failed.emit("the host did not answer")


func _on_server_disconnected() -> void:
	if _closing:
		return
	# a client that loses the room tries to get back into it
	if not _hosting and _last_address != "":
		_reconnecting = true
		_reconnect_timer = RECONNECT_WAIT
		players.clear()
		players_changed.emit()
		return
	leave()


@rpc("any_peer", "call_remote", "reliable", 0)
func _srv_hello(name: String) -> void:
	if not _hosting:
		return
	var id := _api.get_remote_sender_id()
	if _find_player(id) >= 0:
		return
	if is_player_name_taken(name):
		rpc_id(id, "_cli_name_taken")
		return
	players.append({"id": id, "name": name, "color": _color_for(players.size())})
	_broadcast_players()
	_add_own_room()
	players_changed.emit()


@rpc("any_peer", "call_remote", "reliable", 0)
func _cli_name_taken() -> void:
	if _hosting or _api == null or _api.get_remote_sender_id() != 1:
		return
	_wait_for_hello = false
	name_change_required = true
	player_name_taken.emit()


func _broadcast_players() -> void:
	if not _hosting:
		return
	# the colours are looked up on the other side, so only the names travel
	var plain: Array = []
	for p in players:
		plain.append([int(p["id"]), str(p["name"])])
	for pid in _client_ids():
		rpc_id(pid, "_cli_players", plain)


@rpc("any_peer", "call_remote", "reliable", 0)
func _cli_players(list: Array) -> void:
	var out: Array = []
	for i in list.size():
		var row: Array = list[i]
		out.append({"id": int(row[0]), "name": str(row[1]),
			"color": _color_for(i)})
	players = out
	# the host has us in the room now, the greetings can stop
	_wait_for_hello = false
	name_change_required = false
	players_changed.emit()


# A client says hello every now and then, so the host knows it is still there.
@rpc("any_peer", "call_remote", "reliable", 0)
func _srv_ping() -> void:
	pass


# The host does the same, so the client does not time out either.
@rpc("any_peer", "call_remote", "reliable", 0)
func _cli_ping() -> void:
	pass


func _find_player(id: int) -> int:
	for i in players.size():
		if int(players[i]["id"]) == id:
			return i
	return -1


# The peers that joined the room, everybody but the host itself.
func _client_ids() -> Array:
	var out: Array = []
	for p in players:
		var id := int(p["id"])
		if id != my_id():
			out.append(id)
	return out


func player_name_of(id: int) -> String:
	var i := _find_player(id)
	return str(players[i]["name"]) if i >= 0 else "?"


func player_color_of(id: int) -> Color:
	var i := _find_player(id)
	return players[i]["color"] if i >= 0 else Color.WHITE


# --- enemies (the host owns the world) ---------------------------------------
# The host spawns an enemy and tells the clients about it.
func spawn_enemy(kind: String, pos: Vector2, params: Dictionary) -> int:
	if not _hosting:
		return 0
	var id := _next_enemy_id
	_next_enemy_id += 1
	# the settings travel as a plain list, a dictionary does not always make
	# it through the network
	var plain: Array = []
	for key in params:
		plain.append([str(key), params[key]])
	for pid in _client_ids():
		rpc_id(pid, "_cli_enemy_spawn", kind, pos.x, pos.y, id, plain)
	return id


@rpc("authority", "call_remote", "reliable", 0)
func _cli_enemy_spawn(kind: String, x: float, y: float, id: int, plain: Array) -> void:
	var params := {}
	for row in plain:
		params[str(row[0])] = row[1]
	if world != null and world.has_method("enemy_spawned"):
		world.call("enemy_spawned", kind, Vector2(x, y), params, id)


# The host tells the clients that an enemy is gone.
func remove_enemy(id: int) -> void:
	if not _hosting:
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_enemy_removed", id)


# A client says "this enemy took a hit", the host applies it.
func report_hit(id: int, amount: float, kind: String) -> void:
	# the host deals with its own enemies, it never asks itself
	if _hosting or id == 0:
		return
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	rpc_id(1, "_srv_enemy_hit", id, amount, kind)


@rpc("any_peer", "call_remote", "reliable", 0)
func _srv_enemy_hit(id: int, amount: float, kind: String) -> void:
	if not _hosting or world == null:
		return
	# remember who hit the enemy, that player earns the xp
	var sender := _api.get_remote_sender_id()
	if world.has_method("enemy_hit"):
		world.call("enemy_hit", id, amount, kind, sender)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_enemy_removed(id: int) -> void:
	if world != null and world.has_method("enemy_removed"):
		world.call("enemy_removed", id)


# The host tells the clients which wave it is.
func send_wave(wave: int) -> void:
	if not _hosting:
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_wave", wave)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_wave(wave: int) -> void:
	Game.wave = wave
	Game.wave_changed.emit(wave)


# The host tells the player who got the kill to create their local XP orbs.
func send_xp_drop(peer: int, pos: Vector2, amount: int) -> void:
	if not _hosting or peer <= 0 or amount <= 0:
		return
	rpc_id(peer, "_cli_drop_xp", pos, amount)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_drop_xp(pos: Vector2, amount: int) -> void:
	XP_DROP.drop(get_tree(), pos, amount)


# Sends the enemy positions, the host runs the world.
func push_enemies() -> void:
	if not _hosting:
		return
	_enemy_timer -= get_process_delta_time()
	if _enemy_timer > 0.0:
		return
	_enemy_timer = ENEMY_TICK
	var data := {}
	for e in get_tree().get_nodes_in_group("enemy"):
		var id := int(e.get("net_id"))
		if id == 0:
			continue
		data[id] = [e.global_position.x, e.global_position.y,
			e.rotation, float(e.get("hp")), e.get("_net_alive") == true]
	if data.is_empty():
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_enemies", data)


# The host tells the clients where its own player is.
func push_host_player() -> void:
	if not _hosting:
		return
	var pl := get_tree().get_first_node_in_group("player")
	if pl == null or not is_instance_valid(pl):
		return
	var pos: Vector2 = pl.global_position
	var rot := 0.0
	# the ship itself turns, the player node does not
	var spr := pl.get_node_or_null("Sprite2D") as Node2D
	if spr != null:
		rot = spr.rotation
	for pid in _client_ids():
		rpc_id(pid, "_cli_player_state", pos, rot, 1.0, true)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_enemies(data: Dictionary) -> void:
	if world != null and world.has_method("enemies_synced"):
		world.call("enemies_synced", data)


# --- player movement --------------------------------------------------------
# The local player sends where it is, everybody else moves it smoothly.
func send_player_state(pos: Vector2, rot: float, hp: float, alive: bool) -> void:
	if not is_online():
		return
	# the host tells the clients about itself in push_host_player
	if _hosting:
		return
	_net_timer -= get_process_delta_time()
	if _net_timer > 0.0:
		return
	_net_timer = NET_TICK
	# the host is the one that needs to know where the player is
	rpc_id(1, "_cli_player_state", pos, rot, hp, alive)


@rpc("any_peer", "call_remote", "reliable", 0)
func _cli_player_state(pos: Vector2, rot: float, hp: float, alive: bool) -> void:
	var sender := _api.get_remote_sender_id()
	# the host passes it on to the other players, they do not see each other
	if _hosting:
		for pid in _client_ids():
			if pid != sender:
				rpc_id(pid, "_cli_player_state", pos, rot, hp, alive)
	# the host tells the clients about its own player
	var who := 1 if _hosting else sender
	if world != null and world.has_method("player_state"):
		world.call("player_state", who, pos, rot, hp, alive)


# --- session ----------------------------------------------------------------
func start_game() -> void:
	if not _hosting:
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_start")


# Restart the current match without leaving its room. The host owns the reset
# and tells all clients to enter the same fresh game scene.
func restart_room_game() -> void:
	if not is_online():
		return
	if _hosting:
		_restart_room_game_as_host()
	else:
		rpc_id(1, "_cli_request_restart")


@rpc("any_peer", "call_remote", "reliable", 0)
func _cli_request_restart() -> void:
	if not _hosting or _api == null:
		return
	var sender := _api.get_remote_sender_id()
	# Only a player that is currently in this room may request a restart.
	if _find_player(sender) < 0:
		return
	_restart_room_game_as_host()


func _restart_room_game_as_host() -> void:
	Game.reset_run()
	start_game()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main.tscn")


@rpc("authority", "call_remote", "reliable", 0)
func _cli_start() -> void:
	Game.reset_run()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func kick_player(id: int) -> void:
	if not _hosting:
		return
	rpc_id(id, "_cli_kicked")
	var i := _find_player(id)
	if i >= 0:
		players.remove_at(i)
		_broadcast_players()
	players_changed.emit()


@rpc("authority", "call_remote", "reliable", 0)
func _cli_kicked() -> void:
	session_failed.emit("the host kicked you out")
	leave()
