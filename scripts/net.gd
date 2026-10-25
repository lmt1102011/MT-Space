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
const UPGRADE_DROP := preload("res://scenes/upgrade_drop.tscn")
const CARD_DB := preload("res://scripts/card_db.gd")
const ENEMY_BULLET := preload("res://scenes/enemy_bullet.tscn")
const BOSS_MISSILE := preload("res://scenes/boss_missile.tscn")
const ORB_PROJECTILE := preload("res://scenes/orb_projectile.tscn")
const BOSS_SONIC_WAVE := preload("res://scenes/boss_sonic_wave.tscn")
const EXPLOSION_SCENE := preload("res://scenes/explosion.tscn")
# a room that stopped answering is dropped after this many seconds
const ROOM_TTL := 15.0
# A refresh sends a few quick discovery bursts so a host that misses one UDP
# packet still appears almost immediately.
const DISCOVERY_BURST_COUNT := 4
const DISCOVERY_BURST_INTERVAL := 0.25
# how often the local player sends its position
const NET_TICK := 1.0 / 30.0
# how often the host sends the enemy positions
const ENEMY_TICK := 1.0 / 30.0

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
var _discovery_burst_left: int = 0
var _discovery_burst_timer: float = 0.0
var _unicast_scan_timer: float = 0.0
var _unicast_scan_targets: Array[String] = []
var _unicast_scan_index: int = 0
var _net_timer: float = 0.0
var _heartbeat_timer: float = 0.0
var _enemy_timer: float = 0.0
var _next_enemy_id: int = 1
var _next_discarded_card_id: int = 1
var _discarded_card_drops: Dictionary = {}
var _player_nodes_cache: Array = []
var _player_nodes_cache_frame: int = -1
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
	_request_discovery_burst()


func refresh_rooms() -> void:
	if is_online() or OS.has_feature("web"):
		return
	# Keep the current list visible while the new answers arrive. This avoids
	# the empty-list flicker that made refresh look unreliable.
	if _discovery == null:
		_start_discovery(false)
	_request_discovery_burst()


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
func host_room(room_title: String, port: int = DEFAULT_PORT, web_mode: bool = false) -> bool:
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
	room_name = room_title
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
	_discarded_card_drops.clear()
	_next_discarded_card_id = 1
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
	_discovery_burst_left = 0
	_discovery_burst_timer = 0.0
	_unicast_scan_timer = 0.0
	_unicast_scan_index = 0
	# Broadcast/subnet discovery is enough for a normal LAN and avoids flooding
	# every address on every network adapter. Manual host address entry remains
	# available for networks that block broadcast packets.
	_unicast_scan_targets = []
	if not hosting:
		_send_discovery_queries()


func _request_discovery_burst() -> void:
	if _discovery == null or _hosting:
		return
	_discovery_burst_left = DISCOVERY_BURST_COUNT
	_discovery_burst_timer = 0.0
	_send_discovery_queries()


func _send_discovery_queries() -> void:
	if _discovery == null or _hosting:
		return
	for target in _broadcast_targets():
		_discovery.set_dest_address(target, DISCOVERY_PORT)
		_discovery.put_packet("MTDISC?".to_utf8_buffer())


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


func room_connect_address() -> String:
	var address := local_lan_ip() if _hosting else _last_address
	if address.begins_with("ws://") or address.begins_with("wss://"):
		return address
	if address == "":
		address = local_lan_ip()
	return "%s:%d" % [address, _last_port if not _hosting else _room_port]


func _process(delta: float) -> void:
	# a heartbeat keeps the connection alive even when nothing else is sent
	if _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_heartbeat_timer -= delta
		if _heartbeat_timer <= 0.0:
			_heartbeat_timer = 1.0
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
	if not _hosting and _discovery_burst_left > 0:
		_discovery_burst_timer -= delta
		if _discovery_burst_timer <= 0.0:
			_send_discovery_queries()
			_discovery_burst_left -= 1
			_discovery_burst_timer = DISCOVERY_BURST_INTERVAL
	_disc_timer -= delta
	if _disc_timer <= 0.0:
		_disc_timer = 0.05 if _hosting else 0.5
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
			_send_discovery_queries()
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
	var ip := local_lan_ip()
	for r in rooms:
		if _room_identity_matches(r, room_name, _room_port, _web_mode):
			if _prefer_room_address(str(r["address"]), ip):
				r["address"] = ip
			r["count"] = players.size()
			r["web"] = _web_mode
			r["seen"] = Time.get_ticks_msec() / 1000.0
			_deduplicate_rooms()
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
	_deduplicate_rooms()
	rooms_changed.emit()


