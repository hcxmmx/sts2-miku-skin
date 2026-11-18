extends "res://Miku_Hcxmmx/Runtime/StageCastEffect.gd"

var _head := Vector2(0, -325)
var _paw := Vector2(45, -285)
var _tilt := 0.0
var _ears := 0.0
var _cup_style := StyleBoxFlat.new()
var _pad_style := StyleBoxFlat.new()
var _ear_paths: Dictionary = {}
var _headband_paths: Array[PackedVector2Array] = []


func configure(data: Dictionary) -> void:
	for radius: float in [49.0, 42.0]:
		var path := PackedVector2Array()
		for vertex in 49:
			var angle := PI * vertex / 48.0
			path.append(Vector2(-cos(angle) * radius, -5.0 - sin(angle) * radius))
		_headband_paths.append(path)
	super.configure(data)
	_glow.scale = Vector2(155, 120) / _glow.texture.get_size()
	for style: StyleBoxFlat in [_cup_style, _pad_style]:
		style.set_corner_radius_all(7)
		style.set_border_width_all(3)
		style.anti_aliasing = true
		style.shadow_size = 8


func sample(time: float, target: Vector2, target_enabled: bool) -> void:
	super.sample(time, target, target_enabled)
	for pose: Dictionary in profile.head_poses:
		if _time >= float(pose.time):
			_head = Vector2(pose.head[0], pose.head[1])
			_paw = Vector2(pose.paw[0], pose.paw[1])
			_tilt = float(pose.tilt)
	var body_duration := float(profile.body_duration)
	if _time >= body_duration:
		_head = Vector2(0, -325)
		_tilt = 0.0
	_ears = smoothstep(.08, .28, _time) * (1 - smoothstep(body_duration - .12, body_duration + .18, _time))
	_glow.position = _head + Vector2(0, -28)
	_glow.modulate = Color(CYAN, _ears * .1 + _pulse * .08)
	phase = "猫耳显现" if _time < .3 else ("猫爪定势" if _time < body_duration else "音符消散")


func _draw_front() -> void:
	var age := _time - float(profile.hit)
	var twitch := sin(maxf(age, 0) * 32) * exp(-maxf(age, 0) * 12) * smoothstep(0, .025, age)
	_draw_headphones(twitch)
	for beat in 2:
		var paw_age := age - beat * .2
		var alpha := smoothstep(0, .025, paw_age) * (1 - smoothstep(.12, .34, paw_age))
		if alpha < .003:
			continue
		var side := -1.0 if beat == 0 else 1.0
		var point := _paw + Vector2(side * (36 + maxf(paw_age, 0) * 35), -12 - maxf(paw_age, 0) * 22)
		_front.set_shape_transform(point, side * .2, Vector2.ONE * (1 + alpha * .15))
		var pad := PackedVector2Array([
			Vector2(-12, 4), Vector2(-11, 0), Vector2(-6, -6), Vector2(0, -8),
			Vector2(6, -6), Vector2(11, 0), Vector2(12, 4), Vector2(8, 8), Vector2(0, 6), Vector2(-8, 8)])
		_front.draw_colored_polygon(pad, Color(PINK.lerp(WHITE, .3), alpha))
		for toe in 4:
			var toe_point := Vector2((toe - 1.5) * 8, -15 - (5 if toe in [1, 2] else 0))
			_front.fill_circle(toe_point, 4.2, Color(CYAN.lerp(WHITE, .6), alpha), true, -1, true)
		_front.set_shape_transform(Vector2.ZERO)
	var dissolve := smoothstep(float(profile.body_duration) - .08, float(profile.body_duration) + .3, _time)
	var fade := sin(dissolve * PI)
	if fade > .003:
		for index in 5:
			var side := -1.0 if index % 2 == 0 else 1.0
			var point := _head + Vector2(side * (25 + dissolve * (30 + index * 6)), -35 - dissolve * (25 + index * 8))
			GlyphScript.paint_note(_front, point, 17 + index % 2 * 4, side * .2, CYAN if index % 2 else PINK, fade * .7, index % 3)


