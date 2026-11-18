extends Control

const PortraitScript = preload("res://Miku_Hcxmmx/Portrait/PortraitActor.gd")
const BackdropScript = preload("res://Miku_Hcxmmx/Portrait/StageBackdrop.gd")
var actor: Node2D
var backdrop: Control
var art := Control.new()
var selector := OptionButton.new()
var lip_box := CheckBox.new()
var auto_box := CheckBox.new()
var pause_button := Button.new()
var focus_button := Button.new()
var timeline := HSlider.new()
var zoom := HSlider.new()
var time_label := Label.new()
var _poses: Array = []
var _clock := 0.0
var _auto_clock := 0.0
var _speed := 1.0
var _paused := false
var _focus := false
var _updating := false


func _label(text: String, font_size := 16) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	return node


func _button(text: String, callback: Callable, host: Node) -> Button:
	var node := Button.new()
	node.text = text
	node.pressed.connect(callback)
	host.add_child(node)
	return node


func _ready() -> void:
	DisplayServer.window_set_title("经典初音 · 动态插画试作")
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	var style := Theme.new()
	style.default_font = font
	style.default_font_size = 16
	theme = style
	var background := ColorRect.new()
	background.color = Color("10212d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	backdrop = BackdropScript.new()
	art.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actor = PortraitScript.new()
	art.add_child(actor)
	_poses = actor.info.poses.keys()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := _label("经典初音 · 动态插画试作", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_button("动作预览", func(): get_tree().change_scene_to_file("res://Preview/Preview.tscn"), heading)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(middle)
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(spacer)
	var settings := VBoxContainer.new()
	settings.custom_minimum_size.x = 250
	settings.add_theme_constant_override("separation", 14)
	middle.add_child(settings)
	settings.add_child(_label("表情"))
	for pose: String in _poses:
		selector.add_item(actor.info.poses[pose].title)
	selector.item_selected.connect(_select_pose)
	settings.add_child(selector)
	lip_box.text = "播放口型"
	lip_box.button_pressed = true
	lip_box.toggled.connect(func(value: bool):
		actor.select_pose(_poses[selector.selected], value)
		actor.sample(_clock))
	settings.add_child(lip_box)
	auto_box.text = "自动轮换表情"
	settings.add_child(auto_box)
	var dynamics := CheckBox.new()
	dynamics.text = "动态演出"
	dynamics.button_pressed = true
	dynamics.toggled.connect(func(value: bool):
		actor.dynamics_enabled = value
		actor.sample(_clock))
	settings.add_child(dynamics)
	settings.add_child(_label("摆动幅度"))
	var motion := HSlider.new()
	motion.min_value = 0
	motion.max_value = 1.8
	motion.step = .05
	motion.value = 1
	motion.value_changed.connect(func(value: float):
		actor.motion_strength = value
		actor.sample(_clock))
	settings.add_child(motion)
	settings.add_child(_label("灯光强度"))
	var lighting := HSlider.new()
	lighting.min_value = 0
	lighting.max_value = 1.8
	lighting.step = .05
	lighting.value = 1
	lighting.value_changed.connect(func(value: float):
		actor.light_strength = value
		actor.sample(_clock))
	settings.add_child(lighting)
	focus_button = _button("面部近看", _toggle_focus, settings)
	settings.add_child(_label("缩放"))
	zoom.min_value = .6
	zoom.max_value = 1.6
	zoom.step = .05
	zoom.value = 1
	zoom.value_changed.connect(func(_value: float): _layout_art())
	settings.add_child(zoom)
	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 10)
	layout.add_child(transport)
	pause_button = _button("暂停", _toggle_pause, transport)
	_button("上一帧", _step.bind(-1), transport)
	_button("下一帧", _step.bind(1), transport)
	_button("重播", func(): _clock = 0; actor.sample(_clock), transport)
	var speed := OptionButton.new()
	for value in [.5, 1.0, 1.5, 2.0]:
		speed.add_item("%s×" % value)
	speed.select(1)
	speed.item_selected.connect(func(index: int): _speed = [.5, 1.0, 1.5, 2.0][index])
	transport.add_child(speed)
	timeline.min_value = 0
	timeline.max_value = 9.6
	timeline.step = 1.0 / 30
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	timeline.value_changed.connect(_seek)
	transport.add_child(timeline)
	time_label.custom_minimum_size.x = 75
	transport.add_child(time_label)
	resized.connect(_layout_art)
	_layout_art.call_deferred()
	print("ALICE_PORTRAIT_PREVIEW_READY expressions=", _poses.size(), " independent_face_mouth=true")


func _layout_art() -> void:
	art.position = Vector2(24, 82)
	art.size = Vector2(maxf(300, size.x - 330), maxf(300, size.y - 175))
	var bounds: Array = actor.info.bounds
	var source_size := Vector2(bounds[2], bounds[3])
	var center := Vector2(bounds[0], bounds[1]) + source_size * .5
	if _focus:
		source_size = Vector2(440, 350)
		center = Vector2(-20, -1220)
	var factor := minf(art.size.x / source_size.x, art.size.y / source_size.y) * .93 * zoom.value
	actor.scale = Vector2.ONE * factor
	actor.position = art.size * .5 - center * factor


func _select_pose(index: int) -> void:
	_auto_clock = 0
	actor.select_pose(_poses[index], lip_box.button_pressed)
	actor.sample(_clock)


func _toggle_pause() -> void:
	_paused = not _paused
	pause_button.text = "播放" if _paused else "暂停"


func _toggle_focus() -> void:
	_focus = not _focus
	focus_button.text = "全身查看" if _focus else "面部近看"
	_layout_art()


func _step(direction: int) -> void:
	_paused = true
	pause_button.text = "播放"
	_clock = maxf(0, _clock + direction / 30.0)
	actor.sample(_clock)


func _seek(value: float) -> void:
	if _updating:
		return
	_clock = value
	actor.sample(_clock)


func _process(delta: float) -> void:
	if not _paused:
		_clock += delta * _speed
		_auto_clock += delta * _speed
		if auto_box.button_pressed and _auto_clock >= 6.4:
			selector.select((selector.selected + 1) % _poses.size())
			_select_pose(selector.selected)
		actor.sample(_clock)
	backdrop.sample(_clock)
	_updating = true
	timeline.value = fposmod(_clock, timeline.max_value)
	_updating = false
	time_label.text = "%.2f s" % fposmod(_clock, timeline.max_value)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_toggle_pause()
			KEY_LEFT:
				_step(-1)
			KEY_RIGHT:
				_step(1)
