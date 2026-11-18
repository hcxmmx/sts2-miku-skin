extends Control

const ActorScript = preload("res://Miku_Hcxmmx/Runtime/Actor.gd")
const StageScript = preload("res://Preview/Stage.gd")

var actor: Node2D
var stage: Control
var selector: OptionButton
var mode_selector: OptionButton
var timeline: HSlider
var time_label: Label
var pose_label: Label
var pause_button: Button
var loop_box: CheckBox
var _updating := false
var _scale := .95
var _facing := 1.0
var _actions: Array[String] = []
var _capture_path := ""
var _capture_time := .3
var _capture_action := "sts2_attack"


func label(text: String, size := 16) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	return node


func button(text: String, callback: Callable, host: Node) -> Button:
	var node := Button.new()
	node.text = text
	node.pressed.connect(callback)
	host.add_child(node)
	return node


func row(host: Node) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	host.add_child(box)
	return box


func checkbox(text: String, checked: bool, callback: Callable, host: Node) -> CheckBox:
	var node := CheckBox.new()
	node.text = text
	node.button_pressed = checked
	node.toggled.connect(callback)
	host.add_child(node)
	return node


func slider(low: float, high: float, step: float, value: float, callback: Callable, host: Node, width := 140) -> HSlider:
	var node := HSlider.new()
	node.min_value = low
	node.max_value = high
	node.step = step
	node.value = value
	node.custom_minimum_size.x = width
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.value_changed.connect(callback)
	host.add_child(node)
	return node


