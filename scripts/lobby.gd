extends CanvasLayer

# The lobby. The player who creates a room becomes the host: their machine
# runs the server and owns the game, everybody else joins from the network.
#
# Rooms are found on the local network, so a friend only has to be on the same
# wifi (or the same cable) and press join.

const MAX_PLAYERS := 4
const GAME_SCENE := "res://scenes/main.tscn"
const NAME_PROMPT := preload("res://scenes/name_prompt.tscn")

const ROOM_NAMES := [
	"DEATH MACHINE", "NOOB ZONE", "LAST ONE STANDING", "COFFEE BREAK", "NIGHT SHIFT",
]

@onready var _rooms_list: VBoxContainer = $UI/RoomsList
@onready var _empty_label: Label = $UI/EmptyLabel
@onready var _create_btn: Button = $UI/CreateRoomButton
@onready var _solo_btn: Button = $UI/PlaySoloButton
@onready var _join_btn: Button = $UI/JoinRoomButton
@onready var _refresh_btn: Button = $UI/RefreshRoomsButton
@onready var _back_btn: Button = $UI/BackButton
@onready var _header: Label = $UI/Header
@onready var _sub_header: Label = $UI/SubHeader
@onready var _create_panel: Control = $UI/CreatePanel
@onready var _name_edit: LineEdit = $UI/CreatePanel/NameEdit
@onready var _web_mode_btn: Button = $UI/CreatePanel/WebModeButton
@onready var _create_confirm: Button = $UI/CreatePanel/CreateConfirm
@onready var _create_cancel: Button = $UI/CreatePanel/CreateCancel
@onready var _address_panel: Control = $UI/AddressPanel
@onready var _address_edit: LineEdit = $UI/AddressPanel/AddressEdit
@onready var _address_join: Button = $UI/AddressPanel/AddressJoin
@onready var _room_panel: Control = $UI/RoomPanel
@onready var _room_title: Label = $UI/RoomPanel/RoomTitle
@onready var _status: Label = $UI/RoomPanel/Status
@onready var _room_address: Label = $UI/RoomPanel/RoomAddress
@onready var _copy_address_btn: Button = $UI/RoomPanel/CopyAddressButton
@onready var _start_btn: Button = $UI/RoomPanel/StartButton
@onready var _add_btn: Button = $UI/RoomPanel/AddPlayerButton
@onready var _leave_btn: Button = $UI/RoomPanel/LeaveButton
@onready var _slots: Array = [
	$UI/RoomPanel/SlotTL, $UI/RoomPanel/SlotTR,
	$UI/RoomPanel/SlotBL, $UI/RoomPanel/SlotBR,
]

var _creating: bool = false
var _in_room: bool = false
# the address box is only open after the join by host button was pressed
var _address_open: bool = false
# a room that speaks websocket can be joined from a browser
var _web_mode: bool = false
var _name_prompt: Control


