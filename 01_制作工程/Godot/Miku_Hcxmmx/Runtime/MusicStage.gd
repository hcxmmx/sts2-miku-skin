extends Node2D

const CanvasScript = preload("res://Miku_Hcxmmx/Runtime/EffectCanvas.gd")

const FloorShader = preload("res://Miku_Hcxmmx/Runtime/StageFloor.gdshader")
const SpectrumShader = preload("res://Miku_Hcxmmx/Runtime/SpectrumBars.gdshader")
const GlyphScript = preload("res://Miku_Hcxmmx/Runtime/ActionEffect.gd")
const CYAN = Color("35e5f2")
const PINK = Color("ff68cf")
const WHITE = Color("dcffff")
const BAR_COUNT = 40
var floor_radius := Vector2(260, 60) * .7
var spectrum_span := floor_radius.x * 2.0
var bands := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
var spectrum_levels := PackedFloat32Array()
var spectrum_heights := PackedFloat32Array()
var activation := 0.0
var emphasis := 0.0
var draw_count := 0
var _time := 0.0
var _glow := Sprite2D.new()
var _floor_glow := Sprite2D.new()
var _note_particles: Array[Dictionary] = []
var _note_views: Array[MeshInstance2D] = []
var _visible_notes := 0
var note_captures: Array[Dictionary] = []
var _note_seeds: Dictionary = {}
var _note_generations: Dictionary = {}
var entrance_time := -1.0
var wave_motion := 0.0
var light_sweep_angle := 0.0
var light_sweep_strength := 0.0
var note_opacity := 1.0
var note_time_offset := 0.0
var note_boost_strength := 0.0
var continuous_time := -1.0
var audio_driver: Node
var audio_clips: Array = []
var _permanent_note_offset := 0.0
var _default_material: Material
var _floor_node := MeshInstance2D.new()
var _floor_material := ShaderMaterial.new()
var _spectrum_node := MultiMeshInstance2D.new()
var _spectrum_material := ShaderMaterial.new()
var _idle_time := -1.0
var _idle_ripples := CanvasScript.new()
var last_draw_usec := 0


func _ready() -> void:
	# Follow the body and action effects so we use this frame's stage parameters.
	process_priority = 1
	set_process(continuous_time >= 0.0)


func configure(glow_path: String) -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	_default_material = additive
	var texture: Texture2D = load(glow_path)
	_glow.texture = texture
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_glow.use_parent_material = true
	_glow.position = Vector2(0, -200)
	_glow.scale = Vector2(540, 470) / texture.get_size()
	add_child(_glow)
	_floor_glow.texture = texture
	_floor_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_floor_glow.use_parent_material = true
	_floor_glow.position = Vector2(0, 4)
	_floor_glow.scale = Vector2(620, 145) * .7 / texture.get_size()
	add_child(_floor_glow)
	_idle_ripples.z_index = 3
	_idle_ripples.use_parent_material = true
	add_child(_idle_ripples)
	_idle_ripples.set_painter(_draw_idle_ripples)
	var random := RandomNumberGenerator.new()
	random.seed = 20261117
	for index in 8:
		var lifetime := random.randf_range(2.2, 3.2)
		_note_particles.append({"lifetime": lifetime, "offset": random.randf_range(0, lifetime)})
	var floor_quad := QuadMesh.new()
	floor_quad.size = floor_radius * Vector2(2.65, 3.1)
	_floor_node.mesh = floor_quad
	_floor_material.shader = FloorShader
	_floor_node.material = _floor_material
	_floor_node.show_behind_parent = true
	_floor_material.set_shader_parameter("radius", floor_radius)
	add_child(_floor_node)
	var bars := MultiMesh.new()
	bars.transform_format = MultiMesh.TRANSFORM_2D
	bars.use_colors = true
	bars.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	bars.mesh = quad
	bars.instance_count = BAR_COUNT
	_spectrum_node.multimesh = bars
	_spectrum_material.shader = SpectrumShader
	_spectrum_node.material = _spectrum_material
	add_child(_spectrum_node)
	spectrum_levels.resize(BAR_COUNT)
	spectrum_heights.resize(BAR_COUNT)
	for index in _note_particles.size() * 3:
		var view := MeshInstance2D.new()
		view.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		view.use_parent_material = true
		view.hide()
		add_child(view)
		_note_views.append(view)
	sample(0, {}, 0, 0)


