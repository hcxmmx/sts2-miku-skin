extends Node2D

const ActorScript = preload("res://Miku_Hcxmmx/Runtime/Actor.gd")
var body := Sprite2D.new()
var _sources: Array[Dictionary] = []
var _native_bounds := Rect2()
var _idle_bounds := Rect2()
var _animation: Dictionary
var _clock := 0.0
var _frame := -1
var _configured := false
var _facing_anchor: Control


func _ready() -> void:
	ActorScript.load_catalog()
	_animation = ActorScript.catalog.animations.stand
	body.centered = false
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(body)
	var sprite: Dictionary = ActorScript.catalog.sprites[_animation.frames[0]]
	_idle_bounds = Rect2(Vector2(sprite.offset[0], sprite.offset[1] + ActorScript.catalog.ground_offset),
		Vector2(sprite.region[2], sprite.region[3]))
	_sample()
	hide()
	set_process(false)


func configure(originals: Array, kind: String) -> bool:
	if _configured:
		return true
	if originals.is_empty():
		return false
	var first: Node2D = originals[0]
	if not is_instance_valid(first):
		return false
	if first is Sprite2D:
		_native_bounds = first.get_rect()
		if kind == "rest":
			# Native FlipX flips the controls but only updates Spine bodies.
			_facing_anchor = get_parent().get_node_or_null("ControlRoot")
	elif first.has_method("get_skeleton"):
		var skeleton = first.get_skeleton()
		if skeleton == null:
			return false
		_native_bounds = skeleton.get_bounds()
	else:
		return false
	if _native_bounds.size.y <= 0:
		return false
	for original: Node2D in originals:
		_sources.append({"node": weakref(original), "visible": original.visible, "color": original.modulate})
	_configured = true
	show()
	set_process(true)
	_sync()
	print("[MikuSkin] ", kind, " idle attached")
	return true


func _sync() -> void:
	var first = _sources[0].node.get_ref()
	if not is_instance_valid(first):
		return
	for saved: Dictionary in _sources:
		var original = saved.node.get_ref()
		if is_instance_valid(original):
			original.hide()
			original.modulate.a = 0.0
	var factor: float = _native_bounds.size.y * absf(first.scale.y) / _idle_bounds.size.y
	var direction: float = signf(first.scale.x)
	if is_instance_valid(_facing_anchor):
		direction *= signf(_facing_anchor.scale.x)
	scale = Vector2(factor * direction, factor)
	var ground: Vector2 = first.position + Vector2(_native_bounds.get_center().x * first.scale.x,
		_native_bounds.end.y * first.scale.y)
	position = ground - Vector2(_idle_bounds.get_center().x * scale.x, _idle_bounds.end.y * scale.y)


func _sample() -> void:
	var frame: int = int(_clock / float(_animation.delay)) % _animation.frames.size()
	if frame == _frame:
		return
	_frame = frame
	var key: String = _animation.frames[frame]
	var sprite: Dictionary = ActorScript.catalog.sprites[key]
	body.texture = ActorScript.prepare_texture(key)
	body.position = Vector2(sprite.offset[0], sprite.offset[1] + ActorScript.catalog.ground_offset)


func _process(delta: float) -> void:
	_sync()
	_clock += delta
	_sample()


func _exit_tree() -> void:
	for saved: Dictionary in _sources:
		var original = saved.node.get_ref()
		if is_instance_valid(original):
			original.visible = saved.visible
			original.modulate = saved.color
