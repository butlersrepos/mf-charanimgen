@tool
extends EditorPlugin
class_name MFCharAnimGenPlugin

const menu_item_title = "Mini Fantasy - Character Animation Builder"
const MENU_SCENE = preload("res://addons/MF-CharAnimGen/UI/MF-CharAnimGenWindow.tscn")

# Saved settings
const CHARACTER_FOLDER_SETTING_KEY := "MF-CharAnimGen/character_folder"
const DEFAULT_CHARACTER_FOLDER := "res://assets/characters"

const SPRITE_FRAMES_FOLDER_SETTING_KEY := "MF-CharAnimGen/sprite_frames_folder"
const DEFAULT_SPRITE_FRAMES_FOLDER := "res://"

const SPRITE_FRAMES_FILE_NAME_SETTING_KEY := "MF-CharAnimGen/sprite_frames_file_name"
const DEFAULT_SPRITE_FRAMES_NAME := "mini-fantasy-sprite-frames"

var menu_instance: MFCharGenWindow = MENU_SCENE.instantiate()

func _ready() -> void:
	pass

func _enter_tree():
	var editor_settings = EditorInterface.get_editor_settings()
	if not editor_settings.has_setting(CHARACTER_FOLDER_SETTING_KEY):
		editor_settings.set_setting(CHARACTER_FOLDER_SETTING_KEY, DEFAULT_CHARACTER_FOLDER)
	if not editor_settings.has_setting(SPRITE_FRAMES_FOLDER_SETTING_KEY):
		editor_settings.set_setting(SPRITE_FRAMES_FOLDER_SETTING_KEY, DEFAULT_SPRITE_FRAMES_FOLDER)
	if not editor_settings.has_setting(SPRITE_FRAMES_FILE_NAME_SETTING_KEY):
		editor_settings.set_setting(SPRITE_FRAMES_FILE_NAME_SETTING_KEY, DEFAULT_SPRITE_FRAMES_NAME)

	add_tool_menu_item(menu_item_title, func():
		if menu_instance == null:
			menu_instance = MENU_SCENE.instantiate()
		if find_child(menu_instance.name, true, false) != null:
			menu_instance.popup_centered()
			menu_instance.grab_focus()
		else:
			add_child(menu_instance)
	)

func _exit_tree():
	remove_tool_menu_item(menu_item_title)
	if menu_instance:
		menu_instance.queue_free()
