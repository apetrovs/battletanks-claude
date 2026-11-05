class_name Bullet
extends Node2D
## A projectile moving in small sub-steps so fast bullets can't tunnel through 8px cells.
## Parameters come from the shooter's TankStats; new projectile kinds can extend this class
## or add fields to TankStats (e.g. power >= 2 for steel-breaking shots).

const SIZE := 4.0
const SUB_STEP := 2.0

var game: Game
var team := Tank.Team.ENEMY
var dir := Vector2i.UP
var speed := 120.0
var power := 1
var alive := true

var _shooter: WeakRef


func setup(p_game: Game, shooter: Tank) -> void:
	game = p_game
	_shooter = weakref(shooter)
	team = shooter.team
	dir = shooter.dir
	speed = shooter.stats.bullet_speed
	power = shooter.stats.bullet_power
	position = shooter.position + Vector2(dir) * 6.0
	rotation = Vector2(dir).angle() + PI / 2.0


func get_rect() -> Rect2:
	return Rect2(position - Vector2(SIZE, SIZE) * 0.5, Vector2(SIZE, SIZE))


func get_shooter() -> Tank:
	return _shooter.get_ref() if _shooter else null


func tick(delta: float) -> void:
	var remaining := speed * delta
	while alive and remaining > 0.0:
		var step := minf(SUB_STEP, remaining)
		remaining -= step
		position += Vector2(dir) * step
		_check_collisions()


func remove(with_effect: bool) -> void:
	if not alive:
		return
	alive = false
	var shooter := get_shooter()
	if shooter:
		shooter.active_bullets -= 1
	game.on_bullet_removed(self, with_effect)


func _check_collisions() -> void:
	var rect := get_rect()
	for other in game.bullets:
		if other != self and other.alive and other.team != team and rect.intersects(other.get_rect()):
			other.remove(false)
			remove(false)
			return
	for tank in game.tanks:
		if tank.alive and tank.team != team and rect.intersects(tank.get_rect()):
			tank.take_damage(power)
			remove(true)
			return
	if not game.battlefield.is_inside(rect):
		remove(true)
		return
	if game.battlefield.hit_by_bullet(rect, dir, power):
		remove(true)


func _draw() -> void:
	draw_rect(Rect2(-1.5, -2, 3, 4), Color("f4f0c8"))
	draw_rect(Rect2(-0.5, -3, 1, 1), Color("fffbe8"))
