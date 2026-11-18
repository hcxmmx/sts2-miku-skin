extends Node2D

signal pose_changed
signal target_hit

static var catalog: Dictionary = {}
static var textures: Dictionary = {}
static var audio_streams: Dictionary = {}
static var draft_data: Dictionary = {}
const EffectScript = preload("res://Miku_Hcxmmx/Runtime/EffectPlayer.gd")
const CombatEffectScript = preload("res://Miku_Hcxmmx/Runtime/CombatEffect.gd")
const ActionEffectScript = preload("res://Miku_Hcxmmx/Runtime/ActionEffect.gd")
const MusicAttackEffectScript = preload("res://Miku_Hcxmmx/Runtime/MusicAttackEffect.gd")
const StageIntroEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageIntroEffect.gd")
const StageSpinEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageSpinEffect.gd")
const StageCastEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageCastEffect.gd")
const StageStepEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageStepEffect.gd")
const StageGestureEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageGestureEffect.gd")
const StageBlockEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageBlockEffect.gd")
const StageHitEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageHitEffect.gd")
const StageDeathEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageDeathEffect.gd")
const StageFluteEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageFluteEffect.gd")
const StageVictoryEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageVictoryEffect.gd")
const StagePointEffectScript = preload("res://Miku_Hcxmmx/Runtime/StagePointEffect.gd")
const StageReadyEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageReadyEffect.gd")
const StageLiftEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageLiftEffect.gd")
const StageStrongEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageStrongEffect.gd")
const StageAmbientEffectScript = preload("res://Miku_Hcxmmx/Runtime/StageAmbientEffect.gd")

var body := Sprite2D.new()
var sequence_name := "stand"
var sequence: Array[Dictionary] = []
var cues: Array[Dictionary] = []
var duration := 0.0
var clock := 0.0
var speed := 1.0:
	set(value):
		speed = value
		for player: AudioStreamPlayer in _audio_nodes:
			if is_instance_valid(player) and player.get_meta("sync_timeline", false):
				player.pitch_scale = value
var paused := false
var looping := true
var return_to_idle := true
var pending_attack := false
var pending_action := ""
var pending_repeat := false
var active_performance: Dictionary = {}
var voice_enabled := true
var sfx_enabled := true
var voice_volume_db := 0.0
var sfx_volume_db := 0.0
var effects_enabled := true
var target_effects_enabled := true
var effect_clock := 0.0
var effect_events: Array = []
var effect_instances: Dictionary = {}
var _cached_effects: Dictionary = {}
var effect_tails: Array[Dictionary] = []
var target_position := Vector2(500, 0)
var target_center_offset := Vector2(0, -150)
var combat_effect: Node2D
var current_clip := "stand"
var current_frame := 0
var frame_boundaries: Array[float] = []
var tail_loop_start := -1.0
var _audio_nodes: Array[AudioStreamPlayer] = []
var audio_coordinator: Node
var shared_music_stage: Node2D
var _rng := RandomNumberGenerator.new()
var last_update_usec := 0


func _ready() -> void:
	load_catalog()
	# Decode adapted cues before playback so the first attack has no file-read stall.
	for name: String in catalog.adapted_performance_names:
		var performance: Dictionary = catalog.performances[name]
		var preload_cues: Array = performance.get("audio", []).duplicate()
		if performance.get("combat_effect", {}).has("hit_audio"):
			preload_cues.append(performance.combat_effect.hit_audio)
		for cue: Dictionary in preload_cues:
			for path: String in cue.paths:
				if not audio_streams.has(path):
					audio_streams[path] = AudioStreamWAV.load_from_file(path, {})
	_rng.seed = 39
	body.centered = false
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(body)
	play("stand", true)


