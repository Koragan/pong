extends Control

@export_file("*.tscn") var menu_scene: String

@onready var address_label: Label = $CenterContainer/VBoxContainer/AddressLabel
@onready var qr_image: TextureRect = $CenterContainer/VBoxContainer/QrImage
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	var ip := _find_lan_ip()
	if ip == "":
		address_label.text = "No LAN connection found"
		return
	var err := LanServer.start()
	if err != OK:
		address_label.text = "Couldn't start server (error %d)" % err
		return
	var url := "%s://%s:%d" % [LanServer.SCHEME, ip, LanServer.PORT]
	address_label.text = url
	_show_qr(url)
	LanServer.player_joined.connect(_on_players_changed.unbind(1))
	LanServer.player_left.connect(_on_players_changed.unbind(1))
	_on_players_changed()

func _on_back_pressed():
	LanServer.stop()
	get_tree().change_scene_to_file(menu_scene)

func _show_qr(text: String) -> void:
	var qr := QrCode.new()
	qr.error_correct_level = QrCode.ErrorCorrectionLevel.MEDIUM
	qr_image.texture = qr.get_texture(text)
	qr.queue_free()

func _find_lan_ip() -> String:
	var fallback := ""
	for addr in IP.get_local_addresses():
		if addr.contains(":"):
			continue  # skip IPv6
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			return addr
		if addr.begins_with("172.") and fallback == "":
			var second := int(addr.split(".")[1])
			if second >= 16 and second <= 31:
				fallback = addr  # private range, but often Docker/VPN, so only if nothing better
	return fallback

func _on_players_changed() -> void:
	var n := LanServer.player_count()
	status_label.text = "Waiting for players..." if n == 0 else "Players connected: %d" % n
