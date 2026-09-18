shader_type canvas_item;

uniform float hole_radius : hint_range(0.0, 1.2) = 1.0;
uniform vec2 viewport_size = vec2(720.0, 1280.0);
uniform vec4 top_color : source_color = vec4(0.72549, 0.282353, 0.356863, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.298039, 0.129412, 0.278431, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.690196, 0.360784, 1.0);

void fragment() {
	float aspect = viewport_size.x / max(viewport_size.y, 1.0);
	vec2 centered = UV - vec2(0.5);
	centered.x *= aspect;
	float distance_from_center = length(centered);
	float edge_width = max(2.0 / max(viewport_size.y, 1.0), 0.0025);
	float cover_alpha = smoothstep(
		hole_radius - edge_width,
		hole_radius + edge_width,
		distance_from_center
	);

	vec3 background = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, UV.y));
	float center_glow = 1.0 - smoothstep(0.08, 0.48, distance_from_center);
	background = mix(background, glow_color.rgb, center_glow * 0.24);

	vec2 pattern_uv = centered * vec2(12.0, 12.0) + vec2(0.5);
	vec2 pattern_cell = fract(pattern_uv) - vec2(0.5);
	float pattern_dot = 1.0 - smoothstep(0.055, 0.075, length(pattern_cell));
	background += vec3(pattern_dot * 0.035);

	COLOR = vec4(background, cover_alpha);
}
