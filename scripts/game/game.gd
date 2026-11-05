class_name Game
extends Node2D
## Owns one round: loads a level, spawns tanks, steps the simulation, tracks win/lose.
## All gameplay advances through step(delta), called from _physics_process (fixed 60 Hz)
## or directly by tests, which keeps the simulation deterministic.

enum State { PLAYING, WON, LOST }

const LEVELS: PackedStringArray = ["res://levels/level_01.txt"]
const PLAYER_SCENE := preload("res://scenes/entities/player_tank.tscn")
const ENEMY_SCENE := preload("res://scenes/entities/enemy_tank.tscn")
const BULLET_SCENE := preload("res://scenes/entities/bullet.tscn")
const EXPLOSION_SCENE := preload("res://scenes/fx/explosion.tscn")
const ENEMY_TYPES := {
	"basic": preload("res://data/tanks/enemy_basic.tres"),
}

const START_LIVES := 3
const RESPAWN_DELAY := 1.0
const RESPAWN_SHIELD := 3.0
## Gameplay keeps running briefly after the round ends, then the result screen accepts input.
const END_DELAY := 1.5

## Survives restarts so "next level" works without an autoload.
static var current_level := 0

## Tests set this to false before adding the scene to the tree, then call start_level*.
@export var autostart := true

var level: LevelData
var state := State.PLAYING
var paused := false
var player: PlayerTank
var lives := 0
var tanks: Array[Tank] = []
var bullets: Array[Bullet] = []
var spawner: EnemySpawner
var spawning_enabled := true
var enemies_destroyed := 0
var rng := RandomNumberGenerator.new()

var _respawn_timer := -1.0
var _end_timer := 0.0

@onready var battlefield: Battlefield = $World/Battlefield
@onready var base: Base = $World/Base
@onready var entities: Node2D = $World/Entities
@onready var hud: Hud = $Hud


func _ready() -> void:
	battlefield.base_hit.connect(_on_base_hit)
	hud.game = self
	if autostart:
		start_level(current_level)


func _physics_process(delta: float) -> void:
	if not paused:
		step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state == State.PLAYING:
		paused = not paused
	elif event.is_action_pressed("restart"):
		start_level(current_level)
	elif event.is_action_pressed("confirm") and is_round_over():
		start_level(current_level + 1 if state == State.WON else current_level)


func start_level(index: int, seed_value := -1) -> bool:
	current_level = posmod(index, LEVELS.size())
	var data := LevelData.load_file(LEVELS[current_level])
	for type in data.enemies:
		if not ENEMY_TYPES.has(type):
			data.errors.append("unknown enemy type '%s'" % type)
	if not data.is_valid():
		push_error("Level %s is invalid: %s" % [LEVELS[current_level], ", ".join(data.errors)])
		return false
	start_level_data(data, seed_value)
	return true


func start_level_data(data: LevelData, seed_value := -1) -> void:
	_clear_entities()
	level = data
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	battlefield.load_level(level)
	base.reset(Battlefield.area_center(level.base_cell))
	lives = START_LIVES
	state = State.PLAYING
	paused = false
	enemies_destroyed = 0
	_respawn_timer = -1.0
	_end_timer = 0.0
	spawner = EnemySpawner.new(level.enemies, level.max_active_enemies, level.enemy_spawns.size())
	_spawn_player()


func step(delta: float) -> void:
	if state != State.PLAYING:
		if _end_timer <= 0.0:
			return
		_end_timer -= delta
	else:
		_update_spawning(delta)
		_update_respawn(delta)
	for tank in tanks.duplicate():
		if tank.alive:
			tank.tick(delta)
	for bullet in bullets.duplicate():
		if bullet.alive:
			bullet.tick(delta)


func is_round_over() -> bool:
	return state != State.PLAYING and _end_timer <= 0.0


func enemies_remaining() -> int:
	return spawner.remaining() + active_enemy_count()


func active_enemy_count() -> int:
	var count := 0
	for tank in tanks:
		if tank.team == Tank.Team.ENEMY and tank.alive:
			count += 1
	return count


func can_occupy(tank: Tank, rect: Rect2) -> bool:
	if battlefield.blocks_tank(rect):
		return false
	var current := tank.get_rect()
	for other in tanks:
		if other == tank or not other.alive:
			continue
		var other_rect := other.get_rect()
		# Overlaps that already exist (e.g. after a respawn) may only be escaped, never deepened.
		if rect.intersects(other_rect) and not current.intersects(other_rect):
			return false
	return true


func is_area_free(rect: Rect2) -> bool:
	for tank in tanks:
		if tank.alive and tank.get_rect().intersects(rect):
			return false
	return true


func spawn_enemy(type: String, cell: Vector2i) -> EnemyTank:
	var enemy: EnemyTank = ENEMY_SCENE.instantiate()
	enemy.stats = ENEMY_TYPES[type]
	enemy.rng.seed = rng.randi()
	_add_tank(enemy, cell, Vector2i.DOWN)
	return enemy


func spawn_bullet(shooter: Tank) -> Bullet:
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.setup(self, shooter)
	entities.add_child(bullet)
	bullets.append(bullet)
	return bullet


func on_bullet_removed(bullet: Bullet, with_effect: bool) -> void:
	bullets.erase(bullet)
	if with_effect:
		_spawn_explosion(bullet.position, false)
	bullet.queue_free()


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	_add_tank(player, level.player_spawn, Vector2i.UP)
	player.invulnerable_time = RESPAWN_SHIELD


func _add_tank(tank: Tank, cell: Vector2i, facing: Vector2i) -> void:
	entities.add_child(tank)
	tank.setup(self, Battlefield.area_center(cell), facing)
	tank.destroyed.connect(_on_tank_destroyed)
	tanks.append(tank)


func _update_spawning(delta: float) -> void:
	if not spawning_enabled or not spawner.is_ready(delta, active_enemy_count()):
		return
	for index in spawner.point_order():
		var cell := level.enemy_spawns[index]
		if is_area_free(Tank.rect_at(Battlefield.area_center(cell))):
			spawn_enemy(spawner.next_type(), cell)
			spawner.commit(index)
			return


func _update_respawn(delta: float) -> void:
	if _respawn_timer < 0.0:
		return
	_respawn_timer -= delta
	if _respawn_timer <= 0.0 and is_area_free(Tank.rect_at(Battlefield.area_center(level.player_spawn))):
		_respawn_timer = -1.0
		_spawn_player()


func _on_tank_destroyed(tank: Tank) -> void:
	_spawn_explosion(tank.position, true)
	tanks.erase(tank)
	tank.queue_free()
	if tank == player:
		player = null
		lives -= 1
		if lives > 0:
			_respawn_timer = RESPAWN_DELAY
		else:
			_end_round(State.LOST)
	else:
		enemies_destroyed += 1
		if enemies_remaining() == 0:
			_end_round(State.WON)


func _on_base_hit() -> void:
	if base.is_destroyed:
		return
	base.destroy()
	_spawn_explosion(base.position, true)
	_end_round(State.LOST)


func _end_round(result: State) -> void:
	if state != State.PLAYING:
		return
	state = result
	_end_timer = END_DELAY


func _spawn_explosion(at: Vector2, big: bool) -> void:
	var fx: Explosion = EXPLOSION_SCENE.instantiate()
	fx.big = big
	fx.position = at
	entities.add_child(fx)


func _clear_entities() -> void:
	for child in entities.get_children():
		entities.remove_child(child)
		child.queue_free()
	tanks.clear()
	bullets.clear()
	player = null
