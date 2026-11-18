extends Node2D

static var textures: Dictionary = {}
var profile: Dictionary = {}
var phase := "准备"
var _trail: Sprite2D
var _muzzle: Sprite2D
var _impact: Sprite2D
var _impact_glow: Sprite2D
var _impact_ring: Sprite2D
var _impact_core: Sprite2D
var target_flash := 0.0
var target_recoil := Vector2.ZERO
var _marker: Sprite2D
var _marker_ring: Sprite2D
var _return_note: Sprite2D
var _waves: Array[Sprite2D] = []
var _shards: Array[Sprite2D] = []


func configure(data: Dictionary) -> void:
	profile = data
	z_index = 3
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	for key: String in profile.textures:
		var path: String = profile.textures[key]
		if not textures.has(path):
			textures[path] = load(path)
	var note_sheet: Texture2D = textures[profile.textures.note]
	var note := AtlasTexture.new()
	note.atlas = note_sheet
	note.region = Rect2(0, 0, note_sheet.get_width() / 2, note_sheet.get_height() / 2)
	_trail = _sprite(textures[profile.textures.line])
	_muzzle = _sprite(textures[profile.textures.spark])
	_impact = _sprite(textures[profile.textures.spark])
	_impact_glow = _sprite(textures[profile.textures.glow])
	_impact_ring = _sprite(textures[profile.textures.ring])
	_impact_core = _sprite(textures[profile.textures.glow])
	_marker_ring = _sprite(textures[profile.textures.ring])
	_marker = _sprite(note)
	_return_note = _sprite(note)
	for index in 4:
		_waves.append(_sprite(textures[profile.textures.wave]))
	for index in 12:
		_shards.append(_sprite(textures[profile.textures.shard]))
	sample(-1, Vector2.ZERO, false)


func _sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.use_parent_material = true
	add_child(sprite)
	return sprite


func _place(sprite: Sprite2D, point: Vector2, size: Vector2, angle: float, alpha: float, tint := Color.WHITE) -> void:
	sprite.position = point
	sprite.scale = size / sprite.texture.get_size()
	sprite.rotation = angle
	sprite.modulate = Color(tint.r, tint.g, tint.b, clampf(alpha, 0, 1))
	sprite.show()


