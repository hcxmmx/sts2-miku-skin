extends Node2D

const CanvasScript = preload("res://Miku_Hcxmmx/Runtime/EffectCanvas.gd")

const StageScript = preload("res://Miku_Hcxmmx/Runtime/MusicStage.gd")
const StageAccess = preload("res://Miku_Hcxmmx/Runtime/StageAccess.gd")
const GlyphScript = preload("res://Miku_Hcxmmx/Runtime/ActionEffect.gd")
const CYAN = Color("35e5f2")
const PINK = Color("ff68cf")
const WHITE = Color("dcffff")
var profile: Dictionary = {}
var phase := "展开谱面"
var target_flash := 0.0
var target_recoil := Vector2.ZERO
var music_stage: Node2D
var _front := CanvasScript.new()
var _glow := Sprite2D.new()
var _time := 0.0
var _build := 0.0
var _release := 0.0
var _pulse := 0.0


func configure(data: Dictionary) -> void:
	profile = data
	music_stage = StageAccess.acquire(self, profile.textures.glow)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_front.material = additive
	_front.z_index = 3
	add_child(_front)
	_glow.texture = load(profile.textures.glow)
	_glow.position = Vector2(165, -240)
	_glow.scale = Vector2(260, 170) / _glow.texture.get_size()
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_glow.use_parent_material = true
	_front.add_child(_glow)
	_front.set_painter(_draw_front)
	sample(0, Vector2.ZERO, false)


func sample(time: float, _target: Vector2, _target_enabled: bool) -> void:
	_time = maxf(time, 0)
	_build = smoothstep(.03, .2, _time)
	var age := _time - float(profile.hit)
	_release = smoothstep(0, .25, age)
	_pulse = smoothstep(0, .025, age) * (1 - smoothstep(.1, .36, age))
	var activity := _build * (1 - smoothstep(.65, 1.03, _time))
	music_stage.wave_motion = _build * 5 + _release * 7
	music_stage.light_sweep_angle = -.7 + _release * 1.4
	music_stage.light_sweep_strength = activity * .7
	music_stage.sample(_time, {}, 0, _pulse * .7)
	music_stage.activation = activity * .5
	for index in StageScript.BAR_COUNT:
		var horizontal: float = index / float(StageScript.BAR_COUNT - 1) * 2 - 1
		var arch := sqrt(maxf(0, 1 - horizontal * horizontal))
		var level := .35 + absf(sin(index * 1.6 - _time * 7)) * .65
		music_stage.spectrum_levels[index] = level * activity
		music_stage.spectrum_heights[index] += (50 + level * 105) * activity * arch
	for index in 8:
		music_stage.bands[index] = (.35 + absf(sin(index * 1.6 - _time * 7)) * .65) * activity
	_glow.modulate = Color(CYAN, activity * .12 + _pulse * .16)
	phase = "展开与拨动谱面" if age < 0 else ("释放声波" if age < .4 else "谱面碎散")
	_front.queue_redraw()


func _score_point(amount: float, row: float) -> Vector2:
	var spread := lerpf(.12, 1, _build)
	return Vector2(65 + amount * 220 * spread, -270 + amount * 24 - sin(amount * PI) * 17 + row * 15)


func _note_displacement(index: int, progress: float) -> Vector2:
	return Vector2(35 + index * 9, -25 - index % 3 * 18) * progress


func _draw_front() -> void:
	var fade := _build * (1 - smoothstep(float(profile.hit) + .12, float(profile.hit) + .45, _time))
	if fade > .003:
		var surface := PackedVector2Array()
		for index in 33:
			surface.append(_score_point(index / 32.0, -.8))
		for index in range(32, -1, -1):
			surface.append(_score_point(index / 32.0, 4.8))
		_front.draw_colored_polygon(surface, Color(CYAN, fade * .07))
		var points := PackedVector2Array()
		for index in 33:
			points.append(_score_point(index / 32.0, 0))
		for row in 5:
			_front.set_shape_transform(Vector2(0, row * 15))
			_front.stroke_polyline(points, Color(CYAN, fade * .08), 10, true)
			_front.stroke_polyline(points, Color(CYAN.lerp(WHITE, _pulse * .7), fade * .65), 2, true)
		_front.set_shape_transform(Vector2.ZERO)
		var cursor := clampf((_time - .14) / .28, 0, 1)
		var top := _score_point(cursor, -.7)
		var bottom := _score_point(cursor, 4.7)
		_front.stroke_line(top, bottom, Color(PINK, fade * .18), 12, true)
		_front.stroke_line(top, bottom, Color(WHITE, fade * .85), 2.5, true)
	for index in 6:
		var amount := .12 + index * .145
		var row := 1.0 + (index % 3) * .8
		var point := _score_point(amount, row)
		var lit := smoothstep(.14 + index * .04, .18 + index * .04, _time)
		var scatter := smoothstep(float(profile.hit) + .08, float(profile.hit) + .46, _time)
		point += _note_displacement(index, scatter)
		var alpha := _build * (1 - smoothstep(float(profile.hit) + .22, float(profile.hit) + .53, _time))
		var tint := CYAN if index % 2 == 0 else PINK
		GlyphScript.paint_note(_front, point, 20 + lit * 8, -.15 + scatter * .4,
			tint.lerp(WHITE, lit * .45 + _pulse * .3), alpha * (.3 + lit * .7), index % 3)
		if fade > .003:
			var text_point := _score_point(amount, 5.4)
			_front.draw_string(ThemeDB.fallback_font, text_point, "39" if index % 3 == 0 else "01",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(tint, fade * .6))
	_draw_wave(_time - float(profile.hit))


func _draw_wave(age: float) -> void:
	if age < 0 or age > .5:
		return
	var travel := clampf(age / .36, 0, 1)
	var alpha := smoothstep(0, .025, age) * (1 - smoothstep(.22, .5, age))
	for row in 5:
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		var glow := PackedColorArray()
		var head := .48 + travel * .52 - row * .018
		var tint := PINK if row % 3 == 1 else CYAN
		for vertex in 49:
			var portion := vertex / 48.0
			var amount := head - .42 + portion * .42
			var point := _score_point(amount, row)
			var envelope := pow(maxf(0, sin(portion * PI)), .8)
			point.y += sin(portion * TAU * 1.5 - age * 14 + row * .35) * envelope * (3 + travel * 5)
			points.append(point)
			var brightness := alpha * envelope * .9
			colors.append(Color(tint.lerp(WHITE, .45), brightness))
			glow.append(Color(tint, brightness * .14))
		_front.stroke_polyline_colors(points, glow, 12, true)
		_front.stroke_polyline_colors(points, colors, 3, true)


func marker_visible() -> bool:
	return false


func visible_draw_count() -> int:
	return music_stage.draw_count if visible else 0