func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	var style := Theme.new()
	style.default_font = font
	style.default_font_size = 16
	theme = style
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	var heading := row(layout)
	var title := label("初音未来 V4", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(label("愚者外观 · 动作预览"))
	var controls := row(layout)
	mode_selector = OptionButton.new()
	mode_selector.add_item("尖塔改编")
	mode_selector.add_item("动作组合")
	mode_selector.add_item("原始片段")
	mode_selector.add_item("特效单项")
	mode_selector.add_item("动作特效试作")
	mode_selector.add_item("响应分配 · 身体动作")
	mode_selector.add_item("动作与特效")
	mode_selector.add_item("选人立绘 · ALICE")
	mode_selector.select(6)
	mode_selector.item_selected.connect(func(index: int):
		if index == 7:
			get_tree().change_scene_to_file("res://Preview/Portrait/PortraitPreview.tscn")
		else:
			_populate_actions())
	controls.add_child(mode_selector)
	selector = OptionButton.new()
	selector.custom_minimum_size.x = 260
	controls.add_child(selector)
	selector.item_selected.connect(_select_action)
	button("Attack  A", _request_attack, controls)
	button("射击  S", _request_shoot, controls)
	button("PowerUp  P", _request_action.bind("sts2_powerUp"), controls)
	button("入场  E", _request_action.bind("sts2_intro"), controls)
	button("重新播放", _replay, controls)
	loop_box = checkbox("循环", true, _set_looping, controls)
	loop_box.tooltip_text = "尖塔改编循环身体动作，已触发特效独立播完。关闭循环可查看单次完整演出。"
	checkbox("结束回待机", true, func(value: bool): actor.return_to_idle = value, controls)
	checkbox("翻转", false, func(value: bool):
		_facing = -1.0 if value else 1.0
		_layout_stage(), controls)
	stage = StageScript.new()
	stage.clip_contents = true
	stage.custom_minimum_size.y = 440
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(stage)
	actor = ActorScript.new()
	stage.add_child(actor)
	actor.load_drafts()
	actor.target_hit.connect(func(): stage.hit_flash = 1.0)
	stage.target_moved.connect(func(point: Vector2):
		actor.target_position = (point - actor.position) / actor.scale
		actor.refresh_pose())
	stage.resized.connect(_layout_stage)
	var scrub := row(layout)
	pause_button = button("暂停", _pause, scrub)
	button("◀ 帧", func(): actor.step_frame(-1), scrub)
	button("帧 ▶", func(): actor.step_frame(1), scrub)
	timeline = HSlider.new()
	timeline.step = .001
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.value_changed.connect(func(value: float):
		if not _updating:
			actor.set_paused(true)
			actor.seek(value))
	scrub.add_child(timeline)
	time_label = label("0.00 / 1.40 秒")
	time_label.custom_minimum_size.x = 150
	scrub.add_child(time_label)
	var options := row(layout)
	options.add_child(label("速度"))
	var speed := OptionButton.new()
	for text in ["0.25×", "0.5×", "1×", "1.5×", "2×"]:
		speed.add_item(text)
	speed.select(2)
	speed.item_selected.connect(func(index: int): actor.speed = [.25, .5, 1.0, 1.5, 2.0][index])
	options.add_child(speed)
	options.add_child(label("比例"))
	slider(.5, 1.3, .05, _scale, func(value: float):
		_scale = value
		_layout_stage(), options, 100)
	checkbox("特效", true, func(value: bool):
		actor.effects_enabled = value
		actor.refresh_pose(), options)
	checkbox("目标侧演示", true, func(value: bool):
		actor.target_effects_enabled = value
		actor.refresh_pose(), options)
	checkbox("配音", true, func(value: bool): actor.set_audio_enabled("voice", value), options)
	slider(-30, 0, 1, 0, func(value: float): actor.set_volume("voice", value), options, 100)
	checkbox("音效", true, func(value: bool): actor.set_audio_enabled("sfx", value), options)
	slider(-30, 0, 1, 0, func(value: float): actor.set_volume("sfx", value), options, 100)
	checkbox("锚点", false, func(value: bool):
		stage.show_guides = value
		stage.queue_redraw(), options)
	pose_label = label("")
	layout.add_child(pose_label)
	var help := label("Space 播放／暂停    ← → 逐帧    A 轻攻击    C／V 施法候选    P PowerUp    E 舞台入场    S 强音    拖动标靶调整目标", 14)
	help.modulate = Color("8a9ba6")
	layout.add_child(help)
	_populate_actions()
	_layout_stage.call_deferred()
	var args := OS.get_cmdline_user_args()
	if args.has("--check"):
		_check.call_deferred()
	if args.has("--check-effects"):
		_check_effects.call_deferred()
	if args.has("--check-combat"):
		_check_combat.call_deferred()
	if args.has("--record"):
		_record.call_deferred(args[args.find("--record") + 1])
	if args.has("--record-drafts"):
		_record.call_deferred(args[args.find("--record-drafts") + 1], true)
	if args.has("--record-music"):
		_record.call_deferred(args[args.find("--record-music") + 1], true, ["draft_music_attack"])
	if args.has("--action") and not args.has("--capture"):
		var requested := args[args.find("--action") + 1]
		mode_selector.select(_mode_for_action(requested))
		_populate_actions()
		var index := _actions.find(requested)
		if index >= 0:
			selector.select(index)
			_select_action(index)
	if args.has("--capture"):
		_capture_path = args[args.find("--capture") + 1]
		if args.has("--time"):
			_capture_time = float(args[args.find("--time") + 1])
		if args.has("--action"):
			_capture_action = args[args.find("--action") + 1]
		_capture.call_deferred()


func _populate_actions() -> void:
	selector.clear()
	_actions.clear()
	if mode_selector.selected == 0:
		for name: String in actor.catalog.adapted_performance_names:
			_actions.append(name)
			selector.add_item(actor.catalog.performances[name].label)
	elif mode_selector.selected == 1:
		for name: String in actor.catalog.source_performance_names:
			_actions.append(name)
			selector.add_item(actor.catalog.performances[name].label)
	elif mode_selector.selected == 2:
		var names: Array = actor.catalog.source_animation_names.duplicate()
		names.sort()
		for name: String in names:
			_actions.append("clip:" + name)
			selector.add_item(name)
	elif mode_selector.selected == 3:
		var names: Array = actor.catalog.effect_previews.keys()
		names.sort()
		for name: String in names:
			_actions.append("effect:" + name)
			selector.add_item(name)
	elif mode_selector.selected == 4:
		for name: String in actor.catalog.draft_performance_names:
			_actions.append(name)
			selector.add_item(actor.catalog.performances[name].label)
	elif mode_selector.selected == 5:
		for name: String in actor.catalog.response_performance_names:
			_actions.append(name)
			selector.add_item(actor.catalog.performances[name].label)
	else:
		for name: String in actor.catalog.combined_performance_names:
			_actions.append(name)
			selector.add_item(actor.catalog.performances[name].label)
	_select_action(0)


func _layout_stage() -> void:
	if stage == null or actor == null:
		return
	stage.ground = stage.size.y * .86
	actor.position = Vector2(stage.size.x * .30, stage.ground)
	actor.scale = Vector2(_scale * _facing, _scale)
	if stage.target == Vector2.ZERO:
		stage.target = Vector2(stage.size.x * .76, stage.ground)
	stage.target.y = stage.ground
	actor.target_position = (stage.target - actor.position) / actor.scale
	actor.target_center_offset = Vector2(0, -150 / absf(actor.scale.y))
	actor.refresh_pose()
	stage.queue_redraw()


func _select_action(index: int) -> void:
	var name := _actions[index]
	var performance: Dictionary = actor.catalog.performances.get(name, {})
	var repeat: bool = performance.get("repeat", false)
	loop_box.set_pressed_no_signal(repeat)
	actor.play(name, repeat)


func _request_attack() -> void:
	_request_action("sts2_attack")


func _request_shoot() -> void:
	_request_action("sts2_shootBow")


func _request_action(name: String) -> void:
	var combined_actions := {"sts2_attack": "combined_attack", "sts2_shootBow": "combined_shootBow",
		"sts2_powerUp": "combined_powerup_spin", "sts2_intro": "combined_intro_cheer",
		"draft_cast_gesture": "combined_cast_gesture", "draft_cast_step": "combined_powerup_step"}
	if name.begins_with("combined_") or (mode_selector.selected == 6 and combined_actions.has(name)):
		if mode_selector.selected != 6:
			mode_selector.select(6)
			_populate_actions()
		name = combined_actions.get(name, name)
		selector.select(_actions.find(name))
		actor.request_action(name, loop_box.button_pressed)
		return
	var response_actions := {"sts2_attack": "response_attack", "sts2_shootBow": "response_shootBow",
		"sts2_powerUp": "response_powerup_spin", "sts2_intro": "response_intro_cheer",
		"draft_cast_gesture": "response_cast_gesture", "draft_cast_step": "response_powerup_step"}
	if name.begins_with("response_") or (mode_selector.selected == 5 and response_actions.has(name)):
		if mode_selector.selected != 5:
			mode_selector.select(5)
			_populate_actions()
		name = response_actions.get(name, name)
		selector.select(_actions.find(name))
		actor.request_action(name, loop_box.button_pressed)
		return
	var draft_actions := {"sts2_attack": "draft_attack", "sts2_powerUp": "draft_powerup_spin", "sts2_intro": "draft_stage_intro"}
	if name.begins_with("draft_") or (mode_selector.selected == 4 and draft_actions.has(name)):
		if mode_selector.selected != 4:
			mode_selector.select(4)
			_populate_actions()
		name = draft_actions.get(name, name)
		selector.select(_actions.find(name))
		actor.request_action(name, loop_box.button_pressed)
		return
	if mode_selector.selected != 0:
		mode_selector.select(0)
		_populate_actions()
	selector.select(_actions.find(name))
	actor.request_action(name, loop_box.button_pressed)


func _set_looping(value: bool) -> void:
	if actor.catalog.adapted_performance_names.has(actor.sequence_name):
		actor.play(actor.sequence_name, value)
	else:
		actor.looping = value


func _replay() -> void:
	actor.play(_actions[selector.selected], loop_box.button_pressed)


func _pause() -> void:
	actor.set_paused(not actor.paused)


func _process(_delta: float) -> void:
	if actor == null or timeline == null:
		return
	var body_only: bool = actor.sequence_name.begins_with("response_")
	var custom_preview: bool = actor.sequence_name.begins_with("draft_") or actor.sequence_name.begins_with("combined_")
	var target_events: bool = actor.effect_events.any(func(event: Dictionary): return event.get("anchor", "") in ["target", "target_center"])
	var show_target: bool = not body_only and (not custom_preview or actor.active_performance.get("combat_effect", {}).get("target_hit", false) or target_events)
	if stage.show_target != show_target:
		stage.show_target = show_target
		stage.queue_redraw()
	var flash := 0.0
	var recoil := Vector2.ZERO
	var effects: Array = actor.effect_tails.map(func(tail: Dictionary): return tail.combat)
	effects.append(actor.combat_effect)
	if actor.effects_enabled and actor.target_effects_enabled:
		for effect: Node2D in effects:
			if effect != null:
				flash = maxf(flash, effect.target_flash)
				if effect.target_recoil.length_squared() > recoil.length_squared():
					recoil = effect.target_recoil
	stage.set_strong_feedback(flash, recoil * actor.scale)
	stage.capture_status = actor.combat_effect.music_state if actor.combat_effect != null and actor.combat_effect.profile.kind == "music_light" else ""
	_updating = true
	timeline.max_value = actor.duration
	timeline.value = actor.clock
	_updating = false
	time_label.text = "%.2f / %.2f 秒" % [actor.clock, actor.duration]
	pause_button.text = "播放" if actor.paused else "暂停"
	var count: int = actor.catalog.animations[actor.current_clip].frames.size()
	var performance: Dictionary = actor.catalog.performances.get(actor.sequence_name, {})
	var note: String = performance.get("note", "原始片段按单段播放。")
	if actor.looping and performance.get("loop_body_on_repeat", false):
		note = "循环身体动作，起手声音立即播放，命中音跟随命中，已触发特效独立播完。"
	if actor.combat_effect != null:
		note += "    当前阶段 · " + actor.combat_effect.phase
	if actor.sequence_name.begins_with("effect:"):
		var effect_name: String = actor.sequence_name.trim_prefix("effect:")
		note = "特效单项 · " + effect_name + "    目标侧采用标靶基准演示。"
		if int(actor.EffectScript.catalog.effects[effect_name].source_renderers) == 0:
			note += " 镜头控制曲线待接入。"
		elif actor.catalog.effect_previews[effect_name].inventory_only:
			note += " 当前动作逻辑未直接引用。"
	var clips: Array = actor.sequence.map(func(segment: Dictionary): return segment.name)
	var chain_text := " → ".join(clips)
	if performance.get("music_demo", false):
		chain_text = "连续轻击演示 · 三段原音频"
	pose_label.text = "%s    帧 %d / %d    %s%s\n%s" % [actor.current_clip, actor.current_frame + 1, count, chain_text, "    已合并一次后继技能" if actor.pending_attack else "", note]


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_left"):
		actor.step_frame(-1)
	elif event.is_action_pressed("ui_right"):
		actor.step_frame(1)
	elif event is InputEventKey and event.keycode == KEY_SPACE:
		_pause()
	elif event is InputEventKey and event.keycode == KEY_A:
		_request_attack()
	elif event is InputEventKey and event.keycode == KEY_S:
		_request_shoot()
	elif event is InputEventKey and event.keycode == KEY_P:
		_request_action("sts2_powerUp")
	elif event is InputEventKey and event.keycode == KEY_C:
		_request_action("draft_cast_gesture")
	elif event is InputEventKey and event.keycode == KEY_V:
		_request_action("draft_cast_step")
	elif event is InputEventKey and event.keycode == KEY_E:
		_request_action("sts2_intro")
	else:
		return
	get_viewport().set_input_as_handled()


func _mode_for_action(name: String) -> int:
	if name.begins_with("combined_"):
		return 6
	if name.begins_with("response_"):
		return 5
	if name.begins_with("draft_"):
		return 4
	if name.begins_with("sts2_"):
		return 0
	if name.begins_with("clip:"):
		return 2
	if name.begins_with("effect:"):
		return 3
	return 1


func _capture() -> void:
	await get_tree().process_frame
	mode_selector.select(_mode_for_action(_capture_action))
	_populate_actions()
	selector.select(_actions.find(_capture_action))
	loop_box.set_pressed_no_signal(false)
	actor.play(_capture_action)
	actor.set_paused(true)
	actor.seek(_capture_time)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_capture_path)
	get_tree().quit()


