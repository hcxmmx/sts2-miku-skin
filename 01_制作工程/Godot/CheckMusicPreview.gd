extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var actor: Node2D = load("res://Miku_Hcxmmx/Runtime/Actor.gd").new()
	root.add_child(actor)
	actor.set_process(false)
	actor.load_drafts()
	actor.play("draft_music_attack")
	var effect: Node2D = actor.combat_effect
	var checks: Dictionary = {}
	checks.starts_ambient = effect.active_clip_id.is_empty() and is_zero_approx(effect.music_stage.activation)
	checks.three_music_requests = actor.cues.size() == 3 and effect.profile.attacks.size() == 9
	actor.seek(1.0)
	checks.first_clip_spectrum = effect.active_clip_index == 0 and effect.music_stage.activation > .99 and effect.music_stage.bands[0] > 0
	checks.hit_pulse = effect.music_stage.emphasis > .99
	var first_progress: float = effect.hits[0]._bursts[0].material.get_shader_parameter("progress")
	actor.seek(1.02)
	checks.readable_peak_hold = is_zero_approx(first_progress) and is_zero_approx(float(effect.hits[0]._bursts[0].material.get_shader_parameter("progress")))
	actor.seek(1.5)
	checks.fast_attacks_keep_same_clip = effect.active_clip_index == 0
	actor.seek(3.2)
	checks.clip_end_returns_ambient = effect.active_clip_id.is_empty() and is_zero_approx(effect.music_stage.activation) and effect.music_stage.visible
	actor.seek(3.7)
	checks.second_clip = effect.active_clip_index == 1
	actor.seek(6.4)
	checks.third_clip = effect.active_clip_index == 2
	actor.seek(9.0)
	checks.finite_hits_persistent_stage = effect.hits.size() == 2 and effect.hits.all(func(hit: Node2D): return hit.visible_draw_count() == 0) and effect.music_stage.visible
	actor.seek(.3)
	checks.reverse_to_ambient = effect.active_clip_index == -1 and actor._audio_nodes.is_empty()
	actor.play("draft_music_attack")
	actor.advance(.82)
	var player: AudioStreamPlayer = actor._audio_nodes[0]
	checks.original_clip_plays = player.playing and player.stream.get_length() > 2.2 and is_equal_approx(player.pitch_scale, 1)
	actor.advance(.45)
	checks.audio_not_restarted = actor._audio_nodes.size() == 1 and actor._audio_nodes[0] == player
	actor.speed = .5
	checks.speed_sync = is_equal_approx(player.pitch_scale, .5)
	actor.set_paused(true)
	checks.pause_sync = player.stream_paused
	actor.speed = 1
	actor.queue_free()
	await process_frame
	await create_timer(.1).timeout
	var ok := checks.values().all(func(value): return value == true)
	print("MIKU_MUSIC_PREVIEW_CHECK ", JSON.stringify({"ok": ok, "checks": checks}))
	quit(0 if ok else 1)