func _ready() -> void:
	if Web.has_update():
		Web.show_web_update_button()
	_create_btn.pressed.connect(_on_create)
	_join_btn.pressed.connect(_on_join_pressed)
	_refresh_btn.pressed.connect(_on_refresh_rooms)
	_back_btn.pressed.connect(_on_back)
	_leave_btn.pressed.connect(_on_leave)
	_copy_address_btn.pressed.connect(_on_copy_room_address)
	_add_btn.pressed.connect(_on_add_player)
	_start_btn.pressed.connect(_on_start)
	_create_confirm.pressed.connect(_on_create_confirm)
	_create_cancel.pressed.connect(_on_create_cancel)
	_web_mode_btn.pressed.connect(_on_toggle_web_mode)
	_address_join.pressed.connect(_on_join_address)
	_address_edit.text_submitted.connect(func(_t): _on_join_address())
	_name_edit.text_submitted.connect(func(_t): _on_create_confirm())
	Net.rooms_changed.connect(_refresh)
	Net.players_changed.connect(_refresh)
	Net.room_joined.connect(_on_room_joined)
	Net.room_left.connect(_on_room_left)
	Net.session_failed.connect(_on_session_failed)
	Net.player_name_taken.connect(_on_player_name_taken)
	_refresh()
	_set_localized(_header, "ROOM")
	_refresh_web_mode()
	if Net.name_change_required:
		_on_player_name_taken()
	_solo_btn.pressed.connect(_on_play_solo)
	_solo_btn.visible = OS.has_feature("web")
	# a browser cannot host, and it cannot look for rooms either
	if not Net.can_host():
		_create_btn.disabled = true
		_set_localized(_create_btn, "CANNOT HOST HERE")
		_set_localized(
			_sub_header,
			"a browser can only join a desktop host - use JOIN BY HOST"
		)
	# Let the lobby finish entering the scene before opening UDP discovery.
	# This avoids blocking/crashing during scene creation on Android and keeps
	# the Play transition safe on desktop.
	call_deferred("_start_room_browser")


func _start_room_browser() -> void:
	if is_inside_tree():
		Net.browse_rooms()


# --- views ----------------------------------------------------------------
func _refresh() -> void:
	if _creating:
		_show_create_view()
		return
	_create_panel.visible = false
	_room_panel.visible = _in_room
	_header.visible = not _in_room
	_sub_header.visible = not _in_room
	_rooms_list.visible = not _in_room
	_create_btn.visible = not _in_room
	_join_btn.visible = not _in_room
	_refresh_btn.visible = not _in_room
	_empty_label.visible = not _in_room
	_back_btn.visible = not _in_room
	_solo_btn.visible = OS.has_feature("web") and not _in_room
	# the address box only shows after the join by host button was pressed
	_address_panel.visible = _address_open and not _in_room
	if _in_room:
		_refresh_room()
	else:
		_refresh_room_list()


func _refresh_web_mode() -> void:
	var text := "CONNECTION: BROWSER FRIENDLY" if _web_mode \
		else "CONNECTION: FAST (LAN)"
	_web_mode_btn.text = _localized_text(text)


func _refresh_room_list() -> void:
	for c in _rooms_list.get_children():
		c.queue_free()
	_empty_label.visible = Net.rooms.is_empty()
	if Net.rooms.is_empty():
		if Net.can_host():
			var text := "no rooms found - create one, or use JOIN BY HOST\n" \
				+ "auto-discovery needs the same Wi-Fi/LAN; otherwise enter the host IP"
			_empty_label.text = _localized_text(text)
		else:
			_empty_label.text = _localized_text("a browser cannot find rooms - use JOIN BY HOST")
	for i in Net.rooms.size():
		var room: Dictionary = Net.rooms[i]
		var count := int(room["count"])
		var b := Button.new()
		var tag := " (browser)" if bool(room.get("web", false)) else ""
		var text := "%s%s        %d / %d        %s" % [
			str(room["name"]), tag, count, MAX_PLAYERS, str(room["address"])]
		b.text = _localized_text(text)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 17)
		b.disabled = count >= MAX_PLAYERS
		b.pressed.connect(_on_join.bind(i))
		_rooms_list.add_child(b)


