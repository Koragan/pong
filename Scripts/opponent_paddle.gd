extends CharacterBody2D

@export var ball_path: NodePath
@export var min_y = 100.0
@export var max_y = 343.0
@export var post_hit_pause_range: Vector2 = Vector2(0.9, 0.3)  # (worst, best) sec frozen after own hit
var post_hit_pause_timer: float = 0.0

## Single knob: 0.0 = worst possible opponent, 1.0 = near-perfect keeper.
@export_range(0.0, 1.0, 0.1) var skill_level: float = 0.5

# What skill_level interpolates between — tune these bounds to change how
# extreme "easy" vs "hard" feels without touching any logic below.
@export var speed_range: Vector2 = Vector2(120.0, 500.0)       # (worst, best) px/sec
@export var reaction_delay_range: Vector2 = Vector2(0.6, 0.0)  # (worst, best) sec of hesitation
@export var error_range: Vector2 = Vector2(120.0, 0.0)         # (worst, best) one-shot aim error, px

@onready var ball: RigidBody2D = get_node(ball_path)

var target_y: float = 0.0
var reaction_timer: float = 0.0
var was_reacting: bool = false

func _ready():
	target_y = global_position.y
	ball.paddle_hit.connect(_on_paddle_hit)

func _on_paddle_hit(paddle_name: String):
	if paddle_name == "PlayerPaddle":
		reaction_timer = lerp(reaction_delay_range.x, reaction_delay_range.y, skill_level)
		was_reacting = true
	elif paddle_name == "OpponentPaddle":
		post_hit_pause_timer = lerp(post_hit_pause_range.x, post_hit_pause_range.y, skill_level)


func _physics_process(delta):
	if post_hit_pause_timer > 0.0:
		post_hit_pause_timer -= delta
		return   # fully frozen this frame — no movement, no tracking update at all

	var tracking_speed = lerp(speed_range.x, speed_range.y, skill_level)

	if reaction_timer > 0.0:
		reaction_timer -= delta
		# target_y intentionally frozen here — this IS the "didn't react yet" beat
	elif was_reacting:
		# delay just ended: commit to a fresh read on the ball, with a one-shot
		# error so low skill visibly misjudges where it's going
		var error_amount = lerp(error_range.x, error_range.y, skill_level)
		target_y = ball.global_position.y + randf_range(-error_amount, error_amount)
		was_reacting = false
	else:
		# normal continuous tracking the rest of the time
		target_y = ball.global_position.y

	var new_y = move_toward(global_position.y, target_y, tracking_speed * delta)
	global_position.y = clamp(new_y, min_y, max_y)