func _record(directory: String, drafts := false, only: Array = []) -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(directory)
	mode_selector.select(4 if drafts else 0)
	_populate_actions()
	var actions: Array = _actions.duplicate() if drafts else ["sts2_intro", "sts2_powerUp", "sts2_attack", "sts2_shootBow"]
	if not only.is_empty():
		actions = only
	var frame_index := 0
	for name: String in actions:
		selector.select(_actions.find(name))
		stage.capture_title = actor.catalog.performances[name].label if drafts else ""
		loop_box.set_pressed_no_signal(false)
		actor.play(name)
		actor.set_paused(true)
		var fps := 24 if drafts and name != "draft_music_attack" else 30
		for index in ceili(actor.duration * fps):
			actor.seek(float(index) / fps)
			stage.queue_redraw()
			await RenderingServer.frame_post_draw
			var screenshot := get_viewport().get_texture().get_image()
			if drafts:
				screenshot = screenshot.get_region(Rect2i(Vector2i(stage.global_position), Vector2i(stage.size)))
			screenshot.save_png(directory.path_join("frame_%04d.png" % frame_index))
			frame_index += 1
	print("MIKU_RECORDED ", frame_index)
	get_tree().quit()


func _check() -> void:
	await get_tree().process_frame
	actor.return_to_idle = false
	var missing := 0
	for name: String in actor.catalog.source_animation_names:
		actor.play("clip:" + name)
		for boundary: float in actor.frame_boundaries:
			actor.seek(boundary)
			if actor.body.visible and actor.body.texture == null:
				missing += 1
		await get_tree().process_frame
	actor.play("walk", true)
	var movement_chain: bool = actor.sequence.map(func(segment: Dictionary): return segment.name) == ["run_A", "run_B", "run_C", "run_D"]
	actor.play("s200")
	var skill_chain: bool = actor.sequence.map(func(segment: Dictionary): return segment.name) == ["s200", "s201", "s202"] and is_equal_approx(actor.duration, 5.2)
	actor.play("s100_EX")
	var aliases: bool = actor.sequence.map(func(segment: Dictionary): return segment.name) == ["s100", "s101"] and not actor.cues.is_empty()
	actor.play("lose")
	actor.advance(4.0)
	var defeat_tail: bool = actor.sequence_name == "lose" and actor.current_clip == "lose_loop" and is_equal_approx(actor.clock, .72)
	actor.play("s100")
	actor.advance(.2)
	actor.set_paused(true)
	actor.seek(.7)
	var clean_seek: bool = actor._audio_nodes.is_empty()
	var frame_before: int = actor.current_frame
	actor.step_frame(1)
	var stepping: bool = actor.current_frame != frame_before
	actor.play("s100")
	actor.request_attack()
	var merged: bool = actor.pending_attack
	actor.seek(0)
	var cleared: bool = not actor.pending_attack
	actor.return_to_idle = true
	actor.play("s100")
	actor.advance(.02)
	var playing_audio: bool = not actor._audio_nodes.is_empty()
	actor.advance(3.0)
	var audio_tail: bool = playing_audio and actor.sequence_name == "stand" and not actor._audio_nodes.is_empty()
	actor.seek(0)
	print("MIKU_CHECK ", JSON.stringify({"animations": actor.catalog.animations.size(), "performances": actor.catalog.performances.size(), "movement_chain": movement_chain, "skill_chain": skill_chain, "aliases": aliases, "defeat_tail": defeat_tail, "missing_textures": missing, "silent_seek": clean_seek, "frame_step": stepping, "attack_merge": merged, "seek_clears_pending": cleared, "audio_tail": audio_tail}))
	get_tree().quit(0 if missing == 0 and clean_seek and stepping and merged and cleared and audio_tail and movement_chain and skill_chain and aliases and defeat_tail else 1)


