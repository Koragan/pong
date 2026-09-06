extends Camera2D

# --- screen shake (unchanged from before) ---
@export var ball_path: NodePath
@export var max_offset: Vector2 = Vector2(16, 16)
@export var trauma_decay: float = 1.5
@export var paddle_hit_trauma: float = 0.15
@export var wall_bounce_trauma: float = 0.05
@export var score_trauma: float = 0.4

# --- match-point detection ---
@export var predictor_path: NodePath
@export var game_manager_path: NodePath
@export var critical_time_threshold: float = 100   # seconds-to-impact that counts as "about to happen"

# --- match-point slowmo + zoom, all controllable ---
@export_range(0, 1, 0.01) var slowmo_scale: float = 0.05        # how slow — 1.0 = no slowdown, closer to 0 = slower
@export var critical_zoom: Vector2 = Vector2(1.4, 1.4)
@export var transition_duration: float = 1  # how long the smooth ramp in/out takes, in real seconds
@export var hold_time: float = 1            # how long to hold the zoomed/slowed beat, in real seconds

var normal_state_of_zoom : Vector2 = Vector2(0.9, 0.9)
var trauma: float = 0.0
var in_critical_moment: bool = false
var rng := RandomNumberGenerator.new()

@onready var ball: RigidBody2D = get_node(ball_path)
@onready var predictor: Node = get_node(predictor_path)
@onready var game_manager: Node = get_node(game_manager_path)

func _ready():
	rng.randomize()
	ball.paddle_hit.connect(func(_name): add_trauma(paddle_hit_trauma))
	ball.wall_bounce.connect(func(): add_trauma(wall_bounce_trauma))
	ball.score_point.connect(func(_who): add_trauma(score_trauma))

func add_trauma(amount: float):
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _process(delta):
	_update_shake(delta)
	_check_match_point()

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

func _check_match_point():
	if in_critical_moment or ball.is_recovering:
		return

	var prediction = predictor.predict_scoring_wall_hit()
	if prediction.time > critical_time_threshold:
		return

	var player_match_point = prediction.scorer == "player" and game_manager.player_score == game_manager.win_score - 1
	var opponent_match_point = prediction.scorer == "opponent" and game_manager.opponent_score == game_manager.win_score - 1

	if player_match_point or opponent_match_point:
		in_critical_moment = true
		call_deferred("_run_critical_moment")

func _run_critical_moment():
	var original_camera_pos = global_position

	_ramp_time_scale(slowmo_scale, transition_duration)

	var zoom_in = create_tween()
	zoom_in.tween_property(self, "zoom", critical_zoom, transition_duration).set_trans(Tween.TRANS_SINE)

	# follow the ball for the real-world duration of the hold, so the zoom
	# stays centered on it the whole time instead of sitting on board-center
	var hold_start = Time.get_ticks_msec() / 1000.0
	while (Time.get_ticks_msec() / 1000.0) - hold_start < hold_time:
		global_position = ball.global_position
		await get_tree().process_frame

	_ramp_time_scale(1.0, transition_duration)

	var zoom_out = create_tween()
	zoom_out.tween_property(self, "zoom", normal_state_of_zoom, transition_duration).set_trans(Tween.TRANS_SINE)

	var pos_out = create_tween()
	pos_out.tween_property(self, "global_position", original_camera_pos, transition_duration).set_trans(Tween.TRANS_SINE)

	await zoom_out.finished
	in_critical_moment = false

## Smoothly ramps Engine.time_scale toward target over duration real seconds.
## Uses wall-clock time (not delta) since delta is exactly what's being
## distorted by this change — using it to pace itself would be circular.
func _ramp_time_scale(target: float, duration: float):
	var start_value = Engine.time_scale
	var start_time = Time.get_ticks_msec() / 1000.0
	while true:
		var elapsed = (Time.get_ticks_msec() / 1000.0) - start_time
		var t = clamp(elapsed / duration, 0.0, 1.0)
		Engine.time_scale = lerp(start_value, target, t)
		if t >= 1.0:
			break
		await get_tree().process_frame
