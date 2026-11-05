extends "res://tests/test_case.gd"

const BRICK := LevelData.Cell.BRICK
const STEEL := LevelData.Cell.STEEL


func _field(edits := {}) -> Battlefield:
	var b := Battlefield.new()
	add_node(b)
	b.load_level(LevelData.parse(blank_map("basic", 3, edits)))
	return b


func test_brick_blocks_tank() -> void:
	var b := _field({Vector2i(10, 10): "#"})
	assert_true(b.blocks_tank(Tank.rect_at(Vector2(73, 84))))
	assert_false(b.blocks_tank(Tank.rect_at(Vector2(72, 84))), "touching edge must not block")


func test_steel_blocks_tank() -> void:
	var b := _field({Vector2i(10, 10): "@"})
	assert_true(b.blocks_tank(Tank.rect_at(Vector2(73, 84))))
	assert_false(b.blocks_tank(Tank.rect_at(Vector2(72, 84))))


func test_base_blocks_tank() -> void:
	var b := _field()
	assert_true(b.blocks_tank(Tank.rect_at(Vector2(89, 200))))
	assert_false(b.blocks_tank(Tank.rect_at(Vector2(88, 200))))


func test_map_bounds_block_tank() -> void:
	var b := _field()
	assert_false(b.blocks_tank(Tank.rect_at(Vector2(8, 8))))
	assert_true(b.blocks_tank(Tank.rect_at(Vector2(7.9, 100))))
	assert_true(b.blocks_tank(Tank.rect_at(Vector2(100, 7.9))))
	assert_false(b.blocks_tank(Tank.rect_at(Vector2(200, 100))))
	assert_true(b.blocks_tank(Tank.rect_at(Vector2(200.1, 100))))
	assert_true(b.blocks_tank(Tank.rect_at(Vector2(100, 200.1))))


func test_bullet_destroys_aligned_brick_strip_upwards() -> void:
	var b := _field({Vector2i(10, 10): "#", Vector2i(11, 10): "#", Vector2i(10, 9): "#",
			Vector2i(9, 10): "#", Vector2i(12, 10): "#"})
	var stopped := b.hit_by_bullet(Rect2(86, 87, 4, 4), Vector2i.UP, 1)
	assert_true(stopped)
	assert_eq(b.get_cell(Vector2i(10, 10)), LevelData.Cell.EMPTY)
	assert_eq(b.get_cell(Vector2i(11, 10)), LevelData.Cell.EMPTY)
	assert_eq(b.get_cell(Vector2i(10, 9)), BRICK, "only the leading row is removed")
	assert_eq(b.get_cell(Vector2i(9, 10)), BRICK, "strip is 2 cells wide when aligned")
	assert_eq(b.get_cell(Vector2i(12, 10)), BRICK)


func test_bullet_destroys_aligned_brick_strip_sideways() -> void:
	var b := _field({Vector2i(10, 10): "#", Vector2i(10, 11): "#", Vector2i(11, 10): "#",
			Vector2i(10, 9): "#", Vector2i(10, 12): "#"})
	var stopped := b.hit_by_bullet(Rect2(77, 86, 4, 4), Vector2i.RIGHT, 1)
	assert_true(stopped)
	assert_eq(b.get_cell(Vector2i(10, 10)), LevelData.Cell.EMPTY)
	assert_eq(b.get_cell(Vector2i(10, 11)), LevelData.Cell.EMPTY)
	assert_eq(b.get_cell(Vector2i(11, 10)), BRICK, "only the leading column is removed")
	assert_eq(b.get_cell(Vector2i(10, 9)), BRICK)
	assert_eq(b.get_cell(Vector2i(10, 12)), BRICK)


func test_bullet_in_empty_space_is_not_stopped() -> void:
	var b := _field()
	assert_false(b.hit_by_bullet(Rect2(86, 87, 4, 4), Vector2i.UP, 1))


func test_steel_stops_bullet_unchanged() -> void:
	var b := _field({Vector2i(10, 10): "@", Vector2i(11, 10): "@"})
	assert_true(b.hit_by_bullet(Rect2(86, 87, 4, 4), Vector2i.UP, 1))
	assert_eq(b.get_cell(Vector2i(10, 10)), STEEL)
	assert_eq(b.get_cell(Vector2i(11, 10)), STEEL)


func test_base_hit_emits_signal() -> void:
	var b := _field()
	var hits := [0]
	b.base_hit.connect(func() -> void: hits[0] += 1)
	assert_true(b.hit_by_bullet(Rect2(98, 205, 4, 4), Vector2i.UP, 1))
	assert_eq(hits[0], 1)
	assert_eq(b.get_cell(Vector2i(12, 25)), LevelData.Cell.BASE, "base cells are not erased")


func test_brick_hit_does_not_emit_base_hit() -> void:
	var b := _field({Vector2i(10, 10): "#"})
	var hits := [0]
	b.base_hit.connect(func() -> void: hits[0] += 1)
	b.hit_by_bullet(Rect2(78, 87, 4, 4), Vector2i.UP, 1)
	assert_eq(hits[0], 0)


func test_area_center() -> void:
	assert_eq(Battlefield.area_center(Vector2i(8, 24)), Vector2(72, 200))
