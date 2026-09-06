extends Camera2D

# --- screen shake ---
@export var ball_path: NodePath
@export var max_offset: Vector2 = Vector2(16, 16)
@export var trauma_decay: float = 1.5
@export var paddle_hit_trauma: float = 0.15
@export var wall_bounce_trauma: float = 0.05
@export var score_trauma: float = 0.4

# --- references ---
@export var predictor_path: NodePath
@export var game_manager_path: NodePath

# --- distance-driven critical moment, all controllable ---
@export_category("Critical moment")
@export var critical_moment: bool = true
@export var min_distance_to_start: float = 250.0   # remaining path-length to the wall that begins the effect
@export var max_distance_to_end: float = 250.0      # distance traveled AFTER impact before fully back to normal
@export var max_zoom: Vector2 = Vector2(1.4, 1.4)
@export_range(0, 1, 0.01) var min_slowmo_scale: float = 0.05   # time_scale at the peak (moment of impact)
@export var wait_time: float = 1.0                  # real seconds held at peak
@export var normal_state_of_zoom: Vector2 = Vector2(0.9, 0.9)
@export var recovery_tween_duration: float = 1.0    # final camera-position glide back after a normal departure
@export var impact_release_duration: float = 0.3    # fast ease-out specifically when the shot gets intercepted

var trauma: float = 0.0
var rng := RandomNumberGenerator.new()

var critical_state: String = "idle"   # "idle" | "approaching" | "departing"
var impact_happened: bool = false
var original_camera_pos: Vector2 = Vector2.ZERO
var departure_anchor: Vector2 = Vector2.ZERO

@onready var ball: RigidBody2D = get_node(ball_path)
@onready var predictor: Node = get_node(predictor_path)
@onready var game_manager: Node = get_node(game_manager_path)

func _ready():
	rng.randomize()
	zoom = normal_state_of_zoom
	ball.paddle_hit.connect(func(_name): add_trauma(paddle_hit_trauma))
	ball.wall_bounce.connect(func(): add_trauma(wall_bounce_trauma))
	ball.score_point.connect(func(_who):
		add_trauma(score_trauma)
		impact_happened = true
	)

func add_trauma(amount: float):
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _process(delta):
	_update_shake(delta)
	if critical_state == "idle":
		_check_start_condition()

func _update_shake(delta):
	if trauma > 0.0:
		trauma = max(trauma - trauma_decay * delta, 0.0)
		var shake_amount = trauma * trauma
		offset = Vector2(
			rng.randf_range(-1.0, 1.0) * max_offset.x * shake_amount,
			rng.randf_range(-1.0, 1.0) * max_offset.y * shake_amount
		)
	else:
		offset = Vector2.ZERO

func _is_relevant(prediction: Dictionary) -> bool:
	if prediction.distance == INF:
		return false
	var player_match_point = prediction.scorer == "player" and game_manager.player_score == game_manager.win_score - 1
	var opponent_match_point = prediction.scorer == "opponent" and game_manager.opponent_score == game_manager.win_score - 1
	return player_match_point or opponent_match_point

func _check_start_condition():
	if ball.is_recovering:
		return
	var prediction = predictor.predict_scoring_wall_hit()
	if not _is_relevant(prediction):
		return
	if critical_moment == true:
		if prediction.distance <= min_distance_to_start:
			_start_critical_sequence()

func _start_critical_sequence():
	critical_state = "approaching"
	impact_happened = false
	original_camera_pos = global_position
	call_deferred("_run_approach_phase")

func _run_approach_phase():
	while critical_state == "approaching":
		if impact_happened:
			break

		var prediction = predictor.predict_scoring_wall_hit()
		if not _is_relevant(prediction):
			_release_smoothly()
			return

		var t = 1.0 - clamp(prediction.distance / min_distance_to_start, 0.0, 1.0)
		zoom = lerp(normal_state_of_zoom, max_zoom, t)
		Engine.time_scale = lerp(1.0, min_slowmo_scale, t)
		global_position = ball.global_position

		await get_tree().process_frame

	if critical_state != "approaching":
		return   # bailed out via _release_smoothly mid-loop

	# --- hold at peak, real time, still tracking the ball ---
	var hold_start = Time.get_ticks_msec() / 1000.0
	while (Time.get_ticks_msec() / 1000.0) - hold_start < wait_time:
		global_position = ball.global_position
		await get_tree().process_frame

	# --- departure: anchor taken NOW, after any reset-teleport has already happened ---
	critical_state = "departing"
	departure_anchor = ball.global_position

	while true:
		var traveled = departure_anchor.distance_to(ball.global_position)
		var t = clamp(traveled / max_distance_to_end, 0.0, 1.0)
		zoom = lerp(max_zoom, normal_state_of_zoom, t)
		Engine.time_scale = lerp(min_slowmo_scale, 1.0, t)
		global_position = ball.global_position

		if t >= 1.0:
			break
		await get_tree().process_frame

	var pos_out = create_tween()
	pos_out.tween_property(self, "global_position", original_camera_pos, recovery_tween_duration).set_trans(Tween.TRANS_SINE)
	await pos_out.finished

	critical_state = "idle"

func _release_smoothly():
	Engine.time_scale = 1.0
	var zoom_out = create_tween()
	zoom_out.tween_property(self, "zoom", normal_state_of_zoom, impact_release_duration).set_trans(Tween.TRANS_SINE)
	var pos_out = create_tween()
	pos_out.tween_property(self, "global_position", original_camera_pos, impact_release_duration).set_trans(Tween.TRANS_SINE)
	critical_state = "idle"
