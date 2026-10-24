extends Node2D

# The bridge between the network and the world.
#
# The host runs the game: it spawns the enemies, lets them think and takes
# the damage. The clients only draw what the host tells them and pass their
# own shots back to the host, so everybody sees the same fight.
#
# Remote things move by chasing a target position, which keeps them smooth
# even though the updates only arrive a few times a second.

const SHAPE_SCENE := preload("res://scenes/enemy.tscn")
const SHOOTER_SCENE := preload("res://scenes/shooter_enemy.tscn")
const DOUBLE_SCENE := preload("res://scenes/double_enemy.tscn")
const RAILGUN_SCENE := preload("res://scenes/railgun_enemy.tscn")
const CHARGER_SCENE := preload("res://scenes/charger_enemy.tscn")
const REMOTE_PLAYER := preload("res://scenes/remote_player.tscn")

# how fast a remote thing catches up with the position it was told about
const FOLLOW_SPEED := 14.0
# the rotation is followed a bit slower so it does not snap
const FOLLOW_TURN := 10.0

# net id -> the node that draws it
var _enemies: Dictionary = {}
# peer id -> the node that draws it
var _players: Dictionary = {}


func _ready() -> void:
	add_to_group("net_world")
	Net.world = self
	Net.players_changed.connect(_on_players_changed)
	_on_players_changed()


func _exit_tree() -> void:
	if Net.world == self:
		Net.world = null


func _process(_delta: float) -> void:
	# the host streams the world out, the clients follow what they receive
	if Net.is_host():
		Net.push_enemies()
		Net.push_host_player()


# --- enemies ----------------------------------------------------------------
# The host spawns one and tells the clients about it.
func spawn_enemy(kind: String, pos: Vector2, params: Dictionary) -> Node2D:
	var node := _make_enemy(kind, pos, params)
	if node == null:
		return null
	var id := Net.spawn_enemy(kind, pos, params)
	node.set("net_id", id)
	node.set("_net_target", pos)
	# the host thinks for this enemy itself
	node.set("_net_copy", false)
	_enemies[id] = node
	return node


# A client hears about a new enemy and makes one.
func enemy_spawned(kind: String, pos: Vector2, params: Dictionary, id: int) -> void:
	if _enemies.has(id):
		return
	var node := _make_enemy(kind, pos, params)
	if node == null:
		return
	node.set("net_id", id)
	node.set("_net_target", pos)
	# on a client the enemy is only a copy of the one on the host
	node.set("_net_copy", true)
	_enemies[id] = node


func _make_enemy(kind: String, pos: Vector2, params: Dictionary) -> Node2D:
	match kind:
		"shape":
			var e := SHAPE_SCENE.instantiate() as Node2D
			e.global_position = pos
			add_child(e)
			e.call("setup", int(params.get("sides", 3)), float(params.get("radius", 26.0)),
				float(params.get("speed_mult", 1.0)), int(params.get("dmg_bonus", 0)))
			return e
		"shooter":
			var e := SHOOTER_SCENE.instantiate() as Node2D
			e.global_position = pos
			add_child(e)
			e.call("setup", float(params.get("speed_mult", 1.0)), int(params.get("dmg_bonus", 0)),
				float(params.get("fire_mult", 1.0)), float(params.get("hp_mult", 1.0)))
			return e
		"double":
			var e := DOUBLE_SCENE.instantiate() as Node2D
			e.global_position = pos
			add_child(e)
			e.call("setup", float(params.get("speed_mult", 1.0)), int(params.get("dmg_bonus", 0)),
				float(params.get("fire_mult", 1.0)), float(params.get("hp_mult", 1.0)))
			return e
		"railgun":
			var e := RAILGUN_SCENE.instantiate() as Node2D
			e.global_position = pos
			add_child(e)
			e.call("setup", float(params.get("speed_mult", 1.0)), int(params.get("dmg_bonus", 0)),
				float(params.get("fire_mult", 1.0)), float(params.get("hp_mult", 1.0)))
			return e
		"charger":
			var e := CHARGER_SCENE.instantiate() as Node2D
			e.global_position = pos
			add_child(e)
			e.call("setup", float(params.get("speed_mult", 1.0)), int(params.get("dmg_bonus", 0)),
				float(params.get("fire_mult", 1.0)), float(params.get("hp_mult", 1.0)))
			return e
	return null


