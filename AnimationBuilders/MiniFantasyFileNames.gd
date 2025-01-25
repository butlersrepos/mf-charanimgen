@tool
extends EditorScript

func _run() -> void:
	var folder = 'res://Assets/Characters/MiniFantasy/Skeleton_Minotaur'
	var pngs = FileOps.get_all_png_files_from(folder)
	var entity = folder.split('/')[folder.split('/').size() - 1]
	for png in pngs:
		process_spritesheet_info(entity, png, null, Vector2(32, 32))

"""
Actions describe what the spritesheet is showing.
"""
const ACTIONS = ['attack', 'chargedattack', 'die', 'dmg', 'idle', 'jump', 'walk', 'summon, unsummon', 'activate', 'deactivate']

"""
Orthogonal/Diagonal - directions the entity is animating is for the given action
Effect, Impact, etc - The animation of the EFFECT, not the entity using it, sometimes accompanied by "b"-back or "f"-front
Start/End - Paired animations for a particular, often unique, animation
Special - Often a secondary version of an action (see: Wizard_Idle_Special.png)
"""
const ANIM_MODS = ['effect', 'impact', 'projectile', 'special', 'start', 'end', 'diagonal', 'orthogonal', 'backlayer', 'frontlayer']

# Things to remove and probably ignore
const FLUFFS = ['minifantasy_trueheroes', 'layer 1', 'layer 2']

const LIGHTINGS = ['shadow', 'glow']

const unclassified = ['fly', 'disperse']

"""
NOTES: 
	- The presence of the entity's name in the filename usually denotes that the entity
		is doing the action, the opposite is true as well, lack of an entity name in the
		filename usually means it's an effect or a summon/pet.
"""

static func process_spritesheet_info(entity_name: String, path: String, sheet: Texture2D, dimensions: Vector2i) -> Dictionary:
	entity_name = entity_name.to_lower()
	if sheet == null:
		sheet = load(path)
	var anded_regex = RegEx.new()
	anded_regex.compile('.+(_|\\W)(\\w+?)&(\\w+?)($|\\W|_)')
	var info = {
		'entity': entity_name
	}
	# Starts like Entity/Shadows/Minifantasy_TrueHeroesEntityAttack.png
	var path_no_fluff = FLUFFS.reduce(func(acc, f): return acc.replacen(f, ''), path).to_lower() # entity/shadow/entityattack.png
	var path_no_ext = path.get_basename() # entity/shadows/entityattack
	var path_segments = path_no_ext.split('/') # [entity, shadows, entityattack]
	var containing_folder = path_segments[path_segments.size() - 2] # entity
	print_rich("[color=green]%s[/color]" % [containing_folder])
	var filename_with_ext = path_no_fluff.get_file() # entityattack.png
	var filename_no_ext = filename_with_ext.split('.')[0] # entityattack
	# Try to remove entity name, fluff, and known modifier words, if there's still more left than the known actions then it's a unique action
	var filename = filename_no_ext.replacen(entity_name, '') # attack

	var four_even_rows = sheet.get_height() % dimensions.y == 0 and sheet.get_height() / dimensions.y == 4

	# Least conditional identifying characteristics
	if four_even_rows:
		info['is_directional'] = true
	if filename.containsn('orthogonal'):
		info['is_orthogonal'] = true
	if filename.containsn('diagonal'):
		info['is_diagonal'] = true
	if filename.containsn('shadow') or containing_folder.containsn('shadow'):
		info['is_shadow'] = true
	if filename.containsn('glow') or containing_folder.containsn('glow'):
		info['is_glow'] = true
	if filename.containsn('start'):
		info['is_start'] = true
	if filename.containsn('end'):
		info['is_end'] = true
	
	""" DETERMINE ACTION(S) """
	# Special case but very obvious
	var anded_actions = anded_regex.search(filename)
	if anded_actions:
		print(anded_actions)
		info['actions'] = [anded_actions.get_string(2), anded_actions.get_string(3)]
	
	if filename.containsn('effect'):
		if !filename.containsn('without'):
			info['is_effect'] = true
		else:
			info['is_without_effect'] = true
		info['action'] = sanitize_action(filename)
		print_rich("[color=cyan]%s[/color] => [color=yellow]%s[/color]" % [path, info])
		return info
	
	# Check for ones like idle_activate_deactivate
	var filename_pieces = Array(filename.split('_'))
	var actions_in_name = filename_pieces.filter(func(p): return ACTIONS.has(p))
	if actions_in_name.size() >= 2 and sheet.get_height() / dimensions.y == actions_in_name.size():
		info['row_per_action'] = true
		info['actions'] = actions_in_name
		print_rich("[color=cyan]%s[/color] => [color=yellow]%s[/color]" % [path, info])
		return info
	
	var action = sanitize_action(filename)
	info['action'] = action
	
	print_rich("[color=cyan]%s[/color] => [color=yellow]%s[/color]" % [path, info])
	return info

static func sanitize_action(filename: String) -> String:
	var all_mods = []
	all_mods.append_array(ANIM_MODS)
	all_mods.append_array(LIGHTINGS)
	all_mods.append_array(['_', '-', 'without'])
	# Remove all identifiers and punctuation, leave only actions
	var action = all_mods.reduce(func(acc, curr): return acc.replacen(curr, ''), filename)
	return action