static func load_catalog() -> void:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string("res://Miku_Hcxmmx/Assets/actor.json"))
		catalog.source_animation_names = catalog.animations.keys()
		catalog.source_performance_names = catalog.performances.keys()
		var adapted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Miku_Hcxmmx/Assets/combat_profiles.json"))
		catalog.adapted_performance_names = adapted.performances.keys()
		catalog.animations.merge(adapted.animations)
		catalog.performances.merge(adapted.performances)


static func load_draft_data() -> Dictionary:
	if draft_data.is_empty():
		draft_data = JSON.parse_string(FileAccess.get_file_as_string("res://Miku_Hcxmmx/Assets/action_drafts.json"))
	return draft_data


static func prepare_texture(frame_key: String) -> Texture2D:
	if not textures.has(frame_key):
		var sprite: Dictionary = catalog.sprites[frame_key]
		var atlas := AtlasTexture.new()
		atlas.atlas = load(sprite.atlas)
		var region: Array = sprite.region
		atlas.region = Rect2(region[0], region[1], region[2], region[3])
		textures[frame_key] = atlas
	return textures[frame_key]


func load_drafts() -> void:
	var drafts := load_draft_data()
	catalog.animations.merge(drafts.animations)
	catalog.performances.merge(drafts.performances)
	catalog.draft_performance_names = drafts.performances.keys()
	catalog.performances.merge(drafts.body_previews)
	catalog.response_performance_names = drafts.body_previews.keys()
	catalog.performances.merge(drafts.combined_previews)
	catalog.combined_performance_names = drafts.combined_previews.keys()


func load_game() -> void:
	load_drafts()
	if catalog.has("game_pools"):
		return
	var data := load_draft_data()
	catalog.performances.merge(data.game_performances, true)
	catalog.game_pools = data.game_pools
	catalog.music_clips = data.music_clips


