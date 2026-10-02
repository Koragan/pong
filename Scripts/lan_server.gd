extends Node

signal player_joined(id: int)
signal player_left(id: int)
signal message_received(id: int, data: Dictionary)
signal latency_updated(id: int, milliseconds: int)

const PORT := 8443      # HTTPS: serves the controller page
const WS_PORT := 8444   # secure WebSocket: live data from phones
const SCHEME := "https"
const CONTROLLER_PAGE := "res://web/controller.html"
const KEY_PATH := "user://tls.key"
const CERT_PATH := "user://tls.crt"
const MAX_REQUEST_BYTES := 8192
const TIMEOUT_MS := 6000 # Initial connection handshake only.
@export_range(10.0, 120.0, 1.0) var heartbeat_timeout_seconds: float = 30.0

class HttpClient:
	var tcp: StreamPeerTCP
	var tls := StreamPeerTLS.new()
	var buffer := PackedByteArray()

class Player:
	var id: int
	var tcp: StreamPeerTCP
	var tls := StreamPeerTLS.new()
	var ws := WebSocketPeer.new()
	var ws_started := false
	var announced := false
	var last_seen_ms := 0

var _http_server := TCPServer.new()
var _ws_server := TCPServer.new()
var _tls_options: TLSOptions
var _http_clients: Array[HttpClient] = []
var _players: Array[Player] = []
var _next_id := 1

# The lobby assigns the left and right players before starting a match.
var match_player_ids: Array[int] = []
var last_match_result := ""
var last_lobby_reason := ""
var disconnect_reasons: Dictionary = {}
var _session_ids: Dictionary = {}
var _controller_status := "Connected • waiting in lobby"
var player_latency: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	last_match_result = ""
	last_lobby_reason = ""
	disconnect_reasons.clear()
	_session_ids.clear()
	_controller_status = "Connected • waiting in lobby"
	match_player_ids.clear()
	player_latency.clear()
	for c in _http_clients:
		c.tls.disconnect_from_stream()
	_http_clients.clear()
	for p in _players:
		p.ws.close()
	_players.clear()
	_http_server.stop()
	_ws_server.stop()

func broadcast_status(message: String) -> void:
	_controller_status = message
	for p in _players:
		if p.announced and p.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			p.ws.send_text(JSON.stringify({"type": "status", "text": message}))

func _announce_player(p: Player, data: Dictionary) -> void:
	if p.announced:
		return
	var session = data.get("session", "")
	if session is String and not session.is_empty() and session.length() <= 128:
		if _session_ids.has(session):
			var previous_id: int = _session_ids[session]
			for other in _players:
				if other != p and other.announced and other.id == previous_id:
					p.ws.close(1008, "Session already connected")
					return
			p.id = previous_id
		else:
			_session_ids[session] = p.id
	p.announced = true
	disconnect_reasons.erase(p.id)
	player_joined.emit(p.id)
	p.ws.send_text(JSON.stringify({"type": "status", "text": _controller_status}))

func connected_player_ids() -> Array[int]:
	var ids: Array[int] = []
	for p in _players:
		if p.announced:
			ids.append(p.id)
	return ids

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
		p.last_seen_ms = Time.get_ticks_msec()
		if p.tls.accept_stream(p.tcp, _tls_options) == OK:
			_players.append(p)
		else:
			p.tcp.disconnect_from_host()

# Returns true once this player is gone and can be dropped.

func _poll_player(p: Player) -> bool:
	if not p.ws_started:
		p.tls.poll()
		if Time.get_ticks_msec() - p.last_seen_ms >= TIMEOUT_MS:
			p.tls.disconnect_from_stream()
			return true
		match p.tls.get_status():
			StreamPeerTLS.STATUS_HANDSHAKING:
				return false
			StreamPeerTLS.STATUS_CONNECTED:
				if p.ws.accept_stream(p.tls) != OK:
					return true
				p.ws_started = true
			_:
				return true
	p.ws.poll()
	var state := p.ws.get_ready_state()
	if state == WebSocketPeer.STATE_CONNECTING:
		if Time.get_ticks_msec() - p.last_seen_ms < TIMEOUT_MS:
			return false
		p.tls.disconnect_from_stream()
		return true
	if state == WebSocketPeer.STATE_OPEN:
		while p.ws.get_available_packet_count() > 0:
			p.last_seen_ms = Time.get_ticks_msec()  # any traffic counts as alive
			var data = JSON.parse_string(p.ws.get_packet().get_string_from_utf8())
			if data is Dictionary:
				match data.get("type", ""):
					"hello":
						_announce_player(p, data)
					"ping":
						p.ws.send_text(JSON.stringify({"type": "pong", "sent": data.get("sent", 0)}))
					"latency":
						var milliseconds = data.get("ms")
						if (milliseconds is int or milliseconds is float) and is_finite(float(milliseconds)):
							player_latency[p.id] = clampi(int(milliseconds), 0, 60000)
							latency_updated.emit(p.id, player_latency[p.id])
					_:
						if p.announced:
							message_received.emit(p.id, data)
		var timeout_ms := int(heartbeat_timeout_seconds * 1000) if p.announced else TIMEOUT_MS
		if Time.get_ticks_msec() - p.last_seen_ms < timeout_ms:
			return false
		disconnect_reasons[p.id] = "No phone messages for %d seconds." % heartbeat_timeout_seconds
		p.ws.close(1001, "Heartbeat timed out")
	# closing, closed, or timed out: this player is gone
	if p.announced:
		if not disconnect_reasons.has(p.id):
			disconnect_reasons[p.id] = "Phone connection closed."
		p.announced = false
		player_latency.erase(p.id)
		player_left.emit(p.id)
	return true
