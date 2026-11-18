extends SceneTree

var checks: Dictionary = {}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		if not ProjectSettings.load_resource_pack(args[0]):
			push_error("Could not mount test package")
			quit(1)
			return
	var battle: Node2D = load("res://Miku_Hcxmmx/Battle.tscn").instantiate()
	var host := Node2D.new()
	root.add_child(host)
	var original := Node2D.new()
	host.add_child(original)
	host.add_child(battle)
	await process_frame
	battle.set_process(false)
	battle.actor.set_process(false)
	checks.initialized = battle.configure(original, Vector2(-100, -300), Vector2(200, 300), true)
	battle.set_light_enabled(false)
	battle.set_audio_policy(1.0, false)
	checks.unity_audio_gain = is_zero_approx(battle.actor.voice_volume_db) and is_zero_approx(battle.actor.sfx_volume_db)
	checks.entrance = battle.actor.sequence_name in ["sts2_intro", "sts2_intro_alt"] and not battle.actor.looping
	checks.native_hidden = original.visible and is_zero_approx(original.modulate.a)
	checks.ground_alignment = is_equal_approx(battle.actor.position.y + battle.actor_bounds.end.y * battle.size_factor, 0.0)
	battle.handle_trigger("Attack")
	checks.attack = battle.actor.sequence_name == "sts2_attack" and is_equal_approx(battle.actor.duration, .42) and not battle.actor.looping
	checks.target_effect_requires_hit = battle.actor.effect_events.is_empty() and battle.impacts.is_empty()
	for trigger in ["Idle", "Relaxed", "Unknown"]:
		battle.handle_trigger(trigger)
	checks.missing_ignored = battle.actor.sequence_name == "sts2_attack"
	var target := Node2D.new()
	host.add_child(target)
	target.position = Vector2(500, 0)
	var target_body := Node2D.new()
	target.add_child(target_body)
	var foreground := Node2D.new()
	host.add_child(foreground)
	var center := target.global_position + Vector2(0, -150)
	battle.aim_at(target, center)
	checks.aim = battle.actor.to_global(battle.actor.target_position).is_equal_approx(center)
	battle.confirm_hit("Attack", target, center, foreground, target_body)
	checks.real_target_impact = battle.impacts.size() == 1 and battle.impacts[0].node.effect_name == "miku/miku_s200_04_a"
	var impact: Node2D = battle.impacts[0].node
	checks.impact_foreground = impact.get_parent() == foreground and impact.z_index == 10
	battle.actor.advance(.43)
	battle._process(.43)
	checks.idle_after_attack = battle.actor.sequence_name == "stand" and battle.actor.looping
	checks.impact_outlives_body = battle.impacts.size() == 1 and impact.visible_draw_count() > 0
	target.position.x += 80
	battle._process(.01)
	checks.impact_follows_target = impact.global_position.is_equal_approx(center + Vector2(80, 0))
	battle.handle_trigger("Attack")
	checks.next_action_keeps_impact = battle.impacts.size() == 1 and not impact.is_queued_for_deletion()
	battle.handle_trigger("Attack")
	battle.handle_trigger("Attack")
	checks.queued_once = battle.queued_action == "sts2_attack"
	battle.actor.advance(.43)
	battle._process(.01)
	checks.queued_runs = battle.queued_action.is_empty() and battle.actor.sequence_name == "sts2_attack"
	battle.handle_trigger("shootBow")
	checks.strong = battle.actor.sequence_name == "sts2_shootBow" and not battle.actor.combat_effect.profile.marker_enabled and not battle.actor.target_effects_enabled
	checks.strong_timing = is_equal_approx(battle.hit_delay(), .22)
	battle.actor.advance(.1)
	battle.handle_trigger("shootBow")
	checks.strong_restarts_on_native_trigger = is_zero_approx(battle.actor.clock) and battle.queued_action.is_empty()
	var audio_before: int = battle.actor._audio_nodes.size()
	battle.confirm_hit("shootBow", target, center + Vector2(80, 0), foreground, target_body)
	checks.strong_impact = battle.impacts.size() == 2 and battle.impacts.back().node.visible_draw_count() > 0
	var strong_effect: Node2D = battle.impacts.back().node
	checks.strong_impact_tripled = is_equal_approx(strong_effect._impact_glow.scale.x * strong_effect._impact_glow.texture.get_width(), 345.0)
	checks.strong_impact_extended = is_equal_approx(float(battle.impacts.back().duration), .75)
	checks.strong_hit_sound = battle.actor._audio_nodes.size() == audio_before + 1
	checks.target_flash = target_body.modulate.r > 2.0
	battle._process(.2)
	checks.target_flash_restored = target_body.modulate == Color.WHITE
	battle.handle_trigger("PowerUp")
	checks.powerup = battle.actor.current_clip == "s200" and is_equal_approx(battle.actor.duration, 1.0)
	battle._process(3.0)
	checks.impact_cleanup = battle.impacts.is_empty()
	battle.handle_trigger("Cast")
	checks.cast = battle.actor.sequence.map(func(segment: Dictionary): return segment.name) == ["s100", "s101"] and is_equal_approx(battle.actor.duration, 2.2)
	battle.handle_trigger("Block")
	checks.block = battle.actor.current_clip == "defence" and is_equal_approx(battle.actor.duration, .7)
	battle.handle_trigger("Hit")
	checks.hurt = battle.actor.current_clip == "behit_middle" and is_equal_approx(battle.actor.duration, .3)
	battle.actor.advance(.31)
	checks.hurt_returns_idle = battle.actor.sequence_name == "stand"
	battle._play_action("sts2_intro_alt")
	checks.alternate_entrance = battle.actor.current_clip == "show01" and is_equal_approx(battle.actor.duration, 2.3)
	battle.finish_combat()
	battle.actor.advance(3.7)
	checks.victory = battle.combat_ended and battle.actor.current_clip == "winpose" and battle.actor.paused
	battle.handle_trigger("Cast")
	checks.victory_holds = battle.actor.current_clip == "winpose"
	original.show()
	original.modulate = Color.WHITE
	battle.handle_trigger("Dead")
	checks.death_hides_native_body = not original.visible and is_zero_approx(original.modulate.a)
	var death_voices: Array = battle.actor._audio_nodes.filter(func(player: AudioStreamPlayer): return is_instance_valid(player) and player.get_meta("kind", "") == "voice")
	checks.death_voice = death_voices.size() == 1 and death_voices[0].playing and death_voices[0].stream == battle.actor.audio_streams["res://Miku_Hcxmmx/Assets/Audio/voice/miku/miku_08.wav"]
	battle.handle_trigger("Dead")
	checks.death_voice_once = battle.actor._audio_nodes.size() == 1 and battle.actor._audio_nodes[0] == death_voices[0]
	battle.actor.advance(4.0)
	checks.death_standing_hold = battle.dead and battle.actor.current_clip == "lose_loop" and not battle.actor.return_to_idle
	var game_over_layer := Control.new()
	root.add_child(game_over_layer)
	host.reparent(game_over_layer)
	checks.death_reparent_keeps_native_hidden = not original.visible and is_zero_approx(original.modulate.a)
	checks.death_reparent_reconnects_hiding = RenderingServer.frame_pre_draw.is_connected(battle._hide_original)
	checks.death_reparent_keeps_miku_pose = battle.dead and battle.actor.current_clip == "lose_loop"
	original.show()
	original.modulate = Color.WHITE
	RenderingServer.frame_pre_draw.emit()
	checks.death_reparent_draw_hides_native = not original.visible and is_zero_approx(original.modulate.a)
	original.show()
	original.modulate.a = 1.0
	battle._hide_original()
	checks.death_visibility_stays_hidden = not original.visible and is_zero_approx(original.modulate.a)
	battle.handle_trigger("Hit")
	battle.finish_combat()
	checks.death_priority = battle.actor.current_clip == "lose_loop"
	battle.revive()
	checks.revive = not battle.dead and not battle.combat_ended and battle.actor.sequence_name == "stand" and battle.actor.looping
	checks.revive_restores_native_visibility_policy = original.visible and is_zero_approx(original.modulate.a)
	checks.user_melodies = battle.play_melody("wah") and battle.play_melody("cho") and battle.play_melody("ki") and battle.battle_audio.melodies.size() == 1 and battle.battle_audio.melody_queue == ["cho", "ki"]
	battle.play_melody("wah")
	battle.play_melody("cho")
	checks.melody_duplicates_coalesce = battle.battle_audio.melody_queue == ["cho", "ki"]
	var melody_order: Array[String] = []
	for index in 3:
		melody_order.append(battle.battle_audio.active_melody)
		var melody: AudioStreamPlayer = battle.battle_audio.melodies[0]
		melody.stop()
		melody.finished.emit()
	checks.melody_ordered_release = melody_order == ["wah", "cho", "ki"] and battle.battle_audio.melodies.is_empty() and battle.battle_audio.melody_queue.is_empty()
	checks.custom_music = battle.set_music_enabled(true) and battle.battle_audio.music.stream.get_length() > 250
	battle.handle_trigger("Attack")
	checks.music_replaces_light_cue = battle.actor._audio_nodes.is_empty()
	battle.confirm_hit("Attack", target, center, foreground)
	checks.music_hit_accent = is_equal_approx(battle.battle_audio.emphasis, 1.0)
	battle.set_music_enabled(false)
	battle.handle_trigger("Hit")
	battle.handle_trigger("Attack")
	checks.light_cue_without_music = not battle.actor._audio_nodes.is_empty()
	battle.set_light_enabled(true)
	battle.handle_trigger("Hit")
	battle.handle_trigger("Attack")
	var light_audio: Node = battle.battle_audio
	var clips: Array = light_audio.catalog.light_groups[0].clips
	checks.light_group_first = light_audio.light.playing and light_audio.light_index == 1 and light_audio.light.stream == light_audio.streams[clips[0].path] and battle.actor._audio_nodes.is_empty()
	battle.handle_trigger("Attack")
	checks.light_group_busy_skips = light_audio.light_index == 1 and light_audio.light.stream == light_audio.streams[clips[0].path]
	battle.handle_trigger("Block")
	checks.light_survives_actions = light_audio.light.playing and light_audio.light_index == 1
	await create_timer(2.5).timeout
	checks.light_finishes_naturally = not light_audio.light.playing
	battle.handle_trigger("Attack")
	checks.light_group_second = light_audio.light.playing and light_audio.light_index == 2 and light_audio.light.stream == light_audio.streams[clips[1].path]
	light_audio.light.stop()
	battle.handle_trigger("Attack")
	checks.light_group_third = light_audio.light.playing and light_audio.light_index == 3 and light_audio.light.stream == light_audio.streams[clips[2].path]
	light_audio.light.stop()
	battle.set_music_enabled(true)
	battle.handle_trigger("Attack")
	checks.light_group_reselects_with_music = light_audio.music.playing and light_audio.light.playing and light_audio.light_index == 1 and light_audio.light.stream == light_audio.streams[clips[0].path]
	battle.set_light_enabled(false)
	checks.light_option_stops_clip = not light_audio.light.playing and light_audio.light_index == 0
	battle.set_music_enabled(false)
	battle.set_light_enabled(true)
	battle.handle_trigger("Hit")
	battle.handle_trigger("Attack")
	var light_index_before_heavy: int = light_audio.light_index
	battle.handle_trigger("shootBow")
	var heavy: AudioStreamPlayer = battle.actor._audio_nodes.filter(func(player: AudioStreamPlayer): return is_instance_valid(player) and player.get_meta("exclusive_heavy", false))[0]
	checks.user_heavy_clip = heavy.stream.get_length() > 4 and heavy.stream.get_length() < 6
	light_audio._process(.04)
	checks.heavy_fades_light = light_audio.light.playing and light_audio.light_gain > 0 and light_audio.light_gain < 1
	light_audio._process(.05)
	checks.heavy_releases_light = not light_audio.light.playing and not light_audio.light_fading
	battle.handle_trigger("Attack")
	checks.heavy_blocks_light_without_advancing = not light_audio.light.playing and light_audio.light_index == light_index_before_heavy
	battle.play_melody("wah")
	light_audio._process(.1)
	battle.set_audio_policy(1.0, false)
	checks.melody_ducks_heavy = heavy.playing and is_equal_approx(heavy.volume_linear, .25) and is_equal_approx(float(heavy.get_meta("mix_gain")), .25)
	battle.handle_trigger("Hit")
	checks.foreground_blocks_short_voice = battle.actor._audio_nodes.filter(func(player: AudioStreamPlayer): return is_instance_valid(player) and player.playing and player.get_meta("kind", "") == "voice").size() == 1
	var foreground_melody: AudioStreamPlayer = light_audio.melodies[0]
	foreground_melody.stop()
	foreground_melody.finished.emit()
	light_audio._process(.1)
	battle.set_audio_policy(1.0, false)
	checks.heavy_gain_restores = heavy.playing and is_equal_approx(heavy.volume_linear, 1.0)
	battle.handle_trigger("PowerUp")
	battle.handle_trigger("shootBow")
	checks.heavy_survives_actions = is_instance_valid(heavy) and heavy.playing and battle.actor._audio_nodes.has(heavy)
	checks.heavy_no_overlap = battle.actor._audio_nodes.filter(func(player: AudioStreamPlayer): return is_instance_valid(player) and player.get_meta("exclusive_heavy", false)).size() == 1
	heavy.stop()
	battle.handle_trigger("Attack")
	checks.foreground_release_resumes_light = light_audio.light.playing and light_audio.light_index == light_index_before_heavy + 1
	battle.play_melody("ki")
	light_audio._process(.1)
	checks.melody_yields_light = not light_audio.light.playing
	var last_melody: AudioStreamPlayer = light_audio.melodies[0]
	last_melody.stop()
	last_melody.finished.emit()
	light_audio._process(.1)
	battle.handle_trigger("shootBow")
	checks.heavy_released = not battle.actor._audio_nodes.has(heavy) and battle.actor._audio_nodes.any(func(player: AudioStreamPlayer): return is_instance_valid(player) and player.playing and player.get_meta("exclusive_heavy", false))
	battle.set_light_enabled(true)
	battle.handle_trigger("Attack")
	battle.play_melody("cho")
	battle.play_melody("ki")
	battle.finish_combat()
	checks.user_audio_cleanup = not battle.battle_audio.music.playing and not light_audio.light.playing and battle.battle_audio.melodies.is_empty() and light_audio.melody_queue.is_empty() and light_audio.heavy == null and not battle.actor._audio_nodes.any(func(player: AudioStreamPlayer): return is_instance_valid(player) and player.get_meta("exclusive_heavy", false))
	var front := Sprite2D.new()
	host.add_child(front)
	front.self_modulate.a = 0.0
	var note: Node2D = load("res://Miku_Hcxmmx/Runtime/ImpaledNote.gd").new()
	front.add_child(note)
	checks.note_visible = note.note.is_visible_in_tree()
	checks.note_contact_burst = is_equal_approx(note.note.scale.x * note.note.texture.get_width(), 768.0) and note.note.modulate.r > 2.0
	note._process(.1)
	checks.note_peak_hold = is_equal_approx(note.note.scale.x * note.note.texture.get_width(), 768.0)
	note._process(.52)
	checks.note_settled = is_equal_approx(note.note.scale.x * note.note.texture.get_width(), 160.0) and is_equal_approx(note.note.modulate.r, 1.0)
	checks.note_additive = note.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and note.note.use_parent_material and note.ring.use_parent_material
	battle.revive()
	battle.confirm_hit("shootBow", target, center, foreground, target_body, false)
	checks.reparent_has_active_feedback = not battle.impacts.is_empty() and not battle.flashes.is_empty()
	host.reparent(root)
	await process_frame
	battle._process(.01)
	checks.reparent_cleans_feedback = battle.impacts.is_empty() and battle.flashes.is_empty() and target_body.modulate == Color.WHITE
	checks.alive_reparent_keeps_native_hidden = original.visible and is_zero_approx(original.modulate.a) and RenderingServer.frame_pre_draw.is_connected(battle._hide_original)
	battle.queue_free()
	await process_frame
	checks.original_restored = original.visible and is_equal_approx(original.modulate.a, 1.0)
	host.queue_free()
	game_over_layer.queue_free()
	await process_frame
	await create_timer(.1).timeout
	var ok := checks.values().all(func(value): return value == true)
	print("MIKU_BATTLE_CHECK ", JSON.stringify({"ok": ok, "checks": checks}))
	quit(0 if ok else 1)
