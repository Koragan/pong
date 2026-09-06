extends Node

@export var ball_path: NodePath
@export var north_wall_path: NodePath
@export var south_wall_path: NodePath
@export var east_wall_path: NodePath
@export var west_wall_path: NodePath

@export var max_bounces: int = 6
@export var max_distance: float = 500

@onready var ball: RigidBody2D = get_node(ball_path)
@onready var north_wall: StaticBody2D = get_node(north_wall_path)
@onready var south_wall: StaticBody2D = get_node(south_wall_path)
@onready var east_wall: StaticBody2D = get_node(east_wall_path)
@onready var west_wall: StaticBody2D = get_node(west_wall_path)

func _get_wall_inner_y(wall: StaticBody2D, is_top: bool) -> float:
	var shape_node := wall.get_node("CollisionShape2D") as CollisionShape2D
	var half_height = shape_node.shape.size.y / 2.0
	var center_y = shape_node.global_position.y
	return center_y + half_height if is_top else center_y - half_height

func _get_wall_inner_x(wall: StaticBody2D, is_west: bool) -> float:
	var shape_node := wall.get_node("CollisionShape2D") as CollisionShape2D
	var half_width = shape_node.shape.size.x / 2.0
	var center_x = shape_node.global_position.x
	return center_x + half_width if is_west else center_x - half_width

## Projects the ball's path — bouncing off North/South as needed — to find
## how soon and where it will cross the East or West scoring wall.
## Called fresh every frame, so it's always current, including right after
## a bounce changes direction.
func predict_scoring_wall_hit() -> Dictionary:
	var pos = ball.global_position
	var dir = ball.linear_velocity.normalized()
	if dir.length() == 0.0:
		return {"time": INF, "scorer": ""}

	var top_y = _get_wall_inner_y(north_wall, true)
	var bottom_y = _get_wall_inner_y(south_wall, false)

	var target_x: float
	var scorer: String
	if dir.x > 0:
		target_x = _get_wall_inner_x(east_wall, false)
		scorer = "player"
	else:
		target_x = _get_wall_inner_x(west_wall, true)
		scorer = "opponent"

	var traveled = 0.0
	var bounces = 0

	while bounces < max_bounces and traveled < max_distance:
		var dist_to_target = (target_x - pos.x) / dir.x if dir.x != 0 else INF
		var dist_to_wall = INF
		if dir.y > 0:
			dist_to_wall = (bottom_y - pos.y) / dir.y
		elif dir.y < 0:
			dist_to_wall = (top_y - pos.y) / dir.y

		var dist = min(dist_to_target, dist_to_wall)
		if dist == INF or dist <= 0:
			return {"time": INF, "scorer": ""}

		pos += dir * dist
		traveled += dist

		if dist == dist_to_target:
			var speed = ball.linear_velocity.length()
			var time = traveled / speed if speed > 0.0 else INF
			return {"time": time, "scorer": scorer}

		dir.y = -dir.y
		bounces += 1

	return {"time": INF, "scorer": ""}
