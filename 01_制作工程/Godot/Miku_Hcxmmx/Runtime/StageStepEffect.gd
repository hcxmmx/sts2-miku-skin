extends Node2D

const CanvasScript = preload("res://Miku_Hcxmmx/Runtime/EffectCanvas.gd")

const StageScript = preload("res://Miku_Hcxmmx/Runtime/MusicStage.gd")
const StageAccess = preload("res://Miku_Hcxmmx/Runtime/StageAccess.gd")
const GlyphScript = preload("res://Miku_Hcxmmx/Runtime/ActionEffect.gd")
const ShineShader = preload("res://Miku_Hcxmmx/Runtime/PowerUpShine.gdshader")
const CYAN = Color("35e5f2")
const PINK = Color("ff68cf")
const WHITE = Color("dcffff")
var profile: Dictionary = {}
var phase := "侧步踩拍"
var target_flash := 0.0
var target_recoil := Vector2.ZERO
var music_stage: Node2D
var _floor := CanvasScript.new()
var _front := CanvasScript.new()
var _aura := Sprite2D.new()
var _shine_material := ShaderMaterial.new()
var _time := 0.0
var _beats := PackedFloat32Array([0, 0])
var _charge := 0.0
var _shine := 0.0


func configure(data: Dictionary) -> void:
	profile = data
	music_stage = StageAccess.acquire(self, profile.textures.glow)
	_shine_material.shader = ShineShader
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for layer: Node2D in [_floor, _front]:
		layer.material = additive
		add_child(layer)
	_front.z_index = 3
	_floor.set_painter(_draw_floor)
	_front.set_painter(_draw_front)
	_aura.texture = load(profile.textures.glow)
	_aura.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_aura.scale = Vector2(205, 355) / _aura.texture.get_size()
	_aura.position = Vector2(0, -180)
	_aura.material = additive
	add_child(_aura)
	sample(0, Vector2.ZERO, false)


func _beat(age: float) -> float:
	return smoothstep(0, .02, age) * (1 - smoothstep(.1, .34, age))


func sample(time: float, _target: Vector2, _target_enabled: bool) -> void:
	_time = maxf(time, 0)
	var note_offset := 0.0
	var note_speed := 0.0
	for index in 2:
		var age := _time - float(profile.beats[index])
		_beats[index] = _beat(age)
		if age > 0:
			# Integrate each velocity pulse so slowing down preserves the new position.
			var combined_decay := 1.0 / (1.0 / .035 + 1.0 / .22)
			note_offset += 3 * (.22 * (1 - exp(-age / .22)) - combined_decay * (1 - exp(-age / combined_decay)))
			note_speed += 3 * (1 - exp(-age / .035)) * exp(-age / .22)
	music_stage.note_time_offset = note_offset
	music_stage.note_boost_strength = note_speed
	var peak := maxf(_beats[0] * .65, _beats[1])
	var body_duration := float(profile.body_duration)
	_charge = smoothstep(.08, float(profile.beats[1]) + .12, _time)
	_shine = _charge * (1 - smoothstep(body_duration + .35, body_duration + .58, _time))
	_shine_material.set_shader_parameter("charge", _charge)
	_shine_material.set_shader_parameter("strength", _shine)
	_shine_material.set_shader_parameter("peak", peak)
	_aura.modulate = Color(CYAN.lerp(PINK, _beats[1] * .3), _shine * .12 + peak * .12)
	music_stage.wave_motion = smoothstep(.12, .4, _time) * 5 - smoothstep(.46, .78, _time) * 9
	music_stage.sample(_time, {}, 0, peak * .85)
	music_stage.activation = _shine * .25 + peak * .55
	for index in StageScript.BAR_COUNT:
		var horizontal: float = index / float(StageScript.BAR_COUNT - 1) * 2 - 1
		var left := exp(-pow((horizontal + .5) / .38, 2)) * _beats[0]
		var right := exp(-pow((horizontal - .4) / .5, 2)) * _beats[1]
		var energy := maxf(left, right)
		music_stage.spectrum_levels[index] = energy
		music_stage.spectrum_heights[index] += energy * (140 + absf(sin(index * 2.3)) * 85)
	for index in 8:
		music_stage.bands[index] = peak * (.45 + absf(sin(index * 1.8)) * .55)
	phase = "第一拍点亮" if _time < float(profile.beats[1]) else ("第二拍强化" if _time < .95 else "强化辉光保持")
	_floor.queue_redraw()
	_front.queue_redraw()


