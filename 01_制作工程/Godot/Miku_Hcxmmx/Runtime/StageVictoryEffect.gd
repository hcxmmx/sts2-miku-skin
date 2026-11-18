extends "res://Miku_Hcxmmx/Runtime/StageFluteEffect.gd"

const ShineShader = preload("res://Miku_Hcxmmx/Runtime/PowerUpShine.gdshader")
const GOLD = Color("ffe4a3")
var _body_material := ShaderMaterial.new()
var _shine := 0.0


func configure(data: Dictionary) -> void:
	_body_material.shader = ShineShader
	super.configure(data)


func sample(time: float, target: Vector2, target_enabled: bool) -> void:
	super.sample(time, target, target_enabled)
	_shine = smoothstep(.15, .65, _time) * (1 - smoothstep(3.8, 4.2, _time))
	_body_material.set_shader_parameter("charge", smoothstep(.1, .7, _time))
	_body_material.set_shader_parameter("strength", _shine * .7)
	_body_material.set_shader_parameter("peak", _finale * .65)
	phase = "舞台礼花" if _time < 2.9 else "胜利星芒与定姿"


func _draw_front() -> void:
	for burst in 2:
		var age := _time - (.3 if burst == 0 else 2.2)
		if age < 0 or age > 1.7:
			continue
		for side in [-1.0, 1.0]:
			for index in 18:
				var life := age - index % 4 * .015
				if life < 0:
					continue
				var fade := smoothstep(0, .035, life) * (1 - smoothstep(1.05, 1.65, life))
				var speed := 35 + index * 23 % 115
				var upward := 380 + index * 37 % 190
				var point := Vector2(side * (105 + speed * life), -8 - upward * life + 185 * life * life)
				var tint := CYAN if index % 3 == 0 else (PINK if index % 3 == 1 else GOLD)
				if index % 3 == 0:
					GlyphScript.paint_note(_front, point, 25 + index % 4 * 3, side * life * .6, tint.lerp(WHITE, .25), fade, index % 2)
				elif index % 3 == 1:
					var ribbon := PackedVector2Array()
					for vertex in 13:
						var amount := vertex / 12.0
						ribbon.append(point + Vector2(sin(amount * TAU + life * 8 + index) * 7, amount * (23 + index % 4 * 7)).rotated(side * .3))
					_front.stroke_polyline(ribbon, Color(tint, fade * .85), 3.5, true)
				else:
					_draw_star(point, 7 + index % 4 * 2, life * side * 2, tint, fade)
			var muzzle := smoothstep(0, .015, age) * (1 - smoothstep(.06, .18, age))
			_draw_star(Vector2(side * 105, -12), 29, .2, WHITE, muzzle)
	for index in 7:
		var age := _time - (2.95 + index * .025)
		var alpha := smoothstep(0, .025, age) * (1 - smoothstep(.12, .4, age))
		var angle := -PI + index * PI / 6
		var point := Vector2(cos(angle) * 150, -190 + sin(angle) * 160)
		_draw_star(point, 18 + index % 2 * 6, .15, GOLD.lerp(WHITE, .55), alpha)
	_draw_cheering()


func _draw_star(point: Vector2, size: float, angle: float, tint: Color, alpha: float) -> void:
	if alpha < .003:
		return
	var star := PackedVector2Array()
	for vertex in 8:
		var radius := size if vertex % 2 == 0 else size * .14
		star.append(point + Vector2.RIGHT.rotated(vertex * PI / 4 + angle) * radius)
	_front.draw_colored_polygon(star, Color(tint, alpha))


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
