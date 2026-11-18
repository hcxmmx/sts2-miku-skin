extends Node2D

const ShapesShader = preload("res://Miku_Hcxmmx/Runtime/EffectShapes.gdshader")
static var _quad: QuadMesh
static var _material: ShaderMaterial
var _painter: Callable
var _batch := MultiMeshInstance2D.new()
var _instances := MultiMesh.new()
var _capacity := 1024
var _count := 0
var _shape_transform := Transform2D.IDENTITY
var _path_cache: Dictionary = {}


func _init() -> void:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
		_material = ShaderMaterial.new()
		_material.shader = ShapesShader
	_instances.transform_format = MultiMesh.TRANSFORM_2D
	_instances.use_colors = true
	_instances.use_custom_data = true
	_instances.mesh = _quad
	_instances.instance_count = _capacity
	_batch.multimesh = _instances
	_batch.material = _material
	_batch.show_behind_parent = true
	add_child(_batch)


func set_painter(painter: Callable) -> void:
	_painter = painter


func _draw() -> void:
	_count = 0
	_shape_transform = Transform2D.IDENTITY
	if _painter.is_valid():
		_painter.call()
	_batch.visible = _count > 0
	if _count > 0:
		_instances.visible_instance_count = _count


func set_shape_transform(offset: Vector2, angle := 0.0, size := Vector2.ONE) -> void:
	_shape_transform = Transform2D(angle, size, 0, offset)
	draw_set_transform(offset, angle, size)


func set_shape_transform_matrix(transform: Transform2D) -> void:
	_shape_transform = transform
	draw_set_transform_matrix(transform)


func _append(transform: Transform2D, tint: Color, data: Color) -> void:
	if tint.a < .001:
		return
	if _count >= _capacity:
		var previous := _instances.buffer
		_capacity *= 2
		_instances.instance_count = _capacity
		previous.resize(_capacity * 16)
		_instances.buffer = previous
	_instances.set_instance_transform_2d(_count, _shape_transform * transform)
	_instances.set_instance_color(_count, tint)
	_instances.set_instance_custom_data(_count, data)
	_count += 1


func stroke_line(start: Vector2, finish: Vector2, tint: Color, width := 1.0, _antialias := false) -> void:
	var delta := finish - start
	var length := delta.length()
	if length < .001 or tint.a < .001:
		return
	_line(start, finish, delta / length, length, tint, maxf(1, width), 0, 0, 3)


func _line(start: Vector2, finish: Vector2, direction: Vector2, length: float, tint: Color,
		width: float, start_join: float, end_join: float, caps: int) -> void:
	var padded_width := width + 2
	var normal := direction.orthogonal()
	var transform := Transform2D(direction * length, normal * padded_width, (start + finish) * .5)
	_append(transform, tint, Color(start_join * padded_width / length, end_join * padded_width / length,
		width / padded_width * .5, caps))


func stroke_polyline(points: PackedVector2Array, tint: Color, width := 1.0, _antialias := false) -> void:
	if tint.a >= .001:
		_path(points, PackedColorArray(), tint, maxf(1, width))


func stroke_polyline_colors(points: PackedVector2Array, colors: PackedColorArray, width := 1.0, _antialias := false) -> void:
	if not colors.is_empty():
		_path(points, colors, colors[0], maxf(1, width))


func _join(previous: Vector2, direction: Vector2) -> float:
	var sum := previous.orthogonal() + direction.orthogonal()
	var denominator := sum.dot(direction.orthogonal())
	if absf(denominator) < .001:
		return 0
	return clampf(sum.dot(direction) / denominator, -3, 3)


func _prepare_path(points: PackedVector2Array) -> Dictionary:
	var key := hash(points)
	if _path_cache.has(key) and _path_cache[key].points == points:
		return _path_cache[key]
	var geometry := PackedVector4Array()
	var end_joins := PackedFloat32Array()
	var last := points.size() - 2
	var closed := points[0].is_equal_approx(points[points.size() - 1])
	var previous := (points[0] - points[last]).normalized() if closed else Vector2.ZERO
	var first_direction := (points[1] - points[0]).normalized()
	for index in points.size() - 1:
		var delta := points[index + 1] - points[index]
		var length := delta.length()
		var direction := delta / maxf(length, .001)
		var following := (points[index + 2] - points[index + 1]).normalized() if index < last else first_direction
		var start_join := _join(previous, direction) if index > 0 or closed else 0.0
		var end_join := _join(following, direction) if index < last or closed else 0.0
		geometry.append(Vector4(direction.x, direction.y, length, start_join))
		end_joins.append(end_join)
		previous = direction
	var result := {"points": points, "geometry": geometry, "end_joins": end_joins, "closed": closed}
	if _path_cache.size() >= 16:
		_path_cache.erase(_path_cache.keys()[0])
	_path_cache[key] = result
	return result


func _path(points: PackedVector2Array, colors: PackedColorArray, tint: Color, width: float) -> void:
	if points.size() < 2:
		return
	var path := _prepare_path(points)
	var geometry: PackedVector4Array = path.geometry
	var last := points.size() - 2
	for index in geometry.size():
		var segment := geometry[index]
		if segment.z < .001:
			continue
		var caps := (1 if index == 0 else 0) + (2 if index == last else 0) if not path.closed else 0
		var color := tint
		if colors.size() == points.size():
			color = colors[index].lerp(colors[index + 1], .5)
		_line(points[index], points[index + 1], Vector2(segment.x, segment.y), segment.z,
			color, width, segment.w, path.end_joins[index], caps)


func fill_circle(center: Vector2, radius: float, tint: Color, filled := true, width := -1.0, _antialias := false) -> void:
	if radius <= 0 or tint.a < .001:
		return
	var half_width := maxf(1, width) * .5 if not filled else 0.0
	var outer := radius + half_width + 1
	_append(Transform2D(0, Vector2.ONE * outer * 2, 0, center), tint,
		Color(radius / outer, half_width / outer, 1, 1 if filled else 0))


func stroke_arc(center: Vector2, radius: float, start: float, finish: float, _points: int,
		tint: Color, width := 1.0, _antialias := false) -> void:
	if radius <= 0 or tint.a < .001:
		return
	var half_width := maxf(1, width) * .5
	var outer := radius + half_width + 1
	_append(Transform2D(0, Vector2.ONE * outer * 2, 0, center), tint,
		Color(start, minf(TAU, finish - start), 2 + half_width / outer * .5, radius / outer))


func fill_rect(rectangle: Rect2, tint: Color, filled := true, width := -1.0) -> void:
	if not filled:
		draw_rect(rectangle, tint, false, width)
		return
	_append(Transform2D(0, rectangle.size, 0, rectangle.get_center()), tint, Color(0, 0, 3, 0))
