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
var phase := "舞台蓄势"
var target_flash := 0.0
var target_recoil := Vector2.ZERO
var music_stage: Node2D
var _back := CanvasScript.new()
var _front := CanvasScript.new()
var _notes: Array[Dictionary] = []
var _time := 0.0
var _turn := 0.0
var _swirl := 0.0
var _release := 0.0
var _peak := 0.0
var _charge := 0.0
var _shine := 0.0
var _shine_material := ShaderMaterial.new()
var _aura := Sprite2D.new()


func configure(data: Dictionary) -> void:
	profile = data
	music_stage = StageAccess.acquire(self, profile.textures.glow)
	_notes = music_stage.notes_at(0)
	_shine_material.shader = ShineShader
	_aura.texture = load(profile.textures.glow)
	_aura.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_aura.position = Vector2(0, -185)
	_aura.scale = Vector2(210, 370) / _aura.texture.get_size()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_aura.material = additive
	add_child(_aura)
	for layer: Node2D in [_back, _front]:
		layer.material = additive
		add_child(layer)
	_front.z_index = 3
	_back.set_painter(_draw_layer.bind(_back, false))
	_front.set_painter(_draw_layer.bind(_front, true))
	sample(0, Vector2.ZERO, false)


func restart() -> void:
	_notes = music_stage.notes_at(0)

func sample(time: float, _target: Vector2, _target_enabled: bool) -> void:
	_time = maxf(time, 0)
	var body_duration := float(profile.body_duration)
	_turn = clampf((_time - .16) / (body_duration - .16), 0, 1)
	_swirl = smoothstep(.03, .18, _time) * (1 - smoothstep(body_duration + .08, body_duration + .4, _time))
	_release = smoothstep(body_duration + .04, body_duration + .32, _time)
	var age := _time - float(profile.hit)
	_peak = smoothstep(0, .035, age) * (1 - smoothstep(.1, .38, age))
	_charge = smoothstep(.06, float(profile.hit) - .04, _time)
	_shine = _charge * (1 - smoothstep(body_duration + .48, body_duration + .64, _time))
	_aura.modulate = Color(CYAN, _shine * .13 + _peak * .15)
	_shine_material.set_shader_parameter("charge", _charge)
	_shine_material.set_shader_parameter("strength", _shine)
	_shine_material.set_shader_parameter("peak", _peak)
	music_stage.wave_motion = _turn * TAU * 2
	music_stage.light_sweep_angle = -PI / 2 + _turn * TAU
	music_stage.light_sweep_strength = _swirl * (1 - _release)
	music_stage.note_opacity = 1 - _swirl
	music_stage.sample(_time, {}, 0, _peak)
	music_stage.activation = _swirl * .65
	for index in StageScript.BAR_COUNT:
		var horizontal: float = index / float(StageScript.BAR_COUNT - 1) * 2 - 1
		var arch := sqrt(maxf(0, 1 - horizontal * horizontal))
		var wave := .4 + absf(sin(index * 1.7 - _turn * TAU * 2)) * .6
		music_stage.spectrum_levels[index] = wave * _swirl
		music_stage.spectrum_heights[index] += arch * (90 + wave * 120) * _swirl
	for index in 8:
		music_stage.bands[index] = (.4 + absf(sin(index * 1.7 - _turn * TAU * 2)) * .6) * _swirl
	phase = "音符卷起" if _time < float(profile.hit) else ("收势亮拍" if _peak > .01 else "回落至常驻")
	_back.queue_redraw()
	_front.queue_redraw()


func _orbit(index: int, lag := 0.0) -> Vector2:
	var angle := index * TAU / 8 + (_turn - lag) * TAU
	var radius := (Vector2(145, 90) * (1 - _peak * .22)).lerp(Vector2(230, 150), _release)
	return Vector2(0, -165) + Vector2(cos(angle), sin(angle)) * radius


