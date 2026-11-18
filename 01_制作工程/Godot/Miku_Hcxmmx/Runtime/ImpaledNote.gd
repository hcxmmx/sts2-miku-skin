extends Node2D

var note := Sprite2D.new()
var ring := Sprite2D.new()
var clock := 0.0
var profile: Dictionary = {}


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	note.use_parent_material = true
	ring.use_parent_material = true
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Miku_Hcxmmx/Assets/combat_profiles.json"))
	profile = profiles.performances.sts2_shootBow.combat_effect
	var sheet: Texture2D = load(profile.textures.note)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(0, 0, sheet.get_width() / 2, sheet.get_height() / 2)
	note.texture = atlas
	ring.texture = load(profile.textures.ring)
	add_child(ring)
	add_child(note)
	_sample()


func _sample() -> void:
	var hold: float = profile.get("marker_hold_duration", 0.0)
	var settle_duration: float = profile.get("marker_settle_duration", .24)
	var pulse := sin(maxf(0, clock - hold - settle_duration) * 7) * .06
	var settle := clampf((clock - hold) / settle_duration, 0, 1)
	var burst := pow(1 - settle, 2)
	var enlargement := lerpf(1.0, float(profile.get("marker_burst_scale", 3.2)), burst)
	var brightness := 1 + burst * 1.2
	var marker_scale: float = profile.marker_scale
	note.scale = Vector2.ONE * (40 + pulse * 10) * marker_scale * enlargement / note.texture.get_size()
	note.modulate = Color(brightness, brightness, brightness, lerpf(.8, 1.0, burst))
	note.rotation = -.12
	ring.scale = Vector2.ONE * (62 + pulse * 40) * marker_scale * lerpf(1.0, float(profile.get("marker_ring_burst_scale", 2.0)), burst) / ring.texture.get_size()
	ring.rotation = clock * .5
	ring.modulate.a = lerpf(.5, 1.0, burst)


func _process(delta: float) -> void:
	clock += delta
	_sample()
