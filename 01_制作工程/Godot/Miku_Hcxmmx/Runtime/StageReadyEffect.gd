extends "res://Miku_Hcxmmx/Runtime/StageSpinEffect.gd"

var _note_glow := Sprite2D.new()
var _merge := 0.0
var _large_alpha := 0.0


func configure(data: Dictionary) -> void:
	super.configure(data)
	_note_glow.texture = load(profile.textures.glow)
	_note_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_note_glow.scale = Vector2(145, 145) / _note_glow.texture.get_size()
	_note_glow.position = Vector2(55, -253)
	_note_glow.use_parent_material = true
	_front.add_child(_note_glow)


func sample(time: float, target: Vector2, target_enabled: bool) -> void:
	super.sample(time, target, target_enabled)
	_merge = smoothstep(.52, .76, _time)
	_large_alpha = _merge * (1 - smoothstep(1.12, 1.48, _time))
	_note_glow.modulate = Color(CYAN, _large_alpha * (.14 + _peak * .13))
	music_stage.wave_motion = _charge * TAU * 2
	music_stage.light_sweep_angle = -PI / 2 + _charge * TAU
	music_stage.light_sweep_strength = _shine * (.35 + _peak * .5)
	for index in StageScript.BAR_COUNT:
		var horizontal: float = index / float(StageScript.BAR_COUNT - 1) * 2 - 1
		var open := smoothstep(.12 + absf(horizontal) * .25, .32 + absf(horizontal) * .25, _time)
		var level := .35 + absf(sin(index * 1.6 - _time * 5)) * .65
		var arch := sqrt(maxf(0, 1 - horizontal * horizontal))
		music_stage.spectrum_heights[index] = 12 + (75 + level * 140) * arch * open * _shine
		music_stage.spectrum_levels[index] = level * open * _shine
	phase = "音符汇聚与开麦" if _time < float(profile.hit) else ("开麦增强亮拍" if _peak > .01 else "辉光保持")


func _gather_point(note: Dictionary, index: int, lag := 0.0) -> Vector2:
	var gather := smoothstep(.08 + index * .018, .61 + index * .009, _time - lag)
	var angle := index * TAU / 8
	var merge := smoothstep(.52, .76, _time - lag)
	var finish := Vector2(55, -230) + Vector2(cos(angle) * 25, sin(angle) * 24) * (1 - merge)
	var start: Vector2 = note.point
	var side := signf(start.x)
	var point := start.bezier_interpolate(start + Vector2(side * 30, -65),
		finish + Vector2(side * 45, -25), finish, gather)
	return point


func _draw_layer(canvas: Node2D, front: bool) -> void:
	if front:
		_draw_shine(canvas)
		_draw_large_note(canvas)
	if _swirl < .003:
		return
	for index in _notes.size():
		if (index % 2 == 0) != front:
			continue
		var note: Dictionary = _notes[index]
		var point := _gather_point(note, index)
		var gather := smoothstep(.08, .65, _time)
		var size := lerpf(float(note.size), 21, gather) * (1 - _merge * .55)
		var tint: Color = note.tint
		var trail := PackedVector2Array()
		var colors := PackedColorArray()
		for vertex in 13:
			var portion := vertex / 12.0
			trail.append(_gather_point(note, index, (1 - portion) * .07))
			colors.append(Color(tint, _swirl * portion * .4 * (1 - _merge)))
		canvas.stroke_polyline_colors(trail, colors, 2.5, true)
		GlyphScript.paint_note(canvas, point, size, lerpf(float(note.angle), -.1, gather),
			tint.lerp(WHITE, .3 + _peak * .5), _swirl * .85 * (1 - _merge), int(note.variant))
	if front and _peak > .003:
		for index in 6:
			var angle := index * TAU / 6 + .2
			var direction := Vector2.RIGHT.rotated(angle)
			var point := Vector2(55, -252) + direction * (40 + _peak * 9)
			canvas.stroke_line(point, point + direction * 9, Color(WHITE, _peak * .8), 2, true)


func _draw_large_note(canvas: Node2D) -> void:
	if _large_alpha < .003:
		return
	var point := Vector2(55, -230 - _release * 9)
	var size := lerpf(24, 58, _merge) + _peak * 6
	GlyphScript.paint_note(canvas, point + Vector2(0, 1), size + 3, -.1,
		CYAN, _large_alpha * .3, 1)
	GlyphScript.paint_note(canvas, point, size, -.1,
		WHITE.lerp(CYAN, .16), _large_alpha, 1)
