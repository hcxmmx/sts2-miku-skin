extends Node2D

const CanvasScript = preload("res://Miku_Hcxmmx/Runtime/EffectCanvas.gd")

static var _note_meshes: Dictionary = {}
static var _white_texture: GradientTexture2D

const BurstShader = preload("res://Miku_Hcxmmx/Runtime/MusicBurst.gdshader")
const CYAN = Color("29ddf5")
const PINK = Color("ff55ba")
const GOLD = Color("ffe7a3")
const WHITE = Color("eaffff")
var profile: Dictionary = {}
var phase := "准备"
var target_flash := 0.0
var target_recoil := Vector2.ZERO
var _back := CanvasScript.new()
var _front := CanvasScript.new()
var _glows: Array[Sprite2D] = []
var _bursts: Array[Sprite2D] = []
var _time := -1.0
var _target := Vector2.ZERO
var _target_enabled := true
var _draw_count := 0
var music_bands := PackedFloat32Array()
var projectile_note: Dictionary = {}


func configure(data: Dictionary) -> void:
	profile = data
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	_front.z_index = 3
	_back.use_parent_material = true
	_front.use_parent_material = true
	add_child(_back)
	add_child(_front)
	_back.set_painter(_draw_back)
	_front.set_painter(_draw_front)
	var glow: Texture2D = load(profile.textures.glow)
	for index in 4:
		_glows.append(_sprite(glow, _front))
	if _white_texture == null:
		_white_texture = GradientTexture2D.new()
		_white_texture.width = 128
		_white_texture.height = 128
		_white_texture.gradient = Gradient.new()
		_white_texture.gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	for index in 4:
		var layer := _front if profile.kind == "light" else _back
		var sprite := _sprite(_white_texture, layer)
		sprite.use_parent_material = false
		var burst_material := ShaderMaterial.new()
		burst_material.shader = BurstShader
		burst_material.set_shader_parameter("seed", float(index) * 1.73 + .4)
		sprite.material = burst_material
		_bursts.append(sprite)
	sample(-1, Vector2.ZERO, true)


