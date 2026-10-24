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
const ORB_ENEMY_SCENE := preload("res://scenes/orb_enemy.tscn")
const REMOTE_PLAYER := preload("res://scenes/remote_player.tscn")

# how fast a remote thing catches up with the position it was told about
const FOLLOW_SPEED := 14.0
# the rotation is followed a bit slower so it does not snap
const FOLLOW_TURN := 10.0

# net id -> the node that draws it
var _enemies: Dictionary = {}
# peer id -> the node that draws it
var _players: Dictionary = {}
# peers whose death has been received; stale movement packets cannot recreate
# their player until the next wave explicitly revives them
var _dead_peers: Dictionary = {}
var _network_ghosts: Dictionary = {}
var _host_ghost: Node2D = null


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
	_deduplicate_remote_players()
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
		"orb":
			var e := ORB_ENEMY_SCENE.instantiate() as Node2D
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
		var raw: Variant = _enemies.get(id)
		if raw == null or not is_instance_valid(raw):
			_enemies.erase(id)
			continue
		var n := raw as Node2D
		if n == null:
			_enemies.erase(id)
			continue
		n.set("_net_target", Vector2(row[0], row[1]))
		n.set("_net_rot", row[2])
		if row.size() >= 7:
			n.set_meta("net_velocity", Vector2(float(row[5]), float(row[6])))
		if row.size() >= 9:
			n.set("_burn", 2.0 if row[7] == true else 0.0)
			n.set("_slow", 2.0 if row[8] == true else 0.0)
		if row.size() >= 11:
			n.set("max_hp", int(row[10]))
			if row[9] == true and n.has_method("apply_network_elite"):
				n.call("apply_network_elite", int(row[10]))
		n.set("hp", int(row[3]))
		n.set("_net_alive", row[4] == true)
		if n.has_method("_update_bar"):
			n.call("_update_bar")


# A client says an enemy took a hit, the host applies it.
func enemy_hit(id: int, amount: float, kind: String, from_peer: int = 0) -> void:
	var raw: Variant = _enemies.get(id)
	if raw == null or not is_instance_valid(raw):
		_enemies.erase(id)
		return
	var n := raw as Node2D
	if n == null:
		_enemies.erase(id)
		return
	# remember who hit it, that player earns the xp
	if from_peer > 0:
		n.set("_net_hitter", from_peer)
	if n.has_method("take_damage"):
		n.call("take_damage", amount, kind)


func enemy_status(id: int, burn: int, freeze: int) -> void:
	var raw: Variant = _enemies.get(id)
	if raw == null or not is_instance_valid(raw):
		_enemies.erase(id)
		return
	var n := raw as Node2D
	if n == null:
		_enemies.erase(id)
		return
	if n.has_method("apply_status"):
		n.call("apply_status", burn, freeze)


func enemy_removed(id: int) -> void:
	var raw: Variant = _enemies.get(id)
	if raw != null and is_instance_valid(raw):
		var n := raw as Node2D
		n.queue_free()
	_enemies.erase(id)


# --- players ----------------------------------------------------------------
# A client hears where another player is.
func player_state(id: int, pos: Vector2, rot: float, hp: float, alive: bool,
		spectate_target: int = 0, level: int = 1,
		velocity: Vector2 = Vector2.ZERO, thrust: float = 0.0, burning: bool = false,
		frozen: bool = false, stunned: bool = false) -> void:
	# The local Player node is the sole visual owner of this peer. A client can
	# receive its own reliable death packet back from the host, so never create
	# a RemotePlayer or a network ghost for the local id. Doing so produced the
	# duplicate ship/ghost seen after death.
	if id == Net.my_id():
		return
	if not alive:
		_dead_peers[id] = true
		_remove_remote_player(id)
		# The host ghost is sent directly to the player being watched. Creating
		# it from every client's remote proxy caused duplicate ghosts and colour
		# mismatches when the host died.
		if id != 1:
			_create_network_ghost(id, spectate_target, level, pos)
		return
	if _dead_peers.has(id):
		# A movement packet sent before the death arrived after it. Ignore it.
		return
	var raw: Variant = _players.get(id)
	var p: Node2D = null
	if raw != null and is_instance_valid(raw):
		p = raw as Node2D
	if p == null:
		p = _make_remote_player(id)
		if p == null:
			return
		_players[id] = p
	p.set("_net_target", pos)
	p.set("_net_rot", rot)
	p.set("net_hp", hp)
	p.set("net_alive", alive)
	p.set("net_spectate_target", spectate_target)
	p.set("net_level", level)
	p.set("net_velocity", velocity)
	p.set("net_thrust", thrust)
	p.set("net_burning", burning)
	p.set("net_frozen", frozen)
	p.set("net_stunned", stunned)
	p.queue_redraw()


func revive_remote_players() -> void:
	_dead_peers.clear()
	_clear_spectator_ghosts()
	for id in _network_ghosts.keys():
		var ghost: Variant = _network_ghosts[id]
		if ghost != null and is_instance_valid(ghost):
			ghost.queue_free()
	_network_ghosts.clear()
	for raw in _players.values():
		var p := raw as Node2D
		if p == null or not is_instance_valid(p):
			continue
		p.set("net_death_locked", false)
		p.set("net_alive", true)
		p.set("net_spectate_target", 0)
		p.set("net_hp", 1.0)


func show_host_ghost(level: int) -> void:
	clear_host_ghost()
	var ghost := Node2D.new()
	ghost.set_script(load("res://scripts/ghost.gd"))
	ghost.set("network_owned", true)
	ghost.set("local_target", true)
	ghost.set("ghost_name", "%s %d" % [Net.player_name_of(1), level])
	get_tree().current_scene.add_child(ghost)
	_host_ghost = ghost


