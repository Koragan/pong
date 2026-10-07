# Repository Guidelines

## Project Structure & Module Organization

This Godot 4 Pong project supports single-player and native-hosted phone multiplayer. `project.godot` configures the `GameSettings`, `SFX`, and `LanServer` autoloads.

- Root scenes: `main_menu.tscn`, `lobby.tscn`, and `main.tscn`.
- `Scripts/`: gameplay, input, AI, audio, camera effects, and networking.
- `Scripts/game_settings.gd`: validated settings, defaults, persistence, and CRT application.
- `Scripts/menu_overlay.gd`: shared pause/options UI, built in code on an always-processing CanvasLayer above the CRT.
- `Shaders/ctr.gdshader`: CRT post-processing.
- `web/controller.html`: browser controller served by the LAN host.
- `addons/qrcode_generator/`: bundled dependency; preserve its license.
- Root images: branding and Godot import metadata.
- `tests/`: physics, networking, countdown, controller, and pause/options regression checks.

Read `pong-project-handoff.md` for rationale, but verify outdated feature descriptions against current code.

## Build, Test, and Development Commands

Use Godot 4.7 with matching export templates. Run from the repository root:

- `godot --editor --path .`: edit scenes and Inspector properties.
- `godot --path .`: launch the main menu.
- `godot --headless --path . --editor --quit`: import resources and check script errors.
- `mkdir -p build/web`, then `godot --headless --path . --export-release "Web" build/web/index.html`: export for browsers.

Phone hosting requires a native run; Web exports hide phone mode.

## Coding Style & Naming Conventions

Use tabs for GDScript, `snake_case` filenames/functions/variables, and `UPPER_SNAKE_CASE` constants. Follow existing typed declarations and surrounding HTML formatting. `.editorconfig` specifies UTF-8; no formatter or linter is configured.

Preserve resource UIDs and scene references. `East` and `West` wall names drive scoring. Apply ball contact corrections through `_integrate_forces`; defer mutations and hit effects from collision signals. Preserve swept paddle checks and court-facing separation so fast hits and moving paddles cannot trap the ball at corners. Keep paddle physics enabled when replacing mouse or AI input; disabling collision nodes removes their bodies from simulation.

## Testing Guidelines

Run:

```sh
godot --headless --path . --script tests/lan_match_test.gd
godot --headless --path . --script tests/game_physics_test.gd
godot --headless --path . --script tests/countdown_test.gd
node tests/controller_controls_test.cjs
godot --headless --path . --script tests/pause_options_test.gd
```

Run Godot checks sequentially and close other LAN hosts first; they share ports and user data. No coverage threshold is configured. Follow `tests/README.md` for real-phone checks, including tilt, certificates, and reconnection. HTTPS/WebSocket ports are 8443/8444; TLS files live under `user://`. The pause/options test changes settings and restores the previous options file afterward; run it sequentially with other checks. Existing saved gameplay options can affect tests that assume defaults.

## Commit & Pull Request Guidelines

Use descriptive subjects, such as “Add main menu and placeholder lobby scene.” PRs should explain behavior changes, link applicable issues, list validation, and include screenshots for UI changes. Exclude `.godot/`, builds, and private TLS keys.

## Current Project Status

Two phones control native-hosted matches through drag, calibrated tilt, or Up/Down buttons. The controller matches the CRT palette; phones and PC display round-trip ping. Paddle collision boxes match their visuals. The ball uses continuous collision detection plus swept paddle checks, with corner/overlap correction directing it back into the court. A goal awards one point; scoring rearms after the ball returns toward midfield or a fresh serve starts, preventing trapped-ball score bursts. Angry-ball recovery remains a fallback, freezes physics during its return animation, and respects match pauses.

Match starts and restarts use a 3–2–1–GO countdown with rising tones, impact shake, and a green GO burst. The ball stays frozen and scoring is blocked until GO. Disconnects pause both gameplay and countdown with a visible reason; reconnecting the same controller tab preserves scores and paddle assignment. Reload controller pages after frontend changes. Heartbeat timeout defaults to 30 seconds; delayed ping replies do not force a disconnect.

Phone matches return to the lobby with the winner, final score, and return reason. Single-player retains its restart screen. Use Options → Gameplay to edit Points to Win (default 5; supports up to 1000). In `main.tscn`, select `GameManager` to edit `Lobby Return Delay` (2 seconds). Select `UI/Countdown` to edit `Beat Duration` (1 second).

Space or Esc opens the host pause menu in either game mode. Options are available from the main and pause menus and persist in `user://options.cfg`. `GameSettings` applies ball speed, both paddle-hit multipliers, winning score, CRT settings, and SFX volume at runtime; these options take precedence over the corresponding scene Inspector values. Lowering the winning score during a pause is checked on Resume. Reconnection preserves a manual host pause, and Resume cannot bypass a disconnected phone.

Options tabs cover Gameplay (max ball speed 300–3000 px/s, separate paddle-hit multipliers below/above 700 px/s, and win score 1–1000), Display (CRT toggle, scanlines, curvature, vignette, color offset, and edge softness), and Audio (SFX volume, including mute). Changes apply immediately and save automatically; Restore Defaults is available. Default max speed is 1500 px/s, multipliers are 1.15 and 1.009, win score is 5, and SFX volume is 100%. Curvature is controlled by Options rather than paddle-hit boosts.

The pause menu offers Resume, Options, and Main Menu for single-player or Return to Lobby for phone matches. Esc from Options returns to its calling menu; Space or Esc resumes from the pause menu. Phone controllers receive host-pause status.

All five automated regression suites pass, including paddle corners, moving-paddle squeeze correction, repeated goal suppression, angry recovery, saved/live settings, paused countdowns, and pause/reconnection interactions. Countdown and pause/options rendering were inspected in Godot. Real-phone tilt, certificate onboarding, Wi-Fi interruption, and host-pause behavior still need device validation.
