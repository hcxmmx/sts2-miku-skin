extends "res://Miku_Hcxmmx/Runtime/StageCastEffect.gd"

const ShutdownShader = preload("res://Miku_Hcxmmx/Runtime/StageShutdown.gdshader")
const GlitchShader = preload("res://Miku_Hcxmmx/Runtime/HitGlitch.gdshader")
var _shutdown_material := ShaderMaterial.new()
var _body_material := ShaderMaterial.new()
var _falling_notes: Array[Dictionary] = []


func configure(data: Dictionary) -> void:
	_shutdown_material.shader = ShutdownShader
	_body_material.shader = GlitchShader
	super.configure(data)
	music_stage.material = _shutdown_material
	_falling_notes = music_stage.notes_at(0)
	_glow.hide()


func restart() -> void:
	_falling_notes = music_stage.notes_at(0)

func sample(time: float, target: Vector2, target_enabled: bool) -> void:
	super.sample(time, target, target_enabled)
	var power := 1 - smoothstep(.12, .88, _time)
	var glitch := smoothstep(0, .018, _time) * (1 - smoothstep(.055, .17, _time))
	_shutdown_material.set_shader_parameter("effect_time", _time)
	_body_material.set_shader_parameter("strength", glitch * .7)
	_body_material.set_shader_parameter("effect_time", _time)
	_body_material.set_shader_parameter("dim", smoothstep(.25, 1.15, _time) * .55)
	music_stage.note_opacity = 0
	music_stage.light_sweep_strength = 0
	music_stage.activation = power * .5
	music_stage.emphasis = glitch * .3
	music_stage.wave_motion = (1 - exp(-_time * 5)) * 2
	music_stage.modulate.a = 1 - smoothstep(1.4, 1.65, _time)
	for index in StageScript.BAR_COUNT:
		var horizontal: float = index / float(StageScript.BAR_COUNT - 1) * 2 - 1
		var arch := sqrt(maxf(0, 1 - horizontal * horizontal))
		var collapse := pow(power, 1 + absf(horizontal) * .8)
		music_stage.spectrum_heights[index] = 12 + (90 + absf(sin(index * 1.7)) * 100) * arch * collapse
		music_stage.spectrum_levels[index] = collapse * .65
	for index in 8:
		music_stage.bands[index] = power * (.3 + absf(sin(index * 2.3)) * .5)
	phase = "信号中断" if _time < .2 else ("频谱与音符坠落" if _time < .85 else "舞台熄灯" if _time < 1.65 else "败北姿势保持")


func apply_body(sprite: Sprite2D) -> void:
	_body_material.set_shader_parameter("sprite_y", sprite.position.y)
	var atlas := sprite.texture as AtlasTexture
	_body_material.set_shader_parameter("actor_texture", atlas.atlas if atlas != null else sprite.texture)
	if atlas != null:
		var size := atlas.atlas.get_size()
		var region := atlas.region
		_body_material.set_shader_parameter("atlas_rect", Vector4(region.position.x / size.x,
			region.position.y / size.y, region.size.x / size.x, region.size.y / size.y))
	sprite.material = _body_material


func _draw_front() -> void:
	for index in _falling_notes.size():
		var note: Dictionary = _falling_notes[index]
		var age := maxf(0, _time - index * .025)
		var fall := maxf(0, age - .1)
		var point: Vector2 = note.point + Vector2(sin(age * 3 + index) * fall * 10, fall * 45 + fall * fall * 90)
		var fade := (1 - smoothstep(.38, 1.15, age)) * clampf((-point.y - 5) / 35, 0, 1)
		var tint: Color = note.tint
		tint = tint.lerp(Color("687584"), smoothstep(.08, .65, age))
		GlyphScript.paint_note(_front, point, note.size, float(note.angle) + sin(age * 4 + index) * .2,
			tint, float(note.alpha) * fade, note.variant)
	if _time < .24:
		var fade := smoothstep(0, .015, _time) * (1 - smoothstep(.08, .24, _time))
		for index in 9:
			var point := Vector2(-80 + index % 3 * 65, -310 + index * 24)
			var shift := sin(index * 8.3 + floorf(_time * 28)) * 12
			point.x += shift
			_front.stroke_line(point, point + Vector2(18 + index % 4 * 8, 0), Color(PINK, fade * .55), 2, true)
