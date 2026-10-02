# Repository Guidelines

## Project Structure & Module Organization

This Godot 4 project implements Pong with single-player gameplay and a phone-controller lobby. `project.godot` configures the application and the `SFX` and `LanServer` autoloads.

- Root scenes: `main_menu.tscn`, `lobby.tscn`, and `main.tscn`.
- `Scripts/`: gameplay, paddle control, trajectory prediction, audio, camera effects, and LAN networking.
- `Shaders/ctr.gdshader`: CRT post-processing.
- `web/controller.html`: browser controller served by the native LAN host.
- `addons/qrcode_generator/`: bundled QR-code dependency; preserve its license.
- Root image files: branding assets and Godot import metadata.

Read `pong-project-handoff.md` for design rationale, but verify against current scripts and scenes: some feature descriptions are outdated.

## Build, Test, and Development Commands

Run from the repository root with a compatible Godot 4 installation; the project declares version 4.7.

- `godot --editor --path .`: open the project for scene and Inspector edits.
- `godot --path .`: launch the configured main scene.
- `godot --headless --path . --editor --quit`: import resources and check editor startup output for script errors.
- `mkdir -p build/web` followed by `godot --headless --path . --export-release "Web" build/web/index.html`: export using the Web preset; matching export templates are required.

Phone hosting requires a native run; the phone-mode button is hidden in Web exports.

## Coding Style & Naming Conventions

Use tabs for GDScript indentation, `snake_case` for script filenames, functions, and variables, and `UPPER_SNAKE_CASE` for constants. Follow existing typed declarations and use `@export` for Inspector configuration. Match surrounding HTML/CSS/JavaScript formatting. `.editorconfig` specifies UTF-8; no formatter or linter is configured.

Preserve scene references and resource UIDs. Wall names `East` and `West` drive scoring. Defer physics mutations triggered by collision callbacks.

## Testing Guidelines

No automated test framework or coverage threshold is configured. Check menu navigation, paddle movement, collisions, scoring, win/restart behavior, and visual effects manually. For LAN changes, test QR access, phone connection/disconnection, player counts, and lobby exit on the same network. HTTPS and secure WebSocket ports are 8443 and 8444; TLS files are generated under `user://`.

## Commit & Pull Request Guidelines

History uses short descriptive subjects such as “Add main menu and placeholder lobby scene”; no strict commit format is established. Prefer focused, actionable subjects. PRs should describe behavior changes, link applicable issues, and list validation performed. Include screenshots or clips for UI changes. Exclude `.godot/`, generated builds, and private TLS keys from commits.