func _sprite(texture: Texture2D, layer: Node2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.use_parent_material = true
	layer.add_child(sprite)
	return sprite


func _place(sprite: Sprite2D, point: Vector2, size: Vector2, angle: float, alpha: float, tint: Color) -> void:
	sprite.position = point
	sprite.scale = size / sprite.texture.get_size()
	sprite.rotation = angle
	sprite.modulate = Color(tint, clampf(alpha, 0, 1))
	sprite.visible = alpha > .001
	if sprite.visible:
		_draw_count += 1


func _burst(index: int, point: Vector2, size: Vector2, age: float, duration: float, tint: Color, angle := 0.0) -> void:
	if age < 0 or age >= duration:
		return
	var progress := age / duration
	var hold: float = profile.get("readable_hold", 0.0)
	var expansion := lerpf(.65, 1.15, 1 - exp(-progress * 18))
	if hold > 0:
		progress = maxf(0, age - hold) / maxf(.01, duration - hold)
		expansion = lerpf(.65, 1.15, 1 - exp(-age * 60))
	_place(_bursts[index], point, size * expansion, angle, minf(age / .012, 1), Color.WHITE)
	_bursts[index].material.set_shader_parameter("progress", progress)
	_bursts[index].material.set_shader_parameter("edge_color", tint)


func _pulse(age: float, duration: float) -> float:
	if age < 0 or age >= duration:
		return 0.0
	return minf(age / .015, 1) * pow(1 - age / duration, 1.7)


func sample(time: float, target: Vector2, target_enabled: bool) -> void:
	_time = time
	_target = target
	_target_enabled = target_enabled
	_draw_count = 0
	target_flash = 0.0
	target_recoil = Vector2.ZERO
	phase = "准备"
	for sprite: Sprite2D in _bursts + _glows:
		sprite.hide()
	if _active():
		var age := _time - float(profile.hit)
		phase = "起势" if age < 0 else "爆发"
		match profile.kind:
			"light":
				if _target_enabled and age >= 0:
					var direction := (_target - Vector2(profile.origin[0], profile.origin[1])).normalized()
					var impact_duration: float = profile.get("impact_duration", .23)
					_burst(0, _target, Vector2(250, 175), age, impact_duration, CYAN, direction.angle())
					_burst(1, _target, Vector2(190, 145), age - .025, impact_duration - .05, PINK, direction.angle() + .5)
					var pulse := _pulse(age, .22)
					_place(_glows[0], _target, Vector2(210, 140), 0, pulse * .75, CYAN)
					_place(_glows[1], _target, Vector2.ONE * 68, 0, pulse, WHITE)
					target_flash = _pulse(age, .07)
					target_recoil = direction * _pulse(age, .12) * 18
			"gesture":
				_burst(0, Vector2(40, -280), Vector2(260, 220), age, .3, CYAN, -.35)
				_place(_glows[0], Vector2(35, -275), Vector2.ONE * 210, 0, _pulse(age, .35) * .7, CYAN)
			"step":
				for index in 2:
					var beat_age := age - index * .3
					_place(_glows[index], Vector2(0, -12), Vector2(290, 50), 0, _pulse(beat_age, .28) * .75, CYAN if index == 0 else PINK)
			"spin":
				_burst(0, Vector2(0, -175), Vector2(380, 410), age, .34, CYAN, -.2)
				_place(_glows[0], Vector2(0, -180), Vector2(230, 330), 0, _pulse(age, .3) * .55, CYAN)
			"celebrate":
				for index in 2:
					var side := -1.0 if index == 0 else 1.0
					_burst(index, Vector2(side * 95, -20), Vector2(240, 115), age, .22, CYAN if index == 0 else PINK)
					_burst(index + 2, Vector2(side * 150, -270), Vector2.ONE * 145, age - .1, .24, CYAN if index == 0 else GOLD)
					_place(_glows[index], Vector2(side * 100, -70), Vector2(170, 220), 0, _pulse(age, .27) * .65, CYAN if index == 0 else PINK)
	_back.queue_redraw()
	_front.queue_redraw()


func _active() -> bool:
	return _time >= 0 and _time < float(profile.duration)


func _ribbon(canvas: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() < 2 or color.a < .003:
		return
	var outline := PackedVector2Array()
	var opposite := PackedVector2Array()
	for index in points.size():
		var previous := points[maxi(0, index - 1)]
		var following := points[mini(points.size() - 1, index + 1)]
		var normal := (following - previous).normalized().orthogonal()
		var taper := pow(sin(PI * (index + .5) / points.size()), .7)
		outline.append(points[index] + normal * width * taper)
		opposite.append(points[index] - normal * width * taper)
	opposite.reverse()
	outline.append_array(opposite)
	canvas.draw_colored_polygon(outline, color)
	canvas.stroke_polyline(points, Color(WHITE, color.a * .8), maxf(1.0, width * .2), true)
	_draw_count += 1


func _note(canvas: Node2D, point: Vector2, size: float, angle: float, tint: Color, alpha: float) -> void:
	paint_note(canvas, point, size, angle, tint, alpha)
	if alpha > .003:
		_draw_count += 1


static func paint_note(canvas: Node2D, point: Vector2, size: float, angle: float, tint: Color, alpha: float, variant := 1) -> void:
	if alpha <= .003:
		return
	if canvas is CanvasScript:
		canvas.set_shape_transform(Vector2.ZERO)
	else:
		canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_mesh(note_mesh(variant), null, Transform2D(angle, Vector2.ONE * size, 0, point), Color(tint, alpha))


static func note_mesh(variant: int) -> ArrayMesh:
	if not _note_meshes.has(variant):
		_note_meshes[variant] = _make_note_mesh(variant)
	return _note_meshes[variant]


static func _note_polygon(vertices: Array[Vector2], indices: Array[int], points: PackedVector2Array) -> void:
	var offset := vertices.size()
	for point: Vector2 in points:
		vertices.append(point)
	for index: int in Geometry2D.triangulate_polygon(points):
		indices.append(offset + index)


static func _make_note_mesh(variant: int) -> ArrayMesh:
	var vertices: Array[Vector2] = []
	var indices: Array[int] = []
	var head := PackedVector2Array()
	for index in 16:
		var angle := TAU * index / 16
		head.append(Vector2(-.15, 0) + Vector2(cos(angle) * .32, sin(angle) * .22).rotated(-.3))
	_note_polygon(vertices, indices, head)
	_note_polygon(vertices, indices, PackedVector2Array([Vector2(.06, -1.05), Vector2(.2, -1.05), Vector2(.2, -.01), Vector2(.06, -.01)]))
	if variant == 1:
		_note_polygon(vertices, indices, PackedVector2Array([
			Vector2(.18, -1.05), Vector2(.68, -.73), Vector2(.64, -.42),
			Vector2(.52, -.41), Vector2(.46, -.66), Vector2(.18, -.77)]))
	elif variant == 2:
		var second_head := PackedVector2Array()
		for point: Vector2 in head:
			second_head.append(point + Vector2(.7, -.12))
		_note_polygon(vertices, indices, second_head)
		_note_polygon(vertices, indices, PackedVector2Array([Vector2(.76, -1.17), Vector2(.9, -1.17), Vector2(.9, -.13), Vector2(.76, -.13)]))
		_note_polygon(vertices, indices, PackedVector2Array([Vector2(.06, -1.05), Vector2(.9, -1.17), Vector2(.9, -1.02), Vector2(.06, -.9)]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array(vertices)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _chip(canvas: Node2D, point: Vector2, size: Vector2, angle: float, tint: Color, alpha: float) -> void:
	if alpha <= .003:
		return
	canvas.set_shape_transform(point, angle)
	canvas.fill_rect(Rect2(-size / 2, size), Color(tint, alpha))
	canvas.set_shape_transform(Vector2.ZERO)
	_draw_count += 1


func _floor_pulse(canvas: Node2D, age: float, radius: float, tint: Color) -> void:
	var fade := _pulse(age, .28)
	if fade <= .003:
		return
	var spread := 1 - exp(-age * 23)
	var points := PackedVector2Array()
	for index in 48:
		var angle := TAU * index / 48
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * .22) * spread + Vector2(0, -5))
	canvas.draw_colored_polygon(points, Color(tint, fade * .18))
	canvas.stroke_polyline(points, Color(tint, fade * .8), 5 * (1 - spread) + 1, true)
	_draw_count += 1


func _draw_back() -> void:
	if not _active():
		return
	var age := _time - float(profile.hit)
	match profile.kind:
		"gesture":
			_draw_score_fan(_back, age)
		"step":
			_floor_pulse(_back, age, 150, CYAN)
			_floor_pulse(_back, age - .3, 180, PINK)
		"spin":
			_floor_pulse(_back, age + .08, 185, CYAN)
			_draw_spin(_back, false)
		"celebrate":
			_draw_cannons(_back, age)


func _draw_front() -> void:
	if not _active():
		return
	var age := _time - float(profile.hit)
	match profile.kind:
		"light":
			_draw_attack(age)
		"gesture":
			_draw_score_shards(_front, age)
		"step":
			_draw_equalizer(age)
		"spin":
			_draw_spin(_front, true)
			_draw_spectrum_burst(age)
		"celebrate":
			_draw_confetti(age)


func _draw_attack(age: float) -> void:
	var origin := Vector2(profile.origin[0], profile.origin[1])
	var direction := (_target - origin).normalized()
	var normal := direction.orthogonal()
	var release: float = profile.release
	var hit: float = profile.hit
	if _time >= release and _time < hit:
		var travel := (_time - release) / (hit - release)
		var head := origin.lerp(_target, pow(travel, .65))
		var tail := head - direction * minf(origin.distance_to(head), 155)
		for staff in 5:
			var offset := normal * (staff - 2) * 8
			var width := 3.0
			if music_bands.size() == 8:
				width = 2.8 + music_bands[staff + 1] * 1.7
			_ribbon(_front, PackedVector2Array([tail + offset, tail.lerp(head, .7) + offset * .7, head]), Color(CYAN if staff % 2 else WHITE, .85), width)
		if not projectile_note.is_empty():
			var tint: Color = projectile_note.tint
			paint_note(_front, head, 30, -.1, tint.lerp(WHITE, .45), 1, int(projectile_note.variant))
	var tail_duration: float = profile.get("impact_duration", .23) + .04
	if not _target_enabled or age < 0 or age >= tail_duration:
		return
	var hold: float = profile.get("readable_hold", 0.0)
	var fade := pow(1 - maxf(0, age - hold) / (tail_duration - hold), 1.5)
	var expansion := 1 - exp(-age * 32)
	for index in 19:
		var angle := direction.angle() + index * 2.39996
		var speed := 80 + index % 5 * 22
		var spoke := Vector2.RIGHT.rotated(angle)
		var point := _target + spoke * (14 + expansion * speed)
		_chip(_front, point, Vector2(24 - age * 50, 4 + index % 3), angle, WHITE if index % 3 == 0 else CYAN, fade)
	for index in 5:
		var angle := -.9 + index * .55
		var point := _target + Vector2.RIGHT.rotated(angle) * (35 + expansion * (75 + index * 11))
		_note(_front, point, 20 + index % 2 * 12, angle + age * 5, CYAN if index % 2 else PINK, fade)


func _draw_score_fan(canvas: Node2D, age: float) -> void:
	if age < 0 or age >= .38:
		return
	var progress := 1 - exp(-age * 27)
	var fade := pow(1 - age / .38, 1.3)
	var center := Vector2(5, -240)
	for band in 5:
		var points := PackedVector2Array()
		for index in 38:
			var amount := index / 37.0
			var angle := -2.85 + amount * 2.9 * progress
			var radius := 115 + band * 17
			points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * .72))
		_ribbon(canvas, points, Color(CYAN if band % 2 == 0 else PINK, fade * .8), 3.5 + band * .4)
	for index in 24:
		var angle := -2.85 + index / 23.0 * 2.9 * progress
		var radial := Vector2(cos(angle), sin(angle) * .72)
		var point := center + radial * 185
		var height := (20 + absf(sin(index * 2.3)) * 38) * progress
		_chip(canvas, point, Vector2(height, 7), radial.angle(), CYAN if index % 3 else WHITE, fade * .7)