func _refresh_room() -> void:
	_room_title.text = _localized_text(Net.room_name if Net.room_name != "" else "ROOM")
	var players: Array = Net.players
	var host := _is_host()
	var room_address := Net.room_connect_address()
	_room_address.text = _localized_text("JOIN ADDRESS: %s" % room_address)
	_copy_address_btn.visible = host
	_copy_address_btn.tooltip_text = room_address

	for i in _slots.size():
		var slot: Panel = _slots[i]
		var ship: TextureRect = slot.get_node("Ship")
		var lbl: Label = slot.get_node("Name")
		var kick: Button = slot.get_node("Kick")
		if i < players.size():
			var info: Dictionary = players[i]
			var id := int(info["id"])
			lbl.text = str(info["name"])
			ship.visible = true
			ship.modulate = info["color"]
			kick.visible = host and id != Net.my_id()
			if not kick.pressed.is_connected(_on_kick.bind(id)):
				kick.pressed.connect(_on_kick.bind(id))
		else:
			lbl.text = _localized_text("open slot")
			ship.visible = false
			kick.visible = false

	var full: bool = players.size() >= MAX_PLAYERS
	_start_btn.visible = host
	_add_btn.visible = false
	# the host may start whenever they like, even with empty slots
	_start_btn.disabled = false
	if host:
		if full:
			_status.text = _localized_text(
				"ready to start  -  %d / %d" % [players.size(), MAX_PLAYERS]
			)
		else:
			_status.text = _localized_text(
				"%d / %d players - start whenever you like" % [players.size(), MAX_PLAYERS]
			)
	else:
		_status.text = _localized_text("waiting for the host to start...")


func _on_copy_room_address() -> void:
	var address := Net.room_connect_address()
	DisplayServer.clipboard_set(address)
	_copy_address_btn.text = _localized_text("COPIED")


func _show_create_view() -> void:
	# only the room creation UI stays visible
	_header.visible = false
	_sub_header.visible = false
	_rooms_list.visible = false
	_empty_label.visible = false
	_create_btn.visible = false
	_join_btn.visible = false
	_refresh_btn.visible = false
	_back_btn.visible = false
	_room_panel.visible = false
	_address_open = false
	_address_panel.visible = false
	_create_panel.visible = true
	_name_edit.grab_focus()


func _is_host() -> bool:
	return Net.is_host()


# --- actions --------------------------------------------------------------
func _on_create() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	_creating = true
	_name_edit.text = ROOM_NAMES[randi() % ROOM_NAMES.size()]
	_refresh()


func _on_create_cancel() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	_creating = false
	_refresh()


func _on_create_confirm() -> void:
	Game.sfx("cardget", -9.0, 0.98, 1.05)
	_creating = false
	var room_name := _name_edit.text.strip_edges()
	if room_name == "":
		room_name = ROOM_NAMES[randi() % ROOM_NAMES.size()]
	Net.player_name = _player_name()
	if not Net.host_room(room_name, Net.DEFAULT_PORT, _web_mode):
		_refresh()
		return
	_in_room = true
	_refresh()


func _on_toggle_web_mode() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	_web_mode = not _web_mode
	_refresh_web_mode()


# The player typed the address of a host, that is the only way to find a room
# from a browser.
func _on_join_pressed() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	# the address box opens right under the buttons, not in the middle
	_address_open = not _address_open
	_address_panel.visible = _address_open
	if _address_open and _address_edit:
		_address_edit.grab_focus()


func _on_refresh_rooms() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	Net.refresh_rooms()


func _on_join_address() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	var text := _address_edit.text.strip_edges()
	if text == "":
		return
	var address := text
	var port := Net.DEFAULT_PORT
	# a browser can only reach a websocket room, a desktop can use either
	var web := OS.has_feature("web")
	if text.begins_with("ws://") or text.begins_with("wss://"):
		web = true
		address = text
		port = _url_port(text)
		if port <= 0:
			port = 443 if text.begins_with("wss://") else 80
	else:
		# an address may come with the port on it
		if text.contains(":"):
			var bits := text.rsplit(":", true, 1)
			address = bits[0]
			if bits[1].is_valid_int():
				port = int(bits[1])
	# an https page is not allowed to open a plain ws:// connection
	var probe := address if address.begins_with("ws://") else "ws://" + address
	if web and Web.page_is_secure() and not address.begins_with("wss://") \
			and not _is_local_address(probe):
		_set_localized(
			_sub_header,
			"this page is https - type a secure wss:// host address"
		)
		return
	Net.player_name = _player_name()
	if not Net.join_room(address, port, web):
		return
	_in_room = true
	_address_open = false
	_address_panel.visible = false
	_refresh()


