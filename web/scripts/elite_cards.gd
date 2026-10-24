extends RefCounted
class_name WebEliteCards

# Derive combat modifiers for an elite from the upgrade cards it owns.
# Cards the player would normally pick instead make the elite stronger.
static func mods_for(cards: Array) -> Dictionary:
	var m := {
		"fire_rate": 1.0,
		"bullet_speed": 1.0,
		"damage": 1.0,
		"move_speed": 1.0,
		"burn": 0,
		"freeze": 0,
		"crit": 0.0,
		"regen": 0,
		"hp_bonus": 0,
	}
	for entry in cards:
		var card: Dictionary = entry
		match str(card.get("id", "")):
			"fire_rate":
				m["fire_rate"] = float(m["fire_rate"]) * 1.18
			"bullet_speed":
				m["bullet_speed"] = float(m["bullet_speed"]) * 1.20
			"damage":
				m["damage"] = float(m["damage"]) * 1.20
			"move_speed":
				m["move_speed"] = float(m["move_speed"]) * 1.14
			"burn":
				m["burn"] = int(m["burn"]) + 1
			"freeze":
				m["freeze"] = int(m["freeze"]) + 1
			"crit":
				m["crit"] = float(m["crit"]) + 0.12
			"regen":
				m["regen"] = int(m["regen"]) + 1
			"max_hp":
				m["hp_bonus"] = int(m["hp_bonus"]) + 2
	return m