func _add_room(ip: String, _port: int, text: String) -> void:
	var parts := text.split(":")
	if parts.size() < 4:
		return
	var room_title := parts[1]
	var game_port := int(parts[2])
	var count := int(parts[3])
	# the room tells how it talks, a browser can only join a websocket room
	var web := parts.size() >= 5 and int(parts[4]) == 1
	for r in rooms:
		# The host can receive its own broadcast through both 127.0.0.1 and
		# its LAN address. Treat those as one room.
		if _room_identity_matches(r, room_title, game_port, web) \
			and (str(r["address"]) == ip or _is_room_alias(str(r["address"]), ip)):
			var address := str(r["address"])
			if _prefer_room_address(address, ip):
				address = ip
			var changed := str(r["name"]) != room_title or int(r["count"]) != count \
				or bool(r["web"]) != web or str(r["address"]) != address
			r["address"] = address
			r["count"] = count
			r["web"] = web
			r["seen"] = Time.get_ticks_msec() / 1000.0
			_deduplicate_rooms()
			if changed:
				rooms_changed.emit()
			return
	rooms.append({
		"name": room_title,
		"address": ip,
		"port": game_port,
		"count": count,
		"web": web,
		"seen": Time.get_ticks_msec() / 1000.0,
	})
	_deduplicate_rooms()
	rooms_changed.emit()


func _room_identity_matches(room: Dictionary, room_title: String, port: int, web: bool) -> bool:
	return str(room.get("name", "")) == room_title \
		and int(room.get("port", 0)) == port \
		and bool(room.get("web", false)) == web


func _usable_room_address(address: String) -> bool:
	return address != "" and address != "0.0.0.0" and address != "127.0.0.1"


func _is_room_alias(first: String, second: String) -> bool:
	if first == second:
		return true
	if not _usable_room_address(first) or not _usable_room_address(second):
		return true
	return _hosting and (first == local_lan_ip() or second == local_lan_ip())


func _prefer_room_address(current: String, incoming: String) -> bool:
	return not _usable_room_address(current) and _usable_room_address(incoming)


func _deduplicate_rooms() -> void:
	for i in range(rooms.size() - 1, -1, -1):
		for j in range(i - 1, -1, -1):
			var older: Dictionary = rooms[j]
			var newer: Dictionary = rooms[i]
			if not _room_identity_matches(older, str(newer.get("name", "")),
				int(newer.get("port", 0)), bool(newer.get("web", false))):
				continue
			if not _is_room_alias(str(older.get("address", "")),
				str(newer.get("address", ""))):
				continue
			if _prefer_room_address(str(older.get("address", "")),
				str(newer.get("address", ""))):
				older["address"] = newer.get("address", "")
			older["count"] = newer.get("count", older.get("count", 0))
			older["seen"] = maxf(float(older.get("seen", 0.0)),
				float(newer.get("seen", 0.0)))
			rooms.remove_at(i)
			break


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
	_reconnecting = false
	_last_address = ""
	_reset_session()
	browse_rooms()
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
func _srv_hello(requested_name: String) -> void:
	if not _hosting:
		return
	var id := _api.get_remote_sender_id()
	if _find_player(id) >= 0:
		return
	if is_player_name_taken(requested_name):
		rpc_id(id, "_cli_name_taken")
		return
	players.append({"id": id, "name": requested_name, "color": _color_for(players.size())})
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