func sample(time: float, clip: Dictionary, clip_time: float, hit_emphasis: float) -> void:
	_idle_time = -1.0
	_idle_ripples.hide()
	_time = continuous_time + _permanent_note_offset if continuous_time >= 0 else time
	if clip.is_empty() and is_instance_valid(audio_driver) and audio_driver.light.playing:
		for candidate: Dictionary in audio_clips:
			if candidate.id == audio_driver.light_clip_id:
				clip = candidate
				clip_time = audio_driver.light.get_playback_position()
				break
	emphasis = hit_emphasis
	activation = 0.0
	bands.fill(0)
	if not clip.is_empty():
		activation = minf(clip_time / .09, 1) * clampf((float(clip.duration) - clip_time) / .16, 0, 1)
		var position := clampf(clip_time * float(clip.rate), 0, clip.bands.size() - 1)
		var first := int(position)
		var second := mini(first + 1, clip.bands.size() - 1)
		for index in 8:
			bands[index] = lerpf(float(clip.bands[first][index]), float(clip.bands[second][index]), position - first)
	for index in BAR_COUNT:
		var horizontal := index / float(BAR_COUNT - 1) * 2 - 1
		var frequency := absf(horizontal) * 7
		var first := int(frequency)
		var second := mini(first + 1, 7)
		var level := lerpf(bands[first], bands[second], frequency - first)
		var arch := sqrt(maxf(0, 1 - horizontal * horizontal))
		spectrum_levels[index] = level
		spectrum_heights[index] = 12 + activation * (95 + level * 155) * (.25 + arch * .75) + emphasis * 60 * arch
	_glow.modulate = Color(CYAN, .045 + activation * .13 + emphasis * .09)
	_floor_glow.modulate = Color(CYAN, .1 + activation * .1 + emphasis * .16)
	queue_redraw()


func sample_idle(time: float) -> void:
	_idle_time = time
	_idle_ripples.visible = time >= 0
	_idle_ripples.queue_redraw()


func _draw_idle_ripples() -> void:
	if _idle_time < 0:
		return
	var contacts := [Vector2(71, -278), Vector2(71, -266)]
	var times := [.7, 1.0]
	for tap in 2:
		var age := _idle_time - float(times[tap])
		if age < 0 or age > .36:
			continue
		var origin: Vector2 = contacts[tap]
		for echo in 2:
			var life := age - echo * .055
			if life < 0 or life > .3:
				continue
			var progress := life / .3
			var fade := smoothstep(0, .018, life) * pow(1 - progress, 1.15)
			var radius := 4 + (1 - exp(-progress * 3)) * 30
			var points := PackedVector2Array()
			for vertex in 49:
				var angle := vertex * TAU / 48
				points.append(origin + Vector2(cos(angle) * .66, sin(angle)) * radius)
			var tint := CYAN if echo == 0 else PINK
			_idle_ripples.stroke_polyline(points, Color(tint, fade * .18), 9, true)
			_idle_ripples.stroke_polyline(points, Color(tint.lerp(WHITE, .55), fade), 2.3, true)
		var flash := smoothstep(0, .008, age) * (1 - smoothstep(.025, .09, age))
		_idle_ripples.stroke_line(origin - Vector2(4, 0), origin + Vector2(4, 0), Color(WHITE, flash), 2, true)
		_idle_ripples.stroke_line(origin - Vector2(0, 4), origin + Vector2(0, 4), Color(WHITE, flash), 2, true)


func _draw() -> void:
	var start := Time.get_ticks_usec()
	draw_count = 0
	_draw_spectrum()
	_draw_floor()
	if continuous_time < 0.0:
		_update_notes(_note_time(_time))
	draw_count += _visible_notes
	last_draw_usec = Time.get_ticks_usec() - start


func _reveal(delay: float, length: float) -> float:
	return 1.0 if entrance_time < 0 else smoothstep(delay, delay + length, entrance_time)