func play(name: String, repeat := false, preserve_audio := false, keep_effect_tails := false) -> void:
	if keep_effect_tails:
		_retain_effect_tail()
	elif not preserve_audio:
		_clear_effect_tails()
	if not preserve_audio:
		_stop_audio(true, shared_music_stage != null and name == "stand" and clock >= duration)
	pending_attack = false
	pending_action = ""
	pending_repeat = false
	sequence_name = name
	sequence.clear()
	cues.clear()
	frame_boundaries.clear()
	duration = 0.0
	tail_loop_start = -1.0
	var performance: Dictionary = catalog.performances.get(name, {})
	if name.begins_with("effect:"):
		EffectScript.load_catalog()
		var effect_name := name.trim_prefix("effect:")
		var effect_duration := float(EffectScript.catalog.effects[effect_name].frame_count) / float(EffectScript.catalog.fps)
		performance = {"segments": [{"clip": "stand", "action": "stand", "duration": effect_duration}],
			"effects": {"events": [catalog.effect_previews[effect_name]]}}
	active_performance = performance
	body.z_index = int(performance.get("body_z_index", 0))
	body.material = null
	var segments: Array = performance.get("segments", [{"action": name.trim_prefix("clip:"), "clip": name.trim_prefix("clip:")}])
	if repeat and performance.get("loop_body_on_repeat", false):
		segments = segments.slice(0, 1)
	for segment_index in segments.size():
		var source_segment: Dictionary = segments[segment_index]
		var clip_name: String = source_segment.clip
		if not catalog.animations.has(clip_name):
			push_error("Missing Miku animation " + clip_name)
			return
		var animation: Dictionary = catalog.animations[clip_name]
		var length: float = source_segment.get("duration", animation.get("duration", float(animation.delay) * animation.frames.size()))
		if segment_index == int(performance.get("tail_loop_index", -1)):
			tail_loop_start = duration
		var repeats: bool = source_segment.get("loop", false)
		sequence.append({"name": clip_name, "action": source_segment.action, "start": duration, "duration": length, "loop": repeats,
			"mirrored": source_segment.get("mirrored", false)})
		var boundary_count: int = ceili(length / float(animation.delay)) if repeats else animation.frames.size()
		for index in boundary_count:
			var boundary: float = animation.frame_times[index] if animation.has("frame_times") else index * float(animation.delay)
			frame_boundaries.append(duration + boundary)
		for source: Dictionary in catalog.audio.get(source_segment.action, []):
			var cue := source.duplicate(true)
			cue.time = 0.0 if performance.get("audio_at_start", false) else duration + float(source.time)
			cues.append(cue)
		duration += length
	for source: Dictionary in performance.get("audio", []):
		var cue := source.duplicate(true)
		if performance.get("audio_at_start", false):
			cue.time = 0.0
		cues.append(cue)
	if name.begins_with("effect:"):
		frame_boundaries.clear()
		for index in ceili(duration * float(EffectScript.catalog.fps)):
			frame_boundaries.append(float(index) / float(EffectScript.catalog.fps))
	if not preserve_audio:
		if combat_effect != null:
			_release_effect(combat_effect)
			combat_effect = null
		for instance: Node2D in effect_instances.values():
			_release_effect(instance)
		effect_instances.clear()
		effect_clock = 0.0
		var effect_data: Dictionary = performance.get("effects", catalog.raw_effects.get(name.trim_prefix("clip:"), {}))
		effect_events = effect_data.get("events", [])
		if performance.has("combat_effect"):
			combat_effect = _take_effect("combat:" + name)
			if combat_effect != null:
				shared_music_stage.commit_note_motion()
				shared_music_stage.reset_action_state()
				if combat_effect.has_method("restart"):
					combat_effect.restart()
			else:
				var custom: bool = performance.combat_effect.kind in ["light", "gesture", "step", "spin", "celebrate"]
				if performance.combat_effect.kind == "music_light":
					combat_effect = MusicAttackEffectScript.new()
				elif performance.combat_effect.kind == "stage_intro":
					combat_effect = StageIntroEffectScript.new()
				elif performance.combat_effect.kind == "stage_spin":
					combat_effect = StageSpinEffectScript.new()
				elif performance.combat_effect.kind == "stage_cast":
					combat_effect = StageCastEffectScript.new()
				elif performance.combat_effect.kind == "stage_step":
					combat_effect = StageStepEffectScript.new()
				elif performance.combat_effect.kind == "stage_gesture":
					combat_effect = StageGestureEffectScript.new()
				elif performance.combat_effect.kind == "stage_block":
					combat_effect = StageBlockEffectScript.new()
				elif performance.combat_effect.kind == "stage_hit":
					combat_effect = StageHitEffectScript.new()
				elif performance.combat_effect.kind == "stage_death":
					combat_effect = StageDeathEffectScript.new()
				elif performance.combat_effect.kind == "stage_flute":
					combat_effect = StageFluteEffectScript.new()
				elif performance.combat_effect.kind == "stage_victory":
					combat_effect = StageVictoryEffectScript.new()
				elif performance.combat_effect.kind == "stage_point":
					combat_effect = StagePointEffectScript.new()
				elif performance.combat_effect.kind == "stage_ready":
					combat_effect = StageReadyEffectScript.new()
				elif performance.combat_effect.kind == "stage_lift":
					combat_effect = StageLiftEffectScript.new()
				elif performance.combat_effect.kind == "stage_strong":
					combat_effect = StageStrongEffectScript.new()
				elif performance.combat_effect.kind == "stage_ambient":
					combat_effect = StageAmbientEffectScript.new()
				else:
					combat_effect = ActionEffectScript.new() if custom else CombatEffectScript.new()
				add_child(combat_effect)
				combat_effect.configure(performance.combat_effect)
				if shared_music_stage != null:
					combat_effect.set_meta("stage_material", shared_music_stage.material)
				combat_effect.set_meta("pool_key", "combat:" + name)
			combat_effect.show()

	clock = 0.0
	paused = false
	looping = repeat
	_render()
	for cue: Dictionary in cues:
		cue.played = float(cue.time) <= 0.0
		if cue.played:
			_play_cue(cue)
	pose_changed.emit()


func request_attack() -> void:
	request_action("s100")


