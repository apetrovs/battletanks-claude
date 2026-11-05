class_name Explosion
extends Node2D
## Short, purely visual explosion. Not part of the simulation, so it animates on _process.

var big := false
var duration := 0.3

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var radius := (12.0 if big else 5.0) * (0.45 + 0.55 * k)
	var fade := 1.0 - k
	draw_circle(Vector2.ZERO, radius, Color(0.85, 0.25, 0.08, fade))
	draw_circle(Vector2.ZERO, radius * 0.7, Color(1.0, 0.6, 0.15, fade))
	draw_circle(Vector2.ZERO, radius * 0.35, Color(1.0, 0.95, 0.6, fade))
	if big:
		for i in 6:
			var a := TAU * i / 6.0 + 0.4
			var p := Vector2.from_angle(a) * radius * 1.2
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.8, 0.3, fade))
