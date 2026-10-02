extends SceneTree

var failed := false

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	failed = failed or not condition

func _initialize() -> void:
	call_deferred("_run")

func wait_for_physics() -> void:
	await physics_frame
	await process_frame

func launch_at_paddle(ball: RigidBody2D, start: Vector2, speed: Vector2) -> void:
	ball.freeze = true
	await wait_for_physics()
	ball.global_position = start
	await wait_for_physics()
	ball.freeze = false
	PhysicsServer2D.body_set_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, start))
	ball.linear_velocity = speed
	await create_timer(0.12).timeout

func _run() -> void:
	var server = root.get_node("LanServer")
	server.match_player_ids.assign([1, 2])
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	var manager = current_scene.get_node("GameManager")
	await manager.countdown.completed
	var ball: RigidBody2D = manager.ball
	var hits: Array = []
	ball.paddle_hit.connect(func(name): hits.append(name))
	check(manager.win_score == 5, "default winning score is five")
	for name in ["PlayerPaddle", "OpponentPaddle"]:
		var paddle = current_scene.get_node(name)
		check(paddle.process_mode != Node.PROCESS_MODE_DISABLED, name + " physics stays active")
		var visual: ColorRect = paddle.get_node("ColorRect")
		var shape: CollisionShape2D = paddle.get_node("CollisionShape2D")
		check(shape.shape.size.is_equal_approx(visual.size) and shape.position.is_equal_approx(visual.position + visual.size / 2), name + " collision matches visible rectangle")
	await launch_at_paddle(ball, Vector2(750, 231), Vector2(1500, 0))
	check(hits.has("OpponentPaddle") and ball.linear_velocity.x < 0, "ball bounces off remote right paddle at maximum speed")
	await launch_at_paddle(ball, Vector2(140, 231), Vector2(-1500, 0))
	check(hits.has("PlayerPaddle") and ball.linear_velocity.x > 0, "ball bounces off remote left paddle at maximum speed")
	ball.freeze = true
	manager.player_score = 0
	manager.opponent_score = 0
	manager.lobby_return_delay = 0.2
	for i in range(4):
		manager._on_score_point("player")
	check(not manager.game_over and manager.player_score == 4, "match continues below winning score")
	# Miss the right paddle and score through an actual ball/wall collision.
	await launch_at_paddle(ball, Vector2(790, 70), Vector2(500, 0))
	manager._on_score_point("opponent")
	check(manager.game_over and manager.player_score == 5 and manager.opponent_score == 0, "match stops scoring exactly at five")
	await create_timer(0.3, true, false, true).timeout
	check(not paused and current_scene.scene_file_path == "res://lobby.tscn", "winning phone match returns to unpaused lobby")
	check(server.last_match_result == "Left wins! 5 - 0", "lobby preserves winner and final score")
	check(current_scene.get_node("CenterContainer/VBoxContainer/StatusLabel").text.contains("5 - 0"), "lobby displays the final score")
	server.match_player_ids.assign([1, 2])
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	manager = current_scene.get_node("GameManager")
	await manager.countdown.completed
	manager.ball.freeze = true
	manager.win_score = 100
	manager.lobby_return_delay = 0.05
	for i in range(99):
		manager._on_score_point("opponent")
	check(not manager.game_over and manager.opponent_score == 99, "custom score of 100 does not finish at five or 99")
	manager._on_score_point("opponent")
	await create_timer(0.15, true, false, true).timeout
	check(server.last_match_result == "Right wins! 0 - 100" and current_scene.scene_file_path == "res://lobby.tscn", "custom score ends at 100 and returns to lobby")
	server.match_player_ids.clear()
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	manager = current_scene.get_node("GameManager")
	await manager.countdown.completed
	manager.ball.freeze = true
	for i in range(5):
		manager._on_score_point("player")
	await create_timer(0.15, true, false, true).timeout
	check(paused and current_scene.scene_file_path == "res://main.tscn" and manager.win_panel.visible, "single-player retains paused win and restart screen")
	manager._on_restart_pressed()
	check(not paused and not manager.game_over and manager.player_score == 0, "single-player restart resets match")
	server.stop()
	quit(1 if failed else 0)
