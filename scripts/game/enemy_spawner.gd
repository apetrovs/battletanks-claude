class_name EnemySpawner
extends RefCounted
## Decides *when* and *where* the next enemy of the level queue appears.
## The Game performs the actual spawn, because only it knows which spawn points are free.

const FIRST_SPAWN_DELAY := 0.5
const SPAWN_INTERVAL := 2.5

var queue: Array[String] = []
var max_active := 4
var point_count := 1

var _timer := FIRST_SPAWN_DELAY
var _next_point := 0


func _init(types: PackedStringArray, p_max_active: int, p_point_count: int) -> void:
	for t in types:
		queue.append(t)
	max_active = p_max_active
	point_count = maxi(1, p_point_count)


func remaining() -> int:
	return queue.size()


## Advances the timer; true when an enemy should appear now.
func is_ready(delta: float, active_count: int) -> bool:
	if queue.is_empty() or active_count >= max_active:
		return false
	_timer = maxf(0.0, _timer - delta)
	return _timer <= 0.0


func next_type() -> String:
	return queue[0]


## Spawn point indices in the order they should be tried.
func point_order() -> Array[int]:
	var order: Array[int] = []
	for i in point_count:
		order.append((_next_point + i) % point_count)
	return order


func commit(point_index: int) -> void:
	queue.pop_front()
	_timer = SPAWN_INTERVAL
	_next_point = (point_index + 1) % point_count