# The host tells everybody where the enemies are.
func enemies_synced(data: Dictionary) -> void:
	for id in data:
		var row: Array = data[id]
		var n: Node2D = _enemies.get(id)
		if n == null or not is_instance_valid(n):
			continue
		n.set("_net_target", Vector2(row[0], row[1]))
		n.set("_net_rot", row[2])
		n.set("hp", int(row[3]))
		n.set("_net_alive", row[4] == true)
		if n.has_method("_update_bar"):
			n.call("_update_bar")


# A client says an enemy took a hit, the host applies it.
func enemy_hit(id: int, amount: float, kind: String, from_peer: int = 0) -> void:
	var n: Node2D = _enemies.get(id)
	if n == null or not is_instance_valid(n):
		return
	# remember who hit it, that player earns the xp
	if from_peer > 0:
		n.set("_net_hitter", from_peer)
	if n.has_method("take_damage"):
		n.call("take_damage", amount, kind)


func enemy_removed(id: int) -> void:
	var n: Node2D = _enemies.get(id)
	if n != null and is_instance_valid(n):
		n.queue_free()
	_enemies.erase(id)


# --- players ----------------------------------------------------------------
# A client hears where another player is.
func player_state(id: int, pos: Vector2, rot: float, hp: float, alive: bool) -> void:
	var p: Node2D = _players.get(id)
	if p == null or not is_instance_valid(p):
		p = _make_remote_player(id)
		if p == null:
			return
		_players[id] = p
	p.set("_net_target", pos)
	p.set("_net_rot", rot)
	p.set("net_hp", hp)
	p.set("net_alive", alive)


# The players that are still in the game, so a dead one knows who to watch.
func alive_peers() -> Array:
	var out: Array = []
	for id in _players:
		var p: Node2D = _players[id]
		if p == null or not is_instance_valid(p):
			continue
		if bool(p.get("net_alive")):
			out.append(int(id))
	return out


# The ship of a player, so the camera can follow it.
func peer_node(id: int) -> Node2D:
	var p: Node2D = _players.get(id)
	if p == null or not is_instance_valid(p):
		return null
	return p


func _make_remote_player(id: int) -> Node2D:
	var p := REMOTE_PLAYER.instantiate() as Node2D
	add_child(p)
	p.set("net_id", id)
	p.set("net_name", Net.player_name_of(id))
	p.set("net_color", Net.player_color_of(id))
	return p


# The names can arrive after the ships were made, so they are refreshed here.
func _refresh_player_names() -> void:
	for id in _players:
		var p: Node2D = _players[id]
		if p == null or not is_instance_valid(p):
			continue
		p.set("net_name", Net.player_name_of(int(id)))
		p.set("net_color", Net.player_color_of(int(id)))
		p.call("_refresh_name")


# Keep the list of drawn players in sync with the room.
func _on_players_changed() -> void:
	# drop the players that left
	for id in _players.keys():
		var known := false
		for info in Net.players:
			if int(info["id"]) == int(id):
				known = true
				break
		if not known:
			var p: Node2D = _players[id]
			if p != null and is_instance_valid(p):
				p.queue_free()
			_players.erase(id)
	# add the ones that joined
	for info in Net.players:
		var id := int(info["id"])
		if id == Net.my_id() or _players.has(id):
			continue
		var p2 := _make_remote_player(id)
		if p2 != null:
			_players[id] = p2
	# and make sure every name is up to date
	_refresh_player_names()
