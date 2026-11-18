extends Control

signal light_clips_changed(enabled: bool)
signal clip_mix_changed(volume: float, impact_boost: bool)

const PortraitScript = preload("res://Miku_Hcxmmx/Portrait/PortraitActor.gd")
const BackdropScript = preload("res://Miku_Hcxmmx/Portrait/StageBackdrop.gd")
const InfoPanel = preload("res://Miku_Hcxmmx/Portrait/StageShowPanel.gd")
var actor: Node2D
var backdrop: Control
var panel: Control
var _clock := 0.0
var _backgrounds: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	backdrop = BackdropScript.new()
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actor = PortraitScript.new()
	add_child(actor)
	actor.select_pose("normal", false)
	panel = InfoPanel.new()
	add_child(panel)
	panel.light_clips_changed.connect(func(enabled: bool): light_clips_changed.emit(enabled))
	panel.clip_mix_changed.connect(func(volume: float, boost: bool): clip_mix_changed.emit(volume, boost))
	resized.connect(_layout)
	_layout()
	hide()
	set_process(false)


func activate(enabled: bool, backgrounds: Array) -> void:
	if enabled and not visible:
		_clock = 0.0
		sample(0.0)
		_backgrounds.clear()
		for background: Control in backgrounds:
			_backgrounds.append({"node": weakref(background), "visible": background.visible})
			background.hide()
	elif not enabled:
		panel.close_settings()
		_restore_backgrounds()
	visible = enabled
	set_process(enabled)
	if enabled:
		_layout()


func _layout() -> void:
	if actor == null:
		return
	var bounds: Array = actor.info.bounds
	var art_size := Vector2(bounds[2], bounds[3])
	var center := Vector2(bounds[0], bounds[1]) + art_size * .5
	var factor := minf(size.x * .72 / art_size.x, size.y * .98 / art_size.y)
	actor.scale = Vector2.ONE * factor
	actor.position = Vector2(size.x * .70, size.y * .49) - center * factor
	panel.position = Vector2(size.x * .072, size.y * .27)
	panel.scale = Vector2.ONE * minf(size.x / 1440.0, size.y / 900.0)


func set_character_info(hp: int, gold: int, icon: Texture2D) -> void:
	panel.set_character_info(hp, gold, icon)


func set_light_clips_enabled(enabled: bool) -> void:
	panel.set_light_clips_enabled(enabled)


func set_clip_mix(volume: float, impact_boost: bool) -> void:
	panel.set_clip_mix(volume, impact_boost)


func sample(time: float) -> void:
	backdrop.sample(time, time)
	actor.sample(time)
	panel.sample(time)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	sample(_clock)


func _restore_backgrounds() -> void:
	for saved: Dictionary in _backgrounds:
		var background = saved.node.get_ref()
		if is_instance_valid(background):
			background.visible = saved.visible
	_backgrounds.clear()


func _exit_tree() -> void:
	_restore_backgrounds()
