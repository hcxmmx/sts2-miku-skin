extends SceneTree

const TOP = "images/ui/top_panel/character_icon_fool"
const SELECT = "images/packed/character_select/char_select_fool"
const MAP = "images/packed/map/icons/map_marker_fool"
const REST = "images/rooms/rest_sites/rest_site_fool_placeholder"
const COVER = "CrossingVoid_Investigation/Extracted_Miku/Recovered_iOS/Battle_Effects/particles/material/miku_lihui_03/miku_02.png"
const NOTE = "com.alicefiction_extract_20240921/com.alicefiction_extract_20240921/asset-2/AddressableAssetsUpdate/v2.1.0/adv_fxs/adv_fx_miku_buff_eighthnote_tex.png"


func _initialize() -> void:
	var workspace := ProjectSettings.globalize_path("res://../..")
	var leek := Image.load_from_file(workspace.path_join("00_用户素材/界面替换/葱_透明.png"))
	var cover := Image.load_from_file(workspace.path_join(COVER))
	var note := Image.load_from_file(workspace.path_join(NOTE))
	var rest := Image.load_from_file(workspace.path_join("MIKU fix.png"))
	if [leek, cover, note, rest].has(null):
		push_error("Missing interface source texture")
		quit(1)
		return
	var icon := _fit(leek.get_region(leek.get_used_rect()), Vector2i(85, 85), Vector2i(73, 73))
	var portrait := cover.get_region(Rect2i(112, 0, 385, 569))
	portrait.resize(132, 195, Image.INTERPOLATE_LANCZOS)
	note = note.get_region(note.get_used_rect())
	for y in note.get_height():
		for x in note.get_width():
			note.set_pixel(x, y, Color(Color("#79f4ec"), note.get_pixel(x, y).a))
	var marker := _fit(note, Vector2i(49, 64), Vector2i(41, 54))
	var seated := _fit(rest.get_region(Rect2i(0, 122, 1024, 1190)), Vector2i(370, 436), Vector2i(352, 402), 427)
	for entry in [[TOP, icon], [TOP + "_outline", _outline(icon)], [SELECT, portrait], [MAP, marker], [REST, seated]]:
		var output := ProjectSettings.globalize_path("res://" + entry[0] + ".png")
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		if entry[1].save_png(output) != OK:
			push_error("Could not save " + output)
			quit(1)
			return
	quit()


func _fit(image: Image, canvas: Vector2i, area: Vector2i, baseline := -1) -> Image:
	var factor := minf(float(area.x) / image.get_width(), float(area.y) / image.get_height())
	var extent := Vector2i((Vector2(image.get_size()) * factor).round())
	image.convert(Image.FORMAT_RGBA8)
	image.resize(extent.x, extent.y, Image.INTERPOLATE_LANCZOS)
	var result := Image.create_empty(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
	var offset := (canvas - extent) / 2
	if baseline >= 0:
		offset.y = baseline - extent.y
	result.blit_rect(image, Rect2i(Vector2i.ZERO, extent), offset)
	return result


func _outline(icon: Image) -> Image:
	var result := Image.create_empty(icon.get_width(), icon.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(2, icon.get_height() - 2):
		for x in range(2, icon.get_width() - 2):
			var alpha := 0.0
			for direction: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				alpha = maxf(alpha, icon.get_pixel(x + direction.x, y + direction.y).a)
			result.set_pixel(x, y, Color(Color.WHITE, alpha))
	return result
