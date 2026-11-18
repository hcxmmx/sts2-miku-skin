extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var actor: Node2D = load("res://Miku_Hcxmmx/Runtime/Actor.gd").new()
	root.add_child(actor)
	actor.set_process(false)
	actor.set_audio_enabled("voice", false)
	actor.set_audio_enabled("sfx", false)
	actor.load_drafts()
	var checks: Dictionary = {}
	checks.six_candidates = actor.catalog.draft_performance_names.size() == 6
	for name: String in actor.catalog.draft_performance_names:
		actor.play(name)
		var performance: Dictionary = actor.active_performance
		actor.seek(float(performance.combat_effect.hit) + .06)
		var maximum_duration := 10.0 if performance.get("music_demo", false) else 2.0
		checks[name] = actor.combat_effect.visible_draw_count() > 0 and actor.body.texture != null and float(performance.body_duration) < maximum_duration
		actor.effects_enabled = false
		actor.refresh_pose()
		checks[name + "_toggle"] = not actor.combat_effect.visible
		actor.effects_enabled = true
		actor.seek(float(performance.combat_effect.duration) + .01)
		if performance.get("music_demo", false):
			checks[name + "_ambient_after_music"] = actor.combat_effect.active_clip_id.is_empty() and actor.combat_effect.music_stage.visible
		else:
			checks[name + "_effect_finished"] = actor.combat_effect.visible_draw_count() == 0
		actor.play(name)
		actor.advance(actor.duration + .1)
		checks[name + "_idle"] = actor.sequence_name == "stand"
	actor.play("draft_attack")
	actor.seek(float(actor.combat_effect.profile.hit) + .025)
	checks.attack_has_feedback = actor.combat_effect.target_flash > 0 and actor.combat_effect.target_recoil.length() > 0
	actor.target_effects_enabled = false
	actor.refresh_pose()
	checks.target_toggle = actor.combat_effect.visible_draw_count() == 0 and is_zero_approx(actor.combat_effect.target_flash)
	actor.target_effects_enabled = true
	actor.play("draft_powerup_spin")
	actor.seek(.4)
	actor.step_frame(1)
	checks.step_forward = actor.clock > .4
	actor.seek(.1)
	checks.reverse_seek = actor.current_frame < 3 and actor._audio_nodes.is_empty()
	actor.play("sts2_attack")
	checks.live_attack_retained = actor.combat_effect == null and not actor.effect_events.is_empty()
	actor.queue_free()
	await process_frame
	var ok := checks.values().all(func(value): return value == true)
	print("MIKU_DRAFT_CHECK ", JSON.stringify({"ok": ok, "checks": checks}))
	quit(0 if ok else 1)
