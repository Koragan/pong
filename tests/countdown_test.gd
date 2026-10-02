extends SceneTree

var failed := false
var beats: Array[String] = []
var beat_positions: Array[Vector2] = []

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	failed = failed or not condition

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	var countdown = scene.get_node("UI/Countdown")
	var manager = scene.get_node("GameManager")
	countdown.beat_started.connect(func(value):
		beats.append(value)
		beat_positions.append(manager.ball.global_position)
	)
	root.add_child(scene)
	current_scene = scene
	await process_frame
	check(manager.match_starting and manager.ball.freeze, "ball frozen at match start")
	var initial_position: Vector2 = manager.ball.global_position
	manager._on_score_point("player")
	check(manager.player_score == 0, "countdown cannot award points")
	await create_timer(0.15).timeout
	check(manager.ball.global_position.is_equal_approx(initial_position), "ball stays still during countdown")
	# A disconnect pauses the countdown rather than launching unattended.
	root.get_node("LanServer").match_player_ids.assign([1, 2])
	manager.remote_paddles[1] = scene.get_node("PlayerPaddle")
	manager._on_remote_player_left(1)
	var elapsed: float = countdown.elapsed
	await create_timer(0.2, true).timeout
	check(paused and is_equal_approx(countdown.elapsed, elapsed) and manager.ball.freeze, "disconnect holds countdown and ball")
	manager._on_remote_player_joined(1)
	check(not paused, "reconnection resumes countdown")
	await countdown.completed
	check(beats == ["3", "2", "1", "GO"], "countdown presents 3, 2, 1, GO in order")
	check(not manager.match_starting and not manager.ball.freeze and manager.ball.linear_velocity.length() > 0, "GO releases a moving ball")
	check(beat_positions[0].is_equal_approx(beat_positions[1]) and beat_positions[1].is_equal_approx(beat_positions[2]), "ball stays stationary through all numeric beats")
	await create_timer(0.55).timeout
	check(not countdown.visible, "GO overlay clears for play")
	manager.ball.freeze = true
	manager._on_restart_pressed()
	await process_frame
	check(manager.match_starting and manager.ball.freeze and countdown.visible, "restart begins a fresh countdown")
	await countdown.completed
	check(beats.slice(4) == ["3", "2", "1", "GO"], "restart repeats the full sequence")
	root.get_node("LanServer").stop()
	quit(1 if failed else 0)