func _neon_path(points: PackedVector2Array, tint: Color, width := 3.0) -> void:
	_front.stroke_polyline(points, Color(tint, _ears * .07), width + 13, true)
	_front.stroke_polyline(points, Color(tint, _ears * .16), width + 5, true)
	_front.stroke_polyline(points, Color(tint.lerp(WHITE, _pulse * .45), _ears * .95), width, true)


func _ear_shape(side: float, inset: float) -> PackedVector2Array:
	var key := Vector2(side, inset)
	if _ear_paths.has(key):
		return _ear_paths[key]
	var curves := PackedVector2Array([
		Vector2(-62, -65), Vector2(-56, -85),
		Vector2(-55, -91), Vector2(-48, -89),
		Vector2(-28, -84), Vector2(-15, -63),
		Vector2(-26, -44), Vector2(-48, -34)])
	var points := PackedVector2Array([Vector2(-48, -34)])
	for segment in 4:
		var start := points[points.size() - 1]
		var control := curves[segment * 2]
		var finish := curves[segment * 2 + 1]
		for vertex in range(1, 9):
			var t := vertex / 8.0
			points.append(start.lerp(control, t).lerp(control.lerp(finish, t), t))
	var pivot := Vector2(side * 34, -51)
	for index in points.size():
		var point := points[index] * Vector2(-side, 1)
		points[index] = pivot + (point - pivot) * inset
	_ear_paths[key] = points
	return points


func _draw_headphones(twitch: float) -> void:
	var head_transform := Transform2D(_tilt, Vector2.ONE * lerpf(.82, 1.08, _ears), 0, _head + Vector2(0, -28))
	for side in [-1.0, 1.0]:
		var pivot := Vector2(side * 34, -51)
		var turn := Transform2D(side * twitch * .12, Vector2.ZERO)
		turn.origin = pivot - turn.basis_xform(pivot)
		_front.set_shape_transform_matrix(head_transform * turn)
		var outer := _ear_shape(side, 1)
		var inner := _ear_shape(side, .58)
		_front.draw_colored_polygon(outer, Color(PINK, _ears * .1))
		_front.draw_colored_polygon(inner, Color(PINK, _ears * (.22 + _pulse * .12)))
		_neon_path(outer, PINK, 3.2)
		_neon_path(inner, CYAN.lerp(PINK, .6), 2)
	_front.set_shape_transform_matrix(head_transform)
	for band in 2:
		var path := _headband_paths[band]
		var tint := CYAN if band == 0 else CYAN.lerp(WHITE, .45)
		var width := 3.5 if band == 0 else 1.7
		_front.draw_polyline(path, Color(tint, _ears * .07), width + 13, true)
		_front.draw_polyline(path, Color(tint, _ears * .16), width + 5, true)
		_front.draw_polyline(path, Color(tint.lerp(WHITE, _pulse * .45), _ears * .95), width, true)
	_cup_style.bg_color = Color(PINK, _ears * .13)
	_cup_style.border_color = Color(PINK.lerp(WHITE, _pulse * .3), _ears * .95)
	_cup_style.shadow_color = Color(PINK, _ears * .12)
	_pad_style.bg_color = Color(CYAN, _ears * .12)
	_pad_style.border_color = Color(CYAN.lerp(WHITE, .2), _ears * .95)
	_pad_style.shadow_color = Color(CYAN, _ears * .12)
	for side in [-1.0, 1.0]:
		var x: float = side * 53
		_front.draw_style_box(_pad_style, Rect2(Vector2(side * 41 - 6, -8), Vector2(12, 43)))
		_front.draw_style_box(_cup_style, Rect2(Vector2(x - 10, -10), Vector2(20, 41)))
		var connector := PackedVector2Array([Vector2(side * 49, -6), Vector2(side * 54, -6), Vector2(side * 54, 1)])
		_neon_path(connector, CYAN, 2.5)
		var heart := PackedVector2Array()
		for vertex in 33:
			var t := TAU * vertex / 32
			var point := Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)))
			heart.append(Vector2(x, 9) + point * .35)
		_front.draw_colored_polygon(heart, Color(WHITE.lerp(PINK, .25), _ears * (.75 + _pulse * .2)))
	_front.set_shape_transform(Vector2.ZERO)
