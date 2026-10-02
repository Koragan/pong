extends SceneTree

var failed := false
var last_heartbeat_ms := 0

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	failed = failed or not condition

func _initialize() -> void:
	call_deferred("_run")

func pump(clients: Array, frames: int = 30) -> void:
	for i in range(frames):
		for client in clients:
			client.poll()
		if Time.get_ticks_msec() - last_heartbeat_ms >= 1000:
			for client in clients:
				if client.get_ready_state() == WebSocketPeer.STATE_OPEN:
					client.send_text('{"type":"ping","sent":0}')
			last_heartbeat_ms = Time.get_ticks_msec()
		await create_timer(0.01).timeout

func _run() -> void:
	var server = root.get_node("LanServer")
	check(server.start() == OK, "server starts")
	var clients: Array = []
	for i in range(2):
		var client := WebSocketPeer.new()
		client.connect_to_url("wss://127.0.0.1:8444", TLSOptions.client_unsafe())
		clients.append(client)
	await pump(clients, 100)
	check(server.player_count() == 2, "two phones connected")
	if server.player_count() != 2:
		server.stop()
		quit(1)
		return
	clients[0].send_text('{"type":"ping","sent":123}')
	clients[0].send_text('{"type":"latency","ms":12}')
	await pump(clients)
	var pong_ok := false
	while clients[0].get_available_packet_count() > 0:
		var data = JSON.parse_string(clients[0].get_packet().get_string_from_utf8())
		pong_ok = pong_ok or (data is Dictionary and data.get("type") == "pong" and data.get("sent") == 123)
	check(pong_ok, "ping timestamp echoed")
	check(server.player_latency.size() == 1, "PC receives phone latency")
	server.match_player_ids.assign(server.connected_player_ids())
	change_scene_to_file("res://main.tscn")
	await pump(clients)
	var manager = current_scene.get_node("GameManager")
	manager.ball.freeze = true
	check(manager.remote_paddles.size() == 2, "two remote paddles assigned")
	clients[0].send_text('{"type":"move","y":0}')
	clients[1].send_text('{"type":"move","y":1}')
	await pump(clients, 50)
	check(is_equal_approx(current_scene.get_node("PlayerPaddle").global_position.y, 100.0), "left paddle moves to top")
	check(is_equal_approx(current_scene.get_node("OpponentPaddle").global_position.y, 343.0), "right paddle moves to bottom")
	clients[0].send_text('{"type":"move","y":99}')
	await pump(clients)
	check(manager.remote_paddles[server.match_player_ids[0]].target_y == 343.0, "out-of-range input clamped")
	paused = true
	clients[0].send_text('{"type":"lobby"}')
	await pump(clients)
	check(not paused and current_scene.scene_file_path == "res://lobby.tscn", "phone can leave a paused match")
	check(not current_scene.get_node("CenterContainer/VBoxContainer/StartButton").disabled, "lobby ready for rematch")
	clients[1].close()
	await pump(clients)
	check(server.player_count() == 1, "disconnect updates count")
	check(current_scene.get_node("CenterContainer/VBoxContainer/StartButton").disabled, "match cannot start with missing phone")
	server.stop()
	quit(1 if failed else 0)
