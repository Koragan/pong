# Controller checks

Run from the repository root:

```sh
godot --headless --path . --script tests/lan_match_test.gd
godot --headless --path . --script tests/game_physics_test.gd
godot --headless --path . --script tests/countdown_test.gd
node tests/controller_controls_test.cjs
```

The Godot integration check starts the real TLS/WebSocket host on ports 8443/8444, connects two local clients, and checks ping, remote paddle movement, input bounds, paused-match exit, heartbeat timeouts, visible disconnect pauses, same-session reconnection, score preservation, and lobby disconnect handling. Close any running Pong LAN host first. It uses the project's normal Godot user-data directory for the self-signed certificate.

The physics check verifies active remote collision bodies, visual/collision alignment, maximum-speed ball bounces, score limits of 5 and 100, final results in the lobby, and single-player restart behavior.

The countdown check verifies the frozen ball, blocked scoring, 3–2–1–GO order, disconnect/reconnect behavior, GO release, overlay cleanup, and restart.

The Node check uses DOM and sensor mocks to exercise drag, held buttons, cancellation, tilt calibration, denied permission, and latency display. It does not require npm dependencies.

For device validation, run the native game, select Phone Multiplayer, and connect two phones on the same LAN using the QR code. Trust the local certificate; if the WebSocket connection fails, use the controller's certificate link and reload. Start Match on the PC. Check all three control modes, tilt permission and calibration, portrait/landscape behavior, latency on both screens, and Return to Lobby. Interrupt one phone connection and confirm the match pauses with a reason. Reconnect the same controller page and confirm scores and paddle assignment are preserved; use Return to lobby to leave explicitly. Also check single-player still uses mouse input and AI.