# The host chooses among the local player and the remote-player proxies. This
# keeps enemy AI from always locking onto the host's character.
func target_player(from_position: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for candidate in _players_for_physics_frame():
		var node := candidate as Node2D
		if node == null or not is_instance_valid(node):
			continue
		if node.get("net_alive") == false or node.get("_dead") == true:
			continue
		var distance := from_position.distance_squared_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


func any_player_alive() -> bool:
	for candidate in _players_for_physics_frame():
		var node := candidate as Node2D
		if node == null or not is_instance_valid(node):
			continue
		if node.get("net_alive") == false or node.get("_dead") == true:
			continue
		return true
	return false


func _players_for_physics_frame() -> Array:
	var frame := Engine.get_physics_frames()
	if frame != _player_nodes_cache_frame:
		_player_nodes_cache = get_tree().get_nodes_in_group("player")
		_player_nodes_cache_frame = frame
	return _player_nodes_cache


# Damage to a remote player is decided by the host and applied by that player's
# own process. This works for contact damage and enemy projectiles alike.
func damage_remote_player(id: int, amount: float, burn: int = 0, freeze: int = 0) -> void:
	damage_remote_player_with_effect(id, amount, burn, freeze)


func damage_remote_player_orb(id: int, amount: float) -> void:
	if not _hosting or id <= 1:
		return
	rpc_id(id, "_cli_orb_damage_player", amount)


func damage_remote_player_with_effect(id: int, amount: float, burn: int = 0,
		freeze: int = 0, knockback: Vector2 = Vector2.ZERO,
		stun_time: float = 0.0) -> void:
	if not _hosting or id <= 1:
		return
	rpc_id(id, "_cli_damage_player", amount, burn, freeze, knockback, stun_time)


func slow_remote_player(id: int, duration: float = 0.5) -> void:
	if not _hosting or id <= 1:
		return
	rpc_id(id, "_cli_orb_slow", duration)


func broadcast_enemy_bullet(pos: Vector2, direction: Vector2, speed: float,
		damage: int, burn: int, freeze: int, lifetime: float,
		beam_length: float = 20.0, beam_width: float = 5.0) -> void:
	if not _hosting:
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_enemy_bullet", pos, direction, speed, damage,
			burn, freeze, lifetime, beam_length, beam_width)


func broadcast_boss_missile(pos: Vector2, direction: Vector2, speed: float,
		turn_rate: float, lifetime: float) -> void:
	if not _hosting:
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_boss_missile", pos, direction, speed, turn_rate, lifetime)


func spawn_boss_sonic_wave(pos: Vector2, max_radius: float, duration: float) -> void:
	_create_boss_sonic_wave(pos, max_radius, duration, false)
	if not _hosting:
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_boss_sonic_wave", pos, max_radius, duration)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_boss_sonic_wave(pos: Vector2, max_radius: float, duration: float) -> void:
	_create_boss_sonic_wave(pos, max_radius, duration, true)


func _create_boss_sonic_wave(pos: Vector2, max_radius: float,
		duration: float, visual_only: bool) -> void:
	var wave := BOSS_SONIC_WAVE.instantiate()
	wave.global_position = pos
	wave.max_radius = max_radius
	wave.duration = duration
	wave.visual_only = visual_only
	get_tree().current_scene.add_child(wave)


func broadcast_boss_drone_explosion(pos: Vector2, large: bool) -> void:
	if not _hosting:
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_boss_drone_explosion", pos, large)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_boss_drone_explosion(pos: Vector2, large: bool) -> void:
	var explosion := EXPLOSION_SCENE.instantiate() as Explosion
	explosion.global_position = pos
	explosion.setup(1.8 if large else 0.9)
	get_tree().current_scene.add_child(explosion)


func broadcast_orb(pos: Vector2, direction: Vector2, speed: float,
		radius: float, lifetime: float) -> void:
	if not _hosting:
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_orb", pos, direction, speed, radius, lifetime)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _cli_orb(pos: Vector2, direction: Vector2, speed: float,
		radius: float, lifetime: float) -> void:
	var orb := ORB_PROJECTILE.instantiate()
	orb.global_position = pos
	orb.direction = direction
	orb.speed = speed
	orb.radius = radius
	orb.lifetime = lifetime
	orb.network_visual = true
	get_tree().current_scene.add_child(orb)


# Player bullets are simulated by their owner for damage. Other peers receive
# a visual-only copy so everybody can see the same firefight without applying
# damage twice.
func broadcast_player_bullet(pos: Vector2, direction: Vector2, speed: float,
		lifetime: float, beam_length: float, beam_width: float, beam_color: Color) -> void:
	if not is_online():
		return
	if _hosting:
		for pid in _client_ids():
			rpc_id(pid, "_cli_player_bullet", pos, direction, speed, lifetime,
				beam_length, beam_width, beam_color)
		return
	if _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc_id(1, "_srv_player_bullet", pos, direction, speed, lifetime,
			beam_length, beam_width, beam_color)


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


