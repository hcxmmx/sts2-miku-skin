extends Node2D

const ActorScript = preload("res://Miku_Hcxmmx/Runtime/Actor.gd")
const EffectScript = preload("res://Miku_Hcxmmx/Runtime/EffectPlayer.gd")
const CombatEffectScript = preload("res://Miku_Hcxmmx/Runtime/CombatEffect.gd")
const ActionEffectScript = preload("res://Miku_Hcxmmx/Runtime/ActionEffect.gd")
const MusicStageScript = preload("res://Miku_Hcxmmx/Runtime/MusicStage.gd")
const BattleAudioScript = preload("res://Miku_Hcxmmx/Runtime/BattleAudio.gd")
const ACTIONS = {"Attack": "sts2_attack", "shootBow": "sts2_shootBow", "PowerUp": "sts2_powerUp",
	"Cast": "s100", "Block": "defence", "Hit": "behit_middle", "Dead": "lose", "Victory": "winpose"}

var actor: Node2D
var original: Node2D
var original_color := Color.WHITE
var original_visible := true
var configured := false
var actor_bounds := Rect2()
var native_bounds := Rect2()
var size_factor := 1.0
var queued_action := ""
var target_ref: WeakRef
var target_offset := Vector2.ZERO
var impacts: Array[Dictionary] = []
var _cached_impacts: Dictionary = {}
var audio_gain := 1.0
var mute_in_background := true
var flashes: Array[Dictionary] = []
var dead := false
var combat_ended := false
var battle_audio: Node
var music_gain := 1.0
var _last_audio_mix := Vector3(-1, -1, -1)
var action_bags: Dictionary = {}
var _perf_time := 0.0
var _perf_frames := 0
var _perf_actor_usec := 0
var _perf_stage_usec := 0
var _perf_reports := 0
signal music_finished


func _enter_tree() -> void:
	# Game-over presentation reparents the existing visuals, without running _ready again.
	if configured:
		if not RenderingServer.frame_pre_draw.is_connected(_hide_original):
			RenderingServer.frame_pre_draw.connect(_hide_original)
		_hide_original()


func _ready() -> void:
	add_to_group("miku_battles")
	var warmup := get_tree().get_first_node_in_group("miku_warmup")
	actor = warmup.acquire_actor() if warmup != null else null
	if actor == null:
		actor = ActorScript.new()
	add_child(actor)
	actor.load_game()
	actor.position = Vector2.ZERO
	actor.scale = Vector2.ONE
	actor.voice_enabled = true
	actor.sfx_enabled = true
	actor.show()
	actor.set_process(true)
	if actor.shared_music_stage == null:
		actor.shared_music_stage = MusicStageScript.new()
		actor.add_child(actor.shared_music_stage)
		actor.shared_music_stage.configure(actor.catalog.performances.sts2_shootBow.combat_effect.textures.glow)
	actor.shared_music_stage.reset_for_combat()
	actor.play("stand", true)
	actor.target_effects_enabled = false
	battle_audio = BattleAudioScript.new()
	add_child(battle_audio)
	actor.audio_coordinator = battle_audio
	actor.shared_music_stage.audio_driver = battle_audio
	actor.shared_music_stage.audio_clips = actor.catalog.music_clips
	var frame: Dictionary = actor.catalog.sprites[actor.catalog.animations.stand.frames[0]]
	actor_bounds = Rect2(Vector2(frame.offset[0], frame.offset[1] + float(actor.catalog.ground_offset)), Vector2(frame.region[2], frame.region[3]))


func configure(body: Node2D, bounds_position: Vector2, bounds_size: Vector2, enter := true) -> bool:
	if bounds_size.x <= 0 or bounds_size.y <= 0:
		return false
	original = body
	original_color = body.modulate
	original_visible = body.visible
	native_bounds = Rect2(bounds_position, bounds_size)
	size_factor = minf(bounds_size.x * .95 / actor_bounds.size.x, bounds_size.y / actor_bounds.size.y)
	configured = true
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_sync_body()
	RenderingServer.frame_pre_draw.connect(_hide_original)
	_hide_original()
	if enter:
		_play_action(_choose_action("Intro"))
	else:
		handle_trigger("Dead")
	return true


