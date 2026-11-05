class_name PlayerTank
extends Tank
## Player-controlled tank. Reads keyboard actions; tests (and later touch controls)
## disable `use_keyboard` and set move_intent / fire_intent directly.

const MOVE_ACTIONS := {
	"move_up": Vector2i.UP,
	"move_down": Vector2i.DOWN,
	"move_left": Vector2i.LEFT,
	"move_right": Vector2i.RIGHT,
}

var use_keyboard := true


func _init() -> void:
	team = Team.PLAYER


func _think(_delta: float) -> void:
	if not use_keyboard:
		return
	var held: Array[Vector2i] = []
	for action: String in MOVE_ACTIONS:
		if Input.is_action_pressed(action):
			held.append(MOVE_ACTIONS[action])
	if held.is_empty():
		move_intent = Vector2i.ZERO
	elif held.has(dir):
		# Keep the current heading while its key is still held, so diagonals don't jitter.
		move_intent = dir
	else:
		move_intent = held[0]
	fire_intent = Input.is_action_pressed("fire")
