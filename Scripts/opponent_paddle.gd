extends CharacterBody2D

@export var ball_path: NodePath   # drag the Ball node here in the Inspector
@export var min_y = 100.0
@export var max_y = 343.0
@export var tracking_speed = 300.0  # pixels/sec — tune this for difficulty

@onready var ball: RigidBody2D = $"../Ball"


func _physics_process(delta):
	var target_y = ball.global_position.y
	var current_y = global_position.y 
	
	# Move toward the ball's Y, but capped by tracking_speed
	var new_y = move_toward(current_y, target_y, tracking_speed * delta)
	global_position.y = clamp(new_y, min_y, max_y)
