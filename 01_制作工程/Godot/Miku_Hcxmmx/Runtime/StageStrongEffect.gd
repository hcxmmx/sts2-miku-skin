extends Node2D

const StageScript = preload("res://Miku_Hcxmmx/Runtime/MusicStage.gd")
const StageAccess = preload("res://Miku_Hcxmmx/Runtime/StageAccess.gd")
const ImpactScript = preload("res://Miku_Hcxmmx/Runtime/CombatEffect.gd")
const ShineShader = preload("res://Miku_Hcxmmx/Runtime/PowerUpShine.gdshader")
const AfterimageShader = preload("res://Miku_Hcxmmx/Runtime/ColorAfterimage.gdshader")
const CYAN = Color("35e5f2")
const PINK = Color("ff68cf")
var profile: Dictionary = {}
var phase := "强音蓄势"
var target_flash := 0.0
var target_recoil := Vector2.ZERO
var music_stage: Node2D
var _impact: Node2D
var _afterimages: Array[Sprite2D] = []
var _body_material := ShaderMaterial.new()
var _source_age := -1.0
var _source_flash := 0.0
var _afterimage_alpha := 0.0
var _heading := Vector2.RIGHT


func configure(data: Dictionary) -> void:
	profile = data
	music_stage = StageAccess.acquire(self, profile.textures.glow)
	_body_material.shader = ShineShader
	var ghost_material := ShaderMaterial.new()
	ghost_material.shader = AfterimageShader
	for index in 2:
		var ghost := Sprite2D.new()
		ghost.centered = false
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.material = ghost_material
		ghost.hide()
		add_child(ghost)
		_afterimages.append(ghost)
	_impact = ImpactScript.new()
	add_child(_impact)
	_impact.configure(profile)
	sample(0, Vector2.ZERO, false)


func sample(time: float, target: Vector2, target_enabled: bool) -> void:
	var clock := maxf(0, time)
	_impact.sample(time, target, target_enabled)
	phase = String(_impact.phase)
	target_flash = float(_impact.target_flash)
	target_recoil = _impact.target_recoil
	var release := float(profile.release)
	var hit := float(profile.hit)
	_source_age = clock - release
	_source_flash = smoothstep(0, .008, _source_age) * (1 - smoothstep(.12, .26, _source_age))
	_afterimage_alpha = smoothstep(0, .012, _source_age) * (1 - smoothstep(.1, .28, _source_age))
	var origin := Vector2(profile.origin[0], profile.origin[1])
	_heading = (target - origin).normalized() if target.distance_to(origin) > 1 else Vector2.RIGHT
	_body_material.set_shader_parameter("charge", 1.0)
	_body_material.set_shader_parameter("strength", _source_flash * .95)
	_body_material.set_shader_parameter("peak", _source_flash * .45)
	var charge := smoothstep(0, release, clock)
	var travel := clampf((clock - release) / (hit - release), 0, 1)
	var thrust := smoothstep(release, release + .02, clock) * (1 - smoothstep(hit, hit + .24, clock))
	var impact := smoothstep(hit, hit + .025, clock) * (1 - smoothstep(hit + .12, hit + .4, clock))
	var activity := charge * (1 - smoothstep(.5, 1.05, clock))
	music_stage.sample(clock, {}, 0, maxf(thrust * .55, impact * .8))
	music_stage.activation = activity * .65
	music_stage.wave_motion = charge * 3 + travel * 10
	music_stage.light_sweep_angle = -PI / 2 + travel * PI
	music_stage.light_sweep_strength = thrust * .9
	music_stage.note_opacity = 1 - activity * .35
	for index in StageScript.BAR_COUNT:
		var horizontal: float = index / float(StageScript.BAR_COUNT - 1) * 2 - 1
		var arch := sqrt(maxf(0, 1 - horizontal * horizontal))
		var directional := exp(-pow((horizontal - travel * .9) / .32, 2))
		var energy := activity * (.3 + directional * .7)
		music_stage.spectrum_levels[index] = energy
		music_stage.spectrum_heights[index] += arch * (70 * activity + directional * thrust * 130 + impact * 65)
	for index in 8:
		music_stage.bands[index] = activity * (.4 + absf(sin(index * 1.7 - travel * 5)) * .6)


func apply_body(sprite: Sprite2D) -> void:
	_body_material.set_shader_parameter("sprite_y", sprite.position.y)
	var atlas := sprite.texture as AtlasTexture
	_body_material.set_shader_parameter("actor_texture", atlas.atlas if atlas != null else sprite.texture)
	if atlas != null:
		var size := atlas.atlas.get_size()
		var region := atlas.region
		_body_material.set_shader_parameter("atlas_rect", Vector4(region.position.x / size.x,
			region.position.y / size.y, region.size.x / size.x, region.size.y / size.y))
	sprite.material = _body_material
	for index in _afterimages.size():
		var ghost := _afterimages[index]
		var distance := (index + 1) * (35 + clampf(_source_age / .2, 0, 1) * 13)
		ghost.texture = sprite.texture
		ghost.position = sprite.position - _heading * distance
		ghost.scale = sprite.scale
		ghost.rotation = sprite.rotation
		ghost.modulate = Color(CYAN if index == 0 else PINK, _afterimage_alpha * (.27 - index * .08))
		ghost.visible = sprite.visible and _afterimage_alpha > .003


func marker_visible() -> bool:
	return _impact.marker_visible()


func visible_draw_count() -> int:
	return music_stage.draw_count + _impact.visible_draw_count() if visible else 0