func _check_effects() -> void:
	await get_tree().process_frame
	actor.return_to_idle = false
	var results: Dictionary = {}
	var failures: Array = []
	for name: String in actor.catalog.effect_previews:
		actor.play("effect:" + name)
		actor.set_paused(true)
		var instance: Node2D = actor.effect_instances.get(0)
		var count := 0
		if instance != null:
			var frames: Array = instance._frames
			var best := 0
			for index in frames.size():
				if frames[index].size() > frames[best].size():
					best = index
			actor.seek(float(best) / float(instance.catalog.fps))
			count = instance.visible_draw_count()
			if int(instance.catalog.effects[name].max_draws) > 0 and count == 0:
				failures.append(name)
		results[name] = count
		await get_tree().process_frame
	actor.play("s100_EX")
	actor.seek(.9)
	var ex_effects: Array = actor.effect_events.map(func(event: Dictionary): return event.effect)
	var ex_ok := ex_effects == ["miku/miku_s100_02", "miku/miku_s100_02_back", "miku/miku_s100_04"]
	var target_instance: Node2D = actor.effect_instances.get(2)
	var target_draws: int = target_instance.visible_draw_count() if target_instance != null else 0
	actor.target_effects_enabled = false
	actor.refresh_pose()
	var target_toggle: bool = target_instance != null and not target_instance.visible
	actor.target_effects_enabled = true
	actor.play("s200")
	actor.seek(4.6)
	var target_event: Dictionary = actor.effect_events[-1]
	var skill_two: bool = target_event.effect == "miku/miku_s200_04_a" and is_equal_approx(float(target_event.start), 4.5)
	actor.return_to_idle = true
	actor.play("Link1009600_A")
	actor.seek(7.44)
	actor.advance(.1)
	actor.advance(.15)
	var feedback: Node2D = actor.effect_instances.get(5)
	var target_tail: bool = actor.sequence_name == "stand" and feedback != null and feedback.visible_draw_count() > 0
	actor.play("stand", true)
	var interruption: bool = actor.effect_events.is_empty() and actor.effect_instances.is_empty()
	var ok: bool = failures.is_empty() and ex_ok and target_draws > 0 and target_toggle and skill_two and target_tail and interruption
	var report := {"effects": results, "failed": failures, "ex_distinct_effects": ex_ok, "ex_target_draws": target_draws, "target_toggle": target_toggle, "skill_two_target_timing": skill_two, "target_tail_survives_idle": target_tail, "interruption_clears_effects": interruption, "ok": ok}
	var output_path := ProjectSettings.globalize_path("res://").path_join("../../02_构建产物/effect_runtime_check.json").simplify_path()
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print("MIKU_EFFECT_CHECK ", JSON.stringify(report))
	get_tree().quit(0 if ok else 1)


