# Pong Project — Handoff Notes

**Engine:** Godot 4.7.2 (stable)
**Purpose:** Learning-focused Pong build — every piece was implemented with explanations of *why*, not vibe-coded. If you're picking this up, read this doc before touching scripts; several bugs were already hit and fixed, and re-introducing them is easy if you don't know the reasoning below.

---

## 1. Scene Tree

```
Main (Node2D)
├── Camera2D
├── Ball (RigidBody2D)
│   ├── Visual (ColorRect)
│   └── CollisionShape2D (BoxShape2D)
├── PlayerPaddle (CharacterBody2D)
│   ├── Visual (ColorRect)
│   └── CollisionShape2D (BoxShape2D)
├── OpponentPaddle (CharacterBody2D)
│   ├── Visual (ColorRect)
│   └── CollisionShape2D (BoxShape2D)
├── Walls (Node2D — container only)
│   ├── North (StaticBody2D)
│   ├── South (StaticBody2D)
│   ├── East (StaticBody2D)
│   └── West (StaticBody2D)
├── GameManager (Node)
└── PostFX (CanvasLayer, Layer = 10)
	└── CRTOverlay (ColorRect, Full Rect anchor, Mouse Filter = Ignore)
```

Note: exact node positions/scales were manually adjusted from any tutorial defaults — don't assume specific X/Y coordinates, check the actual scene.

**Why these node types:**
- `RigidBody2D` (Ball) — physics engine owns its motion; we don't manually move it.
- `CharacterBody2D` (Paddles) — designed for direct/controlled movement, not physics-driven.
- `StaticBody2D` (Walls) — has collision, never moves.
- Visuals are separate `ColorRect` children from collision shapes — decouples "how it looks" from "how it collides." No sprite assets used; this is intentional to keep focus on logic, not art.

---

## 2. Wall Naming Is Load-Bearing

`Ball.gd`'s collision handler checks **exact node names**: `"East"` and `"West"` trigger scoring, `"North"`/`"South"` are plain bounce walls. **If you rename any wall node, scoring silently breaks with no error** — the `if body.name == "East"` check just never matches. If you ever restructure the Walls container, update the name checks in `ball.gd` accordingly.

---

## 3. Ball (`ball.gd`)

```gdscript
extends RigidBody2D

@export var bounce_damping = 0.99
@export var max_speed = 500
@export var reset_on_score: bool = true   # toggle: reposition ball after a score, or let it keep playing

signal ball_reset
signal score_point(player)

func _ready():
	linear_velocity = Vector2(200, -150)
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

func _on_body_entered(body):
	if body.name == "East":
		emit_signal("score_point", "player")
		if reset_on_score:
			call_deferred("reset_ball")
	elif body.name == "West":
		emit_signal("score_point", "opponent")
		if reset_on_score:
			call_deferred("reset_ball")

func reset_ball():
	position = get_viewport_rect().size / 2
	var angle = randf_range(-45, 45) * PI / 180
	var speed = 250
	linear_velocity = Vector2(cos(angle), sin(angle)) * speed
	emit_signal("ball_reset")
```

**Required Inspector setup on the Ball node (not defaults — must be set manually):**
| Property | Value | Why |
|---|---|---|
| Gravity Scale | `0` | No downward pull; top-down game |
| Lock Rotation | `On` | Ball shouldn't spin |
| Contact Monitor | `On` | **Required** for `body_entered` to fire at all — off by default |
| Max Contacts Reported | `≥ 1` | Also required alongside Contact Monitor; default is `0`, which silently disables signal reporting even with Contact Monitor on |
| Physics Material Override → Bounce | `1.0` | Elastic collisions |
| Physics Material Override → Friction | `0.0` | No drag on contact |
| Linear → Damp Mode | `Replace` | See gotcha #3 below |
| Linear → Damp | `0.0` | See gotcha #3 below |

**Design toggle:** `reset_on_score` (bool, exported) — `true` = classic Pong (ball re-centers after each point), `false` = continuous play (ball just bounces off the East/West wall like any other wall; scoring still counts in the background, but nothing visibly resets). Useful for A/B testing feel.

