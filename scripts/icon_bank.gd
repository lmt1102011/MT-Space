extends RefCounted

# Every card pictogram is a real image, so a card costs one texture blit
# instead of a few hundred vector draw commands.
# The icons are drawn in greyscale and tinted at runtime, which keeps the
# semantic colour of each card intact.
# Deliberately no class_name: referenced through a plain preload so it never
# depends on the editor's global class cache.

const ICONS := {
	"bloodthirst": preload("res://assets/icons/bloodthirst.svg"),
	"brittle": preload("res://assets/icons/brittle.svg"),
	"bullet_speed": preload("res://assets/icons/bullet_speed.svg"),
	"burn": preload("res://assets/icons/burn.svg"),
	"cold_blood": preload("res://assets/icons/cold_blood.svg"),
	"crit": preload("res://assets/icons/crit.svg"),
	"damage": preload("res://assets/icons/damage.svg"),
	"default": preload("res://assets/icons/default.svg"),
	"elite_hunter": preload("res://assets/icons/elite_hunter.svg"),
	"explosive": preload("res://assets/icons/explosive.svg"),
	"fire_rate": preload("res://assets/icons/fire_rate.svg"),
	"freeze": preload("res://assets/icons/freeze.svg"),
	"heavy_caliber": preload("res://assets/icons/heavy_caliber.svg"),
	"homing": preload("res://assets/icons/homing.svg"),
	"inferno": preload("res://assets/icons/inferno.svg"),
	"level_heal": preload("res://assets/icons/level_heal.svg"),
	"lifesteal": preload("res://assets/icons/lifesteal.svg"),
	"max_hp": preload("res://assets/icons/max_hp.svg"),
	"move_speed": preload("res://assets/icons/move_speed.svg"),
	"orb_magnet": preload("res://assets/icons/orb_magnet.svg"),
	"pierce": preload("res://assets/icons/pierce.svg"),
	"pierce_focus": preload("res://assets/icons/pierce_focus.svg"),
	"plating": preload("res://assets/icons/plating.svg"),
	"regen": preload("res://assets/icons/regen.svg"),
	"rushed": preload("res://assets/icons/rushed.svg"),
	"scavenger": preload("res://assets/icons/scavenger.svg"),
	"second_chance": preload("res://assets/icons/second_chance.svg"),
	"splash": preload("res://assets/icons/splash.svg"),
	"thorns": preload("res://assets/icons/thorns.svg"),
	"weapon_burst": preload("res://assets/icons/weapon_burst.svg"),
	"weapon_machine_gun": preload("res://assets/icons/weapon_machine_gun.svg"),
	"weapon_railgun": preload("res://assets/icons/weapon_railgun.svg"),
	"weapon_shotgun": preload("res://assets/icons/weapon_shotgun.svg"),
	"weapon_twin_cannon": preload("res://assets/icons/weapon_twin_cannon.svg"),
	"xp_greed": preload("res://assets/icons/xp_greed.svg"),
}


static func get_icon(id: String) -> Texture2D:
	var icon: Texture2D = ICONS.get(id, null)
	if icon == null:
		icon = ICONS["default"]
	return icon