# The port written in a full websocket address, -1 when there is none.
func _url_port(url: String) -> int:
	var scheme_end := url.find("://")
	if scheme_end < 0:
		return -1
	var rest := url.substr(scheme_end + 3)
	var slash := rest.find("/")
	if slash >= 0:
		rest = rest.substr(0, slash)
	var colon := rest.rfind(":")
	if colon >= 0 and rest.substr(colon + 1).is_valid_int():
		return int(rest.substr(colon + 1))
	return -1


# A browser may open ws:// on localhost even from a secure page.
func _is_local_address(url: String) -> bool:
	var scheme_end := url.find("://")
	var rest := url.substr(scheme_end + 3)
	var slash := rest.find("/")
	if slash >= 0:
		rest = rest.substr(0, slash)
	var colon := rest.rfind(":")
	if colon >= 0:
		rest = rest.substr(0, colon)
	rest = rest.to_lower()
	return rest == "localhost" or rest == "127.0.0.1" \
		or rest == "::1" or rest == "[::1]"


func _on_join(index: int) -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	if index < 0 or index >= Net.rooms.size():
		return
	var room: Dictionary = Net.rooms[index]
	Net.player_name = _player_name()
	# the room tells how it talks, a browser can only join a websocket room
	var web := bool(room.get("web", false))
	if not Net.join_room(str(room["address"]), int(room["port"]), web):
		return
	_in_room = true
	_address_open = false
	_address_panel.visible = false
	_refresh()


func _on_leave() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	Net.leave()
	Net.browse_rooms()
	_in_room = false
	_address_open = false
	_refresh()


func _on_kick(id: int) -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	if not _is_host():
		return
	Net.kick_player(id)


func _on_add_player() -> void:
	# there are no fake players any more, the room fills up with real ones
	pass


func _on_play_solo() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	Net.leave()
	Game.reset_run()
	Net.player_name = _player_name()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_start() -> void:
	if not _is_host():
		return
	Game.sfx("cardget", -8.0, 0.98, 1.04)
	Game.reset_run()
	Net.start_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_back() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	Net.leave()
	call_deferred("_change_to_mode_lobby")


func _change_to_mode_lobby() -> void:
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")


# --- net callbacks --------------------------------------------------------
func _on_room_joined() -> void:
	_in_room = true
	_address_open = false
	_address_panel.visible = false
	_refresh()


func _on_room_left() -> void:
	_in_room = false
	_refresh()


func _on_session_failed(reason: String) -> void:
	_in_room = false
	_creating = false
	_set_localized(_sub_header, reason)
	_refresh()


func _on_player_name_taken() -> void:
	if is_instance_valid(_name_prompt):
		return
	_name_prompt = NAME_PROMPT.instantiate() as Control
	add_child(_name_prompt)
	_name_prompt.call("show_name_taken")
	_name_prompt.name_chosen.connect(_on_replacement_name_chosen)


func _on_replacement_name_chosen(_name: String) -> void:
	_name_prompt = null
	Net.retry_hello()


# Every player gets a name of their own. The name the player typed at the
# start of the game is used, a random one only when they skipped it.
func _player_name() -> String:
	if Net.player_name != "":
		return Net.player_name
	var names := ["NOVA", "KITE", "VEX", "ECHO", "RUNE", "PIXEL", "ASH", "ZEPHYR", "ONYX", "FLINT"]
	var pick: String = names[randi() % names.size()]
	Net.player_name = pick
	return pick


func _localized_text(text: String) -> String:
	var locale := get_node_or_null("/root/Locale")
	return locale.translate_text(text) if locale else text


func _set_localized(control: Control, source_text: String) -> void:
	var locale := get_node_or_null("/root/Locale")
	if locale:
		locale.localize_control(control, source_text)
	else:
		control.set("text", source_text)