func request_action(name: String, repeat := false) -> void:
	if sequence_name == name and not paused and clock < float(active_performance.get("body_duration", duration)):
		pending_attack = true
		pending_action = name
		pending_repeat = repeat
		return
	play(name, repeat)


func seek(time: float) -> void:
	_stop_audio(false)
	_clear_effect_tails()
	pending_attack = false
	pending_action = ""
	pending_repeat = false
	clock = clampf(time, 0.0, duration)
	for cue: Dictionary in cues:
		cue.played = float(cue.time) <= clock
	effect_clock = clock
	_render()
	pose_changed.emit()


func step_frame(direction: int) -> void:
	set_paused(true)
	var destination := duration if direction > 0 else 0.0
	if direction > 0:
		for boundary in frame_boundaries:
			if boundary > clock + 0.00001:
				destination = boundary
				break
	else:
		for boundary in frame_boundaries:
			if boundary >= clock - 0.00001:
				break
			destination = boundary
	seek(destination)


func set_paused(value: bool) -> void:
	paused = value
	for player in _audio_nodes:
		if is_instance_valid(player):
			player.stream_paused = value


func set_audio_enabled(kind: String, enabled: bool) -> void:
	if kind == "voice":
		voice_enabled = enabled
	else:
		sfx_enabled = enabled
	for player in _audio_nodes:
		if is_instance_valid(player) and player.get_meta("kind", "") == kind and not enabled:
			player.stop()


func set_volume(kind: String, decibels: float) -> void:
	if kind == "voice":
		voice_volume_db = decibels
	else:
		sfx_volume_db = decibels
	for player in _audio_nodes:
		if is_instance_valid(player) and player.get_meta("kind", "") == kind:
			player.volume_db = decibels + float(player.get_meta("cue_gain", 0.0)) + linear_to_db(maxf(.0001, float(player.get_meta("mix_gain", 1.0))))


func advance(delta: float) -> void:
	if paused or duration <= 0.0:
		return
	var previous := clock
	for index in range(effect_tails.size() - 1, -1, -1):
		var tail: Dictionary = effect_tails[index]
		tail.clock += delta
		_emit_effect_hits(tail.events, tail.combat, float(tail.clock), delta)
		if float(tail.clock) >= float(tail.duration):
			_free_effect_tail(tail)
			effect_tails.remove_at(index)
	effect_clock += delta
	clock = minf(clock + delta, duration)
	for cue in cues:
		if not cue.get("played", false) and float(cue.time) >= previous and float(cue.time) < clock:
			_play_cue(cue)
			cue.played = true
	_emit_effect_hits(effect_events, combat_effect, effect_clock, delta)
	_render()
	pose_changed.emit()
	if pending_attack and clock >= float(active_performance.get("body_duration", duration)):
		play(pending_action, pending_repeat)
		return
	if clock < duration:
		return
	if tail_loop_start >= 0.0:
		clock = tail_loop_start
		_render()
	elif looping:
		play(sequence_name, true, sequence_name == "stand", active_performance.get("loop_body_on_repeat", false))
	elif return_to_idle and sequence_name != "stand":
		play("stand", true, shared_music_stage == null)
	else:
		set_paused(true)


