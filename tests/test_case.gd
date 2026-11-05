extends RefCounted
## Base class for unit tests. The runner sets `root`, calls before_each(), one test_* method,
## then after_each(), and reports `failures`. Asserts record failures and never abort the test.

const FRAME := 1.0 / 60.0

var root: Node
var failures: Array[String] = []

var _nodes: Array[Node] = []


func before_each() -> void:
	pass


func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func add_node(n: Node) -> Node:
	root.add_child(n)
	_nodes.append(n)
	return n


# --- asserts ---------------------------------------------------------------------------------

func fail(msg: String) -> void:
	var where := ""
	for frame in get_stack():
		if not String(frame["source"]).ends_with("test_case.gd"):
			where = "%s:%d " % [String(frame["source"]).get_file(), frame["line"]]
			break
	failures.append(where + msg)


func assert_true(cond: bool, msg := "expected true") -> void:
	if not cond:
		fail(msg)


func assert_false(cond: bool, msg := "expected false") -> void:
	if cond:
		fail(msg)


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%s expected %s, got %s" % [msg, var_to_str(expected), var_to_str(actual)])


func assert_near(actual: float, expected: float, tol := 0.01, msg := "") -> void:
	if absf(actual - expected) > tol:
		fail("%s expected %s +/- %s, got %s" % [msg, expected, tol, actual])


# --- level / game helpers --------------------------------------------------------------------

## A valid 26x26 level: base at cells 12..13 x 24..25, player at (8,24), enemy spawn at (0,0).
## `edits` maps cell (Vector2i) -> single map character, applied on top (e.g. extra 'E', '#').
func blank_map(enemies := "basic", max_active := 3, edits := {}) -> String:
	var rows: Array[PackedStringArray] = []
	for y in LevelData.HEIGHT:
		var row := PackedStringArray()
		row.resize(LevelData.WIDTH)
		row.fill(".")
		rows.append(row)
	var cells := {Vector2i(12, 24): "B", Vector2i(13, 24): "B", Vector2i(12, 25): "B",
			Vector2i(13, 25): "B", Vector2i(8, 24): "P", Vector2i(0, 0): "E"}
	cells.merge(edits, true)
	for cell: Vector2i in cells:
		rows[cell.y][cell.x] = cells[cell]
	var text := "name=Test\nmax_active=%d\nenemies=%s\nmap:\n" % [max_active, enemies]
	for row in rows:
		text += "".join(row) + "\n"
	return text


## Game scene with the simulation under test control: autostart off, spawning off by default,
## player keyboard off. The player is at (72, 200) facing up on the default blank map.
func make_game(map_text := "", rng_seed := 1, spawning := false) -> Game:
	var g: Game = load("res://scenes/main.tscn").instantiate()
	g.autostart = false
	add_node(g)
	g.spawning_enabled = spawning
	var data := LevelData.parse(map_text if map_text != "" else blank_map())
	assert_true(data.is_valid(), "test level invalid: %s" % ", ".join(data.errors))
	g.start_level_data(data, rng_seed)
	g.player.use_keyboard = false
	return g


func advance(g: Game, seconds: float) -> void:
	for i in roundi(seconds / FRAME):
		g.step(FRAME)


## Steps past the 0.6 s spawn phase; drops the respawn shield unless asked to keep it.
func settle(g: Game, keep_shield := false) -> void:
	advance(g, Tank.SPAWN_TIME + 0.05)
	if not keep_shield and g.player != null:
		g.player.invulnerable_time = 0.0


## Enemy that never moves and never shoots (speed 0, max_bullets 0).
func spawn_passive_enemy(g: Game, cell: Vector2i) -> EnemyTank:
	var enemy := g.spawn_enemy("basic", cell)
	var s: TankStats = enemy.stats.duplicate()
	s.speed = 0.0
	s.max_bullets = 0
	enemy.stats = s
	return enemy


## Lets a passive enemy fire exactly when the test calls try_fire() (huge cooldown keeps the
## AI from shooting). Call after the spawn phase, otherwise the AI uses up the first shot.
func arm(enemy: EnemyTank) -> void:
	enemy.stats.max_bullets = 1
	enemy.stats.fire_cooldown = 1000.0


func enemies_of(g: Game) -> Array[Tank]:
	var result: Array[Tank] = []
	for t in g.tanks:
		if t.team == Tank.Team.ENEMY:
			result.append(t)
	return result
