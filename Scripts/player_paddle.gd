extends CharacterBody2D

@export var min_y = 100.0   # top limit — tune to your North wall's inner edge
@export var max_y = 343.0  # bottom limit — tune to your South wall's inner edge

func _physics_process(_delta):
	var mouse_y = get_global_mouse_position().y
	global_position.y = clamp(mouse_y, min_y, max_y)
