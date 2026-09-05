extends Node

var paddle_hit_stream: AudioStreamWAV
var wall_bounce_stream: AudioStreamWAV
var score_stream: AudioStreamWAV
var win_stream: AudioStreamWAV

@onready var _player_a := AudioStreamPlayer.new()
@onready var _player_b := AudioStreamPlayer.new()

func _ready():
	add_child(_player_a)
	add_child(_player_b)

	paddle_hit_stream = generate_tone(880.0, 0.06, "square")
	wall_bounce_stream = generate_tone(440.0, 0.05, "square")
	score_stream = generate_tone(220.0, 0.18, "square")
	win_stream = generate_tone(660.0, 0.35, "square")

func generate_tone(frequency: float, duration: float, wave_type: String = "square", volume: float = 0.3) -> AudioStreamWAV:
	var mix_rate = 44100
	var sample_count = int(mix_rate * duration)
	var data = PackedByteArray()
	data.resize(sample_count * 2)  # 16-bit = 2 bytes per sample

	var fade_start = duration * 0.7  # last 30% fades out, avoids a clicky cutoff

	for i in sample_count:
		var t = float(i) / mix_rate
		var envelope = 1.0
		if t > fade_start:
			envelope = 1.0 - (t - fade_start) / (duration - fade_start)

		var raw = sin(TAU * frequency * t)
		if wave_type == "square":
			raw = 1.0 if raw >= 0.0 else -1.0

		var sample_value = clamp(raw * volume * envelope, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample_value * 32767.0))

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream

func play_paddle_hit():
	_player_a.stream = paddle_hit_stream
	_player_a.play()

func play_wall_bounce():
	_player_a.stream = wall_bounce_stream
	_player_a.play()

func play_score():
	_player_b.stream = score_stream
	_player_b.play()

func play_win():
	_player_b.stream = win_stream
	_player_b.play()
