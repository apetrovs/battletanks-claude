class_name Base
extends Node2D
## The HQ the player defends. Occupies a 2x2 BASE area of the battlefield grid
## (the grid handles blocking); this node owns the destroyed state and the visuals.

var is_destroyed := false


func reset(center: Vector2) -> void:
	position = center
	is_destroyed = false
	queue_redraw()


func destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	queue_redraw()


func _draw() -> void:
	if is_destroyed:
		draw_rect(Rect2(-8, -8, 16, 16), Color("2a2622"))
		for p: Vector2 in [Vector2(-6, 2), Vector2(-2, -1), Vector2(3, 3), Vector2(1, -5), Vector2(-5, -4), Vector2(4, -2)]:
			draw_rect(Rect2(p, Vector2(3, 2)), Color("5d5249"))
		return
	# Original emblem: a pennant on a mast over a stone plinth.
	draw_rect(Rect2(-8, -8, 16, 16), Color("23232b"))
	draw_rect(Rect2(-7, 3, 14, 5), Color("6b7280"))
	draw_rect(Rect2(-7, 3, 14, 1), Color("9ca3af"))
	draw_rect(Rect2(-5, 1, 10, 2), Color("4b5563"))
	draw_rect(Rect2(-1, -7, 1, 8), Color("d1d5db"))
	var flag := PackedVector2Array([Vector2(0, -7), Vector2(7, -4.5), Vector2(0, -2)])
	draw_colored_polygon(flag, Color("e8c040"))
	draw_rect(Rect2(-2, -8, 3, 1), Color("f5d76e"))
