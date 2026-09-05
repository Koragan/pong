extends Camera2D

@export var ball_path: NodePath   # drag Ball node here

@export var max_offset: Vector2 = Vector2(16, 16)
@export var trauma_decay: float = 1.5   # per second

@export var paddle_hit_trauma: float = 0.15
@export var wall_bounce_trauma: float = 0.05
@export var score_trauma: float = 0.4

var trauma: float = 0.0
var rng := RandomNumberGenerator.new()

@onready var ball: RigidBody2D = get_node(ball_path)

func _ready():
	rng.randomize()
	ball.paddle_hit.connect(func(_name): add_trauma(paddle_hit_trauma))
	ball.wall_bounce.connect(func(): add_trauma(wall_bounce_trauma))
	ball.score_point.connect(func(_who): add_trauma(score_trauma))

func add_trauma(amount: float):
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _process(delta):
	if trauma > 0.0:
		trauma = max(trauma - trauma_decay * delta, 0.0)
		var shake_amount = trauma * trauma   # squared falloff — small trauma barely shows, big trauma hits hard
		offset = Vector2(
			rng.randf_range(-1.0, 1.0) * max_offset.x * shake_amount,
			rng.randf_range(-1.0, 1.0) * max_offset.y * shake_amount
		)
	else:
		offset = Vector2.ZERO
