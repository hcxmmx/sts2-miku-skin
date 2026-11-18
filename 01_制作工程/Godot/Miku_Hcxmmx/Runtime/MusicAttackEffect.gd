extends Node2D

const CanvasScript = preload("res://Miku_Hcxmmx/Runtime/EffectCanvas.gd")

const HitScript = preload("res://Miku_Hcxmmx/Runtime/ActionEffect.gd")
const StageScript = preload("res://Miku_Hcxmmx/Runtime/MusicStage.gd")
const StageAccess = preload("res://Miku_Hcxmmx/Runtime/StageAccess.gd")
var profile: Dictionary = {}
var phase := "常驻待机"
var target_flash := 0.0
var target_recoil := Vector2.ZERO
var active_clip_id := ""
var active_clip_index := -1
var music_state := "常驻待机"
var music_stage: Node2D
var hits: Array[Node2D] = []
var _gather := CanvasScript.new()
var _gather_age := -1.0
var _gather_note: Dictionary = {}
var _runtime_note: Dictionary = {}


func configure(data: Dictionary) -> void:
	profile = data
	music_stage = StageAccess.acquire(self, profile.hit_profile.textures.glow)
	if profile.get("runtime_live", false):
		_runtime_note = music_stage.capture_note()
	else:
		music_stage.prepare_note_captures(profile.attacks)
	for index in (1 if profile.get("runtime_live", false) else 2):
		var hit := HitScript.new()
		add_child(hit)
		hit.configure(profile.hit_profile)
		hits.append(hit)
	_gather.z_index = 3
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_gather.material = additive
	add_child(_gather)
	_gather.set_painter(_draw_gather)
	sample(0, Vector2.ZERO, true)


func restart() -> void:
	if profile.get("runtime_live", false):
		_runtime_note = music_stage.capture_note()
	else:
		music_stage.prepare_note_captures(profile.attacks)

func sample(time: float, target: Vector2, target_enabled: bool) -> void:
	var clip: Dictionary = {}
	var clip_time := 0.0
	active_clip_id = ""
	active_clip_index = -1
	for index in profile.clips.size():
		var candidate: Dictionary = profile.clips[index]
		var age := time - float(candidate.start)
		if age >= 0 and age < float(candidate.duration):
			clip = candidate
			clip_time = age
			active_clip_id = candidate.id
			active_clip_index = index
	var emphasis := 0.0
	var hit_count := 0
	for contact: float in profile.hit_events:
		var age := time - contact
		if age >= 0:
			hit_count += 1
		if age >= 0 and age < .32:
			emphasis = maxf(emphasis, 1 - pow(maxf(0, age - .075) / .245, 1.4))
	music_stage.sample(maxf(0, time), clip, clip_time, emphasis)
	_gather_age = -1.0
	_gather_note = {}
	for hit: Node2D in hits:
		hit.sample(-1, target, target_enabled)
		hit.music_bands = music_stage.bands
		hit.projectile_note = {}
	for index in profile.attacks.size():
		var age := time - float(profile.attacks[index])
		var note: Dictionary = _runtime_note if profile.get("runtime_live", false) else music_stage.note_captures[index].note
		if age >= 0 and age < float(profile.hit_profile.release) + .09:
			_gather_age = age
			_gather_note = note
		if age >= 0 and age < float(profile.hit_profile.duration):
			hits[index % hits.size()].projectile_note = note
			hits[index % hits.size()].sample(age, target, target_enabled)
	target_flash = 0.0
	target_recoil = Vector2.ZERO
	for hit: Node2D in hits:
		target_flash = maxf(target_flash, hit.target_flash)
		if hit.target_recoil.length_squared() > target_recoil.length_squared():
			target_recoil = hit.target_recoil
	if active_clip_index >= 0:
		music_state = "片段 %d 播放 · 已命中 %d 次" % [active_clip_index + 1, hit_count]
	else:
		music_state = "常驻待机" if time < float(profile.clips[0].start) else "片段结束 · 常驻舞台"
	phase = music_state
	_gather.queue_redraw()


func _gather_point(start: Vector2, finish: Vector2, progress: float) -> Vector2:
	var control := start.lerp(finish, .45) + Vector2(0, -55)
	var weight := smoothstep(0, 1, progress)
	return start.lerp(control, weight).lerp(control.lerp(finish, weight), weight)


func _draw_gather() -> void:
	if _gather_age < 0 or _gather_note.is_empty():
		return
	var release := float(profile.hit_profile.release)
	var arrival := release - .015
	var progress := clampf(_gather_age / arrival, 0, 1)
	var start: Vector2 = _gather_note.point
	var finish := Vector2(profile.hit_profile.origin[0], profile.hit_profile.origin[1])
	var point := _gather_point(start, finish, progress)
	var tint: Color = _gather_note.tint
	if _gather_age < release:
		var tail := PackedVector2Array()
		for index in 13:
			var previous := clampf((_gather_age - .04 + index / 12.0 * .04) / arrival, 0, 1)
			tail.append(_gather_point(start, finish, previous))
		_gather.stroke_polyline(tail, Color(tint, .18), 16, true)
		_gather.stroke_polyline(tail, Color(tint.lerp(Color.WHITE, .5), .95), 3.5, true)
		var source_flash := pow(clampf(1 - _gather_age / .055, 0, 1), 1.5)
		for layer in 6:
			var radius := 48 - layer * 6
			_gather.fill_circle(start + Vector2(0, -12), radius, Color(tint, source_flash * .055), true, -1, true)
			_gather.fill_circle(point + Vector2(0, -12), radius * .8, Color(tint, .045 + progress * .015), true, -1, true)
		HitScript.paint_note(_gather, point, lerpf(float(_gather_note.size) * 1.3, 34, progress),
			lerpf(float(_gather_note.angle), -.1, progress), tint.lerp(Color.WHITE, .7),
			1.0, int(_gather_note.variant))
	var flash_age := _gather_age - arrival
	if flash_age >= 0 and flash_age < .09:
		var flash := minf(flash_age / .008, 1) * pow(1 - flash_age / .09, 1.3)
		var center := finish + Vector2(0, -10)
		for layer in 6:
			_gather.fill_circle(center, (60 - layer * 8) * (.8 + flash * .2), Color(tint, flash * .07), true, -1, true)
		var star := PackedVector2Array()
		for index in 8:
			var radius := (32.0 if index % 2 == 0 else 4.0) * (.65 + flash * .35)
			star.append(center + Vector2.RIGHT.rotated(index * PI / 4 - .2) * radius)
		_gather.draw_colored_polygon(star, Color(Color.WHITE, flash))


func marker_visible() -> bool:
	return false


func visible_draw_count() -> int:
	if not visible:
		return 0
	var count: int = music_stage.draw_count
	for hit: Node2D in hits:
		count += hit.visible_draw_count()
	return count
