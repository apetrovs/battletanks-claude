extends "res://tests/test_case.gd"


func test_player_moves_at_stats_speed() -> void:
	var g := make_game()
	settle(g)
	var start := g.player.position
	g.player.move_intent = Vector2i.UP
	advance(g, 0.5)
	assert_near(g.player.position.y, start.y - g.player.stats.speed * 0.5, 0.05)
	assert_near(g.player.position.x, start.x, 0.001)


func test_player_does_not_move_during_spawn_phase() -> void:
	var g := make_game()
	var start := g.player.position
	g.player.move_intent = Vector2i.UP
	advance(g, 0.3)
	assert_eq(g.player.position, start)


func test_player_moves_in_each_direction() -> void:
	var g := make_game()
	settle(g)
	g.player.position = Vector2(104, 104)
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP]:
		var before := g.player.position
		g.player.move_intent = d
		advance(g, 0.25)
		var delta := g.player.position - before
		assert_near(delta.length(), g.player.stats.speed * 0.25, 0.05, "dir %s" % d)
		assert_true(Vector2i(delta.sign()) == d, "dir %s moved %s" % [d, delta])
		assert_eq(g.player.dir, d)


func test_player_stops_flush_against_steel() -> void:
	var g := make_game(blank_map("basic", 3, {Vector2i(8, 20): "@", Vector2i(9, 20): "@"}))
	settle(g)
	g.player.move_intent = Vector2i.UP
	advance(g, 1.0)
	# Steel bottom edge is y=168, so the 16 px tank's center rests at 176.
	assert_near(g.player.position.y, 176.0, 0.01)
	assert_false(g.battlefield.blocks_tank(g.player.get_rect()), "tank overlaps steel")


func test_player_stops_flush_against_brick_horizontally() -> void:
	var g := make_game(blank_map("basic", 3, {Vector2i(4, 24): "#", Vector2i(4, 25): "#"}))
	settle(g)
	g.player.move_intent = Vector2i.LEFT
	advance(g, 2.0)
	# Brick right edge is x=40, so center rests at 48.
	assert_near(g.player.position.x, 48.0, 0.01)


func test_player_cannot_leave_map() -> void:
	var g := make_game()
	settle(g)
	for d: Vector2i in [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]:
		g.player.move_intent = d
		advance(g, 6.0)
		assert_true(g.battlefield.is_inside(g.player.get_rect()), "left the map moving %s" % d)
	assert_near(g.player.position.x, 200.0, 0.01)
	assert_near(g.player.position.y, 8.0, 0.01)


func test_player_blocked_by_other_tank() -> void:
	var g := make_game()
	var enemy := spawn_passive_enemy(g, Vector2i(8, 18))
	settle(g)
	g.player.move_intent = Vector2i.UP
	advance(g, 2.0)
	# Enemy rect spans y 144..160, so the player's center rests at 168.
	assert_near(g.player.position.y, enemy.position.y + 16.0, 0.01)
	assert_false(g.player.get_rect().intersects(enemy.get_rect()))


func test_perpendicular_turn_snaps_cross_axis_to_grid() -> void:
	var g := make_game()
	settle(g)
	g.player.position = Vector2(76, 150)
	g.player.move_intent = Vector2i.RIGHT
	advance(g, 1.0 / 60.0)
	assert_eq(g.player.position.y, 152.0)
	assert_true(g.player.position.x > 76.0)
	g.player.position = Vector2(76, 152)
	g.player.move_intent = Vector2i.UP
	g.step(FRAME)
	assert_eq(g.player.position.x, 80.0, "x snaps 76 -> 80 when turning to vertical")


func test_reverse_turn_does_not_snap() -> void:
	var g := make_game()
	settle(g)
	g.player.position = Vector2(76, 150)
	g.player.move_intent = Vector2i.DOWN
	g.step(FRAME)
	assert_eq(g.player.position.x, 76.0)
	assert_eq(g.player.dir, Vector2i.DOWN)