**Win flow:** `GameManager` owns `win_score` (default 5, first to reach it wins) and freezes the whole tree via `get_tree().paused = true` on win. **There is currently no restart mechanism** — once paused, you have to stop and re-run the scene. This is a known open gap (see Section 7).

---

## 4. PlayerPaddle (`player_paddle.gd`)

```gdscript
extends CharacterBody2D

@export var min_y = 50.0   # tune to match your North wall's inner edge
@export var max_y = 550.0  # tune to match your South wall's inner edge

func _physics_process(delta):
	var mouse_y = get_global_mouse_position().y
	global_position.y = clamp(mouse_y, min_y, max_y)
```

- Moves vertically only, tracks mouse Y 1:1 (not velocity-based movement — directly sets position).
- Fixed X position (left side), set once in the editor.
- `min_y`/`max_y` are **exported and must be tuned per your actual wall positions** — no auto-detection. If you move the walls, update these.

---

## 5. OpponentPaddle (`opponent_paddle.gd`)

```gdscript
extends CharacterBody2D

@export var ball_path: NodePath   # drag the Ball node here in Inspector
@export var min_y = 50.0
@export var max_y = 550.0
@export var tracking_speed = 300.0  # pixels/sec — difficulty knob

@onready var ball: RigidBody2D = get_node(ball_path)

func _physics_process(delta):
	var target_y = ball.global_position.y
	var current_y = global_position.y
	var new_y = move_toward(current_y, target_y, tracking_speed * delta)
	global_position.y = clamp(new_y, min_y, max_y)
```

- **`ball_path` must be set in the Inspector** (drag the `Ball` node into the field) or this throws a null reference at runtime — it's not auto-wired.
- `tracking_speed` is the difficulty knob: lower than ball speed = beatable, at/above ball speed = unbeatable wall, not really "AI."
- Uses `NodePath` + `@onready` pattern instead of a hardcoded relative path — survives scene tree rearranging.

---

## 6. GameManager (`game_manager.gd`)

```gdscript
extends Node

@export var ball_path: NodePath   # drag Ball node here
@export var win_score: int = 5

@onready var ball: RigidBody2D = get_node(ball_path)

var player_score = 0
var opponent_score = 0
var game_over = false

func _ready():
	ball.score_point.connect(_on_score_point)

func _on_score_point(scorer: String):
	if game_over:
		return

	if scorer == "player":
		player_score += 1
	else:
		opponent_score += 1

	print("Player: %d   Opponent: %d" % [player_score, opponent_score])
	check_win()

func check_win():
	if player_score >= win_score:
		end_game("Player")
	elif opponent_score >= win_score:
		end_game("Opponent")

func end_game(winner: String):
	game_over = true
	print("%s wins!" % winner)
	ball.linear_velocity = Vector2.ZERO
	get_tree().paused = true
```

- **`ball_path` must be set in Inspector** (same pattern as OpponentPaddle).
- Score/win state is currently **console-only** (`print()` statements) — no on-screen UI exists yet.
- Connects to the Ball's `score_point` signal in code (`_ready()`), not via the editor's Signal panel — this is intentional so the connection survives node renames/moves.

---

## 7. CRT Post-Processing Shader

