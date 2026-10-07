extends SceneTree

var failed := false
var settings: Node
var saved_values: Dictionary
var old_config: PackedByteArray
var had_config := false

func check(condition: bool, label: String) -> void:
	print("PASS: " if condition else "FAIL: ", label)
	failed = failed or not condition

func _initialize() -> void:
	call_deferred("_run")

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame

func _run() -> void:
	settings = root.get_node("GameSettings")
	saved_values = settings.values.duplicate()
	had_config = FileAccess.file_exists(settings.SAVE_PATH)
	if had_config:
		old_config = FileAccess.get_file_as_bytes(settings.SAVE_PATH)
	settings.values = settings.DEFAULTS.duplicate()
	change_scene_to_file("res://main_menu.tscn")
	await process_frame
	await process_frame
	var main_menu = current_scene
	var options = main_menu.get_node("CenterContainer/VBoxContainer").get_child(3)
	options.pressed.emit()
	check(main_menu.menus.root_control.visible and main_menu.menus.showing_options, "main menu opens Options")
	main_menu.menus.controls.max_ball_speed.value = 600
	main_menu.menus.controls.curvature.value = 4
	main_menu.menus.controls.sfx_volume.value = 25
	check(settings.values.max_ball_speed == 600 and settings.values.sfx_volume == 0.25, "option controls update gameplay and volume values")
	check(main_menu.get_node("PostFX/CRTOverlay").material.get_shader_parameter("curvature") == 4.0, "CRT preview updates live")
	var config := ConfigFile.new()
	check(config.load(settings.SAVE_PATH) == OK and config.get_value("options", "max_ball_speed") == 600, "options persist to disk")
	await press(KEY_ESCAPE)
	check(not main_menu.menus.root_control.visible, "Esc returns from Options to main menu")
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	var manager = current_scene.get_node("GameManager")
	check(manager.ball.max_speed == 600, "new match uses saved options")
	await press(KEY_SPACE)
	check(paused and manager.manual_paused and manager.menus.root_control.visible, "Space pauses single-player during countdown")
	var countdown_elapsed: float = manager.countdown.elapsed
	var position: Vector2 = manager.ball.position
	await create_timer(0.15, true).timeout
	check(manager.countdown.elapsed == countdown_elapsed and manager.ball.position == position, "pause holds countdown and ball")
	manager.menus.show_options(true)
	manager.menus.controls.low_multiplier.value = 1.3
	manager.menus.controls.high_multiplier.value = 1.05
	manager.menus.controls.win_score.value = 10
	manager.menus.controls.crt_enabled.button_pressed = false
	check(manager.ball.low_speed_increase_on_paddle_hit == 1.3 and manager.ball.high_speed_increase_on_paddle_hit == 1.05 and manager.win_score == 10, "pause options apply both boosts and win score")
	check(not current_scene.get_node("PostFX/CRTOverlay").visible, "CRT can be disabled")
	await press(KEY_ESCAPE)
	check(paused and not manager.menus.showing_options, "Esc from Options returns to paused menu")
	await press(KEY_ESCAPE)
	check(not paused and not manager.manual_paused, "Esc resumes single-player")
	await manager.countdown.completed
	await press(KEY_ESCAPE)
	manager.player_score = 4
	manager.menus.show_options(true)
	manager.menus.controls.win_score.value = 3
	manager.menus.back_from_options()
	manager._resume_match()
	await process_frame
	check(manager.game_over and paused, "lowering win score ends an eligible match on Resume")
	paused = false
	settings.values = settings.DEFAULTS.duplicate()
	root.get_node("LanServer").match_player_ids.assign([1, 2])
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	manager = current_scene.get_node("GameManager")
	await manager.countdown.completed
	await press(KEY_SPACE)
	check(paused and manager.manual_paused, "Space pauses a phone match")
	manager._on_remote_player_left(1)
	manager._on_remote_player_joined(1)
	check(paused and manager.manual_paused, "phone reconnect preserves host pause")
	manager._on_remote_player_left(1)
	manager._resume_match()
	check(paused and manager.connection_paused and not manager.manual_paused, "Resume cannot bypass a disconnected phone")
	manager._on_remote_player_joined(1)
	check(not paused, "reconnect resumes after host has requested Resume")
	await press(KEY_ESCAPE)
	manager._leave_match()
	await process_frame
	await process_frame
	check(not paused and current_scene.scene_file_path == "res://lobby.tscn", "paused phone match can return to lobby")
	root.get_node("LanServer").stop()
	settings.values = saved_values
	if had_config:
		var file := FileAccess.open(settings.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(old_config)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.SAVE_PATH))
	settings.changed.emit()
	quit(1 if failed else 0)