func _draw_floor() -> void:
	for beat in 2:
		var age := _time - float(profile.beats[beat])
		for pad in 24:
			var angle := pad * TAU / 24
			var delay := (1 + cos(angle) * (1 if beat == 0 else -1)) * .055
			var alpha := _beat(age - delay)
			if alpha < .003:
				continue
			var tint := CYAN if beat == 0 else PINK
			var points := PackedVector2Array()
			for edge in 2:
				var radius := Vector2(105, 24) if edge == 0 else Vector2(172, 39)
				for vertex in 5:
					var amount := vertex / 4.0 if edge == 0 else 1 - vertex / 4.0
					var a := angle + .025 + amount * (TAU / 24 - .05)
					points.append(Vector2(cos(a), sin(a)) * radius + Vector2(0, -3))
			_floor.draw_colored_polygon(points, Color(tint, alpha * .32))
			var point := Vector2(cos(angle + .13) * 170, sin(angle + .13) * 39 - 3)
			var direction := Vector2(-sin(angle + .13), cos(angle + .13) * .23)
			_floor.stroke_line(point - direction * 9, point + direction * 9, Color(WHITE, alpha * .9), 3, true)


func _draw_front() -> void:
	for beat in 2:
		var age := _time - float(profile.beats[beat])
		var fade := smoothstep(0, .025, age) * (1 - smoothstep(.3, .64, age))
		if fade < .003:
			continue
		var side := -1.0 if beat == 0 else 1.0
		var foot := Vector2(-25 if beat == 0 else 35, -4)
		var spread := 1 - exp(-maxf(age, 0) * 6)
		var rise := 1 - exp(-maxf(age, 0) * 8)
		var tint := CYAN if beat == 0 else PINK
		for index in 3:
			var point := foot + Vector2(((index - 1) * 48 + side * 12) * spread,
				-8 - (65 + index * 20) * rise - age * 12)
			var angle := (index - 1) * .25 + side * .1 * spread
			GlyphScript.paint_note(_front, point + Vector2(0, 9), 27 + index * 3,
				angle, tint, fade * .15, index)
			GlyphScript.paint_note(_front, point, 27 + index * 3,
				angle, tint.lerp(WHITE, .35), fade, index)
		_front.stroke_line(foot - Vector2(18, 0), foot + Vector2(18, 0),
			Color(WHITE, _beats[beat] * .9), 3, true)
	var anchors := PackedVector2Array([Vector2(-42, -285), Vector2(58, -250), Vector2(-37, -160), Vector2(42, -140)])
	for index in anchors.size():
		var alpha := maxf(_beats[0] * .45, _beats[1]) * (.75 + index % 2 * .2)
		alpha = maxf(alpha, _shine * .28 * pow(maxf(0, sin(_time * 16 + index * 2)), 8))
		if alpha < .003:
			continue
		var star := PackedVector2Array()
		for vertex in 8:
			var radius := (18.0 + index * 2) if vertex % 2 == 0 else 2.5
			star.append(anchors[index] + Vector2.RIGHT.rotated(vertex * PI / 4 + .15) * radius)
		_front.draw_colored_polygon(star, Color(WHITE, alpha))


func apply_body(sprite: Sprite2D) -> void:
	_shine_material.set_shader_parameter("sprite_y", sprite.position.y)
	var atlas := sprite.texture as AtlasTexture
	_shine_material.set_shader_parameter("actor_texture", atlas.atlas if atlas != null else sprite.texture)
	if atlas != null:
		var size := atlas.atlas.get_size()
		var region := atlas.region
		_shine_material.set_shader_parameter("atlas_rect", Vector4(region.position.x / size.x,
			region.position.y / size.y, region.size.x / size.x, region.size.y / size.y))
	sprite.material = _shine_material


func marker_visible() -> bool:
	return false


func visible_draw_count() -> int:
	return music_stage.draw_count if visible else 0
