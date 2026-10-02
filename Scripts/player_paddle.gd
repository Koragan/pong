extends CharacterBody2D

enum ControlSource { MOUSE, KEYS_ARROWS, KEYS_WS, REMOTE }

@export var control_source: ControlSource = ControlSource.MOUSE
@export var min_y = 100.0   # top limit — tune to your North wall's inner edge
@export var max_y = 343.0   # bottom limit — tune to your South wall's inner edge
@export var max_speed: float = 900.0      # how fast the paddle chases target_y
@export var keyboard_speed: float = 500.0 # how fast target_y slides while a key is held

# The one thing every control source writes to. REMOTE (phone/network) will set it from outside.
var target_y: float

func _ready():
	target_y = global_position.y

func _physics_process(delta):
	match control_source:
		ControlSource.MOUSE:
			target_y = get_global_mouse_position().y
		ControlSource.KEYS_ARROWS:
			target_y += _key_axis(KEY_UP, KEY_DOWN) * keyboard_speed * delta
		ControlSource.KEYS_WS:
			target_y += _key_axis(KEY_W, KEY_S) * keyboard_speed * delta
		ControlSource.REMOTE:
			pass  # something else assigns target_y; we just follow it

	target_y = clamp(target_y, min_y, max_y)
	global_position.y = move_toward(global_position.y, target_y, max_speed * delta)

func _key_axis(up_key: Key, down_key: Key) -> float:
	return float(Input.is_physical_key_pressed(down_key)) - float(Input.is_physical_key_pressed(up_key))
