extends Control

signal beat_started(value: String)
signal completed
signal cleared

@export_range(0.1, 2.0, 0.05) var beat_duration: float = 1.0

const INK := Color("d9ffe5")
const RED := Color("ff0011")
const BEATS := ["3", "2", "1", "GO"]

@onready var number: Label = $Number
@onready var caption: Label = $Caption

var running := false
var beat_index := 0
var elapsed := 0.0
var released := false

func start() -> void:
	running = true
	released = false
	beat_index = 0
	elapsed = 0.0
	show()
	_show_beat()

func cancel() -> void:
	running = false
	hide()

func _show_beat() -> void:
	number.text = BEATS[beat_index]
	number.modulate = INK if beat_index == 3 else RED
	caption.text = "LET IT RIP" if beat_index == 3 else "FIRST TO %d • GET READY" % get_node("../../GameManager").win_score
	beat_started.emit(number.text)
	if beat_index == 3 and not released:
		released = true
		completed.emit()

func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	var duration := beat_duration if beat_index < 3 else beat_duration * 0.45
	if elapsed >= duration:
		elapsed -= duration
		beat_index += 1
		if beat_index >= BEATS.size():
			running = false
			hide()
			cleared.emit()
			return
		_show_beat()
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	# A hard impact settles into stillness before the next beat.
	var impact := pow(1.0 - clampf(progress / 0.45, 0.0, 1.0), 3.0)
	var intensity := 4.0 + beat_index * 2.0
	var kick := Vector2(sin(progress * 85.0), cos(progress * 107.0)) * impact * intensity
	number.pivot_offset = number.size / 2.0
	number.scale = Vector2.ONE * (1.0 + impact * 0.28)
	number.position = (size - number.size) / 2.0 + kick - Vector2(0, 12)
	caption.position = Vector2((size.x - caption.size.x) / 2.0, size.y / 2.0 + 90)
	number.modulate.a = 1.0 - progress * 0.65 if beat_index == 3 else 1.0
	queue_redraw()

func _draw() -> void:
	if not running:
		return
	var center := size / 2.0 - Vector2(0, 12)
	var progress := clampf(elapsed / beat_duration, 0.0, 1.0)
	var color := INK if beat_index == 3 else RED
	var darkness := 0.82 if beat_index < 3 else 0.82 * (1.0 - clampf(progress / 0.45, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, darkness))
	if beat_index < 3:
		draw_rect(Rect2(center - Vector2(100, 100), Vector2(200, 200)), Color(color, 0.16), false, 1.0)
		var width := 200.0 * (1.0 - progress)
		draw_line(center + Vector2(-100, 100), center + Vector2(-100 + width, 100), color, 3.0)
	else:
		var radius := 80.0 + progress * 220.0
		draw_arc(center, radius, 0, TAU, 64, Color(INK, 1.0 - progress), 2.0, true)
