@tool
extends EditorScript
class_name MiniFantasySpritesheetClassifier

# Run is used mostly as a test util
func _run() -> void:
	var folder = 'res://Assets/Characters/MiniFantasy/Paladin'
	var pngs = FileOps.get_all_png_files_from(folder)
	var entity = folder.split('/')[folder.split('/').size() - 1]
	for png in pngs:
		var infos = animation_infos_from_sheet(entity, png, Vector2(32, 32))
		infos = infos.map(func(i: Dictionary):
			for key in i.keys():
				if i[key] == null:
					i.erase(key)
			return i
		)
		#myprint("[indent]animations: %s[/indent]" % [infos.size()])
		myprint("[color=cyan]%s[/color] => [color=yellow]%s[/color]" % [png, infos])

const DIAGONAL_DIRECTIONS: Array[Dictionary] = [
	{ "name": 'downright', "row": 0 },
	{ "name": 'downleft', "row": 1 },
	{ "name": 'upright', "row": 2 },
	{ "name": 'upleft', "row": 3 }
]

const ORTHOGONAL_DIRECTIONS: Array[Dictionary] = [
	{ 'name': 'right', 'row': 0 },
	{ 'name': 'left', 'row': 1 },
	{ 'name': 'down', 'row': 2 },
	{ 'name': 'up', 'row': 3 },
]

"""
Actions describe what the spritesheet is showing.
"""
const ACTIONS = ['attack', 'chargedattack', 'die', 'dmg', 'idle', 'jump', 'walk', 'summon', 'unsummon', 'activate', 'deactivate']

"""
Orthogonal/Diagonal - directions the entity is animating is for the given action
Effect, Impact, etc - The animation of the EFFECT, not the entity using it, sometimes accompanied by "b"-back or "f"-front
Start/End - Paired animations for a particular, often unique, animation
Special - Often a secondary version of an action (see: Wizard_Idle_Special.png)
"""
const ANIM_MODS = ['effect', 'impact', 'projectile', 'special', 'start', 'cycle', 'end', 'diagonal', 'orthogonal', 'backlayer', 'frontlayer']
# Things to remove and probably ignore
const FLUFFS = ['minifantasy_demonspider', 'minifantasy_giantspider', 'minifantasy_trueheroes', 'minifantasy_npcs', 'minifantasy_spiderqueen', 'minifantasy_', 'layer 1', 'layer 2']
const LIGHTINGS = ['shadow', 'glow']
const unclassified = ['fly', 'disperse']
const LOOPS = ['walk', 'idle', 'fly', 'cycle']

"""
NOTES:
	- The presence of the entity's name in the filename usually denotes that the entity
		is doing the action, the opposite is true as well, lack of an entity name in the
		filename usually means it's an effect or a summon/pet.
"""

## [param entity_name] is typically the containing folder of the asset and should be the name you would likely identify the thing as.
## [param path] is the fully resource path to the spritesheet png file.
## [param sheet] is the loaded png file as a [Texture2D] but only as an optimization if you already have it, otherwise this method will load it.
## [param dimensions] is a [Vector2] of the X and Y size of each frame within the spritesheet.
static func animation_infos_from_sheet(entity_name: String, path: String, dimensions: Vector2i, sheet: Texture2D = null) -> Array[Dictionary]:
	entity_name = entity_name.to_lower()
	if sheet == null:
		sheet = load(path)
	var anded_regex = RegEx.new()
	anded_regex.compile('.+(_|\\W)(\\w+?)&(\\w+?)($|\\W|_)')
	var info = {
		'entity': entity_name,
		'sheet': sheet,
		'row': 0,
		'is_directional': null,
		'is_diagonal': null,
		'is_orthogonal': null,
		'is_shadow': null,
		'is_glow': null,
		'is_start': null,
		'is_end': null,
		'is_cycle': null,
		'is_effect': null,
		'is_without_ effect': null,
		'is_looped': null,
	}
	# Starts like Entity/Shadows/Minifantasy_TrueHeroesEntityAttack.png
	var path_no_fluff = FLUFFS.reduce(func(acc: String, f): return acc.replacen(f, ''), path).to_lower() # entity/shadow/entityattack.png
	var path_no_ext = path.get_basename() # entity/shadows/entityattack
	var path_segments = path_no_ext.split('/') # [entity, shadows, entityattack]
	var containing_folder = path_segments[path_segments.size() - 2] # entity
	var filename_with_ext = path_no_fluff.get_file() # entityattack.png
	var filename_no_ext = filename_with_ext.split('.')[0] # entityattack
	# Try to remove entity name, fluff, and known modifier words, if there's still more left than the known actions then it's a unique action
	var filename: String = filename_no_ext.replacen(entity_name, '') # attack

	var four_even_rows = sheet.get_height() % dimensions.y == 0 and sheet.get_height() / dimensions.y == 4

	""" Indicate least conditional identifying characteristics """
	if four_even_rows:
		info['is_directional'] = true
		info['is_diagonal'] = true
	if filename.containsn('orthogonal'):
		info['is_orthogonal'] = true
		info['is_diagonal'] = false
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
	if filename.containsn('cycle'):
		info['is_cycle'] = true
	if filename.containsn('effect'):
		if !filename.containsn('without'):
			info['is_effect'] = true
		else:
			info['is_without_effect'] = true

	""" Handle special cases, early exits """
	# Special case of "blah_blah_Foo&Bar", but very obvious
	var anded_actions = anded_regex.search(filename)
	if anded_actions:
		myprint(anded_actions)
		# Make config for each action
		var infos = [anded_actions.get_string(2), anded_actions.get_string(3)].map(func(a):
			var i = info.duplicate()
			i['action'] = sanitize_action(a)
			if LOOPS.has(i['action']):
				i['is_looped'] = true
			# Make config for each direction is it's directional
			if four_even_rows:
				return range(4).map(func(n):
					var dir_info = i.duplicate()
					dir_info['row'] = n
					return dir_info
				)
			else:
				# Just one row of animation for one of the actions
				return i
		)
		return DataUtils.flatten_array(infos)

	# Check for ones like "idle_activate_deactivate.png"
	var filename_pieces = Array(filename.split('_'))
	var actions_in_name = filename_pieces.filter(func(p): return ACTIONS.has(p))
	if actions_in_name.size() >= 2 and sheet.get_height() / dimensions.y == actions_in_name.size():
		myprint('[color=purple]Handling multi-sheet[/color]')
		# Sort by order they're listed in, assume that is the row ordering
		actions_in_name.sort_custom(func(a, b): return filename.findn(a) < filename.findn(b))
		var infos = actions_in_name.map(func(act):
			var i = info.duplicate()
			i['row'] = actions_in_name.find(act)
			i['action'] = sanitize_action(act)
			if LOOPS.has(i['action']):
				i['is_looped'] = true
			return i
		)
		return DataUtils.flatten_array(infos)

	# General logic path for most sprites/actions
	var action = sanitize_action(filename)
	info['action'] = action
	if LOOPS.has(action) and info['is_start'] != true and info['is_end'] != true:
		info['is_looped'] = true

	if info['is_directional']:
		var infos = range(4).map(func(d):
			var dir_info = info.duplicate()
			dir_info['row'] = d
			return dir_info
		)
		return DataUtils.flatten_array(infos)
	# Else just return what we've figured out so far
	return [info]