func _sync_body() -> void:
	actor.scale = Vector2(size_factor * (1 if original.scale.x >= 0 else -1), size_factor)
	actor.position = Vector2(native_bounds.get_center().x - actor_bounds.get_center().x * actor.scale.x,
		native_bounds.end.y - actor_bounds.end.y * size_factor)


func _hide_original() -> void:
	if is_instance_valid(original):
		original.visible = not dead
		original.modulate.a = 0.0


func handle_trigger(trigger: String) -> void:
	_hide_original()
	if not ACTIONS.has(trigger):
		return
	if dead or (combat_ended and trigger != "Dead"):
		return
	if trigger == "Dead":
		dead = true
		_hide_original()
		_finish_audio()
	if trigger == "Victory":
		combat_ended = true
		_finish_audio()
	if trigger == "Attack":
		battle_audio.play_light()
	if trigger == "Block" and actor.sequence_name == "game_block" and actor.clock < .9:
		actor.clock = .21
		actor.effect_clock = .21
		actor.paused = false
		return
	if trigger == "Attack" and actor.sequence_name == "sts2_attack" and actor.clock < .42:
		queued_action = "sts2_attack"
		return
	queued_action = ""
	_play_action(_choose_action(trigger))


func _choose_action(trigger: String) -> String:
	var bag: Array = action_bags.get(trigger, [])
	if bag.is_empty():
		bag = actor.catalog.game_pools[trigger].duplicate()
		bag.shuffle()
	var action: String = bag.pop_back()
	action_bags[trigger] = bag
	return action


func _play_action(name: String) -> void:
	print("[MikuSkin] Body ", name)
	var sfx_enabled: bool = actor.sfx_enabled
	if name == "sts2_attack" and (battle_audio.music.playing or battle_audio.uses_light_clips()):
		actor.sfx_enabled = false
	actor.play(name, true)
	actor.sfx_enabled = sfx_enabled
	actor.looping = name == "stand"
	actor.return_to_idle = not dead and not combat_ended
	actor.effect_events = actor.effect_events.filter(func(event: Dictionary): return not event.conditional_hit)
	if actor.combat_effect != null:
		actor.combat_effect.profile = actor.combat_effect.profile.duplicate(true)
		actor.combat_effect.profile.marker_enabled = false
	_apply_audio()


func finish_combat() -> void:
	handle_trigger("Victory")


func _finish_audio() -> void:
	battle_audio.finish()
	actor._stop_audio(false)
	music_finished.emit()


func set_music_enabled(enabled: bool) -> bool:
	return battle_audio.enable_music(enabled and not dead and not combat_ended)


func set_light_enabled(enabled: bool) -> void:
	battle_audio.set_light_enabled(enabled)


var shooting_impact_boost := false


func set_clip_mix(volume: float, impact_boost: bool) -> void:
	battle_audio.set_clip_volume(volume)
	shooting_impact_boost = impact_boost


func play_melody(kind: String) -> bool:
	if not battle_audio.play_melody(kind):
		return false
	for player: AudioStreamPlayer in actor._audio_nodes:
		if is_instance_valid(player) and player.get_meta("kind", "") == "voice" and not player.get_meta("exclusive_heavy", false):
			player.stop()
	return true


func revive() -> void:
	dead = false
	combat_ended = false
	battle_audio.ended = false
	_hide_original()
	queued_action = ""
	_play_action("stand")


func hit_delay() -> float:
	return float(actor.catalog.performances.sts2_shootBow.combat_effect.hit)


func aim_at(target: Node2D, center: Vector2) -> void:
	target_ref = weakref(target)
	target_offset = target.to_local(center)
	_update_aim()


