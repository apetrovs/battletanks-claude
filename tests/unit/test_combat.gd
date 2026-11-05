extends "res://tests/test_case.gd"

const WALL := {Vector2i(8, 20): "#", Vector2i(9, 20): "#", Vector2i(8, 19): "#", Vector2i(9, 19): "#"}


func _walled(char: String) -> Dictionary:
	var edits := {}
	for c: Vector2i in WALL:
		edits[c] = char
	return edits


func test_firing_spawns_bullet() -> void:
	var g := make_game()
	settle(g)
	g.player.fire_intent = true
	g.step(FRAME)
	assert_eq(g.bullets.size(), 1)
	assert_eq(g.player.active_bullets, 1)
	var b := g.bullets[0]
	assert_eq(b.team, Tank.Team.PLAYER)
	assert_eq(b.dir, Vector2i.UP)
	assert_true(b.get_shooter() == g.player)
	assert_true(b.position.y < g.player.position.y)


func test_no_fire_during_spawn_phase() -> void:
	var g := make_game()
	g.player.fire_intent = true
	advance(g, 0.3)
	assert_eq(g.bullets.size(), 0)


func test_max_bullets_limits_active_bullets() -> void:
	var g := make_game()
	settle(g)
	g.player.fire_intent = true
	var fired_ids := {}
	for i in 90:
		g.step(FRAME)
		assert_true(g.player.active_bullets <= g.player.stats.max_bullets)
		for b in g.bullets:
			fired_ids[b.get_instance_id()] = true
	assert_eq(g.player.stats.max_bullets, 1)
	# 1.5 s of held fire: the first bullet leaves the map after ~1.1 s, so exactly 2 shots.
	assert_eq(fired_ids.size(), 2)


func test_cooldown_spaces_shots() -> void:
	var g := make_game()
	settle(g)
	var s: TankStats = g.player.stats.duplicate()
	s.max_bullets = 5
	s.fire_cooldown = 0.5
	g.player.stats = s
	g.player.fire_intent = true
	advance(g, 0.4)
	assert_eq(g.bullets.size(), 1, "second shot must wait for cooldown")
	advance(g, 0.2)
	assert_eq(g.bullets.size(), 2)


func test_player_bullet_destroys_brick() -> void:
	var g := make_game(blank_map("basic", 3, _walled("#")))
	settle(g)
	g.player.fire_intent = true
	g.step(FRAME)
	g.player.fire_intent = false
	advance(g, 0.5)
	var f := g.battlefield
	assert_eq(f.get_cell(Vector2i(8, 20)), LevelData.Cell.EMPTY)
	assert_eq(f.get_cell(Vector2i(9, 20)), LevelData.Cell.EMPTY)
	assert_eq(f.get_cell(Vector2i(8, 19)), LevelData.Cell.BRICK, "second row survives one shot")
	assert_eq(g.bullets.size(), 0)
	assert_eq(g.player.active_bullets, 0)


func test_steel_stops_bullet() -> void:
	var g := make_game(blank_map("basic", 3, _walled("@")))
	settle(g)
	g.player.fire_intent = true
	g.step(FRAME)
	g.player.fire_intent = false
	advance(g, 0.5)
	assert_eq(g.battlefield.get_cell(Vector2i(8, 20)), LevelData.Cell.STEEL)
	assert_eq(g.bullets.size(), 0)
	assert_eq(g.player.active_bullets, 0)


func test_bullet_removed_at_map_edge() -> void:
	var g := make_game()
	settle(g)
	g.player.fire_intent = true
	g.step(FRAME)
	g.player.fire_intent = false
	advance(g, 1.5)
	assert_eq(g.bullets.size(), 0)
	assert_eq(g.player.active_bullets, 0)


func test_player_bullet_kills_basic_enemy() -> void:
	var g := make_game()
	var enemy := spawn_passive_enemy(g, Vector2i(8, 10))
	settle(g)
	g.player.fire_intent = true
	g.step(FRAME)
	g.player.fire_intent = false
	advance(g, 1.0)
	assert_eq(g.enemies_destroyed, 1)
	assert_false(enemy.alive)
	assert_false(g.tanks.has(enemy))
	assert_eq(g.bullets.size(), 0)


func test_player_bullet_ignores_friendly_fire_on_player() -> void:
	var g := make_game()
	settle(g)
	g.player.fire_intent = true
	advance(g, 0.2)
	assert_true(g.player.alive)


func test_enemy_bullet_kills_player_then_respawn() -> void:
	var g := make_game()
	var enemy := spawn_passive_enemy(g, Vector2i(8, 10))
	settle(g)
	arm(enemy)
	enemy.dir = Vector2i.DOWN
	assert_true(enemy.try_fire())
	var frames := 0
	while g.player != null and frames < 240:
		g.step(FRAME)
		frames += 1
	assert_true(g.player == null, "player should be hit by the enemy bullet")
	assert_eq(g.lives, Game.START_LIVES - 1)
	assert_eq(g.state, Game.State.PLAYING)
	var wait := 0
	while g.player == null and wait < 240:
		g.step(FRAME)
		wait += 1
	assert_true(g.player != null, "player should respawn")
	assert_true(absi(wait - roundi(Game.RESPAWN_DELAY / FRAME)) <= 2, "respawn after %d frames" % wait)
	assert_eq(g.player.position, Battlefield.area_center(g.level.player_spawn))
	assert_true(g.player.invulnerable_time > 0.0, "respawned player is shielded")
	assert_eq(g.lives, Game.START_LIVES - 1)


func test_opposing_bullets_cancel() -> void:
	var g := make_game()
	var enemy := spawn_passive_enemy(g, Vector2i(8, 10))
	settle(g)
	arm(enemy)
	enemy.dir = Vector2i.DOWN
	assert_true(enemy.try_fire())
	g.player.fire_intent = true
	g.step(FRAME)
	g.player.fire_intent = false
	assert_eq(g.bullets.size(), 2)
	advance(g, 1.0)
	assert_eq(g.bullets.size(), 0)
	assert_true(g.player.alive)
	assert_true(enemy.alive)
	assert_eq(g.player.active_bullets, 0)
	assert_eq(enemy.active_bullets, 0)


func test_spawn_phase_is_invulnerable() -> void:
	var g := make_game()
	assert_true(g.player.is_spawning())
	g.player.invulnerable_time = 0.0
	g.player.take_damage(1)
	assert_true(g.player.alive)
	assert_eq(g.lives, Game.START_LIVES)
	var enemy := spawn_passive_enemy(g, Vector2i(8, 10))
	enemy.take_damage(1)
	assert_true(enemy.alive)


func test_respawn_shield_absorbs_damage_then_expires() -> void:
	var g := make_game()
	settle(g, true)
	assert_false(g.player.is_spawning())
	g.player.take_damage(1)
	assert_true(g.player.alive, "shield must absorb damage")
	advance(g, Game.RESPAWN_SHIELD)
	assert_eq(g.player.invulnerable_time, 0.0)
	var victim := g.player
	victim.take_damage(1)
	assert_false(victim.alive)
	assert_eq(g.lives, Game.START_LIVES - 1)


func test_shield_absorbs_enemy_bullet() -> void:
	var g := make_game()
	var enemy := spawn_passive_enemy(g, Vector2i(8, 10))
	settle(g, true)
	arm(enemy)
	enemy.dir = Vector2i.DOWN
	assert_true(enemy.try_fire())
	advance(g, 1.5)
	assert_true(g.player.alive)
	assert_eq(g.bullets.size(), 0, "bullet is consumed by the shielded tank")
	assert_eq(g.lives, Game.START_LIVES)
