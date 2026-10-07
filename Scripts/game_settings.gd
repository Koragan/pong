extends Node

signal changed

const SAVE_PATH := "user://options.cfg"
const DEFAULTS := {
	"max_ball_speed": 1500.0, "low_multiplier": 1.15, "high_multiplier": 1.009,
	"win_score": 5.0, "sfx_volume": 1.0, "crt_enabled": 1.0,
	"scanline_intensity": 0.979, "scanline_count": 400.0, "curvature": 2.0,
	"vignette_strength": 0.0, "chroma_offset": 0.007, "border_softness": 0.05,
}
const RANGES := {
	"max_ball_speed": Vector2(300, 3000), "low_multiplier": Vector2(1, 2),
	"high_multiplier": Vector2(1, 2), "win_score": Vector2(1, 1000),
	"sfx_volume": Vector2(0, 1), "crt_enabled": Vector2(0, 1),
	"scanline_intensity": Vector2(0, 1), "scanline_count": Vector2(50, 800),
	"curvature": Vector2(0, 10), "vignette_strength": Vector2(0, 2),
	"chroma_offset": Vector2(0, 0.02), "border_softness": Vector2(0.001, 0.05),
}
var values: Dictionary = DEFAULTS.duplicate()

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		for key in DEFAULTS:
			values[key] = _validated(key, config.get_value("options", key, DEFAULTS[key]))

func _validated(key: String, value: Variant) -> float:
	if not (value is float or value is int) or not is_finite(float(value)):
		return DEFAULTS[key]
	var bounds: Vector2 = RANGES[key]
	var result := clampf(float(value), bounds.x, bounds.y)
	return roundf(result) if key in ["win_score", "scanline_count", "crt_enabled"] else result

func set_option(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	values[key] = _validated(key, value)
	_save()
	changed.emit()

func restore_defaults() -> void:
	values = DEFAULTS.duplicate()
	_save()
	changed.emit()

func _save() -> void:
	var config := ConfigFile.new()
	for key in values:
		config.set_value("options", key, values[key])
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save options: %s" % error_string(error))

func apply_shader(overlay: ColorRect) -> void:
	overlay.visible = values.crt_enabled > 0.5
	for key in ["scanline_intensity", "scanline_count", "curvature", "vignette_strength", "chroma_offset", "border_softness"]:
		overlay.material.set_shader_parameter(key, values[key])
