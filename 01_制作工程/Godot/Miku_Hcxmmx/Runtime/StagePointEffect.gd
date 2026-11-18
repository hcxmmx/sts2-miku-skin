extends "res://Miku_Hcxmmx/Runtime/StageIntroEffect.gd"


func sample(time: float, target: Vector2, target_enabled: bool) -> void:
	super.sample(time, target, target_enabled)
	var age := _time - float(profile.hit)
	var travel := clampf(age / .38, 0, 1)
	var flash := smoothstep(0, .025, age) * (1 - smoothstep(.24, .5, age))
	music_stage.light_sweep_angle = -PI / 2 + travel * PI
	music_stage.light_sweep_strength = flash * .95
	music_stage.wave_motion = travel * TAU
	for index in StageScript.BAR_COUNT:
		var horizontal: float = index / float(StageScript.BAR_COUNT - 1) * 2 - 1
		var pulse := exp(-pow((horizontal - travel * 1.15) / .2, 2)) * flash
		music_stage.spectrum_heights[index] += pulse * 110
		music_stage.spectrum_levels[index] = minf(1, float(music_stage.spectrum_levels[index]) + pulse)
	if _time >= 1.2:
		phase = "指向开场与频谱亮波" if _time < 2.1 else "回落至常驻舞台"