func broadcast_enemy_attack_state(id: int, state: String, duration: float,
		point: Vector2 = Vector2.ZERO) -> void:
	if not _hosting or id <= 0:
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_enemy_attack_state", id, state, duration, point)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_enemy_attack_state(id: int, state: String, duration: float,
		point: Vector2) -> void:
	if world != null and world.has_method("enemy_attack_state"):
		world.call("enemy_attack_state", id, state, duration, point)


# A client says "this enemy took a hit", the host applies it.
func report_hit(id: int, amount: float, kind: String) -> void:
	# the host deals with its own enemies, it never asks itself
	if _hosting or id == 0:
		return
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	rpc_id(1, "_srv_enemy_hit", id, amount, kind)


func report_enemy_status(id: int, burn: int, freeze: int) -> void:
	if _hosting or id == 0:
		return
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	rpc_id(1, "_srv_enemy_status", id, burn, freeze)


@rpc("any_peer", "call_remote", "reliable", 0)
func _srv_enemy_hit(id: int, amount: float, kind: String) -> void:
	if not _hosting or world == null:
		return
	# remember who hit the enemy, that player earns the xp
	var sender := _api.get_remote_sender_id()
	if world.has_method("enemy_hit"):
		world.call("enemy_hit", id, amount, kind, sender)


@rpc("any_peer", "call_remote", "reliable", 0)
func _srv_enemy_status(id: int, burn: int, freeze: int) -> void:
	if not _hosting or world == null:
		return
	if world.has_method("enemy_status"):
		world.call("enemy_status", id, burn, freeze)


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
	if world != null and world.has_method("clear_host_ghost"):
		world.call("clear_host_ghost")
	var local_player := get_tree().current_scene.get_node_or_null("Player")
	if local_player != null and local_player.has_method("revive_for_wave"):
		local_player.call("revive_for_wave")
	if world != null and world.has_method("revive_remote_players"):
		world.call("revive_remote_players")
	Game.wave = wave
	Game.wave_changed.emit(wave)


func send_revive_dead_players() -> void:
	if not _hosting:
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_revive_dead_players")


@rpc("authority", "call_remote", "reliable", 0)
func _cli_revive_dead_players() -> void:
	var local_player := get_tree().current_scene.get_node_or_null("Player")
	if local_player != null and local_player.get("_dead") == true \
			and local_player.has_method("revive_for_wave"):
		local_player.call("revive_for_wave")
	if world != null and world.has_method("revive_remote_players"):
		world.call("revive_remote_players")


# The host tells the player who got the kill to create their local XP orbs.
func send_xp_drop(peer: int, pos: Vector2, amount: int) -> void:
	if not _hosting or peer <= 0 or amount <= 0:
		return
	rpc_id(peer, "_cli_drop_xp", pos, amount)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_drop_xp(pos: Vector2, amount: int) -> void:
	XP_DROP.drop(get_tree(), pos, amount)


# Elite drops belong to the player who landed the killing hit. The host sends
# only the card id because card dictionaries contain local Callable values.
func send_elite_card(peer: int, pos: Vector2, card_id: String) -> void:
	if not _hosting or peer <= 1 or card_id == "":
		return
	rpc_id(peer, "_cli_elite_card", pos, card_id)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_elite_card(pos: Vector2, card_id: String) -> void:
	var card := _find_upgrade_card(card_id)
	if card.is_empty():
		return
	var drop := UPGRADE_DROP.instantiate() as UpgradeDrop
	drop.card = card
	drop.global_position = pos + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 20.0)
	get_tree().current_scene.add_child(drop)


func request_discarded_card(card_id: String, pos: Vector2, direction: Vector2) -> bool:
	if _find_upgrade_card(card_id).is_empty() or direction.is_zero_approx():
		return false
	if not is_online():
		_spawn_discarded_card(0, my_id(), pos, direction, card_id)
		return true
	if _hosting:
		_create_discarded_card_drop(my_id(), pos, direction, card_id)
		return true
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	rpc_id(1, "_srv_discard_card", card_id, pos, direction.normalized())
	return true


@rpc("any_peer", "call_remote", "reliable", 0)
func _srv_discard_card(card_id: String, pos: Vector2, direction: Vector2) -> void:
	if not _hosting or _api == null or not pos.is_finite() \
			or not direction.is_finite() or direction.is_zero_approx():
		return
	var sender := _api.get_remote_sender_id()
	if sender <= 1 or _find_player(sender) < 0 or _find_upgrade_card(card_id).is_empty():
		return
	_create_discarded_card_drop(sender, pos, direction, card_id)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_discarded_card(drop_id: int, owner_id: int, pos: Vector2,
		direction: Vector2, card_id: String) -> void:
	_spawn_discarded_card(drop_id, owner_id, pos, direction, card_id)


