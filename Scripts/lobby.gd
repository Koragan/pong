extends Control

@export_file("*.tscn") var menu_scene: String = "res://main_menu.tscn"

@onready var address_label: Label = $CenterContainer/VBoxContainer/AddressLabel
@onready var qr_image: TextureRect = $CenterContainer/VBoxContainer/QrImage
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel

func _ready():
	LanServer.match_player_ids.clear()
	start_button.pressed.connect(_on_start_pressed)
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
	LanServer.latency_updated.connect(_on_latency_updated)
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
	status_label.text = "Connect two phones (%d/2 ready)" % n
	if not LanServer.last_match_result.is_empty():
		status_label.text = LanServer.last_match_result + "\n" + status_label.text
	var connections: Array[String] = []
	for id in LanServer.connected_player_ids():
		var ping := "%d ms" % LanServer.player_latency[id] if LanServer.player_latency.has(id) else "measuring..."
		connections.append("Phone %d: %s" % [id, ping])
	if not connections.is_empty():
		status_label.text += "\n" + " | ".join(connections)
	start_button.disabled = n < 2

func _on_start_pressed() -> void:
	var ids := LanServer.connected_player_ids()
	if ids.size() < 2:
		return
	LanServer.last_match_result = ""
	LanServer.match_player_ids.assign(ids.slice(0, 2))
	get_tree().change_scene_to_file("res://main.tscn")

func _on_latency_updated(_id: int, _milliseconds: int) -> void:
	_on_players_changed()