func _update_aim() -> void:
	var target := target_ref.get_ref() as Node2D if target_ref != null else null
	if is_instance_valid(target):
		actor.target_position = actor.to_local(target.to_global(target_offset))
		actor.target_center_offset = Vector2.ZERO


func confirm_hit(trigger: String, target: Node2D, center: Vector2, layer: Node = null, body: CanvasItem = null, play_sound := true, hurt := true) -> bool:
	if dead or combat_ended or trigger not in ["Attack", "shootBow"]:
		return false
	print("[MikuSkin] Impact ", trigger, " at ", center)
	if trigger == "Attack":
		battle_audio.accent()
	var effect: Node2D
	var host: Node = layer if is_instance_valid(layer) else self
	if _cached_impacts.has(trigger) and not _cached_impacts[trigger].is_empty():
		effect = _cached_impacts[trigger].pop_back()
		effect.reparent(host, false)
	else:
		effect = ActionEffectScript.new() if trigger == "Attack" else CombatEffectScript.new()
		host.add_child(effect)
		var profile: Dictionary = actor.catalog.performances.sts2_attack.combat_effect.hit_profile.duplicate(true) if trigger == "Attack" else actor.catalog.performances.sts2_shootBow.combat_effect.duplicate(true)
		profile.hit = 0.0
		profile.source_enabled = false
		profile.marker_enabled = false
		if trigger == "Attack":
			profile.duration = float(profile.impact_duration) + .04
			profile.return_at = profile.duration
		effect.configure(profile)
		effect.set_meta("impact_kind", trigger)
	effect.show()
	var length: float = effect.profile.duration if trigger == "Attack" else float(effect.profile.get("impact_duration", .34))
	if trigger == "shootBow":
		if play_sound:
			_apply_audio()
			var cue: Dictionary = effect.profile.hit_audio
			if not shooting_impact_boost:
				cue = cue.merged({"volume": 1.0}, true)
			actor._play_cue(cue)
		if hurt and is_instance_valid(body):
			_flash_target(body)
	effect.z_index = 10
	effect.global_scale = global_scale.abs() * size_factor
	effect.global_position = center
	var origin: Array = actor.catalog.performances.sts2_shootBow.combat_effect.origin if trigger == "shootBow" else actor.catalog.performances.sts2_attack.combat_effect.hit_profile.origin
	var local_origin := effect.to_local(actor.to_global(Vector2(origin[0], origin[1])))
	effect.profile.origin = [local_origin.x, local_origin.y]
	impacts.append({"node": effect, "target": weakref(target), "offset": target.to_local(center),
		"clock": 0.0, "duration": length, "custom": true})
	_sample_impact(impacts.back())
	return true


func _release_impact(effect: Node2D) -> void:
	effect.hide()
	if effect.get_parent() != self:
		effect.reparent(self, false)
	var kind: String = effect.get_meta("impact_kind")
	if not _cached_impacts.has(kind):
		_cached_impacts[kind] = []
	_cached_impacts[kind].append(effect)


func _flash_target(body: CanvasItem) -> void:
	for flash: Dictionary in flashes:
		if flash.target.get_ref() == body:
			flash.clock = 0.0
			return
	flashes.append({"target": weakref(body), "base": body.modulate, "last": body.modulate, "clock": 0.0})
	_update_flashes(0.0)


func _update_flashes(delta: float) -> void:
	for index in range(flashes.size() - 1, -1, -1):
		var flash: Dictionary = flashes[index]
		var body := flash.target.get_ref() as CanvasItem
		if not is_instance_valid(body) or body.modulate != flash.last:
			flashes.remove_at(index)
			continue
		flash.clock += delta
		var flash_duration: float = actor.catalog.performances.sts2_shootBow.combat_effect.get("impact_flash_duration", .085)
		var brightness := 1 + maxf(0, 1 - float(flash.clock) / flash_duration) * 1.4
		flash.last = flash.base * Color(brightness, brightness, brightness, 1)
		body.modulate = flash.last
		if float(flash.clock) >= flash_duration:
			flashes.remove_at(index)


