extends SceneTree

var files: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func collect(path: String) -> void:
	if path == "res://Miku_Hcxmmx/Assets/Audio/User/battle_bgm":
		return
	for folder in DirAccess.get_directories_at(path):
		collect(path.path_join(folder))
	for file in DirAccess.get_files_at(path):
		if file.get_extension() in ["gd", "gdshader", "gdshaderinc", "tscn", "json", "png", "wav", "ogg"]:
			files.append(path.path_join(file))


func run() -> void:
	var output := ProjectSettings.globalize_path("res://../../02_构建产物/游戏测试包/MikuSkin/MikuSkin.pck")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var packer := PCKPacker.new()
	if packer.pck_start(output) != OK:
		quit(1)
		return
	collect("res://Miku_Hcxmmx")
	collect("res://images")
	for path in files.duplicate():
		if path.get_extension() == "png":
			var config := ConfigFile.new()
			if config.load(path + ".import") != OK:
				push_error("Missing texture import " + path)
				quit(1)
				return
			files.append(path + ".import")
			files.append(str(config.get_value("remap", "path")))
	for path in files:
		if packer.add_file(path, path) != OK:
			push_error("Could not pack " + path)
			quit(1)
			return
	if packer.flush() != OK:
		quit(1)
		return
	var inventory := FileAccess.open("res://../../02_构建产物/game_pack_contents.json", FileAccess.WRITE)
	inventory.store_string(JSON.stringify(files, "\t"))
	print("MIKU_PACK_OK files=", files.size(), " output=", output)
	quit()