func clear_host_ghost() -> void:
	if _host_ghost != null and is_instance_valid(_host_ghost):
		_host_ghost.queue_free()
	_host_ghost = null


func _clear_spectator_ghosts() -> void:
	# Do not rely only on _network_ghosts: a ghost can be created locally by
	# Player while the reliable death packet creates another one on the same
	# frame. Remove every scene-level ghost so revival always leaves one clean
	# player per peer.
	for node in get_tree().get_nodes_in_group("spectator_ghost"):
		if node != null and is_instance_valid(node):
			node.queue_free()
	_network_ghosts.clear()


func _remove_remote_player(id: int) -> void:
	var raw: Variant = _players.get(id)
	if raw != null and is_instance_valid(raw):
		(raw as Node).queue_free()
	_players.erase(id)


func _create_network_ghost(id: int, target_id: int, level: int, pos: Vector2) -> void:
	if id == Net.my_id() or target_id <= 0 or target_id == id:
		return
	var old: Variant = _network_ghosts.get(id)
	if old != null and is_instance_valid(old) and not old.is_queued_for_deletion():
		old.call("set_target_id", target_id)
		return
	_network_ghosts.erase(id)
	var ghost := Node2D.new()
	ghost.set_script(load("res://scripts/ghost.gd"))
	ghost.set("network_owned", true)
	ghost.set("ghost_name", "%s %d" % [Net.player_name_of(id), level])
	ghost.global_position = pos
	get_tree().current_scene.add_child(ghost)
	ghost.call("set_target_id", target_id)
	_network_ghosts[id] = ghost


# The players that are still in the game, so a dead one knows who to watch.
func alive_peers() -> Array:
	var out: Array = []
	# The host's own player is not in _players because it is the real Player
	# node. Include it so a dead host can spectate a surviving client.
	var local := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if Net.is_host() and local != null and not bool(local.get("_dead")):
		out.append(1)
	for id in _players.keys():
		var raw: Variant = _players[id]
		if raw == null or not is_instance_valid(raw):
			_players.erase(id)
			continue
		var p := raw as Node2D
		if p == null:
			_players.erase(id)
			continue
		if bool(p.get("net_alive")):
			out.append(int(id))
	return out


# The ship of a player, so the camera can follow it.
func peer_node(id: int) -> Node2D:
	if _dead_peers.has(id):
		return null
	if Net.is_host() and id == 1:
		return get_tree().current_scene.get_node_or_null("Player") as Node2D
	var raw: Variant = _players.get(id)
	if raw == null or not is_instance_valid(raw):
		_players.erase(id)
		# A spectate request can arrive in the same frame as the player list.
		# Build the proxy lazily when the list already knows this peer.
		for info in Net.players:
			if int(info.get("id", 0)) == id:
				var created := _make_remote_player(id)
				if created != null:
					_players[id] = created
					return created
		return null
	var p := raw as Node2D
	if p == null:
		_players.erase(id)
		return null
	return p


func _make_remote_player(id: int) -> Node2D:
	# The player list and a state packet can arrive in the same frame. Reuse an
	# already existing node by net_id instead of creating a visual duplicate.
	for child in get_children():
		var existing := child as Node2D
		if existing == null or existing.is_queued_for_deletion():
			continue
		if not existing.is_in_group("player"):
			continue
		if int(existing.get("net_id")) == id:
			return existing
	var p := REMOTE_PLAYER.instantiate() as Node2D
	# Set the identity before entering the scene tree. This prevents _ready and
	# same-frame network callbacks from observing net_id == 0 and creating a
	# second proxy for the same peer.
	p.set("net_id", id)
	p.set("net_name", Net.player_name_of(id))
	p.set("net_color", Net.player_color_of(id))
	add_child(p)
	return p


func _deduplicate_remote_players() -> void:
	# Network player-list and state packets can create the same proxy through
	# different code paths. Keep exactly one visual node for each peer id.
	var canonical: Dictionary = {}
	for child in get_children():
		var node := child as Node2D
		if node == null or node.is_queued_for_deletion():
			continue
		if not node.is_in_group("player"):
			continue
		var id := int(node.get("net_id"))
		if id <= 0:
			# An orphaned proxy with no network identity cannot represent a real
			# peer. Remove it instead of allowing it to become the differently
			# coloured duplicate seen after a death/revive race.
			node.queue_free()
			continue
		if _dead_peers.has(id):
			node.queue_free()
			continue
		if canonical.has(id):
			node.queue_free()
			continue
		canonical[id] = node
	_players = canonical


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
	var ghost_ids: Array = _network_ghosts.keys()
	for id in ghost_ids:
		var still_here := false
		for info in Net.players:
			if int(info.get("id", 0)) == int(id):
				still_here = true
				break
		if not still_here:
				var ghost: Variant = _network_ghosts[id]
				if ghost != null and is_instance_valid(ghost):
					ghost.queue_free()
				_network_ghosts.erase(id)
	# drop the players that left
	for id in _players.keys():
		var known := false
		for info in Net.players:
			if int(info["id"]) == int(id):
				known = true
				break
		if not known:
			_dead_peers.erase(id)
			var p: Node2D = _players[id]
			if p != null and is_instance_valid(p):
				p.queue_free()
			_players.erase(id)
	# add the ones that joined
	for info in Net.players:
		var id := int(info["id"])
		if _dead_peers.has(id):
			continue
		if id == Net.my_id() or _players.has(id):
			continue
		var p2 := _make_remote_player(id)
		if p2 != null:
			_players[id] = p2
	# and make sure every name is up to date
	_refresh_player_names()
