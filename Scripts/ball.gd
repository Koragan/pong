extends RigidBody2D

@export var bounce_damping = 0.99
@export var max_speed = 500
@export var reset_on_score: bool = true   # toggle: reposition ball after a score, or let it keep playing

signal ball_reset
signal score_point(player)

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

func reset_ball():
	position = get_viewport_rect().size / 2
	var angle = randf_range(-45, 45) * PI / 180
	var speed = 250
	linear_velocity = Vector2(cos(angle), sin(angle)) * speed
	emit_signal("ball_reset")
