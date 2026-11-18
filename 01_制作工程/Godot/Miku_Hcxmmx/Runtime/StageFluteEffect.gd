extends "res://Miku_Hcxmmx/Runtime/StageCastEffect.gd"

var _cheer := 0.0
var _finale := 0.0


func configure(data: Dictionary) -> void:
	super.configure(data)
	_glow.position = Vector2(0, -210)
	_glow.scale = Vector2(350, 420) / _glow.texture.get_size()


func sample(time: float, target: Vector2, target_enabled: bool) -> void:
	super.sample(time, target, target_enabled)
	_cheer = 0.0
	for cue: float in profile.phrases:
		var age := _time - cue
		_cheer = maxf(_cheer, smoothstep(0, .04, age) * (1 - smoothstep(.15, .4, age)))
	var finale_at := float(profile.get("finale_time", 2.12))
	var body_duration := float(profile.body_duration)
	_finale = smoothstep(finale_at, finale_at + .1, _time) * (1 - smoothstep(finale_at + .26, finale_at + .6, _time))
	var activity := smoothstep(.02, .18, _time) * (1 - smoothstep(body_duration + .05, body_duration + .55, _time))
	music_stage.sample(_time, {}, 0, maxf(_cheer * .5, _finale * .85))
	music_stage.activation = activity * .65
	music_stage.wave_motion = _time * 5 * activity
	music_stage.light_sweep_angle = _time * 4
	music_stage.light_sweep_strength = activity * (.3 + _cheer * .4)
	for index in StageScript.BAR_COUNT:
		var horizontal: float = index / float(StageScript.BAR_COUNT - 1) * 2 - 1
		var arch := sqrt(maxf(0, 1 - horizontal * horizontal))
		var level := .35 + absf(sin(index * 1.6 - _time * 6)) * .65
		music_stage.spectrum_levels[index] = level * activity
		music_stage.spectrum_heights[index] += (85 + level * 115) * activity * arch
	for index in 8:
		music_stage.bands[index] = (.4 + absf(sin(index * 1.6 - _time * 6)) * .6) * activity
	_glow.modulate = Color(CYAN.lerp(PINK, _finale * .35), activity * .065 + _finale * .08)
	phase = "吹奏与应援" if _time < finale_at else ("返场亮拍" if _time < finale_at + .6 else "回落至常驻")


func _melody_point(progress: float, row := 0.0) -> Vector2:
	var point := Vector2(45, -295).bezier_interpolate(Vector2(270, -315), Vector2(190, -465), Vector2(-150, -375), progress)
	return point + Vector2(0, row * 7)


func _draw_front() -> void:
	for phrase in profile.phrases.size():
		var age := _time - float(profile.phrases[phrase])
		if age < 0 or age > .86:
			continue
		var head := clampf(age / .62, 0, 1)
		var fade := smoothstep(0, .04, age) * (1 - smoothstep(.48, .86, age))
		var points := PackedVector2Array()
		var brightness := PackedFloat32Array()
		for vertex in 49:
			var amount := vertex / 48.0
			var progress := maxf(0, head - .36 + amount * .36)
			points.append(_melody_point(progress))
			brightness.append(fade * pow(maxf(0, sin(amount * PI)), .6) * .65)
		for row in 5:
			var colors := PackedColorArray()
			var glow := PackedColorArray()
			var tint := CYAN if row % 3 else PINK
			for alpha: float in brightness:
				colors.append(Color(tint, alpha))
				glow.append(Color(tint, alpha * .12))
			_front.set_shape_transform(Vector2(0, (row - 2) * 7))
			_front.stroke_polyline_colors(points, glow, 9, true)
			_front.stroke_polyline_colors(points, colors, 2, true)
		_front.set_shape_transform(Vector2.ZERO)
		for note in 3:
			var progress := clampf(head - note * .095, 0, 1)
			var point := _melody_point(progress, (note - 1) * .8)
			var tint := CYAN if (note + phrase) % 2 == 0 else PINK
			GlyphScript.paint_note(_front, point, 27 + note % 2 * 6, -.13,
				tint.lerp(WHITE, .4), fade * .95, (note + phrase) % 3)
	_draw_cheering()
	if _finale > .003:
		for index in 8:
			var angle := index * TAU / 8
			var point := Vector2(cos(angle) * 165, -200 + sin(angle) * 165)
			var star := PackedVector2Array()
			for vertex in 8:
				var radius := (17.0 if vertex % 2 == 0 else 2.0) * (.7 + _finale * .3)
				star.append(point + Vector2.RIGHT.rotated(vertex * PI / 4 + .15) * radius)
			_front.draw_colored_polygon(star, Color(WHITE.lerp(PINK, .2), _finale * .8))


func _draw_cheering() -> void:
	var body_end := float(profile.body_duration)
	var fade := smoothstep(.08, .28, _time) * (1 - smoothstep(body_end + .15, body_end + .55, _time))
	for side in [-1.0, 1.0]:
		for index in 4:
			var base := Vector2(side * (155 + index * 29), 14 + index % 2 * 9)
			var angle: float = side * (.2 + sin(_time * 8 + index * .65) * .3)
			var tint := CYAN if index % 2 == 0 else PINK
			var height := 44 + index % 3 * 10 + _cheer * 9
			var start := base + Vector2(0, -12).rotated(angle)
			var end := base + Vector2(0, -height).rotated(angle)
			_front.stroke_line(start, end, Color(tint, fade * .12), 17, true)
			_front.stroke_line(start, end, Color(tint, fade * .85), 7, true)
			_front.fill_circle(end, 3.5, Color(tint.lerp(WHITE, .6), fade * .9), true, -1, true)
			_front.stroke_line(start, end, Color(WHITE, fade * (.4 + _cheer * .3)), 2, true)
			_front.stroke_line(base, start, Color(tint, fade * .6), 4, true)
