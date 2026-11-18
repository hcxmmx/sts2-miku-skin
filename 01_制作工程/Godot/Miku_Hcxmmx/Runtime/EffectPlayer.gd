extends Node2D

static var catalog: Dictionary = {}
static var frame_data: Dictionary = {}
static var prepared: Dictionary = {}
static var texture_cache: Dictionary = {}
static var material_cache: Dictionary = {}
static var pinned_effects: Dictionary = {}
var effect_name := ""
var duration := 0.0
var _frames: Array = []
var _drawers: Array[MeshInstance2D] = []
var _sampled_frame := -2


func configure(name: String) -> void:
	effect_name = name
	load_catalog()
	if not catalog.effects.has(name):
		push_error("Missing Miku effect " + name)
		return
	var data: Dictionary = catalog.effects[name]
	duration = float(data.frame_count) / float(catalog.fps)
	if not frame_data.has(name):
		if frame_data.size() >= 8:
			for cached_name: String in frame_data.keys():
				if not pinned_effects.has(cached_name):
					frame_data.erase(cached_name)
					break
		frame_data[name] = JSON.parse_string(FileAccess.get_file_as_string(data.frames_path)).frames
	_frames = frame_data[name]
	if not prepared.has(name):
		prepared[name] = {}
	for index in int(data.max_draws):
		var instance := MeshInstance2D.new()
		instance.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(instance)
		_drawers.append(instance)
	sample(-1.0)


static func load_catalog() -> void:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string("res://Miku_Hcxmmx/Assets/effects.json"))


func _prepare_frame(frame_index: int) -> Array:
	var cache: Dictionary = prepared[effect_name]
	if cache.has(frame_index):
		return cache[frame_index]
	var draws: Array = []
	for entry: Dictionary in _frames[frame_index]:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var points := PackedVector2Array()
		for vertex: Array in entry.vertices:
			points.append(Vector2(vertex[0], vertex[1]))
		var uv := PackedVector2Array()
		for coordinate: Array in entry.uv:
			uv.append(Vector2(coordinate[0], coordinate[1]))
		var colors := PackedColorArray()
		for value: Array in entry.colors:
			colors.append(Color(value[0], value[1], value[2], value[3]))
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(entry.indices)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		draws.append({"mesh": mesh, "material": int(entry.material)})
	if cache.size() >= 128 and not pinned_effects.has(effect_name):
		cache.erase(cache.keys()[0])
	cache[frame_index] = draws
	return draws


static func prepare_material(material_id: int) -> void:
	var source: Dictionary = catalog.materials[material_id]
	if not texture_cache.has(source.texture):
		texture_cache[source.texture] = load(source.texture) if not source.texture.is_empty() else null
	if not material_cache.has(material_id):
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if int(source.blend_dst) == 1 else CanvasItemMaterial.BLEND_MODE_MIX
		material_cache[material_id] = material


func sample(time: float) -> void:
	var sampled_frame := int(time * float(catalog.fps)) if time >= 0 and time < duration else -1
	if sampled_frame == _sampled_frame:
		return
	_sampled_frame = sampled_frame
	for instance in _drawers:
		instance.hide()
	if time < 0.0 or time >= duration or _frames.is_empty():
		return
	var frame_index := int(time * float(catalog.fps))
	var frame := _prepare_frame(frame_index)
	for index in frame.size():
		var draw: Dictionary = frame[index]
		var material_id: int = draw.material
		var source: Dictionary = catalog.materials[material_id]
		prepare_material(material_id)
		_drawers[index].mesh = draw.mesh
		_drawers[index].texture = texture_cache[source.texture]
		_drawers[index].material = material_cache[material_id]
		_drawers[index].show()


func visible_draw_count() -> int:
	var count := 0
	for instance in _drawers:
		if instance.visible:
			count += 1
	return count