func _render() -> void:
	if sequence.is_empty():
		return
	var time := minf(clock, maxf(0.0, duration - 0.000001))
	var active: Dictionary = sequence[0]
	for segment in sequence:
		if time >= float(segment.start):
			active = segment
	current_clip = active.name
	var animation: Dictionary = catalog.animations[current_clip]
	var local_time := time - float(active.start)
	if active.loop:
		local_time = fmod(local_time, float(animation.delay) * animation.frames.size())
	current_frame = mini(int(local_time / float(animation.delay)), animation.frames.size() - 1)
	if animation.has("frame_times"):
		current_frame = 0
		for index in animation.frame_times.size():
			if local_time >= float(animation.frame_times[index]):
				current_frame = index
	if sequence_name.begins_with("effect:"):
		current_frame = int(time / float(animation.delay)) % animation.frames.size()
	var frame_key: String = animation.frames[current_frame]
	body.visible = not frame_key.is_empty()
	if body.visible:
		var sprite: Dictionary = catalog.sprites[frame_key]
		body.texture = prepare_texture(frame_key)
		body.scale.x = -1.0 if active.mirrored else 1.0
		body.position = Vector2(float(sprite.offset[0]) * body.scale.x, sprite.offset[1] + float(catalog.ground_offset))
	_render_effects()
	if combat_effect != null and effects_enabled:
		var music_stage := combat_effect.get("music_stage") as Node2D
		if music_stage != null:
			music_stage.sample_idle(local_time if current_clip == "stand" else -1.0)
	if combat_effect != null and combat_effect.has_method("apply_body"):
		if effects_enabled:
			combat_effect.apply_body(body)
		else:
			body.material = null


func _render_effects() -> void:
	for tail: Dictionary in effect_tails:
		_render_effect_batch(tail.events, tail.instances, tail.combat, float(tail.clock))
	_render_effect_batch(effect_events, effect_instances, combat_effect, effect_clock)


func _render_effect_batch(events: Array, instances: Dictionary, custom_effect: Node2D, time: float) -> void:
	if custom_effect != null:
		custom_effect.visible = effects_enabled
		if shared_music_stage != null:
			shared_music_stage.reset_action_state()
			shared_music_stage.material = custom_effect.get_meta("stage_material", shared_music_stage.material)
		custom_effect.sample(time, target_position + target_center_offset, target_effects_enabled)
	EffectScript.load_catalog()
	for index in events.size():
		var event: Dictionary = events[index]
		var age := time - float(event.start)
		var target_side: bool = event.anchor in ["target", "target_center"]
		var enabled: bool = effects_enabled and (not target_side or target_effects_enabled)
		var source: Dictionary = EffectScript.catalog.effects.get(event.effect, {})
		var sample_time: float = age * float(event.get("time_scale", 1.0))
		var active := sample_time >= 0.0 and sample_time < float(source.get("frame_count", 0)) / float(EffectScript.catalog.fps)
		if active and enabled and not instances.has(index):
			var instance := _take_effect("baked:" + event.effect)
			if instance == null:
				instance = EffectScript.new()
				add_child(instance)
				instance.configure(event.effect)
				instance.set_meta("pool_key", "baked:" + event.effect)
			instance.z_index = -2 if int(event.layer) in [1, 2, 4] else 2
			instances[index] = instance
		if not instances.has(index):
			continue
		var instance: Node2D = instances[index]
		instance.visible = enabled
		var origin := Vector2.ZERO
		if target_side:
			origin = target_position
		if event.anchor == "target_center":
			origin += target_center_offset
		instance.position = origin + Vector2(event.offset[0], event.offset[1])
		instance.scale = Vector2(event.scale[0], event.scale[1])
		instance.call("sample", sample_time if enabled else -1.0)


func _emit_effect_hits(events: Array, custom_effect: Node2D, time: float, delta: float) -> void:
	for event: Dictionary in events:
		if event.conditional_hit and float(event.start) >= time - delta and float(event.start) < time and target_effects_enabled:
			target_hit.emit()
	if custom_effect != null and effects_enabled and target_effects_enabled and custom_effect.profile.get("target_hit", true):
		for hit_time: float in custom_effect.profile.get("hit_events", [custom_effect.profile.hit]):
			if hit_time >= time - delta and hit_time < time:
				if custom_effect.profile.has("hit_audio"):
					_play_cue(custom_effect.profile.hit_audio)
				target_hit.emit()


