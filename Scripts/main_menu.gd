extends Control

@export_file("*.tscn") var game_scene: String
@export_file("*.tscn") var lobby_scene: String

@onready var single_button: Button = $CenterContainer/VBoxContainer/SinglePlayerButton
@onready var phone_button: Button = $CenterContainer/VBoxContainer/PhoneButton

func _ready():
	single_button.pressed.connect(_on_single_pressed)
	phone_button.pressed.connect(_on_phone_pressed)
	# Browsers can't host a LAN server, so no phone mode in the web export.
	if OS.has_feature("web"):
		phone_button.hide()

func _on_single_pressed():
	get_tree().change_scene_to_file(game_scene)

func _on_phone_pressed():
	get_tree().change_scene_to_file(lobby_scene)
