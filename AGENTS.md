# Repository Guidelines

## Project Structure & Module Organization

This Godot 4 Pong project supports single-player and native-hosted phone multiplayer. `project.godot` configures the `SFX` and `LanServer` autoloads.

- Root scenes: `main_menu.tscn`, `lobby.tscn`, and `main.tscn`.
- `Scripts/`: gameplay, input, AI, audio, camera effects, and networking.
- `Shaders/ctr.gdshader`: CRT post-processing.
- `web/controller.html`: browser controller served by the LAN host.
- `addons/qrcode_generator/`: bundled dependency; preserve its license.
- Root images: branding and Godot import metadata.
- `tests/`: physics, networking, and controller regression checks.

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

Preserve resource UIDs and scene references. `East` and `West` wall names drive scoring. Defer collision-triggered physics mutations. Keep paddle physics enabled when replacing mouse or AI input; disabling collision nodes removes their bodies from simulation.

## Testing Guidelines

Run:

```sh
godot --headless --path . --script tests/lan_match_test.gd
godot --headless --path . --script tests/game_physics_test.gd
node tests/controller_controls_test.cjs
```

Close other LAN hosts first. No coverage threshold is configured. Follow `tests/README.md` for real-phone checks, including tilt, certificates, and disconnection. HTTPS/WebSocket ports are 8443/8444; TLS files live under `user://`.

## Commit & Pull Request Guidelines

Use descriptive subjects, such as “Add main menu and placeholder lobby scene.” PRs should explain behavior changes, link applicable issues, list validation, and include screenshots for UI changes. Exclude `.godot/`, builds, and private TLS keys.

## Current Project Status

Two phones control host-started matches through drag, calibrated tilt, or Up/Down buttons. The CRT-styled controller and PC display round-trip ping. Paddle collisions match their visuals; the ball uses continuous collision detection. Phone matches return to the lobby with the final result; single-player retains its restart screen.

In `main.tscn`, select `GameManager` and adjust `Win Score` (default 5; supports 100+) and `Lobby Return Delay` (default 2 seconds). Device tilt and certificate onboarding need validation.
