extends Node

static var catalog: Dictionary = {}
static var streams: Dictionary = {}
var music := AudioStreamPlayer.new()
var melodies: Array[AudioStreamPlayer] = []
var music_gain := 1.0
var sfx_gain := 1.0
var background_muted := false
var emphasis := 0.0
var ended := false
var light := AudioStreamPlayer.new()
var light_enabled := true
var light_group: Dictionary = {}
var light_index := 0
var light_clip_id := ""
var light_gain := 1.0
var light_clip_gain := 1.0
var clip_volume := 1.0
var light_fading := false
var melody_queue: Array[String] = []
var active_melody := ""
var heavy: AudioStreamPlayer
var heavy_mix := 1.0


func _ready() -> void:
	load_catalog()
	add_child(music)
	add_child(light)
	for row: Dictionary in catalog.melodies.values():
		if not streams.has(row.path):
			streams[row.path] = AudioStreamWAV.load_from_file(row.path, {})
	for group: Dictionary in catalog.get("light_groups", []):
		for row: Dictionary in group.clips:
			if not streams.has(row.path):
				streams[row.path] = AudioStreamWAV.load_from_file(row.path, {})


static func load_catalog() -> void:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string("res://Miku_Hcxmmx/Assets/user_audio.json"))


func set_light_enabled(enabled: bool) -> void:
	light_enabled = enabled
	if not enabled:
		light.stop()
		light_fading = false
		light_gain = 1.0
		light_group = {}
		light_index = 0


func uses_light_clips() -> bool:
	return light_enabled and not catalog.get("light_groups", []).is_empty()


func play_light() -> bool:
	if ended or not uses_light_clips():
		return false
	if light.playing or _heavy_playing() or not melodies.is_empty():
		return true
	if light_group.is_empty() or light_index >= light_group.clips.size():
		light_group = catalog.light_groups.pick_random()
		light_index = 0
	var row: Dictionary = light_group.clips[light_index]
	if streams.get(row.path) == null:
		return false
	light.stream = streams[row.path]
	light_clip_id = row.id
	light_clip_gain = db_to_linear(float(row.get("playback_gain_db", 0.0)))
	light_gain = 1.0
	light_fading = false
	_apply_volume()
	light.play()
	light_index += 1
	return true


func enable_music(enabled: bool) -> bool:
	if not enabled or ended:
		music.stop()
		return false
	if music.playing:
		return true
	if catalog.music.is_empty():
		return false
	var row: Dictionary = catalog.music.pick_random()
	var stream := AudioStreamOggVorbis.load_from_file(row.path)
	if stream == null:
		return false
	stream.loop = true
	music.stream = stream
	_apply_volume()
	music.play()
	return true


func play_melody(kind: String) -> bool:
	if ended or not catalog.melodies.has(kind):
		return false
	var path: String = catalog.melodies[kind].path
	if streams.get(path) == null:
		return false
	if kind != active_melody and not melody_queue.has(kind):
		melody_queue.append(kind)
	_start_next_melody()
	return true


func _start_next_melody() -> void:
	if ended or not melodies.is_empty() or melody_queue.is_empty():
		return
	active_melody = melody_queue.pop_front()
	var path: String = catalog.melodies[active_melody].path
	var player := AudioStreamPlayer.new()
	player.stream = streams[path]
	add_child(player)
	melodies.append(player)
	player.finished.connect(func():
		melodies.erase(player)
		active_melody = ""
		player.queue_free()
		_start_next_melody())
	_yield_light()
	_apply_volume()
	player.play()


func _heavy_playing() -> bool:
	return is_instance_valid(heavy) and heavy.playing


func allow_cue(cue: Dictionary) -> bool:
	return cue.kind != "voice" or cue.get("exclusive_heavy", false) or (not _heavy_playing() and melodies.is_empty())


func cue_started(player: AudioStreamPlayer) -> void:
	if player.get_meta("exclusive_heavy", false):
		heavy = player
		_yield_light()
		_apply_volume()


func _yield_light() -> void:
	light_fading = light.playing


func accent() -> void:
	if music.playing:
		emphasis = 1.0
		_apply_volume()


func set_mix(sfx: float, bgm: float, muted: bool) -> void:
	sfx_gain = sfx
	music_gain = bgm
	background_muted = muted
	_apply_volume()


func set_clip_volume(volume: float) -> void:
	clip_volume = clampf(volume, 0.0, 1.0)
	_apply_volume()


func _apply_volume() -> void:
	music.volume_db = linear_to_db(maxf(.0001, music_gain)) + emphasis * float(catalog.get("emphasis_db", 3.0))
	music.volume_linear = 0.0 if background_muted or music_gain <= 0 else db_to_linear(music.volume_db)
	for player: AudioStreamPlayer in melodies:
		player.volume_linear = 0.0 if background_muted else sfx_gain
	light.volume_linear = 0.0 if background_muted else sfx_gain * clip_volume * light_clip_gain * light_gain
	if _heavy_playing():
		var gain := clip_volume * heavy_mix
		heavy.set_meta("mix_gain", gain)
		heavy.volume_linear = 0.0 if background_muted else sfx_gain * gain * db_to_linear(float(heavy.get_meta("cue_gain", 0.0)))


func finish() -> void:
	ended = true
	music.stop()
	light.stop()
	light_fading = false
	light_gain = 1.0
	light_group = {}
	light_index = 0
	melody_queue.clear()
	active_melody = ""
	heavy = null
	heavy_mix = 1.0
	for player: AudioStreamPlayer in melodies:
		player.stop()
		player.queue_free()
	melodies.clear()


func _process(delta: float) -> void:
	var changed := light_fading or emphasis > 0
	if light_fading:
		light_gain = move_toward(light_gain, 0.0, delta / .08)
		if is_zero_approx(light_gain):
			light.stop()
			light_fading = false
	var next_mix := move_toward(heavy_mix, .25 if not melodies.is_empty() else 1.0, delta / .1)
	changed = changed or next_mix != heavy_mix
	heavy_mix = next_mix
	if emphasis > 0:
		emphasis = maxf(0, emphasis - delta / .16)
	if changed:
		_apply_volume()