func _create_discarded_card_drop(owner_id: int, pos: Vector2,
		direction: Vector2, card_id: String) -> void:
	var drop_id := _next_discarded_card_id
	_next_discarded_card_id += 1
	_discarded_card_drops[drop_id] = card_id
	_spawn_discarded_card(drop_id, owner_id, pos, direction, card_id)
	for pid in _client_ids():
		rpc_id(pid, "_cli_discarded_card", drop_id, owner_id, pos,
			direction.normalized(), card_id)


func _spawn_discarded_card(drop_id: int, owner_id: int, pos: Vector2,
		direction: Vector2, card_id: String) -> void:
	var card := _find_upgrade_card(card_id)
	if card.is_empty() or direction.is_zero_approx():
		return
	var drop := UPGRADE_DROP.instantiate() as UpgradeDrop
	drop.card = card
	drop.network_drop_id = drop_id
	drop.global_position = pos + direction.normalized() * 82.0
	drop.configure_thrown(owner_id, direction)
	get_tree().current_scene.add_child(drop)


func claim_discarded_card(drop_id: int, player_id: int) -> void:
	if not _hosting or not _discarded_card_drops.has(drop_id):
		return
	if player_id <= 0 or (player_id > 1 and _find_player(player_id) < 0):
		return
	var card_id := str(_discarded_card_drops[drop_id])
	_discarded_card_drops.erase(drop_id)
	if player_id == 1:
		_grant_discarded_card(card_id)
	else:
		rpc_id(player_id, "_cli_grant_discarded_card", card_id)
	_remove_discarded_card_drop(drop_id)
	for pid in _client_ids():
		rpc_id(pid, "_cli_remove_discarded_card", drop_id)


func _grant_discarded_card(card_id: String) -> void:
	var card := _find_upgrade_card(card_id)
	if card.is_empty() or not Game.grant_card(card):
		return
	Game.card_collected.emit(card)
	Game.sfx("cardget", -11.0, 0.95, 1.06)


func _remove_discarded_card_drop(drop_id: int) -> void:
	for node in get_tree().get_nodes_in_group("upgrade_drop"):
		if int(node.get("network_drop_id")) == drop_id:
			node.queue_free()


@rpc("authority", "call_remote", "reliable", 0)
func _cli_grant_discarded_card(card_id: String) -> void:
	_grant_discarded_card(card_id)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_remove_discarded_card(drop_id: int) -> void:
	_remove_discarded_card_drop(drop_id)


func _find_upgrade_card(card_id: String) -> Dictionary:
	for card in CARD_DB.passives():
		if str(card.get("id", "")) == card_id:
			return card
	for card in CARD_DB.weapon_cards():
		if str(card.get("id", "")) == card_id:
			return card
	return {}


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
		var facing: float = float(e.get("global_rotation"))
		# Some enemies keep their sprite under a Body node (notably the
		# two-barrel enemy). Search recursively so their facing is replicated.
		var sprite := e.find_child("Sprite2D", true, false) as Node2D
		if sprite != null:
			facing = sprite.global_rotation
		var body := e as CharacterBody2D
		var velocity := body.velocity if body != null else Vector2.ZERO
		var burning := float(e.get("_burn")) > 0.0
		var frozen := float(e.get("_slow")) > 0.0
		data[id] = [e.global_position.x, e.global_position.y,
			facing, float(e.get("hp")), e.get("_net_alive") == true,
			velocity.x, velocity.y, burning, frozen,
			e.get("elite") == true, int(e.get("max_hp"))]
	if data.is_empty():
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_enemies", data)


