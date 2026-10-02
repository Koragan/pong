extends Node

signal player_joined(id: int)
signal player_left(id: int)
signal message_received(id: int, data: Dictionary)

const PORT := 8443      # HTTPS: serves the controller page
const WS_PORT := 8444   # secure WebSocket: live data from phones
const SCHEME := "https"
const CONTROLLER_PAGE := "res://web/controller.html"
const KEY_PATH := "user://tls.key"
const CERT_PATH := "user://tls.crt"
const MAX_REQUEST_BYTES := 8192

class HttpClient:
	var tcp: StreamPeerTCP
	var tls := StreamPeerTLS.new()
	var buffer := PackedByteArray()

class Player:
	var id: int
	var tcp: StreamPeerTCP
	var tls := StreamPeerTLS.new()
	var ws := WebSocketPeer.new()
	var announced := false

var _http_server := TCPServer.new()
var _ws_server := TCPServer.new()
var _tls_options: TLSOptions
var _http_clients: Array[HttpClient] = []
var _players: Array[Player] = []
var _next_id := 1

func start() -> Error:
	if _http_server.is_listening():
		return OK
	_tls_options = _load_or_create_tls()
	var err := _http_server.listen(PORT)
	if err != OK:
		return err
	err = _ws_server.listen(WS_PORT)
	if err != OK:
		_http_server.stop()
	return err

func stop() -> void:
	for c in _http_clients:
		c.tls.disconnect_from_stream()
	_http_clients.clear()
	for p in _players:
		p.ws.close()
	_players.clear()
	_http_server.stop()
	_ws_server.stop()

func player_count() -> int:
	var n := 0
	for p in _players:
		if p.announced:
			n += 1
	return n

func _load_or_create_tls() -> TLSOptions:
	var key := CryptoKey.new()
	var cert := X509Certificate.new()
	if FileAccess.file_exists(KEY_PATH) and FileAccess.file_exists(CERT_PATH):
		key.load(KEY_PATH)
		cert.load(CERT_PATH)
	else:
		var crypto := Crypto.new()
		key = crypto.generate_rsa(2048)
		cert = crypto.generate_self_signed_certificate(key, "CN=pong.local,O=Pong,C=TR")
		key.save(KEY_PATH)
		cert.save(CERT_PATH)
	return TLSOptions.server(key, cert)

func _process(_delta):
	if not _http_server.is_listening():
		return
	_accept_http()
	_accept_websockets()
	for i in range(_http_clients.size() - 1, -1, -1):
		if _poll_http_client(_http_clients[i]):
			_http_clients.remove_at(i)
	for i in range(_players.size() - 1, -1, -1):
		if _poll_player(_players[i]):
			_players.remove_at(i)

# ---------- HTTPS: serves the controller page ----------

func _accept_http() -> void:
	while _http_server.is_connection_available():
		var c := HttpClient.new()
		c.tcp = _http_server.take_connection()
		if c.tls.accept_stream(c.tcp, _tls_options) == OK:
			_http_clients.append(c)
		else:
			c.tcp.disconnect_from_host()

# Returns true once this client is finished and can be dropped.
func _poll_http_client(c: HttpClient) -> bool:
	c.tls.poll()
	match c.tls.get_status():
		StreamPeerTLS.STATUS_HANDSHAKING:
			return false
		StreamPeerTLS.STATUS_CONNECTED:
			var available := c.tls.get_available_bytes()
			if available > 0:
				c.buffer.append_array(c.tls.get_data(available)[1])
			if c.buffer.size() > MAX_REQUEST_BYTES:
				c.tls.disconnect_from_stream()
				return true  # too big to be a sane request, drop it
			var request := c.buffer.get_string_from_ascii()
			if request.contains("\r\n\r\n"):  # headers fully arrived
				_respond(c.tls, request)
				c.tls.disconnect_from_stream()
				return true
		_:
			return true  # handshake failed, errored, or closed
	return false

func _respond(peer: StreamPeer, request: String) -> void:
	var parts := request.get_slice("\r\n", 0).split(" ")  # "GET / HTTP/1.1"
	if parts.size() >= 2 and parts[0] == "GET" and parts[1] == "/":
		if FileAccess.file_exists(CONTROLLER_PAGE):
			_send(peer, 200, "OK", FileAccess.get_file_as_bytes(CONTROLLER_PAGE))
		else:
			_send(peer, 500, "Internal Server Error", ("Missing " + CONTROLLER_PAGE).to_utf8_buffer())
	else:
		_send(peer, 404, "Not Found", "Not found".to_utf8_buffer())

func _send(peer: StreamPeer, code: int, reason: String, body: PackedByteArray) -> void:
	var header := "HTTP/1.1 %d %s\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [code, reason, body.size()]
	peer.put_data(header.to_utf8_buffer())
	peer.put_data(body)

# ---------- WebSocket: live link to phones ----------

func _accept_websockets() -> void:
	while _ws_server.is_connection_available():
		var p := Player.new()
		p.id = _next_id
		_next_id += 1
		p.tcp = _ws_server.take_connection()
		# TLS first, then hand the encrypted stream to the WebSocket, which does its own handshake
		if p.tls.accept_stream(p.tcp, _tls_options) == OK and p.ws.accept_stream(p.tls) == OK:
			_players.append(p)
		else:
			p.tcp.disconnect_from_host()

# Returns true once this player is gone and can be dropped.
func _poll_player(p: Player) -> bool:
	p.ws.poll()
	match p.ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not p.announced:
				p.announced = true
				player_joined.emit(p.id)
			while p.ws.get_available_packet_count() > 0:
				var data = JSON.parse_string(p.ws.get_packet().get_string_from_utf8())
				if data is Dictionary:
					message_received.emit(p.id, data)
		WebSocketPeer.STATE_CLOSED:
			if p.announced:
				player_left.emit(p.id)
			return true
	return false
