extends Control

const ASSETS = "res://Miku_Hcxmmx/Portrait/Assets/Stage/"
const BackgroundShader = preload("res://Miku_Hcxmmx/Portrait/StageBackdrop.gdshader")
var _material := ShaderMaterial.new()
var _decorations: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var sky := TextureRect.new()
	sky.texture = load(ASSETS + "bg_7396_01.png")
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material.shader = BackgroundShader
	sky.material = _material
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Distant illuminated buildings frame the stage behind the native interface.
	_add_decoration("bill_04", Vector2(.34, .67), 350, 2, -3, .64)
	_add_decoration("bill_03", Vector2(.025, .59), 175, 3, 0, .72)
	_add_decoration("bill_01", Vector2(.105, .87), 405, 4, -4, .85)
	_add_decoration("bill_02", Vector2(.975, .73), 310, 5, 8, .86)
	# Music props occupy the exposed edges around the illustration.
	_add_decoration("record_left", Vector2(.135, .265), 300, 15, -12, .90)
	_add_decoration("record_right", Vector2(.945, .22), 350, 18, 10, .95)
	_add_decoration("starmic_M", Vector2(.425, .155), 126, 12, -8, .88)
	_add_decoration("speaker_mini_01", Vector2(.44, .79), 108, 13, -8, .80)
	_add_decoration("wave", Vector2(.885, .84), 300, 5, 0, .74)
	var stars := [Vector2(.06, .37), Vector2(.30, .13), Vector2(.47, .36),
		Vector2(.88, .11), Vector2(.965, .45), Vector2(.38, .88)]
	for index in stars.size():
		_add_decoration("star_01" if index % 2 == 0 else "star_02", stars[index], 28 + index * 3, 9, index * 13, .75)
	# Shade the information side after drawing the props, beneath the portrait/UI.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, .38, .64, 1])
	gradient.colors = PackedColorArray([Color(0.02, .025, .07, .56), Color(.02, .025, .07, .38),
		Color(.02, .025, .07, 0), Color(.02, .025, .07, .06)])
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2.ZERO
	shade_texture.fill_to = Vector2.RIGHT
	shade.texture = shade_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout)
	_layout()
	sample(0)


func _add_decoration(name: String, anchor: Vector2, width: float, bob: float, tilt: float, opacity: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(ASSETS + "bg_7396_" + name + ".png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.modulate.a = opacity
	add_child(sprite)
	_decorations.append({"sprite": sprite, "anchor": anchor, "width": width, "bob": bob,
		"tilt": deg_to_rad(tilt), "opacity": opacity, "phase": _decorations.size() * 1.73,
		"star": name.begins_with("star_"), "building": name.begins_with("bill_"),
		"scale": 1.0, "base": Vector2.ZERO})


func _layout() -> void:
	var factor := minf(size.x / 1920.0, size.y / 1080.0)
	for row: Dictionary in _decorations:
		row.base = row.anchor * size
		row.scale = row.width * factor / row.sprite.texture.get_width()
		row.sprite.position = row.base
		row.sprite.scale = Vector2.ONE * row.scale


func sample(time: float, show_time := -1.0) -> void:
	_material.set_shader_parameter("clock", time)
	_material.set_shader_parameter("show_time", show_time)
	var factor := minf(size.x / 1920.0, size.y / 1080.0)
	for row: Dictionary in _decorations:
		var phase: float = time * .48 + row.phase
		row.sprite.position = row.base + Vector2(sin(phase * .63) * row.bob * .35, sin(phase) * row.bob) * factor
		row.sprite.rotation = row.tilt + sin(phase * .72) * .035
		var pulse := .5 + .5 * sin(time * 1.6 + row.phase)
		row.sprite.scale = Vector2.ONE * row.scale * (1.0 + pulse * (.12 if row.star else .015))
		var light := 1.0
		if show_time >= 0.0 and row.building:
			var travel := fposmod(show_time - 1.323529, 5.882353)
			var age: float = travel - .205 - row.anchor.x * .48
			light += .45 * smoothstep(0.0, .07, age) * (1.0 - smoothstep(.07, .42, age))
		row.sprite.modulate = Color(light, light, light, row.opacity * (.55 + .45 * pulse if row.star else 1.0))