func _draw_floor() -> void:
	_floor_material.set_shader_parameter("clock", _time)
	_floor_material.set_shader_parameter("activation", activation)
	_floor_material.set_shader_parameter("emphasis", emphasis)
	_floor_material.set_shader_parameter("entrance_time", entrance_time)
	_floor_material.set_shader_parameter("wave_motion", wave_motion)
	_floor_material.set_shader_parameter("sweep_angle", light_sweep_angle)
	_floor_material.set_shader_parameter("sweep_strength", light_sweep_strength)
	_floor_material.set_shader_parameter("music_bands", bands)
	draw_count += 1


func _draw_spectrum() -> void:
	var width := spectrum_span / BAR_COUNT * .72
	var opacity := activation * .64 + emphasis * .18
	var mood := 0.0
	var shader_time := 0.0
	var shutdown := -1.0
	if material is ShaderMaterial:
		var path: String = material.shader.resource_path
		if path.ends_with("StageNoise.gdshader"):
			mood = float(material.get_shader_parameter("mood"))
			shader_time = float(material.get_shader_parameter("effect_time"))
		elif path.ends_with("StageShutdown.gdshader"):
			shutdown = float(material.get_shader_parameter("effect_time"))
	for target_material: ShaderMaterial in [_spectrum_material, _floor_material]:
		target_material.set_shader_parameter("mood", mood)
		target_material.set_shader_parameter("effect_time", shader_time)
		target_material.set_shader_parameter("shutdown_time", shutdown)
	var bars := _spectrum_node.multimesh
	for index in BAR_COUNT:
		var horizontal := index / float(BAR_COUNT - 1) * 2 - 1
		var arch := sqrt(maxf(0, 1 - horizontal * horizontal))
		var build := _reveal(.23 + absf(horizontal) * .24, .12)
		var base := Vector2(horizontal * spectrum_span / 2, -23 - arch * 45)
		var height := maxf(.01, spectrum_heights[index] * build)
		var level: float = spectrum_levels[index]
		var tint := CYAN.lerp(PINK, pow(absf(horizontal), 2.5) * .9)
		var alpha := (.055 + opacity * (.6 + level * .4)) * build
		bars.set_instance_transform_2d(index, Transform2D(0, Vector2(width * 3.2, height), 0, base - Vector2(0, height / 2)))
		bars.set_instance_color(index, Color(tint, alpha))
		bars.set_instance_custom_data(index, Color(width, height, .4 + emphasis * .55, 0))
	draw_count += 1


func prepare_note_captures(attacks: Array) -> void:
	note_captures.clear()
	var random := RandomNumberGenerator.new()
	random.seed = 17429
	for start in attacks:
		var candidates: Array[Dictionary] = []
		for index in _note_particles.size():
			var note := _note_at(index, float(start))
			if not note.is_empty() and float(note.alpha) > .1:
				candidates.append(note)
		if candidates.is_empty():
			note_captures.append({"start": float(start), "note": {}})
		else:
			var note: Dictionary = candidates[random.randi_range(0, candidates.size() - 1)]
			note_captures.append({"start": float(start), "note": note})


func _note_at(index: int, time: float) -> Dictionary:
	var particle: Dictionary = _note_particles[index]
	var age := time + float(particle.offset)
	var generation := 0
	for capture: Dictionary in note_captures:
		if capture.note.is_empty() or int(capture.note.index) != index or time < float(capture.start):
			continue
		var respawn := float(capture.start) + .32
		if time < respawn:
			return {}
		age = time - respawn
		generation = int(capture.get("generation", generation + 1))
	var cycle := floori(age / float(particle.lifetime))
	var life := fposmod(age, float(particle.lifetime)) / float(particle.lifetime)
	var seed_key := Vector2i(cycle, generation)
	if not _note_seeds.has(index) or _note_seeds[index].key != seed_key:
		var random := RandomNumberGenerator.new()
		random.seed = (index + 1) * 24137 + cycle * 1093 + generation * 7919
		_note_seeds[index] = {"key": seed_key, "x": random.randf_range(120, 200),
			"sway": random.randf_range(-15, 15), "size": random.randf_range(23, 33),
			"angle": random.randf_range(-.3, .3), "variant": random.randi_range(0, 2)}
	var seed: Dictionary = _note_seeds[index]
	var side := -1.0 if index % 2 == 0 else 1.0
	var x := side * float(seed.x) + sin(life * PI) * float(seed.sway)
	return {
		"index": index, "point": Vector2(x, -30 - life * 310),
		"size": seed.size,
		"angle": float(seed.angle) + sin(life * PI) * .12,
		"variant": seed.variant,
		"tint": PINK if index % 3 == 0 else CYAN.lerp(WHITE, .55),
		"alpha": minf(minf(life / .12, (1 - life) / .18), 1) * .75,
	}


