extends "res://tests/test_case.gd"


func _kill_ready_enemies(g: Game) -> void:
	for t in enemies_of(g):
		if not t.is_spawning():
			t.take_damage(1)


func test_start_level_loads_level_one() -> void:
	var g := make_game()
	assert_true(g.start_level(0, 5))
	assert_eq(g.level.name, "Stage 1")
	assert_eq(g.state, Game.State.PLAYING)
	assert_eq(g.lives, Game.START_LIVES)
	assert_eq(g.player.position, Battlefield.area_center(Vector2i(8, 24)))
	assert_eq(g.base.position, Battlefield.area_center(Vector2i(12, 24)))
	assert_eq(g.enemies_remaining(), 8)


func test_won_after_all_enemies_destroyed() -> void:
	var g := make_game(blank_map("basic", 3))
	spawn_passive_enemy(g, Vector2i(12, 0))
	g.spawner.queue.clear()
	settle(g)
	assert_eq(g.state, Game.State.PLAYING)
	_kill_ready_enemies(g)
	assert_eq(g.state, Game.State.WON)
	assert_eq(g.enemies_destroyed, 1)
	assert_false(g.is_round_over(), "result screen waits for END_DELAY")
	advance(g, Game.END_DELAY + 0.1)
	assert_true(g.is_round_over())


func test_not_won_while_queue_not_empty() -> void:
	var g := make_game(blank_map("basic basic", 3))
	spawn_passive_enemy(g, Vector2i(12, 0))
	settle(g)
	_kill_ready_enemies(g)
	assert_eq(g.state, Game.State.PLAYING)
	assert_eq(g.enemies_remaining(), 2)


func test_won_with_real_spawner() -> void:
	var g := make_game(blank_map("basic basic", 3), 1, true)
	for i in 60 * 12:
		g.step(FRAME)
		_kill_ready_enemies(g)
		if g.state != Game.State.PLAYING:
			break
	assert_eq(g.state, Game.State.WON)
	assert_eq(g.enemies_destroyed, 2)
	assert_eq(g.enemies_remaining(), 0)


func test_lost_when_base_destroyed_by_hit() -> void:
	var g := make_game()
	g.battlefield.hit_by_bullet(Rect2(98, 205, 4, 4), Vector2i.UP, 1)
	assert_eq(g.state, Game.State.LOST)
	assert_true(g.base.is_destroyed)
	g.battlefield.hit_by_bullet(Rect2(98, 205, 4, 4), Vector2i.UP, 1)
	assert_eq(g.state, Game.State.LOST)


func test_lost_when_bullet_hits_base() -> void:
	var g := make_game()
	settle(g)
	g.player.position = Vector2(104, 160)
	g.player.move_intent = Vector2i.DOWN
	g.player.fire_intent = true
	g.step(FRAME)
	g.player.move_intent = Vector2i.ZERO
	g.player.fire_intent = false
	advance(g, 0.5)
	assert_eq(g.state, Game.State.LOST)
	assert_true(g.base.is_destroyed)


func test_lost_when_lives_exhausted() -> void:
	var g := make_game()
	for i in Game.START_LIVES:
		assert_eq(g.state, Game.State.PLAYING, "life %d" % i)
		var guard := 0
		while (g.player == null or g.player.is_spawning()) and guard < 600:
			g.step(FRAME)
			guard += 1
		g.player.invulnerable_time = 0.0
		g.player.take_damage(1)
	assert_eq(g.lives, 0)
	assert_eq(g.state, Game.State.LOST)
	assert_true(g.player == null)
	advance(g, 3.0)
	assert_true(g.player == null, "no respawn after the last life")


func test_state_frozen_after_round_end() -> void:
	var g := make_game(blank_map("basic", 3), 1, true)
	g.battlefield.hit_by_bullet(Rect2(98, 205, 4, 4), Vector2i.UP, 1)
	advance(g, Game.END_DELAY + 1.0)
	assert_eq(enemies_of(g).size(), 0, "spawning stops once the round ends")
	g.player.take_damage(1)
	assert_eq(g.state, Game.State.LOST)


func test_restart_resets_everything() -> void:
	var map := blank_map("basic basic", 3, {Vector2i(10, 10): "#"})
	var g := make_game(map, 1, true)
	advance(g, 2.0)
	g.battlefield.set_cell(Vector2i(10, 10), LevelData.Cell.EMPTY)
	g.battlefield.hit_by_bullet(Rect2(98, 205, 4, 4), Vector2i.UP, 1)
	g.enemies_destroyed = 4
	assert_eq(g.state, Game.State.LOST)
	g.start_level_data(LevelData.parse(map), 1)
	assert_eq(g.state, Game.State.PLAYING)
	assert_eq(g.lives, Game.START_LIVES)
	assert_eq(g.enemies_destroyed, 0)
	assert_false(g.base.is_destroyed)
	assert_eq(g.battlefield.get_cell(Vector2i(10, 10)), LevelData.Cell.BRICK)
	assert_eq(g.tanks.size(), 1)
	assert_eq(g.bullets.size(), 0)
	assert_eq(g.entities.get_child_count(), 1)
	assert_true(g.player != null and g.player.alive)
	assert_eq(g.enemies_remaining(), 2)
	assert_false(g.is_round_over())


