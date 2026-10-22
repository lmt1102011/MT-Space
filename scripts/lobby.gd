extends CanvasLayer

# The lobby. The player who creates a room becomes the host: their machine
# runs the server and owns the game, everybody else joins from the network.
#
# Rooms are found on the local network, so a friend only has to be on the same
# wifi (or the same cable) and press join.

const MAX_PLAYERS := 4
const GAME_SCENE := "res://scenes/main.tscn"

const ROOM_NAMES := [
	"DEATH MACHINE", "NOOB ZONE", "LAST ONE STANDING", "COFFEE BREAK", "NIGHT SHIFT",
]

@onready var _rooms_list: VBoxContainer = $UI/RoomsList
@onready var _empty_label: Label = $UI/EmptyLabel
@onready var _create_btn: Button = $UI/CreateRoomButton
@onready var _back_btn: Button = $UI/BackButton
@onready var _header: Label = $UI/Header
@onready var _sub_header: Label = $UI/SubHeader
@onready var _create_panel: Control = $UI/CreatePanel
@onready var _name_edit: LineEdit = $UI/CreatePanel/NameEdit
@onready var _create_confirm: Button = $UI/CreatePanel/CreateConfirm
@onready var _create_cancel: Button = $UI/CreatePanel/CreateCancel
@onready var _room_panel: Control = $UI/RoomPanel
@onready var _room_title: Label = $UI/RoomPanel/RoomTitle
@onready var _status: Label = $UI/RoomPanel/Status
@onready var _start_btn: Button = $UI/RoomPanel/StartButton
@onready var _add_btn: Button = $UI/RoomPanel/AddPlayerButton
@onready var _leave_btn: Button = $UI/RoomPanel/LeaveButton
@onready var _slots: Array = [
	$UI/RoomPanel/SlotTL, $UI/RoomPanel/SlotTR,
	$UI/RoomPanel/SlotBL, $UI/RoomPanel/SlotBR,
]

var _my_room: int = -1          # index into Net.rooms
var _creating: bool = false
var _in_room: bool = false


func _ready() -> void:
	_create_btn.pressed.connect(_on_create)
	_back_btn.pressed.connect(_on_back)
	_leave_btn.pressed.connect(_on_leave)
	_add_btn.pressed.connect(_on_add_player)
	_start_btn.pressed.connect(_on_start)
	_create_confirm.pressed.connect(_on_create_confirm)
	_create_cancel.pressed.connect(_on_create_cancel)
	_name_edit.text_submitted.connect(func(_t): _on_create_confirm())
	Net.rooms_changed.connect(_refresh)
	Net.players_changed.connect(_refresh)
	Net.room_joined.connect(_on_room_joined)
	Net.room_left.connect(_on_room_left)
	Net.session_failed.connect(_on_session_failed)
	_refresh()
	# the web build has no udp, so there is nothing to look for there
	if not Net.is_network_available():
		_create_btn.disabled = true
		_sub_header.text = "multiplayer is not available in the browser - single player only"


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
	_empty_label.visible = not _in_room
	_back_btn.visible = not _in_room
	if _in_room:
		_refresh_room()
	else:
		_refresh_room_list()


func _refresh_room_list() -> void:
	for c in _rooms_list.get_children():
		c.queue_free()
	_empty_label.visible = Net.rooms.is_empty()
	if Net.rooms.is_empty():
		_sub_header.text = "looking for rooms on this network..."
	for i in Net.rooms.size():
		var room: Dictionary = Net.rooms[i]
		var count := int(room["count"])
		var b := Button.new()
		b.text = "%s        %d / %d        %s" % [
			str(room["name"]), count, MAX_PLAYERS, str(room["address"])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 17)
		b.disabled = count >= MAX_PLAYERS
		b.pressed.connect(_on_join.bind(i))
		_rooms_list.add_child(b)


func _refresh_room() -> void:
	_room_title.text = Net.room_name if Net.room_name != "" else "ROOM"
	var players: Array = Net.players
	var host := _is_host()

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
			lbl.text = "open slot"
			ship.visible = false
			kick.visible = false

	var full: bool = players.size() >= MAX_PLAYERS
	_start_btn.visible = host
	_add_btn.visible = false
	# the host may start whenever they like, even with empty slots
	_start_btn.disabled = false
	if host:
		if full:
			_status.text = "ready to start  -  %d / %d" % [players.size(), MAX_PLAYERS]
		else:
			_status.text = "%d / %d players - start whenever you like" % [players.size(), MAX_PLAYERS]
	else:
		_status.text = "waiting for the host to start..."


func _show_create_view() -> void:
	# only the room creation UI stays visible
	_header.visible = false
	_sub_header.visible = false
	_rooms_list.visible = false
	_empty_label.visible = false
	_create_btn.visible = false
	_back_btn.visible = false
	_room_panel.visible = false
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
	var name := _name_edit.text.strip_edges()
	if name == "":
		name = ROOM_NAMES[randi() % ROOM_NAMES.size()]
	Net.player_name = _player_name()
	if not Net.host_room(name):
		return
	_in_room = true
	_refresh()


func _on_join(index: int) -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	if index < 0 or index >= Net.rooms.size():
		return
	var room: Dictionary = Net.rooms[index]
	Net.player_name = _player_name()
	if not Net.join_room(str(room["address"]), int(room["port"])):
		return
	_in_room = true
	_refresh()


func _on_leave() -> void:
	Game.sfx("click", -10.0, 0.95, 1.05)
	Net.leave()
	_in_room = false
	_refresh()


func _on_kick(id: int) -> void:
	Game.sfx("click", -12.0, 0.95, 1.05)
	if not _is_host():
		return
	Net.kick_player(id)


func _on_add_player() -> void:
	# there are no fake players any more, the room fills up with real ones
	pass


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
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# --- net callbacks --------------------------------------------------------
func _on_room_joined() -> void:
	_in_room = true
	_refresh()


func _on_room_left() -> void:
	_in_room = false
	_refresh()


func _on_session_failed(reason: String) -> void:
	_in_room = false
	_creating = false
	_sub_header.text = reason
	_refresh()


# Every player gets a name of their own. The name the player typed at the
# start of the game is used, a random one only when they skipped it.
func _player_name() -> String:
	if Net.player_name != "":
		return Net.player_name
	var names := ["NOVA", "KITE", "VEX", "ECHO", "RUNE", "PIXEL", "ASH", "ZEPHYR", "ONYX", "FLINT"]
	var pick: String = names[randi() % names.size()]
	Net.player_name = pick
	return pick