func _check_combat() -> void:
	await get_tree().process_frame
	actor.return_to_idle = false
	var results: Dictionary = {}
	var counter := {"hits": 0}
	actor.target_hit.connect(func(): counter.hits += 1)
	actor.play("sts2_attack")
	actor.set_paused(true)
	actor.seek(.24)
	results.attack_source = actor.catalog.sprites[actor.catalog.animations.sts2_attack.frames[0]].name == "Miku002_12"
	results.custom_frame_timing = actor.current_frame == 4
	actor.seek(.36)
	var hit_effect: Node2D = actor.effect_instances.get(0)
	results.original_target_effect = actor.combat_effect == null and hit_effect != null and hit_effect.effect_name == "miku/miku_s200_04_a" and hit_effect.visible_draw_count() > 0
	results.attack_target_alignment = hit_effect != null and hit_effect.position.is_equal_approx(actor.target_position + actor.target_center_offset)
	results.target_effect_foreground = hit_effect != null and hit_effect.z_index > 0
	results.silent_seek = counter.hits == 0 and actor._audio_nodes.is_empty()
	actor.play("sts2_attack")
	actor.advance(.23)
	results.single_hit = counter.hits == 1
	actor.advance(.08)
	results.no_duplicate_hit = counter.hits == 1
	actor.request_action("sts2_attack")
	actor.request_action("sts2_attack")
	actor.advance(.12)
	results.queued_attack = actor.sequence_name == "sts2_attack" and is_zero_approx(actor.clock) and not actor.pending_attack
	actor.set_paused(true)
	actor.seek(.11)
	actor.step_frame(1)
	results.frame_step = is_equal_approx(actor.clock, .17)
	actor.play("sts2_shootBow")
	actor.advance(.02)
	results.strong_voice_playback = actor._audio_nodes.any(func(player: AudioStreamPlayer): return player.get_meta("exclusive_heavy", false) and player.stream.get_length() > 4 and player.stream.get_length() < 6 and is_equal_approx(player.pitch_scale, 1.0))
	actor.set_paused(true)
	actor.seek(.17)
	results.strong_wave = actor.combat_effect.phase == "强音" and actor.combat_effect.visible_draw_count() > 0
	results.strong_source = actor.catalog.sprites[actor.catalog.animations.sts2_shootBow.frames[0]].name == "Miku002_08" and is_equal_approx(float(actor.active_performance.body_duration), .62)
	results.strong_voice = actor.cues.any(func(cue: Dictionary): return cue.kind == "voice" and cue.get("exclusive_heavy", false) and cue.paths.size() == 2)
	var contact_time: float = actor.combat_effect.profile.hit
	actor.seek(contact_time)
	var burst_marker: Sprite2D = actor.combat_effect._marker
	var burst_width: float = burst_marker.scale.x * burst_marker.texture.get_width()
	results.marker_contact_burst = is_equal_approx(burst_width, 768.0) and burst_marker.modulate.r > 2.0 and is_equal_approx(burst_marker.modulate.a, 1.0)
	actor.seek(contact_time + .1)
	results.marker_peak_hold = is_equal_approx(burst_marker.scale.x * burst_marker.texture.get_width(), burst_width)
	actor.seek(contact_time + .37)
	var middle_width: float = burst_marker.scale.x * burst_marker.texture.get_width()
	actor.seek(contact_time + .62)
	var settled_width: float = burst_marker.scale.x * burst_marker.texture.get_width()
	results.marker_settles = burst_width > middle_width and middle_width > settled_width and is_equal_approx(settled_width, 160.0) and is_equal_approx(burst_marker.modulate.r, 1.0)
	actor.seek(contact_time + .02)
	results.strong_contact_feedback = actor.combat_effect.target_flash > 0 and actor.combat_effect.target_recoil.length() > 0 and actor.combat_effect.phase == "命中"
	actor.seek(.1)
	results.feedback_resets_on_seek = is_zero_approx(actor.combat_effect.target_flash) and actor.combat_effect.target_recoil == Vector2.ZERO
	actor.play("sts2_shootBow")
	var start_audio: int = actor._audio_nodes.size()
	actor.advance(contact_time - .01)
	results.hit_audio_waits_for_contact = actor._audio_nodes.size() == start_audio
	actor.advance(.02)
	results.hit_audio_at_contact = actor._audio_nodes.size() == start_audio + 1 and actor._audio_nodes.back().stream == actor.audio_streams[actor.combat_effect.profile.hit_audio.paths[0]]
	actor.advance(.02)
	results.hit_audio_once = actor._audio_nodes.size() == start_audio + 1
	actor.set_paused(true)
	actor.seek(contact_time + .02)
	results.hit_seek_silent = actor._audio_nodes.is_empty()
	actor.seek(1.0)
	results.marker = actor.combat_effect.marker_visible() and actor.current_clip == "stand"
	var marker: Sprite2D = actor.combat_effect._marker
	var marker_width: float = marker.scale.x * marker.texture.get_width()
	results.marker_doubled = marker_width > 156 and marker_width < 164 and is_equal_approx(float(actor.combat_effect.profile.marker_scale), 4.0)
	var destination: Vector2 = marker.position
	results.target_alignment = destination.is_equal_approx(actor.target_position + actor.target_center_offset)
	var original_target: Vector2 = actor.target_position
	actor.target_position += Vector2(100, 0)
	actor.refresh_pose()
	results.target_move = marker.position.is_equal_approx(destination + Vector2(100, 0))
	actor.target_position = original_target
	var original_scale: Vector2 = actor.scale
	actor.scale.x *= -1
	actor.target_position = original_target * Vector2(-1, 1)
	actor.refresh_pose()
	var expected: Vector2 = stage.target + Vector2(0, -150)
	results.flip_alignment = marker.global_position.is_equal_approx(stage.get_global_transform() * expected)
	actor.scale = original_scale
	actor.target_position = original_target
	actor.target_effects_enabled = false
	actor.refresh_pose()
	results.target_toggle = not actor.combat_effect.marker_visible()
	actor.target_effects_enabled = true
	actor.seek(2.02)
	results.recall = actor.combat_effect.phase == "返回" and not actor.combat_effect.marker_visible()
	actor.seek(1.0)
	results.reverse_seek = actor.combat_effect.marker_visible()
	actor.effects_enabled = false
	actor.refresh_pose()
	results.effects_toggle = actor.combat_effect.visible_draw_count() == 0
	actor.effects_enabled = true
	actor.play("sts2_powerUp")
	results.powerup = actor.current_clip == "s200" and is_equal_approx(float(actor.active_performance.body_duration), 1.0) and actor.combat_effect == null
	actor.play("sts2_intro")
	results.entrance = actor.current_clip == "show" and actor.effect_events.is_empty() and actor.combat_effect == null
	actor.play("stand", true)
	results.cleanup = actor.combat_effect == null and actor.effect_instances.is_empty()
	results.default_loops = true
	results.body_only_loops = true
	results.audio_at_start = true
	results.no_duplicate_start_audio = true
	results.automatic_restart = true
	results.seek_resume_silent = true
	for name: String in actor.catalog.adapted_performance_names:
		actor._stop_audio(false)
		var performance: Dictionary = actor.catalog.performances[name]
		results.default_loops = results.default_loops and performance.repeat
		actor.play(name, true)
		results.body_only_loops = results.body_only_loops and actor.sequence.size() == 1 and is_equal_approx(actor.duration, float(performance.body_duration))
		var initial_audio: int = actor._audio_nodes.size()
		results.audio_at_start = results.audio_at_start and initial_audio == actor.cues.size() and actor.cues.all(func(cue: Dictionary): return is_zero_approx(float(cue.time)) and cue.played)
		actor.advance(.001)
		results.no_duplicate_start_audio = results.no_duplicate_start_audio and actor._audio_nodes.size() == initial_audio
		actor.advance(actor.duration + .01)
		results.automatic_restart = results.automatic_restart and actor.sequence_name == name and actor.looping and not actor.paused and is_zero_approx(actor.clock) and actor.current_clip != "stand"
		actor.seek(0)
		actor.advance(.01)
		results.seek_resume_silent = results.seek_resume_silent and actor._audio_nodes.is_empty()
		await get_tree().process_frame
	loop_box.set_pressed_no_signal(false)
	_set_looping(false)
	results.full_tail_on_disable = not actor.looping and actor.sequence.size() == 2 and actor.duration > float(actor.active_performance.body_duration)
	actor.play("sts2_attack", true)
	actor.advance(.23)
	var looping_hit: Node2D = actor.effect_instances.get(0)
	actor.advance(.20)
	results.loop_retains_target_effect = actor.effect_tails.size() == 1 and actor.effect_tails[0].instances.get(0) == looping_hit and looping_hit.visible_draw_count() > 0
	var first_tail: Dictionary = actor.effect_tails[0]
	actor.advance(.43)
	actor.advance(.43)
	results.loop_target_continues = float(first_tail.clock) > 1.28 and looping_hit.visible_draw_count() > 0
	var tail_end: float = first_tail.duration
	actor.advance(tail_end - float(first_tail.clock) - .01)
	results.loop_target_full_duration = actor.effect_tails.has(first_tail) and is_equal_approx(float(first_tail.clock), tail_end - .01) and is_instance_valid(looping_hit) and looping_hit.get_parent() == actor
	actor.advance(.02)
	results.loop_target_expires = not actor.effect_tails.has(first_tail) and looping_hit.is_queued_for_deletion()
	results.loop_tail_count_bounded = true
	for index in 20:
		actor.advance(.43)
		results.loop_tail_count_bounded = results.loop_tail_count_bounded and actor.effect_tails.size() <= 6
		await get_tree().process_frame
	actor.target_effects_enabled = false
	actor.refresh_pose()
	results.loop_tail_target_toggle = actor.effect_tails.all(func(tail: Dictionary): return tail.instances.values().all(func(instance: Node2D): return not instance.visible))
	actor.target_effects_enabled = true
	actor.refresh_pose()
	actor.seek(0)
	results.seek_clears_old_tails = actor.effect_tails.is_empty()
	actor.play("sts2_shootBow", true)
	var previous_strong: Node2D = actor.combat_effect
	actor.advance(.63)
	actor.advance(.4)
	results.loop_strong_marker_survives = actor.effect_tails.size() == 1 and previous_strong.marker_visible()
	actor.play("stand", true)
	results.switch_clears_old_tails = actor.effect_tails.is_empty() and previous_strong.is_queued_for_deletion()
	var ok := true
	for value: bool in results.values():
		ok = ok and value
	var output_path := ProjectSettings.globalize_path("res://").path_join("../../02_构建产物/combat_preview_check.json").simplify_path()
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": results, "ok": ok}, "\t"))
	print("MIKU_COMBAT_CHECK ", JSON.stringify({"checks": results, "ok": ok}))
	actor._stop_audio(false)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(.1).timeout
	get_tree().quit(0 if ok else 1)
