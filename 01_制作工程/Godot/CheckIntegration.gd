extends SceneTree

class RoomVisualFixture extends Node2D:
	func get_skeleton() -> Node2D:
		return self
	func get_bounds() -> Rect2:
		return Rect2(-100, -300, 200, 300)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		if not ProjectSettings.load_resource_pack(args[0]):
			push_error("Could not mount Miku runtime pack")
			quit(1)
			return
	var warmup: Node = load("res://Miku_Hcxmmx/Runtime/BattleWarmup.gd").new()
	root.add_child(warmup)
	await warmup.completed
	assert(warmup.prepared and not warmup.retained.is_empty())
	var effect_script: GDScript = load("res://Miku_Hcxmmx/Runtime/EffectPlayer.gd")
	for name: String in effect_script.pinned_effects:
		assert(effect_script.prepared[name].size() == effect_script.frame_data[name].size())
	var host := Node2D.new()
	root.add_child(host)
	var original := Node2D.new()
	host.add_child(original)
	var battle: Node2D = load("res://Miku_Hcxmmx/Runtime/Battle.gd").new()
	host.add_child(battle)
	battle.set_process(false)
	battle.actor.set_process(false)
	battle.actor.set_audio_enabled("voice", false)
	battle.actor.set_audio_enabled("sfx", false)
	battle.battle_audio.light_enabled = false
	var configured: bool = battle.configure(original, Vector2(-100, -350), Vector2(200, 350))
	assert(configured)
	assert(battle.actor.sequence_name in battle.actor.catalog.game_pools.Intro)
	var stage: Node2D = battle.actor.shared_music_stage
	var count := 0
	for names: Array in battle.actor.catalog.game_pools.values():
		for name: String in names:
			battle._play_action(name)
			for time in [0.0, .05, .15, .3, .6, 1.0, 1.8, 3.5]:
				battle.actor.seek(minf(time, battle.actor.duration - .001))
			assert(battle.actor.combat_effect.music_stage == stage)
			assert(is_instance_valid(stage) and stage.get_parent() == battle.actor)
			assert(battle.actor.body.texture != null)
			count += 1
	battle._play_action("stand")
	battle.actor.set_paused(true)
	stage._process(0.0)
	var note_positions := {}
	for note: MeshInstance2D in stage._note_views:
		if note.visible:
			note_positions[note] = note.position
	battle._process(.15)
	stage._process(.15)
	var moved := false
	for note: MeshInstance2D in note_positions:
		if note.visible and not note.position.is_equal_approx(note_positions[note]):
			moved = true
	assert(moved)
	stage.note_opacity = 0.0
	stage._process(0.0)
	assert(stage._visible_notes == 0)
	stage.note_opacity = 1.0
	battle.actor.set_paused(false)
	battle.handle_trigger("Attack")
	assert(battle.actor.active_performance.combat_effect.runtime_live)
	assert(battle.actor.sequence.size() == 2 and is_equal_approx(battle.actor.duration, .62))
	assert(not battle.actor.combat_effect._runtime_note.is_empty())
	var attack_effect: Node2D = battle.actor.combat_effect
	battle._play_action("game_hit")
	battle.handle_trigger("Attack")
	assert(battle.actor.combat_effect == attack_effect)
	var target := Node2D.new()
	host.add_child(target)
	target.position = Vector2(500, 0)
	var light_hit: bool = battle.confirm_hit("Attack", target, Vector2(500, -150), host)
	assert(light_hit)
	assert(battle.impacts.back().node.profile.kind == "light")
	var first_impact: Node2D = battle.impacts.back().node
	var second_hit: bool = battle.confirm_hit("Attack", target, Vector2(500, -150), host)
	assert(second_hit and battle.impacts.back().node != first_impact)
	for impact: Dictionary in battle.impacts:
		impact.clock = float(impact.duration) + .1
	battle._process(0)
	var pooled_hit: bool = battle.confirm_hit("Attack", target, Vector2(500, -150), host)
	assert(pooled_hit and battle.impacts.back().node == first_impact)
	battle.handle_trigger("shootBow")
	assert(is_equal_approx(battle.hit_delay(), .22))
	var heavy_hit: bool = battle.confirm_hit("shootBow", target, Vector2(500, -150), host, null, false)
	assert(heavy_hit)
	battle.handle_trigger("Block")
	var shield: Node2D = battle.actor.combat_effect
	battle.actor.clock = .3
	battle.handle_trigger("Block")
	assert(battle.actor.combat_effect == shield and is_equal_approx(battle.actor.clock, .21))
	battle.handle_trigger("Dead")
	assert(battle.dead and not original.visible)
	var end_layer := Node2D.new()
	root.add_child(end_layer)
	battle.reparent(end_layer)
	assert(not original.visible)
	battle.revive()
	assert(not battle.dead and battle.actor.sequence_name == "stand")
	assert(stage.material == stage._default_material and stage.modulate == Color.WHITE)
	var portrait: Control = load("res://Miku_Hcxmmx/Portrait.tscn").instantiate()
	root.add_child(portrait)
	portrait.set_anchors_preset(Control.PRESET_TOP_LEFT)
	portrait.size = Vector2(1920, 1080)
	var native_background := Control.new()
	root.add_child(native_background)
	portrait.activate(true, [native_background])
	assert(portrait.visible and not native_background.visible)
	portrait.set_light_clips_enabled(false)
	portrait.set_clip_mix(.65, true)
	portrait.sample(1.0)
	portrait.panel._gear.pressed.emit()
	var settings: Panel = portrait.panel._settings
	var toggles := settings.get_children().filter(func(child: Node): return child is CheckButton)
	assert(settings.visible and toggles.size() == 2)
	assert(toggles[0].text == "轻攻击音乐片段" and not toggles[0].button_pressed)
	assert(toggles[1].text == "射击命中增益" and toggles[1].button_pressed)
	assert(is_equal_approx(settings._volume.value, 65.0))
	settings.closed.emit()
	assert(not settings.visible)
	assert(not portrait.actor.lip_enabled and portrait.actor.info.poses.size() == 8)
	portrait.actor.sample(2.0)
	var old_face: Node2D = portrait.actor._face
	portrait.actor.select_pose("fun", false)
	assert(old_face.visible_draw_count() == 0)
	var last_slot := -1
	for slot: Node2D in portrait.actor.get_node("Artwork").get_children():
		var number := int(slot.get_meta("number"))
		assert(number > last_slot)
		last_slot = number
		for drawer: CanvasItem in slot.get_children():
			assert(drawer.z_index == 0)
	portrait.backdrop.sample(2.0)
	assert(portrait.backdrop._decorations.size() == 15)
	portrait.activate(false, [])
	assert(native_background.visible and not portrait.visible)
	var room: Node2D = load("res://Miku_Hcxmmx/RoomIdle.tscn").instantiate()
	host.add_child(room)
	var room_original := RoomVisualFixture.new()
	host.add_child(room_original)
	room_original.scale = Vector2(-.8, .8)
	assert(room.configure([room_original], "fixture"))
	assert(not room_original.visible and room.body.texture != null and room.scale.x < 0)
	room._process(.3)
	room.free()
	assert(room_original.visible and room_original.modulate == Color.WHITE)
	# Fool's actual rest-site scene uses a Sprite2D placeholder, not Spine.
	var rest_host := Node2D.new()
	host.add_child(rest_host)
	var rest_controls := Control.new()
	rest_controls.name = "ControlRoot"
	rest_host.add_child(rest_controls)
	var rest_original := Sprite2D.new()
	var rest_texture := GradientTexture2D.new()
	rest_texture.width = 400
	rest_texture.height = 450
	rest_original.texture = rest_texture
	rest_original.position = Vector2(-23.684, -209.209)
	rest_original.scale = Vector2(1.15024, 1.15024)
	rest_host.add_child(rest_original)
	var rest: Node2D = load("res://Miku_Hcxmmx/RoomIdle.tscn").instantiate()
	rest_host.add_child(rest)
	assert(rest.configure([rest_original], "rest"))
	assert(not rest_original.visible and rest.body.texture != null)
	var native_feet: Vector2 = rest_original.position + Vector2(0, rest_original.get_rect().end.y * rest_original.scale.y)
	var replacement_feet: Vector2 = rest.position + Vector2(rest._idle_bounds.get_center().x * rest.scale.x,
		rest._idle_bounds.end.y * rest.scale.y)
	assert(native_feet.is_equal_approx(replacement_feet))
	rest_controls.scale.x = -1
	rest._process(.1)
	assert(rest.scale.x < 0)
	rest.free()
	assert(rest_original.visible and rest_original.modulate == Color.WHITE)
	portrait.queue_free()
	native_background.queue_free()
	print("MIKU_INTEGRATION_OK actions=", count + 1, " warmup=true shared_stage=true pooled_effects=true concurrent_impacts=true multiblock=true death_revive=true portrait=true rooms=true")
	end_layer.queue_free()
	host.queue_free()
	warmup.queue_free()
	await process_frame
	quit(0)
