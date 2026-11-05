class_name Hud
extends Control
## Side panels (stage, enemies left, lives, controls) and the centre overlay for pause / results.
## Drawn with the fallback font so the prototype has no font assets.

const MAP_RECT := Rect2(96, 8, 208, 208)
const TEXT := Color("e8e4d8")
const DIM := Color("8a8678")
const ACCENT := Color("e8c040")
const DANGER := Color("e05a3a")

var game: Game


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null or game.level == null:
		return
	var font := ThemeDB.fallback_font
	# Left panel: controls help.
	_text(font, Vector2(8, 20), "TANK BATTLE", 10, ACCENT)
	var help := ["WASD/ARROWS", "  move", "SPACE", "  fire", "ESC", "  pause", "R", "  restart"]
	for i in help.size():
		_text(font, Vector2(8, 40 + i * 11), help[i], 8, TEXT if i % 2 == 0 else DIM)
	# Right panel: round status.
	var x := 316.0
	_text(font, Vector2(x, 20), game.level.name.to_upper(), 10, ACCENT)
	_text(font, Vector2(x, 40), "ENEMIES", 8, DIM)
	var remaining := game.enemies_remaining()
	for i in remaining:
		var icon := Vector2(x + (i % 5) * 9, 46 + floori(i / 5.0) * 9)
		draw_rect(Rect2(icon, Vector2(7, 7)), Color("b0b8c4"))
		draw_rect(Rect2(icon + Vector2(3, -1), Vector2(1, 3)), Color("6b7280"))
	_text(font, Vector2(x, 100), "LIVES", 8, DIM)
	_text(font, Vector2(x, 112), str(game.lives), 10, TEXT)
	_text(font, Vector2(x, 132), "KILLS", 8, DIM)
	_text(font, Vector2(x, 144), str(game.enemies_destroyed), 10, TEXT)
	# Centre overlay.
	if game.paused:
		_overlay(font, "PAUSED", "ESC to resume", TEXT)
	elif game.is_round_over():
		if game.state == Game.State.WON:
			_overlay(font, "STAGE CLEAR", "ENTER: next stage   R: replay", ACCENT)
		else:
			_overlay(font, "GAME OVER", "ENTER or R: try again", DANGER)


func _overlay(font: Font, title: String, hint: String, color: Color) -> void:
	var box := Rect2(MAP_RECT.position.x + 8, MAP_RECT.get_center().y - 24, MAP_RECT.size.x - 16, 48)
	draw_rect(box, Color(0, 0, 0, 0.75))
	draw_rect(box, color, false, 1.0)
	draw_string(font, Vector2(box.position.x, box.position.y + 22), title,
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 14, color)
	draw_string(font, Vector2(box.position.x, box.position.y + 38), hint,
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 8, TEXT)


func _text(font: Font, pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
