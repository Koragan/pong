extends Node

@export var ball_path: NodePath
@export var win_score: int = 5

@export var score_label_path: NodePath
@export var win_panel_path: NodePath
@export var win_label_path: NodePath
@export var restart_button_path: NodePath

@onready var ball: RigidBody2D = get_node(ball_path)
@onready var score_label: Label = get_node(score_label_path)
@onready var win_panel: Control = get_node(win_panel_path)
@onready var win_label: Label = get_node(win_label_path)
@onready var restart_button: Button = get_node(restart_button_path)

var player_score = 0
var opponent_score = 0
var game_over = false

func _ready():
	ball.score_point.connect(_on_score_point)
	restart_button.pressed.connect(_on_restart_pressed)
	win_panel.visible = false
	update_score_label()

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
	game_over = true
	SFX.play_win()
	win_label.text = "%s wins!" % winner
	win_panel.visible = true
	call_deferred("_finalize_end_game")

func _finalize_end_game():
	ball.reset_ball(true)          # was: ball.reset_ball()
	ball.linear_velocity = Vector2.ZERO
	get_tree().paused = true

func _on_restart_pressed():
	ball.visible = true
	player_score = 0
	opponent_score = 0
	game_over = false
	win_panel.visible = false
	update_score_label()
	ball.reset_ball(true)          # was: ball.reset_ball()
	get_tree().paused = false
