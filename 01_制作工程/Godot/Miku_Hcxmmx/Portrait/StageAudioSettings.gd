extends Panel

signal closed
signal clips_changed(enabled: bool)
signal clip_mix_changed(volume: float, impact_boost: bool)

var _clips := CheckButton.new()
var _volume := HSlider.new()
var _volume_label := Label.new()
var _impact_boost := CheckButton.new()


func _ready() -> void:
	size = Vector2(438, 266)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.025, .09, .16, .94)
	style.border_color = Color("#61e3ef")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", style)
	var title := Label.new()
	title.text = "初音设置"
	title.position = Vector2(28, 25)
	title.add_theme_color_override("font_color", Color("#dbf8ff"))
	title.add_theme_font_size_override("font_size", 30)
	add_child(title)
	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(340, 31)
	close.size = Vector2(70, 36)
	close.pressed.connect(func(): closed.emit())
	add_child(close)
	_clips.text = "轻攻击音乐片段"
	_clips.position = Vector2(25, 87)
	_clips.size = Vector2(386, 42)
	_clips.add_theme_font_size_override("font_size", 21)
	_clips.toggled.connect(func(enabled: bool): clips_changed.emit(enabled))
	add_child(_clips)
	_volume_label.position = Vector2(28, 138)
	_volume_label.add_theme_font_size_override("font_size", 19)
	add_child(_volume_label)
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.step = 1
	_volume.value = 100
	_volume.position = Vector2(28, 171)
	_volume.size = Vector2(380, 22)
	add_child(_volume)
	_impact_boost.text = "射击命中增益"
	_impact_boost.position = Vector2(25, 202)
	_impact_boost.size = Vector2(386, 42)
	_impact_boost.add_theme_font_size_override("font_size", 21)
	add_child(_impact_boost)
	_volume.value_changed.connect(func(_value: float): _notify_mix())
	_impact_boost.toggled.connect(func(_enabled: bool): _notify_mix())
	set_clip_mix(1.0, false)


func set_clips_enabled(enabled: bool) -> void:
	_clips.set_pressed_no_signal(enabled)


func set_clip_mix(volume: float, impact_boost: bool) -> void:
	_volume.set_value_no_signal(roundf(clampf(volume, 0.0, 1.0) * 100.0))
	_impact_boost.set_pressed_no_signal(impact_boost)
	_update_volume_label()


func _notify_mix() -> void:
	_update_volume_label()
	clip_mix_changed.emit(_volume.value / 100.0, _impact_boost.button_pressed)


func _update_volume_label() -> void:
	_volume_label.text = "轻击与射击片段  %d%%" % int(_volume.value)


func focus_first() -> void:
	_clips.grab_focus()
