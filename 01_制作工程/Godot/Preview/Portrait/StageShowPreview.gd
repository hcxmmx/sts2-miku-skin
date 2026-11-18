extends Control

const PortraitScene = preload("res://Miku_Hcxmmx/Portrait.tscn")
var _portrait: Control
var _panel: Control
var _clock := 0.0


func _ready() -> void:
	DisplayServer.window_set_title("初音未来 · 选人舞台预览")
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	var preview_theme := Theme.new()
	preview_theme.default_font = font
	theme = preview_theme
	_portrait = PortraitScene.instantiate()
	add_child(_portrait)
	_portrait.activate(true, [])
	_portrait.set_process(false)
	_panel = _portrait.panel
	_portrait.set_light_clips_enabled(true)
	var game_pack := OS.get_environment("MIKU_PREVIEW_GAME_PACK")
	if FileAccess.file_exists(game_pack) and ProjectSettings.load_resource_pack(game_pack, false):
		_portrait.set_character_info(77, 99, load("res://images/atlases/relic_atlas.sprites/song_bow.tres"))
	var replay := Button.new()
	replay.text = "重播亮灯"
	replay.pressed.connect(_restart)
	add_child(replay)
	replay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	replay.offset_left = -160
	replay.offset_right = -32
	replay.offset_top = -76
	replay.offset_bottom = -32
	_restart()


func _restart() -> void:
	_panel.close_settings()
	_clock = 0.0
	_process(0.0)


func _process(delta: float) -> void:
	_clock += delta
	_portrait.sample(_clock)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_restart()
		get_viewport().set_input_as_handled()
