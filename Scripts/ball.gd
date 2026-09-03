extends RigidBody2D

@export var bounce_damping = 0.99
@export var max_speed = 800
@export var reset_on_score: bool = true
@export var speed_increase_on_paddle_hit: float = 1.1  # multiplier per paddle hit
@export var high_speed_increase_on_paddle_hit: float = 1.05  # multiplier per paddle hit


signal ball_reset
signal score_point(player)
signal paddle_hit(paddle_name)

func _ready():
	linear_velocity = Vector2(200, -150)
	body_entered.connect(_on_body_entered)

func _physics_process(_delta):
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

func _on_body_entered(body):
	if body.name == "East":
		emit_signal("score_point", "player")
		if reset_on_score:
			call_deferred("reset_ball")
	elif body.name == "West":
		emit_signal("score_point", "opponent")
		if reset_on_score:
			call_deferred("reset_ball")
	elif body is CharacterBody2D:
		emit_signal("paddle_hit", body.name)   # just a notification, safe to emit immediately
		call_deferred("_boost_speed")          # mutates velocity — must be deferred

func _boost_speed():
	if linear_velocity.length() <= max_speed:
		if linear_velocity.length() <= 700:
			linear_velocity *= speed_increase_on_paddle_hit
	#		print("low") # Debug
		else:
			linear_velocity *= high_speed_increase_on_paddle_hit
	#		print("high") # Debug
	#print(linear_velocity.length()) # Debug
	
	
func reset_ball():
	position = get_viewport_rect().size / 2
	var angle = randf_range(-45, 45) * PI / 180
	var speed = 250
	linear_velocity = Vector2(cos(angle), sin(angle)) * speed
	emit_signal("ball_reset")