func _draw_score_shards(canvas: Node2D, age: float) -> void:
	if age < 0 or age >= .5:
		return
	var fade := pow(1 - age / .5, 1.7)
	var spread := 1 - exp(-age * 20)
	for index in 8:
		var angle := -2.7 + index * .4
		var point := Vector2(15, -250) + Vector2(cos(angle) * 165, sin(angle) * 125) * spread
		_note(canvas, point, 28 + index % 3 * 9, -.2 + index * .16 + age * 2, WHITE if index % 3 == 0 else CYAN, fade)
	for index in 24:
		var angle := index * 2.39996
		var point := Vector2(35, -280) + Vector2.RIGHT.rotated(angle) * (35 + spread * (75 + index % 4 * 20))
		_chip(canvas, point, Vector2(8 + index % 4 * 3, 3), angle, PINK if index % 3 == 0 else CYAN, fade * .7)


func _draw_equalizer(age: float) -> void:
	for beat in 2:
		var beat_age := age - beat * .3
		var envelope := _pulse(beat_age, .32)
		if envelope <= .003:
			continue
		for index in 19:
			var x := (index - 9) * 12.0
			var height := (28 + pow(absf(sin(index * 1.9 + beat)), 1.5) * 100) * envelope
			var tint := CYAN if index % 4 else PINK
			for segment in ceili(height / 12):
				_chip(_front, Vector2(x, -16 - segment * 12), Vector2(8, 8), 0, WHITE if segment * 12 > height - 15 else tint, envelope)
		for index in 5:
			var point := Vector2((index - 2) * 55, -60 - beat_age * (170 + index * 25))
			_note(_front, point, 22 + index % 2 * 8, -.3 + index * .15, CYAN if index % 2 else PINK, envelope)


