extends RefCounted

const StageScript = preload("res://Miku_Hcxmmx/Runtime/MusicStage.gd")


static func acquire(effect: Node2D, glow_path: String) -> Node2D:
	var shared := effect.get_parent().get("shared_music_stage") as Node2D
	if shared != null:
		shared.commit_note_motion()
		shared.reset_action_state()
		return shared
	var stage := StageScript.new()
	effect.add_child(stage)
	stage.configure(glow_path)
	return stage
