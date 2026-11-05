extends "res://tests/test_case.gd"


func _lines(text: String) -> PackedStringArray:
	return text.split("\n")


func test_shipped_levels_are_valid() -> void:
	assert_true(Game.LEVELS.size() > 0, "no levels registered")
	for path in Game.LEVELS:
		var data := LevelData.load_file(path)
		assert_true(data.is_valid(), "%s invalid: %s" % [path, ", ".join(data.errors)])
		assert_true(data.base_cell != Vector2i(-1, -1), "%s has no base" % path)
		assert_eq(data.cells.count(LevelData.Cell.BASE), 4, "%s base cells" % path)
		assert_true(data.player_spawn != Vector2i(-1, -1), "%s has no player spawn" % path)
		assert_true(data.enemy_spawns.size() > 0, "%s has no enemy spawns" % path)
		assert_true(data.enemies.size() > 0, "%s has no enemies" % path)
		for type in data.enemies:
			assert_true(Game.ENEMY_TYPES.has(type), "%s: unknown enemy type %s" % [path, type])


func test_level_one_values() -> void:
	var data := LevelData.load_file(Game.LEVELS[0])
	assert_eq(data.base_cell, Vector2i(12, 24))
	assert_eq(data.player_spawn, Vector2i(8, 24))
	assert_eq(data.enemy_spawns.size(), 3)
	assert_eq(data.enemies.size(), 8)
	assert_eq(data.max_active_enemies, 3)


func test_missing_file_is_reported() -> void:
	var data := LevelData.load_file("res://levels/does_not_exist.txt")
	assert_false(data.is_valid())


func test_blank_map_parses() -> void:
	var data := LevelData.parse(blank_map("basic basic", 2))
	assert_true(data.is_valid(), ", ".join(data.errors))
	assert_eq(data.base_cell, Vector2i(12, 24))
	assert_eq(data.player_spawn, Vector2i(8, 24))
	assert_eq(data.enemy_spawns, [Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(data.enemies.size(), 2)
	assert_eq(data.max_active_enemies, 2)
	assert_eq(data.name, "Test")
	assert_eq(data.get_cell(Vector2i(12, 24)), LevelData.Cell.BASE)
	assert_eq(data.get_cell(Vector2i(8, 24)), LevelData.Cell.EMPTY)


func test_cell_symbols() -> void:
	var data := LevelData.parse(blank_map("basic", 3, {
		Vector2i(4, 4): "#", Vector2i(6, 4): "@", Vector2i(20, 0): "E"}))
	assert_true(data.is_valid(), ", ".join(data.errors))
	assert_eq(data.get_cell(Vector2i(4, 4)), LevelData.Cell.BRICK)
	assert_eq(data.get_cell(Vector2i(6, 4)), LevelData.Cell.STEEL)
	assert_eq(data.enemy_spawns.size(), 2)


func test_comments_are_ignored() -> void:
	var data := LevelData.parse("; comment\n" + blank_map())
	assert_true(data.is_valid(), ", ".join(data.errors))


func test_wrong_row_count_rejected() -> void:
	var rows := _lines(blank_map())
	rows.remove_at(rows.size() - 2)
	assert_false(LevelData.parse("\n".join(rows)).is_valid())


func test_wrong_row_width_rejected() -> void:
	var rows := _lines(blank_map())
	rows[6] += "."
	assert_false(LevelData.parse("\n".join(rows)).is_valid())


func test_missing_base_rejected() -> void:
	var edits := {}
	for c in [Vector2i(12, 24), Vector2i(13, 24), Vector2i(12, 25), Vector2i(13, 25)]:
		edits[c] = "."
	assert_false(LevelData.parse(blank_map("basic", 3, edits)).is_valid())


func test_partial_base_rejected() -> void:
	assert_false(LevelData.parse(blank_map("basic", 3, {Vector2i(13, 25): "."})).is_valid())


func test_second_base_rejected() -> void:
	var edits := {Vector2i(2, 12): "B", Vector2i(3, 12): "B", Vector2i(2, 13): "B", Vector2i(3, 13): "B"}
	assert_false(LevelData.parse(blank_map("basic", 3, edits)).is_valid())


func test_unknown_symbol_rejected() -> void:
	assert_false(LevelData.parse(blank_map("basic", 3, {Vector2i(5, 5): "X"})).is_valid())


func test_missing_player_spawn_rejected() -> void:
	assert_false(LevelData.parse(blank_map("basic", 3, {Vector2i(8, 24): "."})).is_valid())


func test_missing_enemy_spawn_rejected() -> void:
	assert_false(LevelData.parse(blank_map("basic", 3, {Vector2i(0, 0): "."})).is_valid())


func test_no_enemies_rejected() -> void:
	assert_false(LevelData.parse(blank_map("")).is_valid())


func test_blocked_spawn_area_rejected() -> void:
	assert_false(LevelData.parse(blank_map("basic", 3, {Vector2i(9, 25): "#"})).is_valid())


func test_unknown_header_key_rejected() -> void:
	assert_false(LevelData.parse("bogus=1\n" + blank_map()).is_valid())