func _draw_spin(canvas: Node2D, front: bool) -> void:
	if _time < .04 or _time >= .57:
		return
	var age := _time - .04
	var envelope := minf(age / .04, 1) * clampf((.57 - _time) / .18, 0, 1)
	for ribbon in 2:
		var points := PackedVector2Array()
		for index in 81:
			var amount := index / 80.0
			var angle := age * 28 + amount * TAU * 1.3 + ribbon * PI
			if (sin(angle) > 0) != front:
				_ribbon(canvas, points, Color(CYAN if ribbon == 0 else PINK, envelope * .75), 7)
				points.clear()
				continue
			points.append(Vector2(cos(angle) * (125 - amount * 48), -20 - amount * 290))
		_ribbon(canvas, points, Color(CYAN if ribbon == 0 else PINK, envelope * .75), 7)


func _draw_spectrum_burst(age: float) -> void:
	if age < 0 or age >= .42:
		return
	var envelope := pow(1 - age / .42, 1.8)
	var spread := 1 - exp(-age * 24)
	for index in 26:
		var angle := index * TAU / 26
		var radial := Vector2(cos(angle), sin(angle) * .5)
		var point := Vector2(0, -150) + radial * (65 + spread * 115)
		_chip(_front, point, Vector2(6, 20 + index % 4 * 9), angle + PI / 2, CYAN if index % 3 else PINK, envelope)
	for index in 6:
		var angle := index * TAU / 6 - PI / 2
		var point := Vector2(0, -150) + Vector2(cos(angle) * 130, sin(angle) * 165) * spread
		_note(_front, point, 31, angle * .2, WHITE if index % 2 == 0 else CYAN, envelope)


