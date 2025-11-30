@tool
extends EditorScript
class_name MiniFantasySpriteFramesBuilder

"""
Builds SpriteFrames for every character folder.
These frames are not the whole animation, they're a sequence of frames + coordination between Base, Shadow, and Effects.
Importantly - they lack any notion of timing, hitboxes, or higher-level orchestration like enabling/disabling things.
@see MiniFantasyAnimationLibraryBuilder for things like anim tracks, frame timing, hiding sprites.
"""

## For testing
func _run() -> void:
	create_sprite_frames_res('res://Assets/Characters/MiniFantasy', 'res://', 'test')
	pass

const info_filenames = ["AnimationInfo.txt", "_AnimationInfo.txt"]

const DEFAULT_SPRITE_SIZE: Vector2 = Vector2(32, 32)

# Helper to colorcode all logs in this file
static func myprint(msg: String) -> void:
	print_rich('[color=purple]MiniFantasySpriteFramesBuilder[/color] ' + msg)

"""
This script processes the entire target folder of all characters to produce
a SpriteFrames resource with all animations. The resource is saved to the
provided output_folder as "mini-fantasy-sprite-frames".
"""
static func create_sprite_frames_res(characters_folder: String, output_folder: String, output_name: String) -> void:
	myprint('Building sprite frames for characters in: ' + characters_folder + ', output folder: ' + output_folder)
	var sprite_frames: SpriteFrames
	var path_to_frames = "%s/%s.res" % [output_folder, output_name]
	# Setup or use existing file
	if FileAccess.file_exists(path_to_frames):
		myprint('Found existing sprite frames, amending that instead.')
		sprite_frames = load(path_to_frames)
	else:
		sprite_frames = SpriteFrames.new()

	sprite_frames.remove_animation("default")

	var folders = FileOps.get_all_folders(characters_folder)
	myprint("Processing folders: " + ", ".join(folders))
	for folder in folders:
		var dimensions: Vector2
		# Check different combos for the AnimationInfo text file
		for info_filename in info_filenames:
			var anim_info_file_path = "%s/%s/%s" % [characters_folder, folder, info_filename]
			if FileAccess.file_exists(anim_info_file_path):
				dimensions = FileOps.get_dimensions_from_file(anim_info_file_path)
				break
		if dimensions == Vector2.ZERO:
			myprint("WARNING: Didn't find sprite size for %s. Using 32x32px." % [folder])
			dimensions = DEFAULT_SPRITE_SIZE
		process_sprite_folder(sprite_frames, characters_folder + "/" + folder, dimensions, output_folder, output_name)

static func process_sprite_folder(sprite_frames: SpriteFrames, folder_path: String, dimensions: Vector2i, output_folder: String, output_name: String) -> Error:
	var folder_name = folder_path.get_file().split('.')[0]
	myprint("\nProcessing individual folder: " + folder_name)
	var pngs = FileOps.get_all_png_files_from(folder_path)
	myprint("\nFound PNGs: " + ", ".join(pngs))

	for png in pngs:
		Image.new()
		var spritesheet: Texture2D = load(png)
		# This is costly, but enables frame checking for empty/short rows
		var ss_img = spritesheet.get_image()
		var anim_configs = MiniFantasySpritesheetClassifier.animation_infos_from_sheet(folder_name, png, dimensions, spritesheet)
		# Sort shadows last
		anim_configs.sort_custom(func(a: Dictionary, b: Dictionary):
			if a['is_shadow'] and !b['is_shadow']:
				return false
			elif b['is_shadow'] and !a['is_shadow']:
				return true
			else:
				return a['action'].naturalnocasecmp_to(b['action']) < 0
		)
		for config in anim_configs:
			var anim_name = MiniFantasySpritesheetClassifier.build_anim_name(config)
			myprint("[color=cyan]%s[/color] => [color=green]%s[/color] (%s)" % [png, anim_name, config])
			# These types of animations all sync up to another animation, so empty frames are tolerable, check empty frames for others
			var should_check_frames = config['is_shadow'] != true && config['is_effect'] != true && config['is_start'] != true && config['is_end'] != true && config['is_cycle'] != true && config['is_glow'] != true
			add_animation_row(sprite_frames, spritesheet, ss_img, anim_name, dimensions, [config['row']], should_check_frames)
			sprite_frames.set_animation_loop(anim_name, config["is_looped"] if config['is_looped'] != null else false)

	# Write all the SpriteFrames out to a saved resource
	return FileOps.save_res(sprite_frames, "%s/%s.res" % [output_folder, output_name])

static func add_animation_row(sprite_frames: SpriteFrames, ss: Texture2D, ss_img: Image, anim_name: String, dimensions: Vector2, rows: Array[int] = [0], should_check_frames: bool = false) -> void:
	assert(ss.get_width() != 0 and dimensions.x != 0)
	if sprite_frames.has_animation(anim_name):
		myprint("Animation '%s' already exists in sprite frames!\n\tRebuilding frames" % [anim_name])
		sprite_frames.clear(anim_name)
	else:
		sprite_frames.add_animation(anim_name)
	if should_check_frames:
		myprint('[color=pink]Checking frames[/color]')
	var horizontal_frames = ss.get_width() / dimensions.x
	for f in range(horizontal_frames):
		# Setup empty frames, since we fill them in in reverse
		sprite_frames.add_frame(anim_name, null)
	for row in rows:
		for f in range(horizontal_frames - 1, -1, -1):
			if should_check_frames and not frame_has_content(ss_img, row, f, dimensions):
				sprite_frames.remove_frame(anim_name, f)
				myprint('[color=pink]Empty frame found: %s - %s,%s[/color]' % [anim_name, row, f])
				continue
			var atlas_texture: AtlasTexture = AtlasTexture.new()
			atlas_texture.atlas = ss
			atlas_texture.region = Rect2((f * dimensions.x), row * dimensions.y, dimensions.x, dimensions.y)
			sprite_frames.set_frame(anim_name, f, atlas_texture)

## Perform a spiral check from the center to try and prove if there's any pixels ASAP
static func frame_has_content(image: Image, row: int, frame: int, dimensions: Vector2i) -> bool:
	var region = image.get_region(Rect2i(dimensions.x * frame, dimensions.y * row, dimensions.x, dimensions.y))
	var x = 0
	var y = 0
	var dx = 0
	var dy = -1

	var width = dimensions.x
	var height = dimensions.y
	for i in range(max(width, height) * max(width, height)):
		if x+(width/2) >= 0 and x+(width/2) < width and y+(height/2) >= 0 and y+(height/2) < height:
			if region.get_pixel(x+(width/2), y+(height/2)).a > 0:
				return true

		if x == y or (x < 0 and x == -y) or (x > 0 and x == 1 - y):
			var temp = dx
			dx = -dy
			dy = temp

		x += dx
		y += dy
	return false
