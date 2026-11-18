extends Node2D

const StageScript = preload("res://Miku_Hcxmmx/Runtime/MusicStage.gd")
const StageAccess = preload("res://Miku_Hcxmmx/Runtime/StageAccess.gd")
var profile: Dictionary = {}
var phase := "键盘螺旋与聚光"
var target_flash := 0.0
var target_recoil := Vector2.ZERO
var music_stage: Node2D


func configure(data: Dictionary) -> void:
	profile = data
	music_stage = StageAccess.acquire(self, profile.textures.glow)
	sample(0, Vector2.ZERO, false)


func sample(time: float, _target: Vector2, _target_enabled: bool) -> void:
	var clock := maxf(time, 0)
	var age := clock - float(profile.hit)
	var pulse := smoothstep(0, .035, age) * (1 - smoothstep(.12, .42, age))
	var rise := smoothstep(.04, .48, clock)
	var activity := rise * (1 - smoothstep(1.7, 2.9, clock))
	music_stage.wave_motion = rise * TAU + smoothstep(.6, 1.2, clock) * 4
	music_stage.light_sweep_angle = -PI / 2 + clock * 3.5
	music_stage.light_sweep_strength = activity * (.3 + pulse * .5)
	music_stage.sample(clock, {}, 0, pulse * .75)
	music_stage.activation = activity * .55
	music_stage.note_opacity = 1 - activity * .35
	for index in StageScript.BAR_COUNT:
		var horizontal: float = index / float(StageScript.BAR_COUNT - 1) * 2 - 1
		var arch := sqrt(maxf(0, 1 - horizontal * horizontal))
		var level := .35 + absf(sin(index * 1.7 - clock * 5)) * .65
		music_stage.spectrum_levels[index] = level * activity
		music_stage.spectrum_heights[index] += (65 + level * 100) * arch * activity
	for index in 8:
		music_stage.bands[index] = (.35 + absf(sin(index * 1.7 - clock * 5)) * .65) * activity
	phase = "键盘螺旋与举手聚光" if clock < 1.15 else ("光粒与旋律收尾" if clock < 2.9 else "常驻舞台")


func marker_visible() -> bool:
	return false


func visible_draw_count() -> int:
	return music_stage.draw_count if visible else 0