# The host tells the clients where its own player is.
func push_host_player() -> void:
	if not _hosting:
		return
	var pl := get_tree().current_scene.get_node_or_null("Player")
	if pl == null or not is_instance_valid(pl):
		return
	var pos: Vector2 = pl.global_position
	var rot := 0.0
	# the ship itself turns, the player node does not
	var spr := pl.get_node_or_null("Sprite2D") as Node2D
	if spr != null:
		rot = spr.rotation
	var hp_ratio := 1.0
	if pl.has_method("max_hp_total"):
		hp_ratio = float(pl.get("hp")) / float(pl.call("max_hp_total"))
	# Node.get() returns Variant, so give the RPC payload an explicit type.
	var alive: bool = not bool(pl.get("_dead"))
	var thrust: float = float(pl.get("_thrust"))
	var burning: bool = float(pl.get("_burn")) > 0.0
	var frozen: bool = float(pl.get("_slow")) > 0.0
	var stunned: bool = float(pl.get("_stun_t")) > 0.0
	var player_velocity: Vector2 = Vector2(pl.get("velocity"))
	for pid in _client_ids():
		rpc_id(pid, "_cli_player_state", 1, pos, rot, hp_ratio, alive,
			Game.spectate_target if Game.spectate_mode else 0, Game.level,
			player_velocity, thrust, burning, frozen, stunned)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _cli_enemies(data: Dictionary) -> void:
	if world != null and world.has_method("enemies_synced"):
		world.call("enemies_synced", data)


# --- player movement --------------------------------------------------------
# The local player sends where it is, everybody else moves it smoothly.
func send_player_state(pos: Vector2, rot: float, hp: float, alive: bool,
		spectate_target: int = 0, level: int = 1, velocity: Vector2 = Vector2.ZERO,
		thrust: float = 0.0,
		burning: bool = false, frozen: bool = false, stunned: bool = false) -> void:
	if not is_online() or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	# the host tells the clients about itself in push_host_player
	if _hosting:
		return
	_net_timer -= get_process_delta_time()
	if _net_timer > 0.0:
		return
	_net_timer = NET_TICK
	# the host is the one that needs to know where the player is
	rpc_id(1, "_cli_player_state", my_id(), pos, rot, hp, alive, spectate_target,
		level, velocity, thrust, burning, frozen, stunned)


# Death is a state transition, not a movement update. Send it reliably so a
# dropped movement packet can never leave the host believing this player is
# still alive and targetable by enemies.
func send_player_death(spectate_target: int = 0, level: int = 1) -> void:
	var pl := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if pl == null:
		return
	var pos := pl.global_position
	var rot := 0.0
	var sprite := pl.get_node_or_null("Sprite2D") as Node2D
	if sprite != null:
		rot = sprite.rotation
	if _hosting:
		for pid in _client_ids():
			rpc_id(pid, "_cli_player_death", 1, pos, rot, spectate_target, level)
		# Only the client being watched needs the host's visible ghost. It
		# follows that client's local Player node, avoiding remote-proxy races.
		if spectate_target > 1:
			rpc_id(spectate_target, "_cli_show_host_ghost", level)
		return
	if _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc_id(1, "_srv_player_death", pos, rot, spectate_target, level)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _cli_player_state(player_id: int, pos: Vector2, rot: float,
		hp: float, alive: bool, spectate_target: int = 0, level: int = 1,
		velocity: Vector2 = Vector2.ZERO, thrust: float = 0.0,
		burning: bool = false, frozen: bool = false, stunned: bool = false) -> void:
	var sender := _api.get_remote_sender_id()
	# the host passes it on to the other players, they do not see each other
	if _hosting:
		for pid in _client_ids():
			if pid != sender:
				rpc_id(pid, "_cli_player_state", player_id, pos, rot, hp, alive,
					spectate_target, level, velocity, thrust, burning, frozen, stunned)
	# the host tells the clients about its own player
	var who := player_id
	if world != null and world.has_method("player_state"):
		world.call("player_state", who, pos, rot, hp, alive, spectate_target, level,
			velocity, thrust, burning, frozen, stunned)


@rpc("any_peer", "call_remote", "reliable", 0)
func _srv_player_death(pos: Vector2, rot: float, spectate_target: int = 0,
		level: int = 1) -> void:
	if not _hosting or _api == null or world == null:
		return
	var sender := _api.get_remote_sender_id()
	if _find_player(sender) < 0:
		return
	world.call("player_state", sender, pos, rot, 0.0, false, spectate_target, level)
	for pid in _client_ids():
		rpc_id(pid, "_cli_player_death", sender, pos, rot, spectate_target, level)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_player_death(player_id: int, pos: Vector2, rot: float,
		spectate_target: int = 0, level: int = 1) -> void:
	if world != null and world.has_method("player_state"):
		world.call("player_state", player_id, pos, rot, 0.0, false, spectate_target, level)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_show_host_ghost(level: int) -> void:
	if world != null and world.has_method("show_host_ghost"):
		world.call("show_host_ghost", level)


