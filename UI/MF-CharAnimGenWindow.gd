@tool
extends Window
class_name MFCharGenWindow

# Saved settings
const CHARACTER_FOLDER_SETTING_KEY := "MF-CharAnimGen/character_folder"
const DEFAULT_CHARACTER_FOLDER := "res://assets/characters"

const SPRITE_FRAMES_FOLDER_SETTING_KEY := "MF-CharAnimGen/sprite_frames_folder"
const DEFAULT_SPRITE_FRAMES_FOLDER := "res://"

const SPRITE_FRAMES_FILE_NAME_SETTING_KEY := "MF-CharAnimGen/sprite_frames_file_name"
const DEFAULT_SPRITE_FRAMES_NAME := "mini-fantasy-sprite-frames"

const METADATA_FILENAME = 'metadata.json'

@onready var editor_settings = EditorInterface.get_editor_settings()
@onready var item_list: ItemList = %ItemList
@onready var popup_menu: Panel = %PopupMenu
# Dialogs
@onready var sprite_frames_resource_folder_dialog: FileDialog = %SpriteFramesResourceFolderDialog
@onready var character_folder_dialog: FileDialog = %CharacterFolderDialog
@onready var accept_dialog: AcceptDialog = %AcceptDialog
@onready var generation_done_dialog: AcceptDialog = %GenerationDoneDialog
# Labels
@onready var frames_check_label: Label = %FramesCheckLabel
@onready var sprite_frames_path_label: Label = %SpriteFramesPathLabel
@onready var character_folder_path_label: Label = %CharacterFolderPathLabel

# Persisted paths & files
@onready var sprite_frames_file_name: String = editor_settings.get_setting(SPRITE_FRAMES_FILE_NAME_SETTING_KEY):
	set(val):
		sprite_frames_file_name = val
		editor_settings.set_setting(SPRITE_FRAMES_FILE_NAME_SETTING_KEY, val)

@onready var mini_fantasy_characters_folder: String = editor_settings.get_setting(CHARACTER_FOLDER_SETTING_KEY):
	set(val):
		mini_fantasy_characters_folder = val
		editor_settings.set_setting(CHARACTER_FOLDER_SETTING_KEY, val)
		characters = FileOps.get_all_folders(val)
		character_folder_path_label.text = val
		update_items()
		update_frames_check()

@onready var sprite_frames_folder: String = editor_settings.get_setting(SPRITE_FRAMES_FOLDER_SETTING_KEY):
	set(val):
		sprite_frames_folder = val
		editor_settings.set_setting(SPRITE_FRAMES_FOLDER_SETTING_KEY, val)
		var path = "%s%s%s.res" % [sprite_frames_folder, '' if sprite_frames_folder.ends_with("/") else "/", sprite_frames_file_name]
		sprite_frames_path_label.text = path
		if FileAccess.file_exists(path):
			# Found sprite frames res, load it
			sprite_frames = load(path)
		else:
			# No sprite frames yet, ask user to gen
			sprite_frames = null
		update_items()
		update_frames_check()

var sprite_frames: SpriteFrames:
	set(val):
		sprite_frames = val
		anim_names.assign([] if !sprite_frames else Array(sprite_frames.get_animation_names()))
var characters: Array[String]
var anim_names: Array[String] = []

func _ready() -> void:
	mini_fantasy_characters_folder = mini_fantasy_characters_folder
	sprite_frames_folder = sprite_frames_folder
	update_frames_check()
	update_items()


"""
GUI State Updaters
"""
func update_frames_check() -> void:
	var found_all = characters.all(func(char_name: String):
		# See if every character has at least one animation
		return anim_names.any(func(anim_name: String):
			return anim_name.begins_with(char_name.to_lower())
		)
	)
	if sprite_frames == null:
		frames_check_label.text = "⛔ No SpriteFrames file found, click to generate them."
	elif found_all:
		frames_check_label.text = "✅ All characters have some SpriteFrames."
	else:
		frames_check_label.text = "⚠️ Found SpriteFrames file but some characters are missing."

func update_items() -> void:
	item_list.clear()
	for character in characters:
		var idx = item_list.add_item(character)
		if anim_names.any(func(a): return a.begins_with(character.to_lower())):
			item_list.set_item_disabled(idx, false)
		else:
			item_list.set_item_disabled(idx, true)

"""
File/Folder Selector Handlers
"""
func _on_sprite_frames_resource_file_dialog_dir_selected(dir: String) -> void:
	sprite_frames_folder = dir

func _on_character_folder_dialog_dir_selected(dir: String) -> void:
	mini_fantasy_characters_folder = dir

"""
Menu GUI Interaction Handlers
"""

