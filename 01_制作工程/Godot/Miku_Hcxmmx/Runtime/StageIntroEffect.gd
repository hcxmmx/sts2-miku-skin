extends Node2D

const CanvasScript = preload("res://Miku_Hcxmmx/Runtime/EffectCanvas.gd")

const StageScript = preload("res://Miku_Hcxmmx/Runtime/MusicStage.gd")
const StageAccess = preload("res://Miku_Hcxmmx/Runtime/StageAccess.gd")
const RevealShader = preload("res://Miku_Hcxmmx/Runtime/StageReveal.gdshader")
const CYAN = Color("35e5f2")
const PINK = Color("ff68cf")
const DATA_SYMBOLS = ["01", "01", "01", "39"]
var profile: Dictionary = {}
var phase := "舞台建立"
var target_flash := 0.0
var target_recoil := Vector2.ZERO
var music_stage: Node2D
var _reveal := ShaderMaterial.new()
var _front := CanvasScript.new()
var _time := 0.0


func configure(data: Dictionary) -> void:
	profile = data
	_reveal.shader = RevealShader
	music_stage = StageAccess.acquire(self, profile.textures.glow)
	_front.z_index = 3
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_front.material = additive
	add_child(_front)
	_front.set_painter(_draw_front)
	sample(0, Vector2.ZERO, false)


func sample(time: float, _target: Vector2, _target_enabled: bool) -> void:
	_time = maxf(time, 0)
	var peak := smoothstep(1.45, 1.57, _time) * (1 - smoothstep(1.75, 2.1, _time))
	music_stage.entrance_time = _time * .55
	music_stage.sample(_time, {}, 0, peak * .75)
	var spectrum := smoothstep(.35, .8, _time) * (1 - smoothstep(2.2, 2.9, _time))
	music_stage.activation = spectrum * .65
	for index in StageScript.BAR_COUNT:
		var horizontal: float = index / float(StageScript.BAR_COUNT - 1) * 2 - 1
		var arch := sqrt(maxf(0, 1 - horizontal * horizontal))
		var level := .4 + absf(sin(index * 1.73 + _time * 10)) * .6
		music_stage.bands[index % 8] = level * spectrum
		music_stage.spectrum_levels[index] = level * spectrum
		music_stage.spectrum_heights[index] += (80 + level * 140) * arch * spectrum
	music_stage.modulate.a = smoothstep(0, .06, _time)
	_reveal.set_shader_parameter("scan_y", lerpf(-400, 20, clampf((_time - .3) / .9, 0, 1)))
	_reveal.set_shader_parameter("appearance", smoothstep(0, .08, _time))
	phase = "舞台建立" if _time < .3 else ("扫描显现" if _time < 1.2 else "登场庆祝" if _time < 2.8 else "常驻舞台")
	_front.queue_redraw()


func apply_body(sprite: Sprite2D) -> void:
	_reveal.set_shader_parameter("sprite_y", sprite.position.y)
	sprite.material = _reveal


func _draw_front() -> void:
	var scan := clampf((_time - .3) / .9, 0, 1)
	var scan_alpha := smoothstep(.28, .34, _time) * (1 - smoothstep(1.15, 1.23, _time))
	var scan_y := lerpf(-400, 20, scan)
	var trail_length := minf(120, maxf(0, (_time - .3) * 420 / .9))
	if trail_length > 1:
		for column in 20:
			var x := (column - 9.5) * 17
			var length := minf(trail_length, 58 + absf(sin(column * 2.73)) * 62)
			var speed := 48 + absf(sin(column * 5.17)) * 65
			for row in 8:
				var distance := fposmod(_time * speed + row * 15 + column * 7.3, 120) + 5
				if distance > length:
					continue
				var tick := floori(_time * 12 + column * .37)
				var symbol_index := posmod(column * 31 + row * 17 + tick * 7, DATA_SYMBOLS.size())
				var alpha := pow(1 - distance / length, .65) * scan_alpha
				var flicker := .6 + .4 * absf(sin(tick * 2.3 + column + row * 1.7))
				var tint := CYAN.lerp(Color.WHITE, .65 if row % 3 == 0 else .15)
				var point := Vector2(x - 7, scan_y - distance)
				_front.draw_string(ThemeDB.fallback_font, point, DATA_SYMBOLS[symbol_index], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(tint, alpha * flicker))
				if row % 3 == 0:
					_front.stroke_line(point + Vector2(3, -12), point + Vector2(3, -18), Color(CYAN, alpha * .35), 1, true)
	for layer in 3:
		var height := 12.0 if layer == 0 else (4.0 if layer == 1 else 1.2)
		var alpha := (.1 if layer == 0 else (.3 if layer == 1 else .95)) * scan_alpha
		var tint := CYAN if layer < 2 else Color.WHITE
		var points := PackedVector2Array([
			Vector2(-195, scan_y), Vector2(-150, scan_y - height),
			Vector2(150, scan_y - height), Vector2(195, scan_y),
			Vector2(150, scan_y + height), Vector2(-150, scan_y + height)])
		_front.draw_polygon(points, PackedColorArray([
			Color(tint, 0), Color(tint, alpha), Color(tint, alpha),
			Color(tint, 0), Color(tint, alpha), Color(tint, alpha)]))
	for index in 6:
		var x := sin(index * 12.73 + _time * 2) * 150
		var point := Vector2(x, scan_y + sin(index * 3.7) * 4)
		_front.stroke_line(point - Vector2(0, 3), point + Vector2(0, 3), Color(Color.WHITE, scan_alpha * .65), 1.5, true)
	var age := _time - 1.57
	if age < 0 or age > .45:
		return
	var fade := minf(age / .025, 1) * pow(1 - age / .45, 1.4)
	if fade <= .001:
		return
	for index in 8:
		var angle := index * TAU / 8 + .2
		var point := Vector2(cos(angle) * (120 + age * 160), -165 + sin(angle) * (145 + age * 90))
		var tint := CYAN if index % 2 == 0 else PINK
		_front.fill_circle(point, 18, Color(tint, fade * .1), true, -1, true)
		var star := PackedVector2Array()
		for vertex in 8:
			var radius := (14.0 if vertex % 2 == 0 else 2.0) * (.65 + fade * .35)
			star.append(point + Vector2.RIGHT.rotated(vertex * PI / 4 + .2) * radius)
		_front.draw_colored_polygon(star, Color(tint.lerp(Color.WHITE, .65), fade))


func marker_visible() -> bool:
	return false


func visible_draw_count() -> int:
	return music_stage.draw_count if visible else 0
