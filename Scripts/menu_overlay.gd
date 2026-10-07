extends CanvasLayer

signal resume_requested
signal leave_requested
signal closed

var root_control: Control
var heading: Label
var body: VBoxContainer
var controls: Dictionary = {}
var showing_options := false
var in_match := false
var return_to_pause := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 50)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	root_control.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.add_theme_color_override("font_color", Color("d9ffe5"))
	margin.add_child(body)
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	body.add_child(heading)
	root_control.hide()

func _clear_body() -> void:
	for child in body.get_children():
		if child != heading:
			body.remove_child(child)
			child.queue_free()
	controls.clear()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func show_pause(phone_match: bool) -> void:
	in_match = true
	showing_options = false
	_clear_body()
	heading.text = "PAUSED"
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var resume := _button(body, "Resume • Space / Esc", func(): resume_requested.emit())
	_button(body, "Options", func(): show_options(true))
	_button(body, "Return to Lobby" if phone_match else "Main Menu", func(): leave_requested.emit())
	var hint := Label.new()
	hint.text = "The host pauses both players." if phone_match else "Take your time."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(hint)
	root_control.show()
	resume.grab_focus()

func show_options(from_pause: bool = false) -> void:
	return_to_pause = from_pause
	showing_options = true
	_clear_body()
	heading.text = "OPTIONS"
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	var gameplay := _tab(tabs, "Gameplay")
	_number(gameplay, "Maximum ball speed", "max_ball_speed", 50, " px/s")
	_number(gameplay, "Paddle boost • below 700 px/s", "low_multiplier", 0.01, " ×")
	_number(gameplay, "Paddle boost • above 700 px/s", "high_multiplier", 0.001, " ×")
	_number(gameplay, "Points to win", "win_score", 1, "")
	var note := Label.new()
	note.text = "Changes apply now. A lower win score is checked when you resume."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gameplay.add_child(note)
	var display := _tab(tabs, "Display")
	var enabled := CheckButton.new()
	enabled.text = "CRT effect"
	enabled.button_pressed = GameSettings.values.crt_enabled > 0.5
	display.add_child(enabled)
	enabled.toggled.connect(func(value): GameSettings.set_option("crt_enabled", float(value)))
	controls.crt_enabled = enabled
	_number(display, "Scanline strength", "scanline_intensity", 0.01, "")
	_number(display, "Scanline count", "scanline_count", 10, "")
	_number(display, "Screen curvature", "curvature", 0.1, "")
	_number(display, "Dark corners", "vignette_strength", 0.05, "")
	_number(display, "Color offset", "chroma_offset", 0.001, "")
	_number(display, "Edge softness", "border_softness", 0.001, "")
	var audio := _tab(tabs, "Audio")
	_number(audio, "SFX volume • 0 is mute", "sfx_volume", 0.05, "", 100.0)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	_button(footer, "Restore Defaults", _restore)
	var back := _button(footer, "Back • Esc", back_from_options)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_control.show()
	back.grab_focus()

func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	return column

func _number(parent: Node, title: String, key: String, step: float, suffix: String, factor: float = 1.0) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var input := SpinBox.new()
	input.custom_minimum_size.x = 160
	input.min_value = GameSettings.RANGES[key].x * factor
	input.max_value = GameSettings.RANGES[key].y * factor
	input.step = step * factor
	input.suffix = suffix if factor == 1.0 else "%"
	input.value = GameSettings.values[key] * factor
	row.add_child(input)
	input.value_changed.connect(func(value): GameSettings.set_option(key, value / factor))
	controls[key] = input

func _restore() -> void:
	GameSettings.restore_defaults()
	show_options(return_to_pause)

func back_from_options() -> void:
	if return_to_pause:
		show_pause(not LanServer.match_player_ids.is_empty())
	else:
		hide_menu()
		closed.emit()

func hide_menu() -> void:
	root_control.hide()

func _input(event: InputEvent) -> void:
	if not root_control.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or (event.keycode == KEY_SPACE and not showing_options):
		get_viewport().set_input_as_handled()
		if showing_options:
			back_from_options()
		else:
			resume_requested.emit()
