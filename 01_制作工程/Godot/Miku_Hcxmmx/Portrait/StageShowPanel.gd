extends Control

signal light_clips_changed(enabled: bool)

const SettingsScript = preload("res://Miku_Hcxmmx/Portrait/StageAudioSettings.gd")
const WIDTH := 438.0
const HEIGHT := 372.0
const EDGE := Color("#61e3ef")
const TEXT := Color("#dbf8ff")
const PINK := Color("#ff83d1")
var _content := Control.new()
var _scan := 0.0
var _clock := 0.0
var _hp: Label
var _gold: Label
var _icon := TextureRect.new()
var _gear := Button.new()
var _settings := SettingsScript.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var panel_theme := Theme.new()
	panel_theme.default_font = font
	theme = panel_theme
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.clip_contents = true
	add_child(_content)
	_label("初音未来", Vector2(30, 25), 282, 43, TEXT)
	_hp = _label("生命  77 / 77", Vector2(30, 105), 172, 18, EDGE)
	_gold = _label("金币  99", Vector2(221, 105), 187, 18, Color("#ffd99d"))
	_label("她曾用歌声点亮整座首都。如今，初音未来走进高塔，每一次出手都为下一段旋律打下节拍。",
		Vector2(30, 156), WIDTH - 60, 18, TEXT, 78)
	_label("初始遗物", Vector2(106, 254), 302, 14, EDGE)
	_label("歌曲之弓", Vector2(106, 276), 302, 22, TEXT)
	_label("每场战斗开始时拥有6点瞄准", Vector2(106, 312), 302, 16, TEXT, 42)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.position = Vector2(32, 267)
	_icon.size = Vector2(60, 60)
	_content.add_child(_icon)
	_gear.text = "⚙"
	_gear.tooltip_text = "初音设置"
	_gear.position = Vector2(371, 93)
	_gear.size = Vector2(37, 36)
	var symbol := SystemFont.new()
	symbol.font_names = PackedStringArray(["Segoe UI Symbol"])
	_gear.add_theme_font_override("font", symbol)
	_gear.add_theme_font_size_override("font_size", 23)
	_gear.pressed.connect(_open_settings)
	_content.add_child(_gear)
	add_child(_settings)
	_settings.hide()
	_settings.closed.connect(close_settings.bind(true))
	_settings.clips_changed.connect(func(enabled: bool): light_clips_changed.emit(enabled))


func _label(value: String, origin: Vector2, width: float, font_size: int, tint: Color, wrap_height := 0.0) -> Label:
	var label := Label.new()
	label.text = value
	label.position = origin
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	if wrap_height > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	_content.add_child(label)
	label.size = Vector2(width, wrap_height)
	return label


func set_character_info(hp: int, gold: int, icon: Texture2D) -> void:
	_hp.text = "生命  %d / %d" % [hp, hp]
	_gold.text = "金币  %d" % gold
	_icon.texture = icon


func set_light_clips_enabled(enabled: bool) -> void:
	_settings.set_clips_enabled(enabled)


func _open_settings() -> void:
	_content.hide()
	_settings.show()
	_settings.focus_first()
	queue_redraw()


func close_settings(restore_focus := false) -> void:
	_settings.hide()
	_content.show()
	if restore_focus:
		_gear.grab_focus()
	queue_redraw()


func sample(time: float) -> void:
	_clock = time
	_scan = HEIGHT * smoothstep(.34, .91, time)
	_content.size = Vector2(WIDTH, _scan)
	_gear.disabled = time < .91
	queue_redraw()


func _draw() -> void:
	if _scan <= 0.0 or _settings.visible:
		return
	var corner := minf(19.0, _scan * .5)
	var plate := PackedVector2Array([Vector2(0, corner), Vector2(corner, 0), Vector2(WIDTH, 0),
		Vector2(WIDTH, _scan - corner), Vector2(WIDTH - corner, _scan), Vector2(0, _scan), Vector2(0, corner)])
	draw_colored_polygon(plate, Color(.015, .065, .14, .75))
	draw_polyline(plate, Color(EDGE, .13), 7, true)
	draw_polyline(plate, Color(EDGE, .62), 1.5, true)
	draw_line(Vector2(corner + 8, 0), Vector2(122, 0), EDGE, 3, true)
	for y: float in [138.0, 244.0]:
		if _scan > y:
			draw_line(Vector2(30, y), Vector2(WIDTH - 30, y), Color(EDGE, .26), 1, true)
	var scanner := smoothstep(.34, .43, _clock) * (1.0 - smoothstep(.84, 1.02, _clock))
	if scanner > .01:
		draw_line(Vector2(0, _scan), Vector2(WIDTH - corner, _scan), Color(EDGE, scanner * .19), 18, true)
		draw_line(Vector2(0, _scan), Vector2(WIDTH - corner, _scan), Color(TEXT, scanner), 2, true)
		for index in 18:
			var phase := fposmod(_clock * 4 + index * .371, 1.0)
			var point := Vector2(12 + index * 23, _scan - 11 - phase * 29)
			if point.y > 12:
				draw_string(ThemeDB.fallback_font, point, "0" if index % 3 == 0 else "1",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(EDGE, scanner * (1.0 - phase) * .9))
	var seal_alpha := smoothstep(36.0, 69.0, _scan)
	if seal_alpha > .003:
		_draw_seal(Color(PINK.lerp(EDGE, .42), seal_alpha * .57))


func _draw_seal(tint: Color) -> void:
	var origin := Vector2(WIDTH - 91, 25)
	var three := PackedVector2Array([Vector2(0, 0), Vector2(20, 0), Vector2(24, 4), Vector2(24, 29),
		Vector2(20, 33), Vector2(0, 33), Vector2(0, 28), Vector2(18, 28), Vector2(18, 19),
		Vector2(5, 19), Vector2(5, 14), Vector2(18, 14), Vector2(18, 5), Vector2(0, 5), Vector2.ZERO])
	var nine := PackedVector2Array([Vector2(34, 0), Vector2(51, 0), Vector2(55, 4), Vector2(55, 29),
		Vector2(51, 33), Vector2(32, 33), Vector2(32, 28), Vector2(49, 28), Vector2(49, 20),
		Vector2(34, 20), Vector2(30, 16), Vector2(30, 4), Vector2(34, 0)])
	var counter := PackedVector2Array([Vector2(36, 5), Vector2(49, 5), Vector2(49, 15),
		Vector2(36, 15), Vector2(36, 5)])
	draw_set_transform(origin)
	for stroke in [three, nine, counter]:
		draw_polyline(stroke, tint, 1.25, true)
	draw_polyline(PackedVector2Array([Vector2(-7, 12), Vector2(-7, -3), Vector2(-3, -7), Vector2(14, -7)]), tint, 1, true)
	draw_polyline(PackedVector2Array([Vector2(62, 21), Vector2(62, 36), Vector2(58, 40), Vector2(41, 40)]), tint, 1, true)
	draw_set_transform(Vector2.ZERO)