## Clicked a Character, so we generate everything to produce the Nodes
func _on_item_list_item_selected(index: int) -> void:
	var folders = FileOps.get_all_folders(mini_fantasy_characters_folder)
	generate_nodes(folders[index])
	generation_done_dialog.show()

## Generate/regen the Sprite Frames resource, necessary when we added new folders or changed the directory
func _on_generate_sprites_button_pressed() -> void:
	MiniFantasySpriteFramesBuilder.create_sprite_frames_res(mini_fantasy_characters_folder, sprite_frames_folder, sprite_frames_file_name)
	sprite_frames_folder = sprite_frames_folder
	update_frames_check()

func _on_close_requested() -> void:
	self.queue_free()

func _on_pick_sprite_frames_resource_button_pressed() -> void:
	sprite_frames_resource_folder_dialog.show()

func _on_change_character_folder_button_pressed() -> void:
	character_folder_dialog.show()

func _on_docs_button_pressed() -> void:
	accept_dialog.show()

func _on_refresh_characters_button_pressed() -> void:
	characters = FileOps.get_all_folders(mini_fantasy_characters_folder)
	update_items()

func get_anim_metadata(folder_name: String) -> Dictionary:
	var path = '%s/%s/%s' % [mini_fantasy_characters_folder, folder_name, METADATA_FILENAME]
	if not FileAccess.file_exists(path):
		push_warning('Failed to find metadata from path: ', path)
		return {}
	else:
		var file = FileAccess.open(path, FileAccess.READ)
		if not file:
			push_error('Failed to open metadata from path: ', path)
			return {}
		else:
			var content = file.get_as_text()
			return JSON.parse_string(content) as Dictionary


"""
Node Generation Logic
"""
func generate_nodes(folder_name: String):
	var anim_metadata = get_anim_metadata(folder_name)
	if anim_metadata.keys().size() > 0:
		myprint('Found animation metadata for ' + folder_name)
	var name = folder_name.to_lower()
	var root = EditorInterface.get_edited_scene_root()
	var base_animated_sprite_2d = AnimatedSprite2D.new()
	root.add_child(base_animated_sprite_2d)
	base_animated_sprite_2d.sprite_frames = sprite_frames
	base_animated_sprite_2d.owner = root
	base_animated_sprite_2d.name = "MF-BaseSprite"

	var shadow_animated_sprite_2d = AnimatedSprite2D.new()
	root.add_child(shadow_animated_sprite_2d)
	shadow_animated_sprite_2d.sprite_frames = sprite_frames
	shadow_animated_sprite_2d.owner = root
	shadow_animated_sprite_2d.name = "MF-ShadowSprite"

	var effects_animated_sprite_2d = AnimatedSprite2D.new()
	root.add_child(effects_animated_sprite_2d)
	effects_animated_sprite_2d.sprite_frames = sprite_frames
	effects_animated_sprite_2d.owner = root
	effects_animated_sprite_2d.name = "MF-EffectsSprite"

	var hitbox_anim_player = root.find_child('MF-HitBoxPlayer', true, false)
	if not hitbox_anim_player:
		hitbox_anim_player = AnimationPlayer.new()
		hitbox_anim_player.deterministic = true
		root.add_child(hitbox_anim_player)
		hitbox_anim_player.owner = root
		hitbox_anim_player.name = "MF-HitBoxPlayer"
		hitbox_anim_player.editor_description = "Create tracks for hitboxes during attacks. They will automatically be played by the MF-AnimationPlayer. Don't delete this node even if it's empty."

	var anim_library = MiniFantasyAnimationLibraryBuilder.create_anim_library(
		name,
		sprite_frames,
		base_animated_sprite_2d,
		shadow_animated_sprite_2d,
		effects_animated_sprite_2d,
		hitbox_anim_player,
		anim_metadata
	)

	var anim_player = AnimationPlayer.new()
	anim_player.deterministic = true
	anim_player.add_animation_library("", anim_library)
	root.add_child(anim_player)
	anim_player.owner = root
	anim_player.name = "MF-AnimationPlayer"

	var anim_tree = MiniFantasyAnimationTreeBuilder.create_animation_tree(
		name,
		anim_library
	)

	root.add_child(anim_tree)
	anim_tree.owner = root
	anim_tree.name = "MF-AnimationTree"
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)

	root.move_child(shadow_animated_sprite_2d, 0)
	root.move_child(base_animated_sprite_2d, 1)
	root.move_child(effects_animated_sprite_2d, 2)
	root.move_child(anim_player, 3)
	root.move_child(hitbox_anim_player, 4)
	root.move_child(anim_tree, 5)

# Helper to colorcode all logs in this file
static func myprint(msg: String) -> void:
	print_rich('[color=lightgreen]MFCharGenWindow[/color] ' + msg)