func _process(_delta: float) -> void:
	_update_notes(_note_time(_time))


func _update_notes(time: float) -> void:
	_visible_notes = 0
	for index in _note_particles.size():
		var first_view := index * 3
		var note := _note_at(index, time)
		var reveal := _reveal(.46 + index * .015, .2)
		var alpha := float(note.get("alpha", 0.0)) * (.55 + activation * .22) / .75 * reveal * note_opacity
		if alpha <= .003:
			for offset in 3:
				_note_views[first_view + offset].hide()
			continue
		var point: Vector2 = note.point * lerpf(.7, 1, reveal)
		point.x += signf(point.x) * note_boost_strength * 5
		var tint: Color = note.tint
		for echo in 2:
			var echo_alpha := alpha * note_boost_strength * .1 / (echo + 1)
			if echo_alpha > .003:
				var previous := point + Vector2(-signf(point.x) * (echo + 1) * 2, (echo + 1) * 12)
				_place_note(first_view + echo, note, previous, Color(tint, echo_alpha))
			else:
				_note_views[first_view + echo].hide()
		_place_note(first_view + 2, note, point, Color(tint.lerp(WHITE, minf(note_boost_strength * .2, .45)), alpha))


func _place_note(index: int, note: Dictionary, point: Vector2, tint: Color) -> void:
	var view := _note_views[index]
	var mesh := GlyphScript.note_mesh(int(note.variant))
	if view.mesh != mesh:
		view.mesh = mesh
	view.transform = Transform2D(float(note.angle), Vector2.ONE * float(note.size), 0.0, point)
	view.self_modulate = tint
	view.show()
	_visible_notes += 1


func notes_at(time: float) -> Array[Dictionary]:
	time = _note_time(time)
	var notes: Array[Dictionary] = []
	for index in _note_particles.size():
		var note := _note_at(index, time)
		if not note.is_empty():
			notes.append(note)
	return notes


func _note_time(preview_time: float) -> float:
	var clock := continuous_time + _permanent_note_offset if continuous_time >= 0 else preview_time
	return clock + note_time_offset


func commit_note_motion() -> void:
	_permanent_note_offset += note_time_offset
	note_time_offset = 0


func reset_action_state() -> void:
	material = _default_material
	modulate = Color.WHITE
	entrance_time = -1
	wave_motion = 0
	light_sweep_angle = 0
	light_sweep_strength = 0
	note_opacity = 1
	note_time_offset = 0
	note_boost_strength = 0


func reset_for_combat() -> void:
	continuous_time = 0
	set_process(true)
	_permanent_note_offset = 0
	note_captures.clear()
	_note_generations.clear()
	_note_seeds.clear()
	reset_action_state()


func capture_note() -> Dictionary:
	var time := _note_time(0)
	var candidates: Array[Dictionary] = []
	for note: Dictionary in notes_at(time):
		if float(note.alpha) > .1:
			candidates.append(note)
	if candidates.is_empty():
		return {}
	var note: Dictionary = candidates.pick_random()
	var index := int(note.index)
	_note_generations[index] = int(_note_generations.get(index, 0)) + 1
	# Runtime only needs the latest capture for each note. Preview timelines retain history.
	note_captures = note_captures.filter(func(capture: Dictionary): return int(capture.note.get("index", -1)) != index)
	note_captures.append({"start": time, "note": note, "generation": _note_generations[index]})
	return note
