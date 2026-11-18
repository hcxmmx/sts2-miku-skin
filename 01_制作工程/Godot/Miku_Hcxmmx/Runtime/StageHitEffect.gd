extends "res://Miku_Hcxmmx/Runtime/StageCastEffect.gd"

const GlitchShader = preload("res://Miku_Hcxmmx/Runtime/HitGlitch.gdshader")
const NoiseShader = preload("res://Miku_Hcxmmx/Runtime/StageNoise.gdshader")
const InkShader = preload("res://Miku_Hcxmmx/Runtime/InkIcon.gdshader")
const DARK_RED = Color("a6233f")
const RED_LIGHT = Color("f56873")
var _glitch_material := ShaderMaterial.new()
var _glitch := 0.0
var _stage_material := ShaderMaterial.new()
var _mood := 0.0
var _ambient_notes: Array[Dictionary] = []
var _dislikes: Array[Sprite2D] = []


func configure(data: Dictionary) -> void:
	_glitch_material.shader = GlitchShader
	_stage_material.shader = NoiseShader
	super.configure(data)
	music_stage.material = _stage_material
	_ambient_notes = music_stage.notes_at(float(profile.hit))
	var icon: Texture2D = load("res://Miku_Hcxmmx/Assets/Icons/thumbs_down_reference.png")
	var ink_material := ShaderMaterial.new()
	ink_material.shader = InkShader
	ink_material.set_shader_parameter("icon_texture", icon)
	for index in 2:
		var glyph := Sprite2D.new()
		glyph.texture = icon
		glyph.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glyph.material = ink_material
		glyph.hide()
		_front.add_child(glyph)
		_dislikes.append(glyph)
	_glow.position = Vector2(15, -190)
	_glow.scale = Vector2(175, 280) / _glow.texture.get_size()


func restart() -> void:
	_ambient_notes = music_stage.notes_at(float(profile.hit))

func sample(time: float, target: Vector2, target_enabled: bool) -> void:
	super.sample(time, target, target_enabled)
	var age := _time - float(profile.hit)
	_glitch = smoothstep(0, .012, age) * (1 - smoothstep(.065, .19, age))
	_glitch_material.set_shader_parameter("strength", _glitch)
	_glitch_material.set_shader_parameter("effect_time", _time)
	_mood = smoothstep(0, .025, age) * (1 - smoothstep(.27, .52, age))
	_stage_material.set_shader_parameter("mood", _mood)
	_stage_material.set_shader_parameter("effect_time", _time)
	music_stage.note_opacity = 1 - _mood
	_glow.modulate = Color(DARK_RED, _glitch * .18)
	music_stage.light_sweep_strength = 0
	music_stage.activation = _glitch * .45
	music_stage.wave_motion = _glitch * sin(_time * 45) * 2
	for index in StageScript.BAR_COUNT:
		music_stage.spectrum_heights[index] = 12 + _glitch * (25 + absf(sin(index * 3.7)) * 75)
		music_stage.spectrum_levels[index] = _glitch * .5
	phase = "数字错位与冲击" if _glitch > .05 else "受击姿态恢复"
	for index in _dislikes.size():
		if 3 + index * 4 >= _ambient_notes.size():
			_dislikes[index].hide()
			continue
		var note: Dictionary = _ambient_notes[3 + index * 4]
		var glyph := _dislikes[index]
		glyph.position = _emote_point(note, 3 + index * 4, maxf(age, 0))
		glyph.rotation = sin(maxf(age, 0) * 23 + 3 + index * 4) * .07
		glyph.scale = Vector2(40, 45) / glyph.texture.get_size() * float(note.size) / 28
		glyph.modulate = Color(RED_LIGHT, _mood * clampf(float(note.alpha) + .25, .4, 1))
		glyph.visible = _mood > .003


