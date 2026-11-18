extends "res://Miku_Hcxmmx/Runtime/StageCastEffect.gd"

var _tube_styles: Array[StyleBoxFlat] = []
var _grip_styles: Array[StyleBoxFlat] = []


func configure(data: Dictionary) -> void:
	super.configure(data)
	_glow.position = Vector2(85, -180)
	_glow.scale = Vector2(250, 285) / _glow.texture.get_size()
	for index in 2:
		var tube := StyleBoxFlat.new()
		tube.set_corner_radius_all(11)
		tube.set_border_width_all(2)
		tube.anti_aliasing = true
		tube.shadow_size = 10
		_tube_styles.append(tube)
		var grip := StyleBoxFlat.new()
		grip.set_corner_radius_all(5)
		grip.set_border_width_all(2)
		grip.anti_aliasing = true
		_grip_styles.append(grip)


func sample(time: float, target: Vector2, target_enabled: bool) -> void:
	super.sample(time, target, target_enabled)
	phase = "应援棒交叉架起" if _time < float(profile.hit) else ("承力回弹" if _pulse > .05 else "应援光点散开")


func _draw_front() -> void:
	var enter := smoothstep(.015, .17, _time)
	var leave := smoothstep(.65, .96, _time)
	var fade := enter * (1 - leave)
	if fade < .003:
		return
	var age := _time - float(profile.hit)
	var bounce := sin(maxf(age, 0) * 32) * exp(-maxf(age, 0) * 12) * smoothstep(.035, .06, age)
	var center := Vector2(85 - _pulse * 12 + bounce * 4, -178 + _pulse * 3)
	for index in 2:
		_draw_baton(index, center, enter, leave, fade, age)
	if age >= 0 and age < .4:
		var impact := smoothstep(0, .015, age) * (1 - smoothstep(.08, .3, age))
		var star := PackedVector2Array()
		for vertex in 8:
			var radius := (33.0 if vertex % 2 == 0 else 4.0) * (.8 + impact * .2)
			star.append(center + Vector2.RIGHT.rotated(vertex * PI / 4 + .12) * radius)
		_front.draw_colored_polygon(star, Color(WHITE, impact))
		for index in 9:
			var angle := index * 2.39996
			var direction := Vector2.RIGHT.rotated(angle)
			var point := center + direction * (16 + age * (120 + index % 3 * 45))
			_front.stroke_line(point, point + direction * (7 + index % 3 * 4), Color(CYAN if index % 2 else PINK, impact * .85), 2.5, true)
	if leave > .01:
		for index in 10:
			var side := -1.0 if index % 2 == 0 else 1.0
			var point := center + Vector2(side * (25 + leave * (80 + index * 6)), -30 - leave * (30 + index % 4 * 25))
			var alpha := sin(leave * PI) * .7
			if index % 3 == 0:
				GlyphScript.paint_note(_front, point, 17, side * .2, CYAN if index % 2 else PINK, alpha, index % 3)
			else:
				_front.fill_circle(point, 2 + index % 3, Color(WHITE, alpha), true, -1, true)


func _draw_baton(index: int, center: Vector2, enter: float, leave: float, fade: float, age: float) -> void:
	var side := -1.0 if index == 0 else 1.0
	var tint := CYAN if index == 0 else PINK
	var position := center + Vector2(side * (1 - enter) * 175 + side * leave * 48, (1 - enter) * 70 - leave * 12)
	var angle := side * (.62 + (1 - enter) * .35 + leave * .32 + _pulse * .025)
	_front.set_shape_transform(position, angle)
	var tube := _tube_styles[index]
	tube.bg_color = Color(tint, fade * (.24 + _pulse * .15))
	tube.border_color = Color(tint.lerp(WHITE, .4 + _pulse * .35), fade * .95)
	tube.shadow_color = Color(tint, fade * .18)
	_front.draw_style_box(tube, Rect2(-12, -148, 24, 181))
	_front.stroke_line(Vector2(0, -134), Vector2(0, 20), Color(WHITE, fade * (.42 + _pulse * .25)), 7, true)
	_front.stroke_line(Vector2(-6, -131), Vector2(-6, 18), Color(WHITE, fade * .45), 1.5, true)
	var grip := _grip_styles[index]
	grip.bg_color = Color(tint, fade * .07)
	grip.border_color = Color(tint.lerp(WHITE, .25), fade * .85)
	_front.draw_style_box(grip, Rect2(-10, 37, 20, 62))
	_front.draw_style_box(grip, Rect2(-19, 29, 38, 10))
	for ridge in 3:
		var y := 77.0 + ridge * 6
		_front.stroke_line(Vector2(-6, y), Vector2(6, y), Color(tint, fade * .65), 1.5, true)
	_front.draw_string(ThemeDB.fallback_font, Vector2(-8, 65), "39", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(WHITE, fade * .85))
	if age >= 0 and age < .29:
		var travel := clampf(age / .19, 0, 1)
		var alpha := smoothstep(0, .02, age) * (1 - smoothstep(.13, .29, age)) * fade
		for direction in [-1.0, 1.0]:
			var y: float = direction * travel * (140 if direction < 0 else 87)
			_front.stroke_line(Vector2(-13, y), Vector2(13, y), Color(tint, alpha * .18), 17, true)
			_front.stroke_line(Vector2(-11, y), Vector2(11, y), Color(WHITE, alpha), 5, true)
	_front.set_shape_transform(Vector2.ZERO)
