extends Node
@export var ball_path: NodePath
@export var win_score: int = 5

@onready var ball: RigidBody2D = get_node(ball_path)
var player_score = 0
var opponent_score = 0
var game_over = false

func _ready():
	ball.score_point.connect(_on_score_point)

func _on_score_point(scorer: String):
	if game_over:
		return  # ignore further scoring once someone's won

	if scorer == "player":
		player_score += 1
	else:
		opponent_score += 1

	print("Player: %d   Opponent: %d" % [player_score, opponent_score])
	check_win()

func check_win():
	if player_score >= win_score:
		end_game("Player")
	elif opponent_score >= win_score:
		end_game("Opponent")

func end_game(winner: String):
	game_over = true
	print("%s wins!" % winner)
	ball.linear_velocity = Vector2.ZERO
	get_tree().paused = true

#debug
#func _process(delta: float) -> void:
#	print(player_score)
#	pass
	
	
	
