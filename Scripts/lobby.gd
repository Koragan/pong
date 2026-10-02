extends Control

const PORT := 8443

@export_file("*.tscn") var menu_scene: String

@onready var address_label: Label = $CenterContainer/VBoxContainer/AddressLabel
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton
@onready var qr_image: TextureRect = $CenterContainer/VBoxContainer/QrImage

func _ready():
	back_button.pressed.connect(func(): get_tree().change_scene_to_file(menu_scene))
	var ip := _find_lan_ip()
	if ip == "":
		address_label.text = "No LAN connection found"
	else:
		var url := "https://%s:%d" % [ip, PORT]
		address_label.text = url
		_show_qr(url)


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


func _show_qr(text: String) -> void:
	var qr := QrCode.new()
	qr.error_correct_level = QrCode.ErrorCorrectionLevel.MEDIUM
	qr_image.texture = qr.get_texture(text)
	qr.queue_free()  # the class is a Node, so free it when done, as the README says