func _sample_impact(impact: Dictionary) -> void:
	var effect: Node2D = impact.node
	var target := impact.target.get_ref() as Node2D
	if is_instance_valid(target):
		effect.global_position = target.to_global(impact.offset)
	if impact.custom:
		effect.sample(float(impact.clock), Vector2.ZERO, true)
	else:
		effect.sample(float(impact.clock))


func set_audio_policy(gain: float, background: bool, bgm_gain := 1.0) -> void:
	audio_gain = clampf(gain, 0.0, 1.0)
	mute_in_background = background
	music_gain = clampf(bgm_gain, 0.0, 1.0)
	_apply_audio()


func _apply_audio() -> void:
	var gain := audio_gain
	if mute_in_background and not DisplayServer.window_is_focused():
		gain = 0.0
	var mix := Vector3(gain, music_gain, 1 if mute_in_background and not DisplayServer.window_is_focused() else 0)
	if mix == _last_audio_mix:
		return
	_last_audio_mix = mix
	var decibels := linear_to_db(maxf(.0001, gain))
	actor.set_volume("voice", decibels)
	actor.set_volume("sfx", decibels)
	battle_audio.set_mix(audio_gain, music_gain, mute_in_background and not DisplayServer.window_is_focused())


func _process(delta: float) -> void:
	if not configured:
		return
	if not is_instance_valid(original):
		queue_free()
		return
	_sync_body()
	actor.shared_music_stage.continuous_time += delta
	_update_aim()
	_apply_audio()
	_update_flashes(delta)
	if not queued_action.is_empty() and actor.sequence_name == "stand":
		var next := queued_action
		queued_action = ""
		_play_action(next)
	for index in range(impacts.size() - 1, -1, -1):
		var impact: Dictionary = impacts[index]
		impact.clock += delta
		if float(impact.clock) >= float(impact.duration):
			_release_impact(impact.node)
			impacts.remove_at(index)
		else:
			_sample_impact(impact)
	_sample_performance(delta)


func _sample_performance(delta: float) -> void:
	if _perf_reports >= 6:
		return
	_perf_time += delta
	_perf_frames += 1
	_perf_actor_usec += actor.last_update_usec
	_perf_stage_usec += actor.shared_music_stage.last_draw_usec
	if _perf_time < 2.0:
		return
	var report := {
		"action": actor.sequence_name,
		"fps": _perf_frames / _perf_time,
		"frame_ms": _perf_time * 1000 / _perf_frames,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
		"actor_ms": _perf_actor_usec / (_perf_frames * 1000.0),
		"stage_draw_ms": _perf_stage_usec / (_perf_frames * 1000.0),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"battles": get_tree().get_nodes_in_group("miku_battles").size(),
		"viewport": str(get_viewport().get_visible_rect().size),
		"fps_limit": Engine.max_fps,
		"focused": DisplayServer.window_is_focused(),
	}
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		report.render_cpu_ms = RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
		report.render_gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
	print("[MikuPerf] ", JSON.stringify(report))
	_perf_time = 0
	_perf_frames = 0
	_perf_actor_usec = 0
	_perf_stage_usec = 0
	_perf_reports += 1
	if _perf_reports == 6 and RenderingServer.get_current_rendering_method() != "gl_compatibility":
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)


func _exit_tree() -> void:
	if configured and _perf_reports < 6 and RenderingServer.get_current_rendering_method() != "gl_compatibility":
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
	for flash: Dictionary in flashes:
		var body := flash.target.get_ref() as CanvasItem
		if is_instance_valid(body) and body.modulate == flash.last:
			body.modulate = flash.base
	flashes.clear()
	for impact: Dictionary in impacts:
		if is_instance_valid(impact.node):
			impact.node.queue_free()
	impacts.clear()
	if RenderingServer.frame_pre_draw.is_connected(_hide_original):
		RenderingServer.frame_pre_draw.disconnect(_hide_original)
	if is_instance_valid(original):
		original.modulate = original_color
		original.visible = original_visible
