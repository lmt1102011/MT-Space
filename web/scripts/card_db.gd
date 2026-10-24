extends RefCounted
class_name WebCardDB

enum Rarity { COMMON, RARE, EPIC }
enum Category { PASSIVE, WEAPON }

const RARITY_COLORS := {
	Rarity.COMMON: Color(0.45, 0.85, 0.5),
	Rarity.RARE: Color(0.35, 0.6, 1.0),
	Rarity.EPIC: Color(0.75, 0.45, 0.95),
}

const RARITY_NAMES := {
	Rarity.COMMON: "COMMON",
	Rarity.RARE: "RARE",
	Rarity.EPIC: "EPIC",
}

# Passive cards: stat upgrades, always available.
static func passives() -> Array:
	return [
		{
			"id": "fire_rate", "cat": Category.PASSIVE,
			"name": "Rapid Fire", "desc": "+18% fire rate",
			"rarity": Rarity.COMMON, "max": 8,
			"apply": func(g): g.upg_fire_rate *= 1.18,
		},
		{
			"id": "bullet_speed", "cat": Category.PASSIVE,
			"name": "Hot Rounds", "desc": "+20% bullet speed",
			"rarity": Rarity.COMMON, "max": 8,
			"apply": func(g): g.upg_bullet_speed *= 1.20,
		},
		{
			"id": "move_speed", "cat": Category.PASSIVE,
			"name": "Turbo Thrusters", "desc": "+14% move speed",
			"rarity": Rarity.COMMON, "max": 8,
			"apply": func(g): g.upg_move_speed *= 1.14,
		},
		{
			"id": "damage", "cat": Category.PASSIVE,
			"name": "Heavy Slugs", "desc": "+20% bullet damage",
			"rarity": Rarity.RARE, "max": 8,
			"apply": func(g): g.upg_damage *= 1.20,
		},
		{
			"id": "burn", "cat": Category.PASSIVE,
			"name": "Incendiary", "desc": "Shots set enemies on fire",
			"rarity": Rarity.RARE, "max": 5,
			"apply": func(g): g.upg_burn += 1,
		},
		{
			"id": "freeze", "cat": Category.PASSIVE,
			"name": "Cryo Rounds", "desc": "Shots slow enemies",
			"rarity": Rarity.RARE, "max": 5,
			"apply": func(g): g.upg_freeze += 1,
		},
		{
			"id": "lifesteal", "cat": Category.PASSIVE,
			"name": "Vampiric Core", "desc": "Kills restore 1 HP",
			"rarity": Rarity.EPIC, "max": 1,
			"apply": func(g): g.upg_lifesteal = true,
		},
		{
			"id": "crit", "cat": Category.PASSIVE,
			"name": "Precision", "desc": "+12% crit chance (x2 dmg)",
			"rarity": Rarity.RARE, "max": 5,
			"apply": func(g): g.upg_crit += 0.12,
		},
		{
			"id": "orb_magnet", "cat": Category.PASSIVE,
			"name": "araviton", "desc": "+40% XP pickup range",
			"rarity": Rarity.COMMON, "max": 4,
			"apply": func(g): g.upg_magnet *= 1.4,
		},
		{
			"id": "max_hp", "cat": Category.PASSIVE,
			"name": "Reinforced Hull", "desc": "+2 max HP and heal 2",
			"rarity": Rarity.RARE, "max": 5,
			"apply": func(g):
				g.upg_bonus_hp += 2
				var pl: Node = g.get_tree().get_first_node_in_group("player")
				if pl and pl.has_method("heal"):
					pl.heal(2),
		},
		{
			"id": "regen", "cat": Category.PASSIVE,
			"name": "Nano Repair", "desc": "Regenerate 1 HP / 8s",
			"rarity": Rarity.EPIC, "max": 3,
			"apply": func(g): g.upg_regen += 1,
		},
		{
			"id": "pierce", "cat": Category.PASSIVE,
			"name": "Piercing Tips", "desc": "Bullets pierce +1 enemy",
			"rarity": Rarity.EPIC, "max": 3,
			"apply": func(g): g.upg_pierce += 1,
		},
		{
			"id": "homing", "cat": Category.PASSIVE,
			"name": "Homing Rounds", "desc": "Bullets curve toward the nearest foe",
			"rarity": Rarity.EPIC, "max": 2,
			"apply": func(g): g.upg_homing += 1,
		},
		{
			"id": "splash", "cat": Category.PASSIVE,
			"name": "Shatter", "desc": "Crit hits burst, hurting nearby foes",
			"rarity": Rarity.EPIC, "max": 3,
			"apply": func(g): g.upg_splash += 1,
		},
		{
			"id": "elite_hunter", "cat": Category.PASSIVE,
			"name": "Elite Hunter", "desc": "+50% damage to elite enemies",
			"rarity": Rarity.RARE, "max": 3,
			"apply": func(g): g.upg_elite_hunter += 1,
		},
		{
			"id": "bloodthirst", "cat": Category.PASSIVE,
			"name": "Bloodthirst", "desc": "Kills may restore 1 HP",
			"rarity": Rarity.EPIC, "max": 3,
			"apply": func(g): g.upg_bloodthirst += 1,
		},
		{
			"id": "plating", "cat": Category.PASSIVE,
			"name": "Hull Plating", "desc": "Take 1 less contact damage",
			"rarity": Rarity.RARE, "max": 3,
			"apply": func(g): g.upg_plating += 1,
		},
		{
			"id": "level_heal", "cat": Category.PASSIVE,
			"name": "Second Wind", "desc": "Restore 1 HP on every level up",
			"rarity": Rarity.RARE, "max": 3,
			"apply": func(g): g.upg_level_heal += 1,
		},
		{
			"id": "xp_greed", "cat": Category.PASSIVE,
			"name": "Greed", "desc": "+20% XP from orbs",
			"rarity": Rarity.RARE, "max": 2,
			"apply": func(g): g.upg_xp_greed += 1,
		},
		{
			"id": "inferno", "cat": Category.PASSIVE,
			"name": "Inferno", "desc": "Burn damage +40%",
			"rarity": Rarity.RARE, "max": 3,
			"apply": func(g): g.upg_inferno += 1,
		},
		{
			"id": "brittle", "cat": Category.PASSIVE,
			"name": "Brittle", "desc": "Frozen enemies take +35% damage",
			"rarity": Rarity.RARE, "max": 3,
			"apply": func(g): g.upg_brittle += 1,
		},
		{
			"id": "thorns", "cat": Category.PASSIVE,
			"name": "Thorns", "desc": "Taking a hit hurts nearby foes",
			"rarity": Rarity.RARE, "max": 3,
			"apply": func(g): g.upg_thorns += 1,
		},
		{
			"id": "pierce_focus", "cat": Category.PASSIVE,
			"name": "Piercing Focus", "desc": "Rounds gain damage as they pierce",
			"rarity": Rarity.EPIC, "max": 2,
			"apply": func(g): g.upg_pierce_focus += 1,
		},
		{
			"id": "explosive", "cat": Category.PASSIVE,
			"name": "Explosive Rounds", "desc": "Rounds burst when they expire",
			"rarity": Rarity.RARE, "max": 3,
			"apply": func(g): g.upg_explosive += 1,
		},
		{
			"id": "scavenger", "cat": Category.PASSIVE,
			"name": "Scavenger", "desc": "Kills drop +40% XP",
			"rarity": Rarity.RARE, "max": 2,
			"apply": func(g): g.upg_scavenger += 1,
		},
		{
			"id": "rushed", "cat": Category.PASSIVE,
			"name": "Rushed", "desc": "+25% fire rate, -15% bullet speed",
			"rarity": Rarity.RARE, "max": 3,
			"apply": func(g): g.upg_rushed += 1,
		},
		{
			"id": "heavy_caliber", "cat": Category.PASSIVE,
			"name": "Heavy Caliber", "desc": "+30% damage, -15% fire rate",
			"rarity": Rarity.RARE, "max": 3,
			"apply": func(g): g.upg_heavy_caliber += 1,
		},
		{
			"id": "second_chance", "cat": Category.PASSIVE,
			"name": "Second Chance", "desc": "Revive once with half HP",
			"rarity": Rarity.EPIC, "max": 1,
			"apply": func(g): g.upg_second_chance += 1,
		},
		{
			"id": "cold_blood", "cat": Category.PASSIVE,
			"name": "Cold Blood", "desc": "Crit chance rises as HP drops",
			"rarity": Rarity.RARE, "max": 3,
			"apply": func(g): g.upg_cold_blood += 1,
		},
	]

# Weapon cards: offered ALL AT ONCE the first time you reach LV5.
static func weapon_cards() -> Array:
	var out: Array = []
	for id in WebWeaponDB.WEAPONS.keys():
		var w: Dictionary = WebWeaponDB.WEAPONS[id]
		out.append({
			"id": "weapon_" + id, "cat": Category.WEAPON,
			"weapon": id,
			"name": w.name, "desc": w.desc,
			"pros": w.pros, "cons": w.cons,
			"rarity": w.rarity, "max": 1,
			"apply": func(g): g.weapon = id; g.weapon_chosen = true,
		})
	return out

static func rarity_color(rarity: int) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)
