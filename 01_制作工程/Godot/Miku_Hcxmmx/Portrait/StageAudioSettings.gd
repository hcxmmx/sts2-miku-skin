extends Panel

signal closed
signal clips_changed(enabled: bool)

var _clips := CheckButton.new()


func _ready() -> void:
	size = Vector2(438, 156)
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


func set_clips_enabled(enabled: bool) -> void:
	_clips.set_pressed_no_signal(enabled)


func focus_first() -> void:
	_clips.grab_focus()
