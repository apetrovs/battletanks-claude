class_name EnemyTank
extends Tank
## Simple, robust enemy AI: wander with a bias towards the base (sometimes the player),
## pick a new direction when blocked, shoot periodically and when a target is in line,
## and shoot through bricks in its way.

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const BLOCKED_REACT_TIME := 0.2
const BASE_TARGET_CHANCE := 0.65
const ALIGN_TOLERANCE := 6.0

var rng := RandomNumberGenerator.new()

var _turn_timer := 0.0
var _fire_timer := 0.0
var _blocked_time := 0.0


func _init() -> void:
	team = Team.ENEMY


func _think(delta: float) -> void:
	_turn_timer -= delta
	_fire_timer -= delta
	if move_intent == Vector2i.ZERO or _turn_timer <= 0.0:
		_pick_direction(Vector2i.ZERO)
	fire_intent = false
	if _fire_timer <= 0.0:
		fire_intent = true
		_fire_timer = rng.randf_range(0.7, 1.8)
	elif _target_in_line():
		fire_intent = true


func _on_move_result(blocked: bool, delta: float) -> void:
	if not blocked:
		_blocked_time = 0.0
		return
	_blocked_time += delta
	if _blocked_time < BLOCKED_REACT_TIME:
		return
	_blocked_time = 0.0
	var ahead := get_rect()
	ahead.position += Vector2(dir) * 2.0
	if game.battlefield.contains_cell(ahead, LevelData.Cell.BRICK) and rng.randf() < 0.6:
		fire_intent = true  # dig through instead of turning away
	else:
		_pick_direction(dir)


func _pick_direction(avoid: Vector2i) -> void:
	var to_target := _choose_target() - position
	var weights: Array[float] = []
	var total := 0.0
	for d in DIRS:
		var w := 1.0
		if d == avoid:
			w = 0.0
		else:
			if (d.y > 0 and to_target.y > 4.0) or (d.y < 0 and to_target.y < -4.0):
				w += 3.0
			if (d.x > 0 and to_target.x > 4.0) or (d.x < 0 and to_target.x < -4.0):
				w += 2.0
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in DIRS.size():
		roll -= weights[i]
		if roll <= 0.0 and weights[i] > 0.0:
			move_intent = DIRS[i]
			break
	_turn_timer = rng.randf_range(1.0, 3.0)


func _choose_target() -> Vector2:
	var player := game.player
	if player == null or rng.randf() < BASE_TARGET_CHANCE:
		return game.base.position
	return player.position


func _target_in_line() -> bool:
	var targets: Array[Vector2] = [game.base.position]
	if game.player != null and not game.player.is_spawning():
		targets.append(game.player.position)
	for target in targets:
		var to := target - position
		if dir.x != 0 and absf(to.y) < ALIGN_TOLERANCE and signf(to.x) == dir.x:
			return true
		if dir.y != 0 and absf(to.x) < ALIGN_TOLERANCE and signf(to.y) == dir.y:
			return true
	return false
