extends Node2D

const StageScript = preload("res://Miku_Hcxmmx/Runtime/MusicStage.gd")
const StageAccess = preload("res://Miku_Hcxmmx/Runtime/StageAccess.gd")
var profile: Dictionary = {}
var phase := "常驻音乐舞台"
var target_flash := 0.0
var target_recoil := Vector2.ZERO
var music_stage: Node2D


func configure(data: Dictionary) -> void:
	profile = data
	music_stage = StageAccess.acquire(self, profile.textures.glow)


func sample(time: float, _target: Vector2, _target_enabled: bool) -> void:
	music_stage.sample(maxf(0, time), {}, 0, 0)


func marker_visible() -> bool:
	return false


func visible_draw_count() -> int:
	return music_stage.draw_count if visible else 0
