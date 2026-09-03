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
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;  // valid here, inside fragment()
	vec2 uv = curve_uv(SCREEN_UV, aspect);

	// smooth falloff at the screen edge instead of a hard on/off cutoff —
	// this one change removes most of the "sticker" look on its own
	float mask = smoothstep(0.0, border_softness, uv.x)
	           * smoothstep(0.0, border_softness, uv.y)
	           * smoothstep(0.0, border_softness, 1.0 - uv.x)
	           * smoothstep(0.0, border_softness, 1.0 - uv.y);

	uv = clamp(uv, 0.0, 1.0);

	// chromatic aberration scaled by distance from center: real lenses are
	// sharp/aligned at dead center and get worse toward the rim — a constant
	// offset everywhere (what we had before) is optically wrong and looks flat
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
	color *= mask;   // fade smoothly to black at the true edge

	COLOR = vec4(color, 1.0);
}