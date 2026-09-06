extends RigidBody2D

@export var max_speed = 1500
@export var reset_on_score: bool = false
@export var low_speed_increase_on_paddle_hit: float = 1.15
@export var high_speed_increase_on_paddle_hit: float = 1.009

@export var base_speed: float = 300
@export var reset_speed_retention: float = 0.85   # fraction of pre-reset speed carried into the next round

@export var stress_hit_threshold: int = 8
@export var stress_time_window: float = 0.9
@export var angry_pause_duration: float = 1.4
@export var recover_travel_duration: float = 1.0

@export var offscreen_margin: float = 100.0
@export var boring_check_interval: float = 10
@export var boring_x_range_threshold: float = 80.0
@export var boring_y_range_threshold: float = 80.0


@export var crt_overlay_path: NodePath
@onready var crt_mat: ShaderMaterial = get_node(crt_overlay_path).material


signal ball_reset
signal score_point(player)
signal paddle_hit(paddle_name)
signal wall_bounce   

var recent_hit_times: Array = []
var is_recovering: bool = false

var boring_timer: float = 0.0
var window_min_x: float = 0.0
var window_max_x: float = 0.0
var window_min_y: float = 0.0
var window_max_y: float = 0.0

var shader_effect_value: float = 2

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	shader_effect_value = 2
	linear_velocity = Vector2(300, -200)
	body_entered.connect(_on_body_entered)
	window_min_x = position.x
	window_max_x = position.x
	window_min_y = position.y
	window_max_y = position.y
	shader_effect_value = 2
	print(shader_effect_value)

func _physics_process(delta):
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

	_check_offscreen()
	_check_boring_trajectory(delta)

func _check_offscreen():
	if is_recovering:
		return
	var screen_size = get_viewport_rect().size
	if position.x < -offscreen_margin or position.x > screen_size.x + offscreen_margin \
	or position.y < -offscreen_margin or position.y > screen_size.y + offscreen_margin:
		_trigger_angry_recovery()

func _check_boring_trajectory(delta):
	if is_recovering:
		return

	window_min_x = min(window_min_x, position.x)
	window_max_x = max(window_max_x, position.x)
	window_min_y = min(window_min_y, position.y)
	window_max_y = max(window_max_y, position.y)
	boring_timer += delta

	if boring_timer >= boring_check_interval:
		var x_range = window_max_x - window_min_x
		var y_range = window_max_y - window_min_y

		if x_range < boring_x_range_threshold or y_range < boring_y_range_threshold:
			_trigger_angry_recovery()

		boring_timer = 0.0
		window_min_x = position.x
		window_max_x = position.x
		window_min_y = position.y
		window_max_y = position.y

func _on_body_entered(body):
	if is_recovering:
		return

	if _record_hit_and_check_stress():
		recent_hit_times.clear()
		_trigger_angry_recovery()
		return

	if body.name == "East":
		SFX.play_score()
		emit_signal("score_point", "player")
		if reset_on_score:
			call_deferred("reset_ball")
	elif body.name == "West":
		SFX.play_score()
		emit_signal("score_point", "opponent")
		if reset_on_score:
			call_deferred("reset_ball")
	elif body is CharacterBody2D:
		SFX.play_paddle_hit()
		emit_signal("paddle_hit", body.name)
		call_deferred("_boost_speed")
	elif body is StaticBody2D:
		SFX.play_wall_bounce()
		emit_signal("wall_bounce")

func _record_hit_and_check_stress() -> bool:
	var now = Time.get_ticks_msec() / 1000.0
	recent_hit_times.append(now)

	var fresh_hits: Array = []
	for t in recent_hit_times:
		if now - t <= stress_time_window:
			fresh_hits.append(t)
	recent_hit_times = fresh_hits

	return recent_hit_times.size() >= stress_hit_threshold

func _boost_speed():
	if linear_velocity.length() <= 700:
		linear_velocity *= low_speed_increase_on_paddle_hit
	else:
		linear_velocity *= high_speed_increase_on_paddle_hit
	print(linear_velocity.length())
	shader_effect_value += 0.1
	crt_mat.set_shader_parameter("curvature", shader_effect_value)
 

func _trigger_angry_recovery():
	if is_recovering:
		return
	is_recovering = true   # locked immediately — blocks a second trigger firing later this same frame
	call_deferred("_start_angry_recovery")

func _start_angry_recovery():
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_shape.disabled = true

	modulate = Color.RED
	scale = Vector2(1.6, 1.6)
	z_index = 5

	await get_tree().create_timer(angry_pause_duration).timeout

	var tween = create_tween()
	tween.tween_property(self, "global_position", get_viewport_rect().size / 2, recover_travel_duration)
	await tween.finished

	modulate = Color.WHITE
	scale = Vector2.ONE
	z_index = 0
	collision_shape.disabled = false

	reset_ball(true)   # hard reset — don't carry forward whatever speed caused the glitch
	is_recovering = false

func reset_ball(hard_reset: bool = false):
	position = get_viewport_rect().size / 2
	var angle = randf_range(-45, 45) * PI / 180
	shader_effect_value = 2
	var speed: float
	if hard_reset:
		speed = base_speed
	else:
		speed = clamp(linear_velocity.length() * reset_speed_retention, base_speed, max_speed)

	linear_velocity = Vector2(cos(angle), sin(angle)) * speed
	emit_signal("ball_reset")