func sample(time: float, target: Vector2, target_enabled: bool) -> void:
	for child: Sprite2D in get_children():
		child.hide()
	phase = "准备"
	target_flash = 0.0
	target_recoil = Vector2.ZERO
	if time < 0:
		return
	var origin := Vector2(profile.origin[0], profile.origin[1])
	var release: float = profile.release
	var hit: float = profile.hit
	var heading := (target - origin).angle()
	var wave_duration := hit - release
	for index in _waves.size():
		if not profile.get("source_enabled", true):
			break
		var delay := index * .014
		var age := time - release - delay
		var travel_duration := maxf(.01, wave_duration - delay)
		if age < 0 or age >= travel_duration:
			continue
		var travel := pow(age / travel_duration, .75)
		var point := origin.lerp(target, travel)
		var alpha := minf(age / .008, 1.0)
		_place(_waves[index], point, Vector2(18 + travel * 14, 75 + travel * 90), heading, alpha, Color("a1faff"))
		phase = "强音"
	var voice_time := time - release
	if profile.get("source_enabled", true) and voice_time >= 0 and voice_time < wave_duration + .055:
		var travel := pow(clampf(voice_time / wave_duration, 0, 1), .75)
		var head := origin.lerp(target, travel)
		var fade := 1 - clampf((time - hit) / .055, 0, 1)
		_place(_trail, origin.lerp(head, .5), Vector2(maxf(1, origin.distance_to(head)), 24), heading, fade * .9, Color("baffff"))
		_place(_muzzle, origin, Vector2.ONE * 85, heading, maxf(0, 1 - voice_time / .1))
		phase = "强音"
	var impact_age := time - hit
	var impact_duration: float = profile.get("impact_duration", .34)
	if target_enabled and impact_age >= 0 and impact_age < impact_duration:
		var progress := impact_age / impact_duration
		var hold: float = profile.get("marker_hold_duration", 0.0)
		var burst := 1 - pow(1 - clampf(impact_age / .12, 0, 1), 3)
		var fade := pow(1 - clampf((impact_age - hold) / maxf(.01, impact_duration - hold), 0, 1), 1.8)
		var impact_scale: float = profile.get("impact_scale", 1.0)
		target_flash = maxf(0, 1 - impact_age / float(profile.get("impact_flash_duration", .085)))
		var recoil := sin(minf(impact_age / .075, 1.0) * PI * .5) * exp(-impact_age * 15)
		target_recoil = Vector2.RIGHT.rotated(heading) * recoil * 24
		_place(_impact_glow, target, Vector2.ONE * lerpf(115, 220, burst) * impact_scale, 0, fade * .85, Color("87f7ff"))
		_place(_impact, target, Vector2(205, 100) * (1 + burst * .35) * impact_scale, heading + PI / 4, fade)
		_place(_impact_core, target, Vector2.ONE * lerpf(90, 125, burst) * impact_scale, 0, target_flash)
		_place(_impact_ring, target, Vector2.ONE * lerpf(32, 190, burst) * impact_scale, progress * .5, fade * .9, Color("b4ffff"))
		for index in _shards.size():
			var angle := index * TAU / _shards.size() + .18
			var distance := lerpf(8, 125, burst)
			var point := target + Vector2.RIGHT.rotated(angle) * distance * impact_scale
			var tint := Color("54edff") if index % 2 == 0 else Color("c396ff")
			_place(_shards[index], point, Vector2(11, 28) * (1 - progress * .7) * impact_scale, angle + progress, fade, tint)
		phase = "命中"
	if not target_enabled or not profile.get("marker_enabled", true):
		return
	var return_at: float = profile.return_at
	var return_duration: float = profile.return_duration
	var marker_scale: float = profile.marker_scale
	if impact_age >= 0 and time < return_at:
		var hold: float = profile.get("marker_hold_duration", 0.0)
		var settle_duration: float = profile.get("marker_settle_duration", .24)
		var pulse := sin(maxf(0, impact_age - hold - settle_duration) * 7) * .06
		var settle := clampf((impact_age - hold) / settle_duration, 0, 1)
		var burst := pow(1 - settle, 2)
		var enlargement := lerpf(1.0, float(profile.get("marker_burst_scale", 3.2)), burst)
		var brightness := 1 + burst * 1.2
		_place(_marker_ring, target, Vector2.ONE * (62 + pulse * 40) * marker_scale * lerpf(1.0, float(profile.get("marker_ring_burst_scale", 2.0)), burst), impact_age * .5, lerpf(.5, 1.0, burst))
		_place(_marker, target, Vector2.ONE * (40 + pulse * 10) * marker_scale * enlargement, -.12, lerpf(.8, 1.0, burst), Color(brightness, brightness, brightness))
		if impact_age >= impact_duration:
			phase = "扎穿标记"
	elif time >= return_at and time < return_at + return_duration:
		var progress := (time - return_at) / return_duration
		var home := Vector2(20, -210)
		var point := target.lerp(home, progress) + Vector2(0, -sin(progress * PI) * 45)
		_place(_return_note, point, Vector2.ONE * lerpf(40, 22, progress) * marker_scale, progress * -.4, 1 - progress * .5)
		phase = "返回"
	elif time >= return_at + return_duration:
		phase = "完成"


func marker_visible() -> bool:
	return _marker.is_visible_in_tree()


func visible_draw_count() -> int:
	var count := 0
	for child: Sprite2D in get_children():
		if child.is_visible_in_tree():
			count += 1
	return count