func _retain_effect_tail() -> void:
	EffectScript.load_catalog()
	var end := 0.0
	for event: Dictionary in effect_events:
		var source: Dictionary = EffectScript.catalog.effects[event.effect]
		var length := float(source.frame_count) / float(EffectScript.catalog.fps) / float(event.get("time_scale", 1.0))
		end = maxf(end, float(event.start) + length)
	if combat_effect != null:
		end = maxf(end, float(combat_effect.profile.return_at) + float(combat_effect.profile.return_duration))
	if end <= effect_clock:
		return
	effect_tails.append({"events": effect_events, "instances": effect_instances,
		"combat": combat_effect, "clock": effect_clock, "duration": end})
	effect_instances = {}
	combat_effect = null


func _free_effect_tail(tail: Dictionary) -> void:
	for instance: Node2D in tail.instances.values():
		_release_effect(instance)
	if tail.combat != null:
		_release_effect(tail.combat)


func _take_effect(key: String) -> Node2D:
	if shared_music_stage == null or not _cached_effects.has(key) or _cached_effects[key].is_empty():
		return null
	return _cached_effects[key].pop_back()


func _release_effect(effect: Node2D) -> void:
	if shared_music_stage == null or not effect.has_meta("pool_key"):
		remove_child(effect)
		effect.queue_free()
		return
	effect.hide()
	var key: String = effect.get_meta("pool_key")
	if not _cached_effects.has(key):
		_cached_effects[key] = []
	_cached_effects[key].append(effect)


func _clear_effect_tails() -> void:
	for tail: Dictionary in effect_tails:
		_free_effect_tail(tail)
	effect_tails.clear()


func refresh_pose() -> void:
	_render()


func _play_cue(cue: Dictionary) -> void:
	var kind: String = cue.kind
	if (kind == "voice" and not voice_enabled) or (kind == "sfx" and not sfx_enabled):
		return
	if is_instance_valid(audio_coordinator) and not audio_coordinator.allow_cue(cue):
		return
	if cue.get("exclusive_heavy", false) and _audio_nodes.any(func(node: AudioStreamPlayer): return is_instance_valid(node) and node.playing and node.get_meta("exclusive_heavy", false)):
		return
	var path: String = cue.paths[_rng.randi_range(0, cue.paths.size() - 1)]
	if not audio_streams.has(path):
		audio_streams[path] = AudioStreamWAV.load_from_file(path, {})
	if audio_streams[path] == null:
		push_error("Cannot load Miku audio " + path)
		return
	var player := AudioStreamPlayer.new()
	player.stream = audio_streams[path]
	var gain := linear_to_db(maxf(0.0001, float(cue.volume)))
	gain += float(cue.get("gain_db_by_path", {}).get(path, 0.0))
	player.volume_db = (voice_volume_db if kind == "voice" else sfx_volume_db) + gain
	player.set_meta("kind", kind)
	player.set_meta("cue_gain", gain)
	player.set_meta("exclusive_heavy", cue.get("exclusive_heavy", false))
	player.set_meta("finish_on_idle", cue.get("finish_on_idle", false))
	player.set_meta("sync_timeline", cue.get("sync_timeline", false))
	if cue.get("sync_timeline", false):
		player.pitch_scale = speed
	add_child(player)
	_audio_nodes.append(player)
	player.finished.connect(player.queue_free)
	player.play()
	if is_instance_valid(audio_coordinator):
		audio_coordinator.cue_started(player)


func _stop_audio(keep_heavy := true, keep_action_tail := false) -> void:
	var retained: Array[AudioStreamPlayer] = []
	for player in _audio_nodes:
		if is_instance_valid(player):
			var keep := (keep_heavy and bool(player.get_meta("exclusive_heavy", false))) or \
				(keep_action_tail and bool(player.get_meta("finish_on_idle", false)))
			if keep and player.playing:
				retained.append(player)
				continue
			player.stop()
			player.queue_free()
	_audio_nodes = retained


func _process(delta: float) -> void:
	var start := Time.get_ticks_usec()
	advance(minf(delta, 0.2) * speed)
	last_update_usec = Time.get_ticks_usec() - start


func _exit_tree() -> void:
	_stop_audio(false)
