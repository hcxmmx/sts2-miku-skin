extends Node2D

const EffectScript = preload("res://Miku_Hcxmmx/Runtime/EffectPlayer.gd")
const LayerScript = preload("res://Miku_Hcxmmx/Portrait/PortraitLayer.gd")
const AlphaShader = preload("res://Miku_Hcxmmx/Portrait/PortraitAlpha.gdshader")
const AccentsShader = preload("res://Miku_Hcxmmx/Portrait/PortraitAccents.gdshader")
static var _material_id := -1
var info: Dictionary
var _players: Dictionary = {}
var _face: Node2D
var _mouth: Node2D
var pose := "normal"
var lip_enabled := true
var dynamics_enabled := true
var motion_strength := 1.0
var light_strength := 1.0
var _body_material := ShaderMaterial.new()
var _accent_material := ShaderMaterial.new()
var _slot_root := Node2D.new()


func _ready() -> void:
	info = JSON.parse_string(FileAccess.get_file_as_string("res://Miku_Hcxmmx/Portrait/Assets/portrait.json"))
	EffectScript.load_catalog()
	if _material_id < 0:
		_material_id = EffectScript.catalog.materials.size()
		EffectScript.catalog.materials.append({"texture": info.texture, "blend_dst": 10})
		var material := ShaderMaterial.new()
		material.shader = AlphaShader
		EffectScript.material_cache[_material_id] = material
	# Keep internal layer order within the portrait's tree so native fades draw over it.
	_slot_root.name = "Artwork"
	add_child(_slot_root)
	var body := _player("body")
	body.sample(0)
	_body_material.shader = AlphaShader
	_body_material.set_shader_parameter("body_layer", true)
	_body_material.set_shader_parameter("body_uv", Vector4(info.body_uv[0], info.body_uv[1], info.body_uv[2], info.body_uv[3]))
	body._drawers[0].material = _body_material
	var bounds: Array = info.bounds
	var source_bounds := Vector4(bounds[0], bounds[1], bounds[2], bounds[3])
	_body_material.set_shader_parameter("art_bounds", source_bounds)
	_accent_material.shader = AccentsShader
	_accent_material.set_shader_parameter("art_bounds", source_bounds)
	var accent := MeshInstance2D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(bounds[2], bounds[3]) * 1.12
	quad.center_offset = Vector3(bounds[0] + bounds[2] * .5, bounds[1] + bounds[3] * .5, 0)
	accent.mesh = quad
	accent.material = _accent_material
	add_child(accent)
	select_pose("normal", true)


func _player(clip: String) -> Node2D:
	if _players.has(clip):
		return _players[clip]
	var key := "alice_portrait/" + clip
	if not EffectScript.catalog.effects.has(key):
		EffectScript.catalog.effects[key] = info.clips[clip]
		EffectScript.pinned_effects[key] = true
		var frames: Array = JSON.parse_string(FileAccess.get_file_as_string(info.clips[clip].frames_path)).frames
		for frame: Array in frames:
			for draw: Dictionary in frame:
				draw.material = _material_id
		EffectScript.frame_data[key] = frames
	var player := LayerScript.new()
	player.slot_root = _slot_root
	add_child(player)
	player.configure(key)
	_players[clip] = player
	return player


func select_pose(value: String, lip: bool) -> void:
	pose = value
	lip_enabled = lip
	if _face != null:
		_face.sample(-1.0)
		_mouth.sample(-1.0)
	var row: Dictionary = info.poses[pose]
	_face = _player(row.face)
	_mouth = _player(row.lip if lip else row.mouth)
	sample(0)


func sample(time: float) -> void:
	_body_material.set_shader_parameter("clock", time)
	_body_material.set_shader_parameter("motion_gain", motion_strength if dynamics_enabled else 0.0)
	_body_material.set_shader_parameter("light_gain", light_strength if dynamics_enabled else 0.0)
	_accent_material.set_shader_parameter("clock", time)
	_accent_material.set_shader_parameter("motion_gain", motion_strength if dynamics_enabled else 0.0)
	_accent_material.set_shader_parameter("light_gain", light_strength if dynamics_enabled else 0.0)
	_face.sample(fposmod(time, _face.duration))
	_mouth.sample(fposmod(time, _mouth.duration))