static func sanitize_action(filename: String) -> String:
	var all_mods = []
	all_mods.append_array(ANIM_MODS)
	all_mods.append_array(LIGHTINGS)
	all_mods.append_array(['_', '-', 'without'])
	# Remove all identifiers and punctuation, leave only actions
	var action = all_mods.reduce(func(acc, curr): return acc.replacen(curr, ''), filename)
	return action

## Takes a config from the spritesheet classifier and builds the appropriate animation name
static func build_anim_name(config: Dictionary) -> String:
	var direction = '' if config['is_directional'] != true else DIAGONAL_DIRECTIONS[config['row']] if config['is_diagonal'] else ORTHOGONAL_DIRECTIONS[config['row']]
	var suffix =  '-shadow' if config['is_shadow'] else '-glow' if config['is_glow'] else '-effect' if config['is_effect'] else ''
	var suffixes = "".join([
		'-cycle' if  config['is_cycle'] else '',
		'-start' if  config['is_start'] else '',
		'-end' if  config['is_end'] else '',
		'-effect' if  config['is_effect'] else '',
		'-shadow' if  config['is_shadow'] else '',
		'-glow' if  config['is_glow'] else '',
	])
	var name = "%s-%s%s%s" % [config['entity'], config['action'], '-%s' % [direction['name']] if direction else '', suffixes]
	return name

static func decipher_name(anim_name: String) -> Dictionary:
	# {entity}-{action}-{?direction}-{?lifecycle}-{?shadow/glow}
	var parts: Array = Array(anim_name.split('-'))
	var info = {
		'anim_name': anim_name,
		'entity': parts[0],
		'action': parts[1],
		'direction': 'none',
		'is_directional': null,
		'is_diagonal': null,
		'is_orthogonal': null,
		'is_shadow': null,
		'is_glow': null,
		'is_start': null,
		'is_end': null,
		'is_cycle': null,
		'is_effect': null,
		'is_without_effect': null,
		'is_looped': null,
	}
	if parts.any(func(p): return p == 'shadow'):
		info['is_shadow'] = true
	if parts.any(func(p): return p == 'effect'):
		info['is_effect'] = true
	if parts.any(func(p): return p == 'start'):
		info['is_start'] = true
	if parts.any(func(p): return p == 'cycle'):
		info['is_cycle'] = true
	if parts.any(func(p): return p == 'end'):
		info['is_end'] = true
	if parts.any(func(p): return p == 'without'):
		info['is_without_effect'] = true

	if LOOPS.has(info['action']):
		info['is_looped'] = true

	if parts.size() >= 3 and ['up', 'down', 'left', 'right'].any(func(x): return parts[2].containsn(x)):
		info['direction'] = parts[2]
		if DIAGONAL_DIRECTIONS.any(func(d): return d['name'] == parts[2]):
			info['is_diagonal'] = true
		if ORTHOGONAL_DIRECTIONS.any(func(d): return d['name'] == parts[2]):
			info['is_orthogonal'] = true

	return info

# Helper to colorcode all logs in this file
static func myprint(msg: String) -> void:
	print_rich('[color=lightblue]MiniFantasySpritesheetClassifier[/color] ' + msg)
