extends Control

var hit_flash := 0.0
var target := Vector2.ZERO
var ground := 0.0
var show_guides := false
var dragging := false
var strong_flash := 0.0
var recoil := Vector2.ZERO
var capture_title := ""
var capture_status := ""
var show_target := true

signal target_moved(point: Vector2)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101a24"))
	if not capture_title.is_empty():
		draw_string(get_theme_default_font(), Vector2(22, 34), capture_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("d7e8ee"))
		if not capture_status.is_empty():
			draw_string(get_theme_default_font(), Vector2(22, 59), capture_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("8faebc"))
	for index in range(1, 11):
		var y := ground + index * index * 1.8
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.25, 0.4, 0.45, 0.12))
	draw_line(Vector2(0, ground), Vector2(size.x, ground), Color("364b55"), 1.0)
	if show_target:
		draw_set_transform(recoil)
		var center := target + Vector2(0, -150)
		# A solid target makes foreground overlap and the hit flash visible.
		draw_circle(center, 50, Color("243d4b").lerp(Color("d9ffff"), strong_flash))
		draw_circle(center, 68, Color(0.24, 0.45, 0.52, 0.06))
		draw_arc(center, 52, 0, TAU, 64, Color("55707e"), 2.0)
		draw_arc(center, 36, 0, TAU, 64, Color("3c5363"), 1.0)
		draw_line(center + Vector2(-65, 0), center + Vector2(65, 0), Color("55707e"))
		draw_line(center + Vector2(0, -65), center + Vector2(0, 65), Color("55707e"))
		draw_line(center + Vector2(0, 65), target, Color("3c5363"), 2.0)
		draw_ellipse_ground(target)
		if hit_flash > 0:
			draw_arc(center, 52 + (1 - hit_flash) * 24, 0, TAU, 64, Color(0.3, 1, 0.9, hit_flash), 3)
		draw_set_transform(Vector2.ZERO)
	if show_guides:
		draw_line(Vector2(size.x * .3, 0), Vector2(size.x * .3, size.y), Color(0.3, 1, 0.9, .3))
		draw_circle(Vector2(size.x * .3, ground), 4, Color("5de4cc"))


func set_strong_feedback(flash: float, offset: Vector2) -> void:
	if is_equal_approx(strong_flash, flash) and recoil.is_equal_approx(offset):
		return
	strong_flash = flash
	recoil = offset
	queue_redraw()


func draw_ellipse_ground(point: Vector2) -> void:
	draw_set_transform(point, 0, Vector2(1, .25))
	draw_circle(Vector2.ZERO, 45, Color(0.1, .18, .22, .6))
	draw_set_transform(Vector2.ZERO)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = show_target and event.pressed and event.position.distance_to(target + Vector2(0, -150)) < 85
	if event is InputEventMouseMotion and dragging:
		target.x = clampf(event.position.x, 90, size.x - 90)
		target_moved.emit(target)
		queue_redraw()


func _process(delta: float) -> void:
	if hit_flash > 0:
		hit_flash = maxf(0, hit_flash - delta * 3)
		queue_redraw()
