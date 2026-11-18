extends "res://Miku_Hcxmmx/Runtime/EffectPlayer.gd"

var _ordered_frame := -2
var slot_root: Node2D


func sample(time: float) -> void:
	super.sample(time)
	if _ordered_frame == _sampled_frame:
		return
	_ordered_frame = _sampled_frame
	if _sampled_frame < 0:
		return
	var frame: Array = _frames[_sampled_frame]
	for index in frame.size():
		var slot := _get_slot(int(frame[index].slot))
		if _drawers[index].get_parent() != slot:
			_drawers[index].reparent(slot, false)


func _get_slot(number: int) -> Node2D:
	var slot_name := "Slot%d" % number
	var slot := slot_root.get_node_or_null(slot_name) as Node2D
	if slot != null:
		return slot
	slot = Node2D.new()
	slot.name = slot_name
	slot.set_meta("number", number)
	for sibling in slot_root.get_children():
		if int(sibling.get_meta("number")) > number:
			slot_root.add_child(slot)
			slot_root.move_child(slot, sibling.get_index())
			return slot
	slot_root.add_child(slot)
	return slot