func _draw_layer(canvas: Node2D, front: bool) -> void:
	if front:
		_draw_shine(canvas)
	if _swirl < .003:
		return
	var ribbon := PackedVector2Array()
	var colors := PackedColorArray()
	for index in 65:
		var amount := index / 64.0
		var angle := _turn * TAU - 2.2 + amount * 2.2
		var point := Vector2(0, -165) + Vector2(cos(angle) * 147, sin(angle) * 92)
		if (sin(angle) >= 0) != front:
			_draw_trail(canvas, ribbon, colors)
			ribbon.clear()
			colors.clear()
			continue
		ribbon.append(point)
		colors.append(Color(CYAN.lerp(PINK, amount * .65), amount * _swirl * (1 - _release) * .75))
	_draw_trail(canvas, ribbon, colors)
	for index in _notes.size():
		var note: Dictionary = _notes[index]
		var angle := index * TAU / 8 + _turn * TAU
		if (sin(angle) >= 0) != front:
			continue
		var point: Vector2 = note.point.lerp(_orbit(index), smoothstep(.03, .2, _time))
		var tint: Color = note.tint
		var size := lerpf(float(note.size), 32, _swirl)
		for echo in 3:
			var previous: Vector2 = note.point.lerp(_orbit(index, (3 - echo) * .018), smoothstep(.03, .2, _time))
			GlyphScript.paint_note(canvas, previous, size, float(note.angle), tint, _swirl * (echo + 1) * .065, int(note.variant))
		GlyphScript.paint_note(canvas, point, size, lerpf(float(note.angle), -.15, _swirl),
			tint.lerp(WHITE, .35 + _peak * .4), _swirl * .95, int(note.variant))
		canvas.fill_circle(point + Vector2(0, -12), 24, Color(tint, _swirl * .07), true, -1, true)
	if front and _peak > .003:
		for index in 12:
			var angle := TAU * index / 12
			var direction := Vector2(cos(angle), sin(angle) * .24)
			var distance := 140 + _release * 70
			var start := direction * distance + Vector2(0, -5)
			canvas.stroke_line(start, start + direction * (18 + _peak * 20), Color(WHITE, _peak * .9), 3, true)


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


func _draw_shine(canvas: Node2D) -> void:
	var anchors := PackedVector2Array([
		Vector2(-35, -310), Vector2(65, -265), Vector2(-75, -225),
		Vector2(40, -150), Vector2(80, -285), Vector2(-35, -165)])
	for index in anchors.size():
		var age := _time - (.2 + index * .105)
		var glint := smoothstep(0, .025, age) * (1 - smoothstep(.075, .24, age))
		var burst_age := _time - float(profile.hit) - index * .018
		var burst := smoothstep(0, .025, burst_age) * (1 - smoothstep(.12, .38, burst_age))
		var hold := _shine * .3 * smoothstep(1.2, 1.28, _time) * pow(maxf(0, sin(_time * 17 + index * 2.3)), 6)
		var alpha := maxf(glint * .8, maxf(burst, hold))
		if alpha < .003:
			continue
		var point := anchors[index] + Vector2(sin(_turn * TAU + index) * 8, 0)
		var tint := CYAN if index % 3 != 0 else PINK
		var radius := (17 + index % 3 * 6) * (.7 + alpha * .3)
		for layer in 4:
			canvas.fill_circle(point, radius * (1.5 - layer * .3), Color(tint, alpha * .045), true, -1, true)
		var star := PackedVector2Array()
		for vertex in 8:
			var length := radius if vertex % 2 == 0 else radius * .12
			star.append(point + Vector2.RIGHT.rotated(vertex * PI / 4 + .15) * length)
		canvas.draw_colored_polygon(star, Color(WHITE, alpha))


func _draw_trail(canvas: Node2D, points: PackedVector2Array, colors: PackedColorArray) -> void:
	if points.size() < 2:
		return
	var glow := PackedColorArray()
	for tint: Color in colors:
		glow.append(Color(tint, tint.a * .12))
	canvas.stroke_polyline_colors(points, glow, 17, true)
	canvas.stroke_polyline_colors(points, colors, 4, true)


func marker_visible() -> bool:
	return false


func visible_draw_count() -> int:
	return music_stage.draw_count if visible else 0
