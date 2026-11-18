extends Node

signal completed

const ActorScript = preload("res://Miku_Hcxmmx/Runtime/Actor.gd")
const EffectScript = preload("res://Miku_Hcxmmx/Runtime/EffectPlayer.gd")
const AudioScript = preload("res://Miku_Hcxmmx/Runtime/BattleAudio.gd")
const StageScript = preload("res://Miku_Hcxmmx/Runtime/MusicStage.gd")
const ImpactScript = preload("res://Miku_Hcxmmx/Runtime/ActionEffect.gd")

var prepared := false
var retained: Dictionary = {}
var _worker := Thread.new()
var _view: SubViewport
var cached_actor: Node2D


func _ready() -> void:
	add_to_group("miku_warmup")
	prepare.call_deferred()


func acquire_actor() -> Node2D:
	var result := cached_actor
	if result != null:
		remove_child(result)
		cached_actor = null
	return result


func _exit_tree() -> void:
	if _worker.is_started():
		_worker.wait_to_finish()


func _menu_frame() -> void:
	await get_tree().process_frame
	while get_tree().get_nodes_in_group("miku_battles").size() > 0:
		if _view != null:
			_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		await get_tree().process_frame


func _read_frames(path: String) -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(path)).frames


func _read_audio(path: String) -> AudioStreamWAV:
	return AudioStreamWAV.load_from_file(path, {})


func _background(task: Callable) -> Variant:
	var error := _worker.start(task)
	if error != OK:
		return task.call()
	while _worker.is_alive():
		await get_tree().process_frame
	return _worker.wait_to_finish()


func _collect_paths(value: Variant, images: Dictionary, audio: Dictionary) -> void:
	if value is Dictionary:
		for child: Variant in value.values():
			_collect_paths(child, images, audio)
	elif value is Array:
		for child: Variant in value:
			_collect_paths(child, images, audio)
	elif value is String and value.begins_with("res://"):
		if value.get_extension() == "png":
			images[value] = true
		elif value.get_extension() == "wav":
			audio[value] = true


func prepare() -> void:
	await _menu_frame()
	ActorScript.load_catalog()
	EffectScript.load_catalog()
	AudioScript.load_catalog()
	var drafts := ActorScript.load_draft_data()
	ActorScript.catalog.animations.merge(drafts.animations)
	var images: Dictionary = {"res://Miku_Hcxmmx/Assets/Icons/thumbs_down_reference.png": true}
	var audio: Dictionary = {}
	var frames: Dictionary = {}
	var effects: Dictionary = {}
	for performance: Dictionary in drafts.game_performances.values():
		_collect_paths(performance, images, audio)
		for segment: Dictionary in performance.get("segments", []):
			for key: String in ActorScript.catalog.animations[segment.clip].frames:
				if not key.is_empty():
					frames[key] = true
			_collect_paths(ActorScript.catalog.audio.get(segment.action, []), images, audio)
		for event: Dictionary in performance.get("effects", {}).get("events", []):
			effects[event.effect] = true
	for name: String in ActorScript.catalog.adapted_performance_names:
		_collect_paths(ActorScript.catalog.performances[name], images, audio)
	for key: String in frames:
		images[ActorScript.catalog.sprites[key].atlas] = true
	for row: Dictionary in AudioScript.catalog.melodies.values():
		audio[row.path] = true
	for group: Dictionary in AudioScript.catalog.get("light_groups", []):
		for row: Dictionary in group.clips:
			audio[row.path] = true
	var materials: Dictionary = {}
	for name: String in effects:
		await _menu_frame()
		EffectScript.pinned_effects[name] = true
		if not EffectScript.frame_data.has(name):
			EffectScript.frame_data[name] = await _background(_read_frames.bind(EffectScript.catalog.effects[name].frames_path))
		for frame: Array in EffectScript.frame_data[name]:
			for draw: Dictionary in frame:
				materials[int(draw.material)] = true
	for id: int in materials:
		var path: String = EffectScript.catalog.materials[id].texture
		if not path.is_empty():
			images[path] = true
	# Keep strong references after warmup so room changes cannot evict textures.
	for path: String in images:
		await _menu_frame()
		var error := ResourceLoader.load_threaded_request(path)
		if error != OK:
			push_warning("[MikuSkin] Warmup texture request failed: " + path)
			continue
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			retained[path] = ResourceLoader.load_threaded_get(path)
	for key: String in frames:
		ActorScript.prepare_texture(key)
	for path: String in audio:
		await _menu_frame()
		if not ActorScript.audio_streams.has(path):
			ActorScript.audio_streams[path] = await _background(_read_audio.bind(path))
		AudioScript.streams[path] = ActorScript.audio_streams[path]
	for id: int in materials:
		EffectScript.prepare_material(id)
	var budget_start := Time.get_ticks_usec()
	for name: String in effects:
		var builder := EffectScript.new()
		builder.effect_name = name
		builder._frames = EffectScript.frame_data[name]
		if not EffectScript.prepared.has(name):
			EffectScript.prepared[name] = {}
		for index in builder._frames.size():
			builder._prepare_frame(index)
			if Time.get_ticks_usec() - budget_start >= 2000:
				await _menu_frame()
				budget_start = Time.get_ticks_usec()
		builder.free()
	await _render_actions(drafts.game_performances.keys())
	prepared = true
	print("[MikuSkin] Battle warmup ready: body_frames=", frames.size(), " effects=", effects.size(), " textures=", retained.size(), " audio=", audio.size(), " (retained across rooms).")
	completed.emit()


func _render_actions(names: Array) -> void:
	await _menu_frame()
	_view = SubViewport.new()
	_view.size = Vector2i(1024, 768)
	_view.disable_3d = true
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	var actor := ActorScript.new()
	actor.voice_enabled = false
	actor.sfx_enabled = false
	actor.position = Vector2(400, 610)
	actor.target_position = Vector2(300, 0)
	_view.add_child(actor)
	actor.set_process(false)
	actor.load_game()
	actor.shared_music_stage = StageScript.new()
	actor.add_child(actor.shared_music_stage)
	actor.shared_music_stage.configure(actor.catalog.performances.sts2_shootBow.combat_effect.textures.glow)
	# Render offscreen once per phase to compile the actual shader variants.
	for name: String in names:
		await _menu_frame()
		actor.play(name)
		for time in [.06, .25, .55, 1.0]:
			await _menu_frame()
			actor.seek(minf(time, actor.duration - .001))
			_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var impact := ImpactScript.new()
	actor.add_child(impact)
	impact.configure(actor.catalog.performances.sts2_attack.combat_effect.hit_profile)
	impact.sample(.3, Vector2(250, -150), true)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	await _menu_frame()
	impact.free()
	actor.play("stand", true)
	actor.reparent(self, false)
	actor.hide()
	cached_actor = actor
	_view.queue_free()
	_view = null
