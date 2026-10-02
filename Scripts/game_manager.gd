extends Node

## Points required to win. Change this on GameManager in the Inspector.
@export_range(1, 100, 1, "or_greater") var win_score: int = 5
@export_range(0.0, 10.0, 0.1, "or_greater") var lobby_return_delay: float = 2.0
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
var remote_paddles: Dictionary = {}
var returning_to_lobby := false

func _ready():
	ball.score_point.connect(_on_score_point)
	restart_button.pressed.connect(_on_restart_pressed)
	win_panel.visible = false
	update_score_label()
	if LanServer.match_player_ids.size() == 2:
		var paddles := [get_node("../PlayerPaddle"), get_node("../OpponentPaddle")]
		for i in range(2):
			var paddle = paddles[i]
			# Keep physics bodies active; only replace their input source.
			if i == 0:
				paddle.control_source = paddle.ControlSource.REMOTE
			else:
				paddle.remote_control = true
			paddle.target_y = paddle.global_position.y
			remote_paddles[LanServer.match_player_ids[i]] = paddle
		LanServer.message_received.connect(_on_remote_message)
		LanServer.player_left.connect(_on_remote_player_left)
		LanServer.latency_updated.connect(_on_latency_updated)
		_update_connection_label()
		# Phone matches return to the lobby instead of restarting in place.
		restart_button.hide()

func _on_remote_message(id: int, data: Dictionary) -> void:
	if not remote_paddles.has(id):
		return
	match data.get("type", ""):
		"move":
			var y = data.get("y")
			if (y is float or y is int) and is_finite(float(y)):
				var paddle = remote_paddles[id]
				paddle.target_y = lerpf(paddle.min_y, paddle.max_y, clampf(float(y), 0.0, 1.0))
		"lobby":
			_return_to_lobby()

func _on_remote_player_left(id: int) -> void:
	if remote_paddles.has(id):
		_return_to_lobby()

func _return_to_lobby() -> void:
	if returning_to_lobby:
		return
	returning_to_lobby = true
	call_deferred("_open_lobby")

func _open_lobby() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	LanServer.match_player_ids.clear()
	get_tree().change_scene_to_file("res://lobby.tscn")

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
	if game_over:
		return
	if not remote_paddles.is_empty():
		winner = "Left" if winner == "Player" else "Right"
		LanServer.last_match_result = "%s wins! %d - %d" % [winner, player_score, opponent_score]
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
	if not remote_paddles.is_empty():
		get_tree().create_timer(lobby_return_delay, true, false, true).timeout.connect(_return_to_lobby)

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

func _on_restart_button_mouse_entered() -> void:
	SFX.play_paddle_hit()
	pass # Replace with function body.

func _on_latency_updated(_id: int, _milliseconds: int) -> void:
	_update_connection_label()

func _update_connection_label() -> void:
	var connections: Array[String] = []
	for i in range(LanServer.match_player_ids.size()):
		var id := LanServer.match_player_ids[i]
		var ping := "%d ms" % LanServer.player_latency[id] if LanServer.player_latency.has(id) else "..."
		connections.append("%s: %s" % ["Left" if i == 0 else "Right", ping])
	get_node("../UI/ConnectionLabel").text = " | ".join(connections)
