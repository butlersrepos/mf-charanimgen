@tool
extends EditorScript
class_name FileOps

"""
#####################
Files/Folders helpers
#####################
"""

static func save_res(res: Resource, filepath: String) -> Error:
	var save_result = ResourceSaver.save(res, filepath)
	if save_result == OK:
		myprint("Successfully saved node to resource file")
	else:
		myprint("Failed to save resource file")
	return save_result

## Gets all folder names under a provided path, i.e. if a/b/c & a/b/d exist, then providing a/b will return [c,d]
static func get_all_folders(path: String) -> Array[String]:
	var dir = DirAccess.open(path)
	var folders: Array[String] = []
	# Record all folders we intend to process
	if dir:
		dir.list_dir_begin()
		var folder = dir.get_next()
		while folder != "":
			if dir.current_is_dir() and folder != "." and folder != "..":
				folders.append(folder)
			folder = dir.get_next()
		dir.list_dir_end()
	else:
		myprint("Could not open directory: " + path)
	return folders

static func get_all_png_files_from(path: String) -> Array[String]:
	var png_files: Array[String] = []
	var dir = DirAccess.open(path)

	if dir:
		var files = dir.get_files()
		myprint('Scanning file: ' + ", ".join(files))
		for file in files:
			# Get full path
			var full_path = path.path_join(file)
			# If it's a PNG file, add it to our list
			if file.get_extension() == "png":
				png_files.append(full_path)

		dir.include_hidden = false
		dir.include_navigational = false
		for folder in dir.get_directories():
			png_files.append_array(get_all_png_files_from(path + "/" + folder))
	else:
		myprint("Could not open directory: " + path)

	return png_files

static func save_node(savee: Node) -> void:
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(savee)

	if result == OK:
		FileOps.save_res(packed_scene, "res://%s.res" % [savee.name])
	else:
		myprint("Failed to pack node")

# Reads the animation info folder to discover sprite size
static func get_dimensions_from_file(file_path: String) -> Vector2i:
	if not FileAccess.file_exists(file_path):
		myprint("File not found: " + file_path)
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

# Helper to colorcode all logs in this file
static func myprint(msg: String) -> void:
	print_rich('[color=lightyelow]FileOps[/color]' + msg)
