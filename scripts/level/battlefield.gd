class_name Battlefield
extends Node2D
## Runtime grid of the current level: collision queries for tanks/bullets, brick destruction, drawing.
## Coordinates are local pixels; (0, 0) is the top-left corner of the map.

signal base_hit

const CELL := LevelData.CELL_SIZE
const EPS := 0.001
## Half-width of the strip a bullet chews out of a brick wall (perpendicular to its flight).
const IMPACT_HALF_WIDTH := 7.0

const COLOR_GROUND := Color("16161c")
const COLOR_BRICK := Color("a5522a")
const COLOR_BRICK_LIGHT := Color("c97440")
const COLOR_MORTAR := Color("5a2814")
const COLOR_STEEL := Color("8a93a3")
const COLOR_STEEL_LIGHT := Color("dde2ec")
const COLOR_STEEL_DARK := Color("4a505c")

var width := LevelData.WIDTH
var height := LevelData.HEIGHT
var cells := PackedByteArray()


func load_level(level: LevelData) -> void:
	width = LevelData.WIDTH
	height = LevelData.HEIGHT
	cells = level.cells.duplicate()
	queue_redraw()


static func area_center(top_left: Vector2i) -> Vector2:
	return Vector2(top_left) * CELL + Vector2(CELL, CELL)


func pixel_size() -> Vector2:
	return Vector2(width * CELL, height * CELL)


func get_cell(cell: Vector2i) -> int:
	return cells[cell.y * width + cell.x]


func set_cell(cell: Vector2i, value: int) -> void:
	cells[cell.y * width + cell.x] = value
	queue_redraw()


func is_inside(rect: Rect2) -> bool:
	return Rect2(Vector2.ZERO, pixel_size()).encloses(rect)


func blocks_tank(rect: Rect2) -> bool:
	return not is_inside(rect) or _any_solid(rect)


func blocks_bullet(rect: Rect2) -> bool:
	return _any_solid(rect)


func contains_cell(rect: Rect2, value: int) -> bool:
	var r := _cell_range(rect)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if get_cell(Vector2i(x, y)) == value:
				return true
	return false


## Applies a bullet impact. Returns true if the bullet was stopped by the terrain.
func hit_by_bullet(rect: Rect2, dir: Vector2i, _power: int) -> bool:
	if not blocks_bullet(rect):
		return false
	var hit_base := false
	var changed := false
	var zone := _impact_zone(rect, dir)
	for y in range(zone.position.y, zone.end.y):
		for x in range(zone.position.x, zone.end.x):
			var cell := Vector2i(x, y)
			match get_cell(cell):
				LevelData.Cell.BRICK:
					cells[y * width + x] = LevelData.Cell.EMPTY
					changed = true
				LevelData.Cell.BASE:
					hit_base = true
	# A bullet grazing the base corner may overlap BASE cells outside the impact strip.
	if not hit_base and contains_cell(rect, LevelData.Cell.BASE):
		hit_base = true
	if changed:
		queue_redraw()
	if hit_base:
		base_hit.emit()
	return true


func _any_solid(rect: Rect2) -> bool:
	var r := _cell_range(rect)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if get_cell(Vector2i(x, y)) != LevelData.Cell.EMPTY:
				return true
	return false


## Cells overlapped by `rect`, clipped to the map. Edges touching a cell border do not count.
func _cell_range(rect: Rect2) -> Rect2i:
	var x0 := clampi(floori(rect.position.x / CELL), 0, width)
	var y0 := clampi(floori(rect.position.y / CELL), 0, height)
	var x1 := clampi(floori((rect.end.x - EPS) / CELL) + 1, 0, width)
	var y1 := clampi(floori((rect.end.y - EPS) / CELL) + 1, 0, height)
	return Rect2i(x0, y0, maxi(0, x1 - x0), maxi(0, y1 - y0))


## The single row/column of cells at the bullet's leading edge, widened across the flight axis.
func _impact_zone(rect: Rect2, dir: Vector2i) -> Rect2i:
	var c := rect.get_center()
	var zone: Rect2
	if dir.y != 0:
		var lead := rect.position.y if dir.y < 0 else rect.end.y - EPS
		var row_top := floorf(lead / CELL) * CELL
		zone = Rect2(c.x - IMPACT_HALF_WIDTH, row_top, IMPACT_HALF_WIDTH * 2.0, CELL)
	else:
		var lead := rect.position.x if dir.x < 0 else rect.end.x - EPS
		var col_left := floorf(lead / CELL) * CELL
		zone = Rect2(col_left, c.y - IMPACT_HALF_WIDTH, CELL, IMPACT_HALF_WIDTH * 2.0)
	return _cell_range(zone)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, pixel_size()), COLOR_GROUND)
	for y in height:
		for x in width:
			var p := Vector2(x * CELL, y * CELL)
			match get_cell(Vector2i(x, y)):
				LevelData.Cell.BRICK:
					_draw_brick(p)
				LevelData.Cell.STEEL:
					_draw_steel(p)


func _draw_brick(p: Vector2) -> void:
	draw_rect(Rect2(p, Vector2(CELL, CELL)), COLOR_BRICK)
	draw_rect(Rect2(p, Vector2(CELL, 1)), COLOR_BRICK_LIGHT)
	draw_rect(Rect2(p + Vector2(0, 4), Vector2(CELL, 1)), COLOR_BRICK_LIGHT)
	draw_rect(Rect2(p + Vector2(0, 3), Vector2(CELL, 1)), COLOR_MORTAR)
	draw_rect(Rect2(p + Vector2(0, 7), Vector2(CELL, 1)), COLOR_MORTAR)
	draw_rect(Rect2(p + Vector2(3, 0), Vector2(1, 3)), COLOR_MORTAR)
	draw_rect(Rect2(p + Vector2(7, 4), Vector2(1, 3)), COLOR_MORTAR)


func _draw_steel(p: Vector2) -> void:
	draw_rect(Rect2(p, Vector2(CELL, CELL)), COLOR_STEEL)
	draw_rect(Rect2(p + Vector2(7, 0), Vector2(1, CELL)), COLOR_STEEL_DARK)
	draw_rect(Rect2(p + Vector2(0, 7), Vector2(CELL, 1)), COLOR_STEEL_DARK)
	draw_rect(Rect2(p + Vector2(2, 2), Vector2(4, 4)), COLOR_STEEL_LIGHT)
