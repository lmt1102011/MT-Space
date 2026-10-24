extends RefCounted
class_name WebWeaponDB

# Weapon archetypes offered once at LV5. Choosing one permanently replaces the
# basic fire style, each with its own advantages and drawbacks.

const WEAPONS := {
	"machine_gun": {
		"name": "Machine Gun",
		"desc": "Fast fire rate, lower damage, wide spread.",
		"pros": "+25% fire rate",
		"cons": "-40% damage, inaccurate",
		"rarity": 0,   # COMMON color
	},
	"twin_cannon": {
		"name": "Twin Cannon",
		"desc": "Fires two parallel rounds each shot.",
		"pros": "2 bullets / shot",
		"cons": "+25% cooldown",
		"rarity": 1,
	},
	"shotgun": {
		"name": "Shotgun",
		"desc": "Huge burst up close, weak at range, slow reload.",
		"pros": "7 pellets up close",
		"cons": "slow, short range",
		"rarity": 1,
	},
	"railgun": {
		"name": "Railgun",
		"desc": "One fast piercing round, big damage, slow cadence.",
		"pros": "pierce + big damage",
		"cons": "+120% cooldown",
		"rarity": 2,
	},
	"burst": {
		"name": "Burst Rifle",
		"desc": "Fires a 3-round burst, then a short pause.",
		"pros": "3-round burst",
		"cons": "+30% cooldown",
		"rarity": 1,
	},
}

