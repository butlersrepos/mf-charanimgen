extends Node

"""
Actions describe what the spritesheet is showing.
"""
const ACTIONS = ["Attack", "ChargedAttack", "Die", "Dmg", "Idle", "Jump", "Walk", "Summon, Unsummon", "Activate", "Deactivate"]

"""
Orthogonal/Diagonal - directions the entity is animating is for the given action
Effect, Impact, etc - The animation of the EFFECT, not the entity using it, sometimes accompanied by "b"-back or "f"-front
Start/End - Paired animations for a particular, often unique, animation
Special - Often a secondary version of an action (see: Wizard_Idle_Special.png)
"""
const ANIM_MODS = ["Effect", "Impact", "Projectile", "Special", "Start", "End", "Diagonal", "Orthogonal", "BackLayer", "FrontLayer"]

# Things to remove and probably ignore
const FLUFFS = ["Minifantasy_TrueHeroes"]

const LIGHTINGS = ["_shadow", "_glow"]

const unclassified = ["Fly"]

"""
NOTES: 
	- The presence of the entity's name in the filename usually denotes that the entity
		is doing the action, the opposite is true as well, lack of an entity name in the
		filename usually means it's an effect or a summon/pet.
"""

static func process_spritesheet_name(name: String) -> void:
	var path_without_ext = name.get_basename() # /path/to/foo
	var filename_with_ext = name.get_file() # foo.png
	
