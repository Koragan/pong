extends CharacterBody2D

@export var min_y = 100.0   # top limit — tune to your North wall's inner edge
@export var max_y = 343.0  # bottom limit — tune to your South wall's inner edge
@export var max_speed: float = 900.0   # generous — normally feels ~instant, but now scales with time_scale

func _physics_process(delta):
	var mouse_y = get_global_mouse_position().y
	var target_y = clamp(mouse_y, min_y, max_y)
	global_position.y = move_toward(global_position.y, target_y, max_speed * delta)
