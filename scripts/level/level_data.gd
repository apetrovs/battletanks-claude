class_name LevelData
extends RefCounted
## Grid description of a level, parsed from a plain-text level file (see levels/level_01.txt).
## Kept free of scene dependencies so it can be unit-tested and reused by a future level editor.

enum Cell { EMPTY, BRICK, STEEL, BASE }

const CELL_SIZE := 8
const WIDTH := 26
const HEIGHT := 26

const CHAR_TO_CELL := {
	".": Cell.EMPTY,
	"#": Cell.BRICK,
	"@": Cell.STEEL,
	"B": Cell.BASE,
	"P": Cell.EMPTY,
	"E": Cell.EMPTY,
}

var name := ""
var cells := PackedByteArray()
var player_spawn := Vector2i(-1, -1)
var enemy_spawns: Array[Vector2i] = []
var base_cell := Vector2i(-1, -1)
var enemies := PackedStringArray()
var max_active_enemies := 4
var errors := PackedStringArray()


func is_valid() -> bool:
	return errors.is_empty()


func get_cell(cell: Vector2i) -> int:
	return cells[cell.y * WIDTH + cell.x]


func set_cell(cell: Vector2i, value: Cell) -> void:
	cells[cell.y * WIDTH + cell.x] = value


static func load_file(path: String) -> LevelData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var broken := LevelData.new()
		broken.errors.append("cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return broken
	return parse(file.get_as_text())


static func parse(text: String) -> LevelData:
	var data := LevelData.new()
	var rows := PackedStringArray()
	var in_map := false
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if in_map:
			if not line.is_empty():
				rows.append(line)
			continue
		if line.is_empty() or line.begins_with(";"):
			continue
		if line == "map:":
			in_map = true
			continue
		var eq := line.find("=")
		if eq < 0:
			data.errors.append("malformed header line: '%s'" % line)
			continue
		var key := line.substr(0, eq).strip_edges()
		var value := line.substr(eq + 1).strip_edges()
		match key:
			"name":
				data.name = value
			"enemies":
				data.enemies = value.split(" ", false)
			"max_active":
				data.max_active_enemies = maxi(1, value.to_int())
			_:
				data.errors.append("unknown header key: '%s'" % key)
	data._parse_map(rows)
	data._validate()
	return data


func _parse_map(rows: PackedStringArray) -> void:
	if rows.size() != HEIGHT:
		errors.append("map must have %d rows, got %d" % [HEIGHT, rows.size()])
		return
	cells.resize(WIDTH * HEIGHT)
	for y in HEIGHT:
		var row := rows[y]
		if row.length() != WIDTH:
			errors.append("map row %d must have %d cells, got %d" % [y, WIDTH, row.length()])
			return
		for x in WIDTH:
			var ch := row[x]
			if not CHAR_TO_CELL.has(ch):
				errors.append("unknown map symbol '%s' at %d,%d" % [ch, x, y])
				continue
			var cell := Vector2i(x, y)
			set_cell(cell, CHAR_TO_CELL[ch])
			match ch:
				"P":
					if player_spawn != Vector2i(-1, -1):
						errors.append("more than one player spawn")
					player_spawn = cell
				"E":
					enemy_spawns.append(cell)
				"B":
					if base_cell == Vector2i(-1, -1):
						base_cell = cell


func _validate() -> void:
	if not errors.is_empty():
		return
	if player_spawn == Vector2i(-1, -1):
		errors.append("no player spawn (P)")
	if enemy_spawns.is_empty():
		errors.append("no enemy spawns (E)")
	if enemies.is_empty():
		errors.append("no enemies listed")
	if base_cell == Vector2i(-1, -1) or cells.count(Cell.BASE) != 4 or not _area_is(base_cell, Cell.BASE):
		errors.append("base (B) must be exactly one 2x2 block")
	var spawns: Array[Vector2i] = enemy_spawns.duplicate()
	if player_spawn != Vector2i(-1, -1):
		spawns.append(player_spawn)
	for spawn in spawns:
		if not _area_is(spawn, Cell.EMPTY):
			errors.append("spawn at %s needs a free 2x2 area" % spawn)


func _area_is(top_left: Vector2i, value: Cell) -> bool:
	if top_left.x < 0 or top_left.y < 0 or top_left.x + 1 >= WIDTH or top_left.y + 1 >= HEIGHT:
		return false
	for dy in 2:
		for dx in 2:
			if get_cell(top_left + Vector2i(dx, dy)) != value:
				return false
	return true
