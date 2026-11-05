class_name Tank
extends Node2D
## Shared tank behaviour: grid-friendly movement, collision, firing, damage and drawing.
## Subclasses only decide *what* to do by filling move_intent / fire_intent in _think().
## The Game drives every tank through tick() so the simulation is deterministic and testable.

signal destroyed(tank: Tank)

enum Team { PLAYER, ENEMY }

const SIZE := 16.0
const HALF := SIZE / 2.0
## Tanks re-align to this grid when turning 90 degrees, so they fit 2-cell corridors.
const GRID := 8.0
const SPAWN_TIME := 0.6
const HIT_FLASH_TIME := 0.12
const EPSILON_MOVE := 0.001

@export var stats: TankStats

var team := Team.ENEMY
var game: Game
var dir := Vector2i.UP
var hp := 1
var alive := true
var move_intent := Vector2i.ZERO
var fire_intent := false
var invulnerable_time := 0.0
var active_bullets := 0

var _cooldown := 0.0
var _spawn_time := 0.0
var _track_phase := 0.0
var _flash_time := 0.0


func setup(p_game: Game, center: Vector2, p_dir: Vector2i) -> void:
	game = p_game
	position = center
	dir = p_dir
	hp = stats.max_hp
	_spawn_time = SPAWN_TIME
	_update_rotation()


func get_rect() -> Rect2:
	return rect_at(position)


static func rect_at(center: Vector2) -> Rect2:
	return Rect2(center - Vector2(HALF, HALF), Vector2(SIZE, SIZE))


func is_spawning() -> bool:
	return _spawn_time > 0.0


func is_invulnerable() -> bool:
	return invulnerable_time > 0.0 or is_spawning()


func tick(delta: float) -> void:
	if not alive:
		return
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_flash_time = maxf(0.0, _flash_time - delta)
	queue_redraw()
	if _spawn_time > 0.0:
		_spawn_time -= delta
		return
	_think(delta)
	if move_intent != Vector2i.ZERO:
		_turn(move_intent)
		var wanted := stats.speed * delta
		var moved := _move_forward(wanted)
		_track_phase += moved
		_on_move_result(moved < wanted - EPSILON_MOVE, delta)
	if fire_intent:
		try_fire()


func try_fire() -> bool:
	if not alive or is_spawning() or _cooldown > 0.0 or active_bullets >= stats.max_bullets:
		return false
	_cooldown = stats.fire_cooldown
	active_bullets += 1
	game.spawn_bullet(self)
	return true


func take_damage(amount: int) -> void:
	if not alive or is_invulnerable():
		return
	hp -= amount
	_flash_time = HIT_FLASH_TIME
	if hp <= 0:
		alive = false
		destroyed.emit(self)


## Override: decide move_intent / fire_intent for this tick.
func _think(_delta: float) -> void:
	pass


## Override: react to a fully performed or blocked move.
func _on_move_result(_blocked: bool, _delta: float) -> void:
	pass


func _turn(new_dir: Vector2i) -> void:
	if new_dir == dir:
		return
	var perpendicular := (dir.x == 0) != (new_dir.x == 0)
	dir = new_dir
	_update_rotation()
	if not perpendicular:
		return
	# Snapping only shrinks the set of occupied cells, so it can't push us into a wall,
	# but it may push us into another tank — then we keep the unsnapped position.
	var snapped := position
	if new_dir.x != 0:
		snapped.y = roundf(position.y / GRID) * GRID
	else:
		snapped.x = roundf(position.x / GRID) * GRID
	if game.can_occupy(self, rect_at(snapped)):
		position = snapped


## Moves up to `distance` along `dir`, stopping flush against obstacles. Returns distance moved.
func _move_forward(distance: float) -> float:
	var step := Vector2(dir)
	if game.can_occupy(self, rect_at(position + step * distance)):
		position += step * distance
		return distance
	var lo := 0.0
	var hi := distance
	for i in 8:
		var mid := (lo + hi) * 0.5
		if game.can_occupy(self, rect_at(position + step * mid)):
			lo = mid
		else:
			hi = mid
	position += step * lo
	return lo


func _update_rotation() -> void:
	rotation = Vector2(dir).angle() + PI / 2.0


func _draw() -> void:
	if _spawn_time > 0.0:
		_draw_spawn_marker()
		return
	var body := stats.body_color
	if _flash_time > 0.0:
		body = Color.WHITE
	var tread := stats.track_color.darkened(0.45)
	# Tracks with treads that scroll as the tank moves (drawn facing up; node rotation handles direction).
	draw_rect(Rect2(-8, -8, 4, 16), stats.track_color)
	draw_rect(Rect2(4, -8, 4, 16), stats.track_color)
	var offset := posmod(int(_track_phase), 3)
	for y in range(-8 + offset, 8, 3):
		draw_rect(Rect2(-8, y, 4, 1), tread)
		draw_rect(Rect2(4, y, 4, 1), tread)
	# Hull, turret and barrel.
	draw_rect(Rect2(-5, -6, 10, 12), body)
	draw_rect(Rect2(-5, -6, 10, 1), body.lightened(0.35))
	draw_rect(Rect2(-5, 5, 10, 1), body.darkened(0.35))
	draw_rect(Rect2(-3, -3, 6, 6), body.darkened(0.25))
	draw_rect(Rect2(-2, -2, 4, 4), body.lightened(0.15))
	draw_rect(Rect2(-1, -9, 2, 7), body.darkened(0.4))
	if invulnerable_time > 0.0 and posmod(int(invulnerable_time * 16.0), 2) == 0:
		draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 20, Color(0.55, 0.9, 1.0, 0.85), 1.0)


func _draw_spawn_marker() -> void:
	var r := 3.0 + 4.0 * absf(sin(_spawn_time * 18.0))
	var color := Color(1.0, 1.0, 0.85)
	draw_rect(Rect2(-r, -0.5, r * 2.0, 1.0), color)
	draw_rect(Rect2(-0.5, -r, 1.0, r * 2.0), color)
	draw_rect(Rect2(-1.5, -1.5, 3.0, 3.0), color)
