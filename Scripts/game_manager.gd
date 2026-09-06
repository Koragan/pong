extends Node

@export var win_score: int = 5
@export var max_speed_for_tint: float = 500.0

@export var ball_path: NodePath
@export var score_label_path: NodePath
@export var win_panel_path: NodePath
@export var win_label_path: NodePath
@export var restart_button_path: NodePath
@export var background_path: NodePath
@export var crt_overlay_path: NodePath
@export var camera_path: NodePath

@onready var camera: Camera2D = get_node(camera_path)
@onready var crt_mat: ShaderMaterial = get_node(crt_overlay_path).material
@onready var ball: RigidBody2D = get_node(ball_path)
@onready var score_label: Label = get_node(score_label_path)
@onready var win_panel: Control = get_node(win_panel_path)
@onready var win_label: Label = get_node(win_label_path)
@onready var restart_button: Button = get_node(restart_button_path)
@onready var background: ColorRect = get_node(background_path)

var player_score = 0
var opponent_score = 0
var game_over = false

func _ready():
	ball.score_point.connect(_on_score_point)
	restart_button.pressed.connect(_on_restart_pressed)
	win_panel.visible = false
	update_score_label()

func _process(_delta):
	var speed_t = clamp(ball.linear_velocity.length() / max_speed_for_tint, 0.0, 1.0)
	var base_tint = Color(1.0, 0.0, 0.067, 1.0)
	var hot_tint = Color(0.851, 1.0, 0.898, 1.0)
	crt_mat.set_shader_parameter("tint", base_tint.lerp(hot_tint, speed_t))

func _on_score_point(scorer: String):
	if game_over:
		return

	if scorer == "player":
		player_score += 1
	else:
		opponent_score += 1

	update_score_label()
	check_win()

func update_score_label():
	score_label.text = "%d   -   %d" % [player_score, opponent_score]

func check_win():
	if player_score >= win_score:
		end_game("Player")
	elif opponent_score >= win_score:
		end_game("Opponent")

func end_game(winner: String):
	ball.visible = false
	background.z_index = 2
	game_over = true
	SFX.play_win()
	win_label.text = "%s wins!" % winner
	win_panel.visible = true
	call_deferred("_finalize_end_game")

func _finalize_end_game():
	Engine.time_scale = 1.0   # safety net in case a critical moment was still active
	ball.reset_ball(true)          # was: ball.reset_ball()
	ball.linear_velocity = Vector2.ZERO
	get_tree().paused = true

func _on_restart_pressed():
	Engine.time_scale = 1.0
	SFX.play_paddle_hit()
	SFX.play_score()
	SFX.play_wall_bounce()
	SFX.play_win()
	background.z_index = -3
	ball.visible = true
	player_score = 0
	opponent_score = 0
	game_over = false
	win_panel.visible = false
	update_score_label()
	ball.reset_ball(true)          # was: ball.reset_ball()
	get_tree().paused = false