func apply_body(sprite: Sprite2D) -> void:
	_glitch_material.set_shader_parameter("sprite_y", sprite.position.y)
	var atlas := sprite.texture as AtlasTexture
	_glitch_material.set_shader_parameter("actor_texture", atlas.atlas if atlas != null else sprite.texture)
	if atlas != null:
		var size := atlas.atlas.get_size()
		var region := atlas.region
		_glitch_material.set_shader_parameter("atlas_rect", Vector4(region.position.x / size.x,
			region.position.y / size.y, region.size.x / size.x, region.size.y / size.y))
	sprite.material = _glitch_material
	sprite.position.x -= _glitch * 6


func _draw_front() -> void:
	_draw_emotes()
	var age := _time - float(profile.hit)
	if age < 0 or age > .34:
		return
	var fade := smoothstep(0, .012, age) * (1 - smoothstep(.1, .34, age))
	var spread := 1 - exp(-age * 16)
	for index in 15:
		var side := -1.0 if index % 2 == 0 else 1.0
		var point := Vector2(side * (50 + spread * (25 + index % 4 * 13)), -95 - index * 14)
		var tint := DARK_RED if index % 3 == 0 else RED_LIGHT
		var length := 10 + index % 4 * 6
		_front.stroke_line(point, point + Vector2(side * length, 0), Color(tint, fade * .1), 9, true)
		_front.stroke_line(point, point + Vector2(side * length, 0), Color(tint, fade * .85), 2 + index % 2, true)
		if index % 4 == 0:
			var triangle := PackedVector2Array([point + Vector2(0, -6), point + Vector2(side * 8, 5), point + Vector2(-side * 4, 5)])
			_front.draw_colored_polygon(triangle, Color(tint, fade * .55))


func _draw_emotes() -> void:
	if _mood < .003:
		return
	var age := maxf(0, _time - float(profile.hit))
	for index in _ambient_notes.size():
		if index in [3, 7]:
			continue
		var note: Dictionary = _ambient_notes[index]
		var point := _emote_point(note, index, age)
		var scale := float(note.size) / 28
		var alpha := _mood * clampf(float(note.alpha) + .25, .4, 1)
		_front.set_shape_transform(point, sin(age * 23 + index) * .07, Vector2.ONE * scale)
		if index % 2 == 0:
			_front.fill_circle(Vector2.ZERO, 16, Color(DARK_RED, alpha * .13), true, -1, true)
			_front.stroke_arc(Vector2.ZERO, 16, 0, TAU, 48, Color(DARK_RED, alpha * .18), 9, true)
			_front.stroke_arc(Vector2.ZERO, 16, 0, TAU, 48, Color(RED_LIGHT, alpha), 2.5, true)
			for side in [-1.0, 1.0]:
				_front.stroke_line(Vector2(side * 9, -6), Vector2(side * 3, -3), Color(RED_LIGHT, alpha), 3, true)
				_front.fill_circle(Vector2(side * 5, 0), 1.8, Color(RED_LIGHT, alpha), true, -1, true)
			_front.stroke_polyline(PackedVector2Array([Vector2(-6, 9), Vector2(-3, 6), Vector2(0, 5), Vector2(3, 6), Vector2(6, 9)]), Color(RED_LIGHT, alpha), 2.5, true)
		else:
			for corner in 4:
				var path := PackedVector2Array([Vector2(4, -16), Vector2(4, -8), Vector2(8, -4), Vector2(16, -4)])
				for vertex in path.size():
					path[vertex] = path[vertex].rotated(corner * PI / 2)
				_front.stroke_polyline(path, Color(DARK_RED, alpha * .15), 9, true)
				_front.stroke_polyline(path, Color(RED_LIGHT, alpha), 3.5, true)
		_front.set_shape_transform(Vector2.ZERO)


func _emote_point(note: Dictionary, index: int, age: float) -> Vector2:
	return note.point + Vector2(sin(age * 75 + index) * exp(-age * 10) * 5, -12 + 30 * (1 - exp(-age * 7)))