**Setup:**
- `PostFX` is a `CanvasLayer` with **Layer = 10** (renders after/on top of the default gameplay layer, which is `1`).
- `CRTOverlay` is a `ColorRect` inside it, anchored **Full Rect**, **Mouse Filter = Ignore** (critical — without this it silently swallows mouse input, breaking `PlayerPaddle`'s cursor tracking).
- Shader is attached via a `ShaderMaterial` on the `ColorRect`.

**Shader code (`crt_overlay.gdshader`):**

```glsl
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float scanline_count : hint_range(50.0, 800.0) = 300.0;
uniform float curvature : hint_range(0.0, 10.0) = 3.0;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.8;
uniform float chroma_offset : hint_range(0.0, 0.02) = 0.004;
uniform vec4 tint : source_color = vec4(0.85, 1.0, 0.9, 1.0);
uniform float border_softness : hint_range(0.001, 0.05) = 0.01;

vec2 curve_uv(vec2 uv, float aspect) {
	vec2 cc = uv * 2.0 - 1.0;
	cc.x *= aspect;

	float r2 = dot(cc, cc);
	cc *= 1.0 + curvature * 0.02 * r2;

	cc.x /= aspect;
	return cc * 0.5 + 0.5;
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = curve_uv(SCREEN_UV, aspect);

	float mask = smoothstep(0.0, border_softness, uv.x)
			   * smoothstep(0.0, border_softness, uv.y)
			   * smoothstep(0.0, border_softness, 1.0 - uv.x)
			   * smoothstep(0.0, border_softness, 1.0 - uv.y);

	uv = clamp(uv, 0.0, 1.0);

	float edge_dist = distance(uv, vec2(0.5));
	float chroma = chroma_offset * edge_dist * 2.0;

	float r = textureLod(screen_texture, uv + vec2(chroma, 0.0), 0.0).r;
	float g = textureLod(screen_texture, uv, 0.0).g;
	float b = textureLod(screen_texture, uv - vec2(chroma, 0.0), 0.0).b;
	vec3 color = vec3(r, g, b);

	float scanline = sin(uv.y * scanline_count * PI) * 0.5 + 0.5;
	color *= mix(1.0, scanline, scanline_intensity);

	vec2 vig_uv = uv * (1.0 - uv.yx);
	float vignette = pow(vig_uv.x * vig_uv.y * 15.0, vignette_strength);
	color *= vignette;

	color *= tint.rgb;
	color *= mask;

	COLOR = vec4(color, 1.0);
}
```

All uniforms are Inspector-tunable under **Material → Shader Parameters** without touching code.

---

## 8. Gotchas Already Hit (don't re-break these)

1. **`body_entered` on RigidBody2D is off by default.** Requires both `Contact Monitor = On` and `Max Contacts Reported ≥ 1` on the Ball, or the signal never fires — no error, it just silently never triggers.

2. **Godot's `PhysicsMaterial` has no "combine mode" dropdown.** With `absorbent = false` (default) on both colliding bodies, bounce values are *added*, not averaged — a common misconception. This was NOT the cause of an earlier "ball loses speed" bug.

3. **The real cause of ball losing speed on bounce was `Linear Damp`**, which continuously bleeds velocity every physics frame regardless of collisions — unrelated to bounce/friction material settings entirely. Fixed by setting the Ball's `Linear Damp Mode = Replace` and `Linear Damp = 0.0`. This is called out directly in Godot's own docs on `bounce`.

4. **Never mutate a RigidBody2D's `position`/`linear_velocity` synchronously inside `body_entered`.** It's called mid-physics-step; Godot's physics server still has its own in-flight copy of the transform for that step and will briefly overwrite your change, producing a one-frame teleport/snap-back glitch. Always wrap the mutation in `call_deferred(...)` from inside a collision signal.

5. **`return` is not allowed inside `fragment()`/`vertex()`/`light()`** in Godot Shading Language — these must fall through to a single exit. Regular helper functions (like `curve_uv()`) don't have this restriction and can `return` normally.

6. **Built-ins like `SCREEN_PIXEL_SIZE` and `TIME` aren't visible inside custom helper functions**, even if that helper is only ever called from `fragment()`. They're scoped to the specific stage function they belong to. Fix: read the built-in inside `fragment()` and pass it into the helper as a parameter.

---

## 9. Open Items / Not Yet Built

- **No on-screen UI** — score and win messages currently only print to the Output console.
- **No restart mechanism** — `get_tree().paused = true` freezes everything on win with no way back in short of stopping the scene.
- **No paddle-angle bounce** — hitting the edge of a paddle currently bounces at whatever angle the physics engine's default elastic collision gives you, not an intentional "steeper angle near paddle edges" classic-Pong feel. Flagged twice during development, deferred both times.
- **No sound/juice** — no screen shake, particles, or audio on hits/scores.
- **No difficulty scaling** — ball speed is constant; doesn't ramp up with rally length or paddle hits.

---

## 10. Design Decisions (so you don't second-guess them)

- Paddle movement is classic-Pong style (vertical, left/right sides), not Breakout-style — explicitly chosen over the alternative.
- Scoring model is continuous play with score increment (not "game fully stops and requires explicit restart input per point") — explicitly chosen over the alternative.
- Assets are plain `ColorRect`s, not sprites/textures — intentional, to keep focus on logic over art during the learning phase.
