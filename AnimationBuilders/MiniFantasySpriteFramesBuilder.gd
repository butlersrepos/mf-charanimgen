@tool
extends EditorScript
class_name MiniFantasySpriteFramesBuilder

const info_filenames = ["AnimationInfo.txt", "_AnimationInfo.txt"]
#################################################################################
# Commonly used mapping of row index to direction name
const directions: Array[Dictionary] = [
	{ "name": 'downright', "row": 0 },
	{ "name": 'downleft', "row": 1 },
	{ "name": 'upright', "row": 2 },
	{ "name": 'upleft', "row": 3 }
]
# Special case verbiage that was in some packs and made deciphering harder
const  fluffs: Array[String] = ["Minifantasy_TrueHeroes"]
# Using regex to read dimensions from animation_info txt files in format like "32x32"
var dimension_regex = RegEx.new()
const DEFAULT_SPRITE_SIZE: Vector2 = Vector2(32,32)

"""
This script processes the entire target folder of all characters to produce
a SpriteFrames resource with all animations. The resource is saved to the 
provided output_folder as "mini-fantasy_sprite_frames".
"""
static func create_sprite_frames_res(characters_folder: String, output_folder: String, output_name: String) -> void:
	print('Building sprite frames for characters in: ' + characters_folder + ', output folder: ' + output_folder)
	var sprite_frames: SpriteFrames
	var path_to_frames = "%s/%s.res" % [output_folder, output_name]
	# Setup or use existing file
	if FileAccess.file_exists(path_to_frames):
		print('Found existing sprite frames, amending that instead.')
		sprite_frames = load(path_to_frames)
	else:
		sprite_frames = SpriteFrames.new()
	
	sprite_frames.remove_animation("default")
	
	var folders = FileOps.get_all_folders(characters_folder)
	print("Processing folders: " + ", ".join(folders))
	for folder in folders:
		var dimensions: Vector2
		# Check different combos for the AnimationInfo text file
		for info_filename in info_filenames:
			if FileAccess.file_exists("%s/%s/%s" % [characters_folder, folder, info_filename]):
				dimensions = get_dimensions_from_file("%s/%s/%s" % [characters_folder, folder, info_filename])
				break
		if dimensions == Vector2.ZERO:
			print("WARNING: Didn't find sprite size for %s. Using 32x32px." % [folder])
			dimensions = DEFAULT_SPRITE_SIZE
		process_sprites(sprite_frames, characters_folder + "/" + folder, dimensions, output_folder, output_name)

# Turns "a/b/c/foo.txt" into "foo"
static func clean_up_png_name(filepath: String) -> String:
	var base = filepath.get_file().split('.')[0]
	for fluff in fluffs:
		base.replace(fluff, "")
	return base

# Cleans up pieces used to build animation names
static func clean(s: String) -> String:
	return s.to_lower().replace("shadow", "").lstrip("_").lstrip('-')
	
static func get_spritesheet_info(character: String, filename: String) -> Dictionary:
	var sheet_name = filename.to_lower().replace(character.to_lower(), "")
	var is_shadow = filename.to_lower().contains('shadow')
	var is_not_looped = ["die", "dmg", "chargedattack", "jump"].any(func(a): return sheet_name.contains(a))
	return { 
		"is_shadow": is_shadow,
		"is_looped": !is_not_looped
	}

static func build_anim_name(character: String, spritesheet_name: String) -> String:
	# Remove redunanct entity naming like Paladin/PaladinDmg -> Dmg
	var animation_name = spritesheet_name.replace(character, "")
	# Like "Troll-ShadowDmg" or "Cleric-Attack"
	var anim_prefix = "%s-%s" % [clean(character), clean(animation_name)]
	# Like "paladin-idle"
	return anim_prefix.lstrip("_").lstrip('-').to_lower()

static func process_sprites(sprite_frames: SpriteFrames, folder_path: String, dimensions: Vector2i, output_folder: String, output_name: String) -> Error:
	var folder_name = folder_path.get_file().split('.')[0]
	print("\nProcessing individual folder: ", folder_name)
	var pngs = FileOps.get_all_png_files_from(folder_path)
	# Sort shadows last
	pngs.sort_custom(func(a: String, b: String): 
		var a_shadow = a.to_lower().contains("shadow")
		var b_shadow = b.to_lower().contains("shadow")
		if a_shadow and !b_shadow:
			return false
		elif b_shadow and !a_shadow:
			return true
		else:
			return a.naturalnocasecmp_to(b) < 0
	)
	print("\nFound PNGs: " + ", ".join(pngs))
	for png in pngs:
		var spritesheet: Texture2D = load(png)
		var filename = clean_up_png_name(png)
		var info = get_spritesheet_info(folder_name, filename)
		var is_directional = spritesheet.get_height() / dimensions.y == 4 and spritesheet.get_height() % dimensions.y == 0
		var anim_name = build_anim_name(folder_name, filename)
		if is_directional:
			# Animations like Attack/Idle have four rows to intake, everything else (Die, ChargedAttack) is treated as one long row
			for direction in directions:
				# Like "attack-downleft-shadow"
				var final_name = "%s-%s%s" % [anim_name, direction["name"], "-shadow"  if info["is_shadow"] else ""]
				print_rich("[color=cyan]%s[/color] => [color=green]%s[/color] (%s)" % [png, final_name, info])
				# ASSUMPTION: Directional animations only span one row
				add_animation_row(sprite_frames, spritesheet, final_name, dimensions, [direction["row"]])
				sprite_frames.set_animation_loop(final_name, info["is_looped"])
		else:
			var final_name = "%s%s" % [anim_name, "-shadow"  if info["is_shadow"] else ""]
			print_rich("[color=cyan]%s[/color] => [color=green]%s[/color] (%s)" % [png, final_name, info])
			# ASSUMPTION: A non-directional animation ("die", "chargedattack") spans the entire sheet
			add_animation_row(sprite_frames, spritesheet, final_name, dimensions)
			sprite_frames.set_animation_loop(final_name, info["is_looped"])
	
	# Write all the SpriteFrames out to a saved resource
	return FileOps.save_res(sprite_frames,  "%s/%s.res" % [output_folder, output_name])

static func add_animation_row(sprite_frames: SpriteFrames, ss: Texture2D, anim_name: String, dimensions: Vector2, rows: Array[int] = [0]) -> void:
	assert(ss.get_width() != 0 and dimensions.x != 0)
	if sprite_frames.has_animation(anim_name):
		print_debug("Animation '%s' already exists in sprite frames!\n\tRebuilding frames" % [anim_name])
		sprite_frames.clear(anim_name)
	else:
		sprite_frames.add_animation(anim_name)
	var hor_frames = ss.get_width() / dimensions.x
	for row in rows:
		for f in hor_frames:
			var atlas_texture = AtlasTexture.new()
			atlas_texture.atlas = ss
			atlas_texture.region = Rect2((f * dimensions.x), row * dimensions.y, dimensions.x, dimensions.y)
			sprite_frames.add_frame(anim_name, atlas_texture)

# Reads the animation info folder to discover sprite size
static func get_dimensions_from_file(file_path: String) -> Vector2i:
	if not FileAccess.file_exists(file_path):
		printerr("File not found: ", file_path)
		return Vector2i.ZERO
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	
	var dimension_regex = RegEx.new()
	dimension_regex.compile("(\\d+)x(\\d+)")
	var result = dimension_regex.search(content)
	if result:
		var width = result.get_string(1).to_int()
		var height = result.get_string(2).to_int()
		return Vector2i(width, height)
	
	return Vector2i.ZERO