func send_host_ghost_clear() -> void:
	if not _hosting:
		return
	for pid in _client_ids():
		rpc_id(pid, "_cli_clear_host_ghost")


@rpc("authority", "call_remote", "reliable", 0)
func _cli_clear_host_ghost() -> void:
	if world != null and world.has_method("clear_host_ghost"):
		world.call("clear_host_ghost")


@rpc("authority", "call_remote", "reliable", 0)
func _cli_damage_player(amount: float, burn: int, freeze: int,
		knockback: Vector2 = Vector2.ZERO, stun_time: float = 0.0) -> void:
	var local_player := get_tree().current_scene.get_node_or_null("Player")
	if local_player == null or not local_player.has_method("take_damage"):
		return
	local_player.take_damage(amount)
	if local_player.has_method("apply_status"):
		local_player.apply_status(burn, freeze)
	if stun_time > 0.0 and local_player.has_method("apply_knockback"):
		local_player.apply_knockback(knockback, stun_time)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_orb_damage_player(amount: float) -> void:
	var local_player := get_tree().current_scene.get_node_or_null("Player")
	if local_player != null and local_player.has_method("apply_orb_damage"):
		local_player.apply_orb_damage(amount)


@rpc("authority", "call_remote", "reliable", 0)
func _cli_orb_slow(duration: float = 0.5) -> void:
	var local_player := get_tree().current_scene.get_node_or_null("Player")
	if local_player != null and local_player.has_method("apply_orb_slow"):
		local_player.apply_orb_slow(duration)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _cli_enemy_bullet(pos: Vector2, direction: Vector2, speed: float,
		damage: int, burn: int, freeze: int, lifetime: float,
		beam_length: float, beam_width: float) -> void:
	var bullet := ENEMY_BULLET.instantiate()
	bullet.global_position = pos
	bullet.direction = direction
	bullet.speed = speed
	bullet.damage = damage
	bullet.burn = burn
	bullet.freeze = freeze
	bullet.lifetime = lifetime
	bullet.beam_length = beam_length
	bullet.beam_width = beam_width
	bullet.network_visual = true
	get_tree().current_scene.add_child(bullet)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _cli_boss_missile(pos: Vector2, direction: Vector2, speed: float,
		turn_rate: float, lifetime: float) -> void:
	var missile := BOSS_MISSILE.instantiate()
	missile.global_position = pos
	missile.direction = direction
	missile.speed = speed
	missile.turn_rate = turn_rate
	missile.lifetime = lifetime
	missile.network_visual = true
	get_tree().current_scene.add_child(missile)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _srv_player_bullet(pos: Vector2, direction: Vector2, speed: float,
		lifetime: float, beam_length: float, beam_width: float, beam_color: Color) -> void:
	if not _hosting:
		return
	var sender := _api.get_remote_sender_id()
	# Draw the remote player's shot on the host.
	_add_network_player_bullet(pos, direction, speed, lifetime, beam_length,
		beam_width, beam_color)
	# Relay it to everybody except the owner, who already has the real bullet.
	for pid in _client_ids():
		if pid != sender:
			rpc_id(pid, "_cli_player_bullet", pos, direction, speed, lifetime,
				beam_length, beam_width, beam_color)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _cli_player_bullet(pos: Vector2, direction: Vector2, speed: float,
		lifetime: float, beam_length: float, beam_width: float, beam_color: Color) -> void:
	_add_network_player_bullet(pos, direction, speed, lifetime, beam_length,
		beam_width, beam_color)


func _add_network_player_bullet(pos: Vector2, direction: Vector2, speed: float,
		lifetime: float, beam_length: float, beam_width: float, beam_color: Color) -> void:
	var scene := load("res://scenes/bullet.tscn") as PackedScene
	if scene == null or get_tree().current_scene == null:
		return
	var bullet := scene.instantiate()
	bullet.global_position = pos
	bullet.direction = direction
	bullet.speed = speed
	bullet.lifetime = lifetime
	bullet.beam_length = beam_length
	bullet.beam_width = beam_width
	bullet.beam_color = beam_color
	bullet.network_visual = true
	get_tree().current_scene.add_child(bullet)


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