func test_spawner_respects_max_active_and_queue() -> void:
	var edits := {Vector2i(12, 0): "E", Vector2i(24, 0): "E"}
	var g := make_game(blank_map("basic basic basic basic", 2, edits), 3, true)
	advance(g, 1.0)
	assert_eq(g.active_enemy_count(), 1)
	advance(g, 2.1)
	assert_eq(g.active_enemy_count(), 2)
	var second_spawn := false
	for t in enemies_of(g):
		second_spawn = second_spawn or (t.is_spawning() and t.position == Battlefield.area_center(Vector2i(12, 0)))
	assert_true(second_spawn, "second enemy appears at the next spawn point")
	for i in 60 * 5:
		g.step(FRAME)
		assert_true(g.active_enemy_count() <= 2, "max_active exceeded")
		if g.state != Game.State.PLAYING:
			break
	assert_eq(g.state, Game.State.PLAYING)
	assert_eq(g.spawner.remaining(), 2)
	assert_eq(g.active_enemy_count(), 2)


func test_spawner_refills_after_kill_and_drains_queue() -> void:
	var g := make_game(blank_map("basic basic", 1), 3, true)
	advance(g, 1.5)
	assert_eq(g.active_enemy_count(), 1)
	assert_eq(g.spawner.remaining(), 1)
	_kill_ready_enemies(g)
	assert_eq(g.active_enemy_count(), 0)
	assert_eq(g.enemies_destroyed, 1)
	advance(g, 3.0)
	assert_eq(g.active_enemy_count(), 1)
	assert_eq(g.spawner.remaining(), 0)
	advance(g, 5.0)
	assert_eq(g.spawner.remaining(), 0)
	assert_true(g.active_enemy_count() <= 1)


func test_spawner_waits_for_blocked_spawn_point() -> void:
	var g := make_game(blank_map("basic", 3), 1, true)
	var blocker := spawn_passive_enemy(g, Vector2i(0, 0))
	g.spawner.queue.clear()
	g.spawner.queue.append("basic")
	advance(g, 3.0)
	assert_eq(g.spawner.remaining(), 1, "spawn point occupied")
	blocker.position = Vector2(100, 100)
	advance(g, 0.1)
	assert_eq(g.spawner.remaining(), 0)


func _signature(g: Game) -> Array:
	var sig: Array = [g.state, g.lives, g.enemies_destroyed, g.bullets.size(), g.spawner.remaining()]
	for t in g.tanks:
		sig.append([t.team, t.position, t.dir])
	return sig


func test_simulation_is_deterministic() -> void:
	var text := FileAccess.get_file_as_string(Game.LEVELS[0])
	var a := make_game(text, 77, true)
	var b := make_game(text, 77, true)
	for i in 60 * 20:
		a.step(FRAME)
		b.step(FRAME)
	assert_eq(_signature(a), _signature(b))


func test_ai_run_on_level_one_for_60_seconds() -> void:
	var g := make_game(FileAccess.get_file_as_string(Game.LEVELS[0]), 2024, true)
	var start_pos := {}
	var max_move := 0.0
	var enemy_bullets := {}
	var steps := 0
	for i in 60 * 60:
		g.step(FRAME)
		steps += 1
		for t in g.tanks:
			assert_true(t.active_bullets >= 0 and t.active_bullets <= t.stats.max_bullets, "bullet count")
			assert_false(g.battlefield.blocks_tank(t.get_rect()), "tank inside a wall at step %d" % i)
			if t.team == Tank.Team.ENEMY:
				var id := t.get_instance_id()
				if not start_pos.has(id):
					start_pos[id] = t.position
				max_move = maxf(max_move, t.position.distance_to(start_pos[id]))
		for b in g.bullets:
			if b.team == Tank.Team.ENEMY:
				enemy_bullets[b.get_instance_id()] = true
		assert_true(g.active_enemy_count() <= g.level.max_active_enemies, "max_active exceeded")
		if g.state != Game.State.PLAYING and g.is_round_over():
			break
	assert_true(start_pos.size() >= 3, "only %d enemies spawned" % start_pos.size())
	assert_true(max_move > 16.0, "enemies barely moved (%s px)" % max_move)
	assert_true(enemy_bullets.size() >= 3, "enemies fired only %d bullets" % enemy_bullets.size())