func _draw_cannons(canvas: Node2D, age: float) -> void:
	var pulse := _pulse(age, .2)
	if pulse <= .003:
		return
	for side in [-1.0, 1.0]:
		var base := Vector2(side * 85, -10)
		var polygon := PackedVector2Array([base + Vector2(side * -12, 0), base + Vector2(side * -35, -280), base + Vector2(side * 140, -260), base + Vector2(side * 12, 0)])
		canvas.draw_colored_polygon(polygon, Color(CYAN if side < 0 else PINK, pulse * .22))
		_draw_count += 1


func _draw_confetti(age: float) -> void:
	if age < 0 or age >= .95:
		return
	var fade := pow(1 - age / .95, 1.5)
	for index in 52:
		var delay := index % 4 * .009
		var life := age - delay
		if life < 0:
			continue
		var side := -1.0 if index % 2 == 0 else 1.0
		var speed := 65 + (index * 37) % 180
		var upward := 700 + (index * 29) % 350
		var point := Vector2(side * (85 + speed * life), -12 - upward * life + 750 * life * life)
		var tint := CYAN if index % 3 == 0 else (PINK if index % 3 == 1 else GOLD)
		_chip(_front, point, Vector2(5 + index % 4 * 2, 12 + index % 3 * 4), index + life * (8 + index % 5), tint, fade)
	for index in 10:
		var side := -1.0 if index % 2 == 0 else 1.0
		var point := Vector2(side * (60 + age * (90 + index * 12)), -120 - age * (500 + index * 20) + age * age * 350)
		_note(_front, point, 32 + index % 3 * 9, side * (.2 + age * 2), WHITE if index % 3 == 0 else (CYAN if side < 0 else PINK), fade)


func marker_visible() -> bool:
	return false


func visible_draw_count() -> int:
	return _draw_count if visible and _active() else 0
