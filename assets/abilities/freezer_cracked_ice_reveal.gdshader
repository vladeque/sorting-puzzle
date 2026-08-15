shader_type canvas_item;
render_mode unshaded;

uniform float reveal_amount : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float reveal_depth : hint_range(0.1, 0.5) = 0.38;
uniform float reveal_softness : hint_range(0.001, 0.08) = 0.025;
uniform vec4 glow_color : source_color = vec4(0.08, 0.58, 1.0, 1.0);
uniform float glow_width : hint_range(0.005, 0.08) = 0.035;
uniform float glow_intensity : hint_range(0.0, 0.6) = 0.30;


void fragment() {
	vec4 ice = texture(TEXTURE, UV);
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float frontier = reveal_amount * reveal_depth;
	float edge_reveal = 1.0 - smoothstep(frontier, frontier + reveal_softness, edge_distance);
	ice.a *= edge_reveal * opacity;

	// Measure the halo against the shorter viewport dimension so every side receives the same
	// apparent thickness on tall phones, wide tablets, and the clipped TopHud copy.
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float edge_pixels = min(
		min(UV.x * screen_size.x, (1.0 - UV.x) * screen_size.x),
		min(UV.y * screen_size.y, (1.0 - UV.y) * screen_size.y)
	);
	float normalized_edge = edge_pixels / min(screen_size.x, screen_size.y);
	float glow_mask = 1.0 - smoothstep(0.0, glow_width, normalized_edge);
	float glow_reveal = smoothstep(0.0, 0.22, reveal_amount);
	float glow_alpha = glow_mask * glow_intensity * glow_color.a * opacity * glow_reveal;

	// Composite the blue halo behind the original crack pixels using straight alpha.
	float combined_alpha = ice.a + glow_alpha * (1.0 - ice.a);
	vec3 combined_rgb = vec3(0.0);
	if (combined_alpha > 0.0001) {
		combined_rgb = (
			ice.rgb * ice.a
			+ glow_color.rgb * glow_alpha * (1.0 - ice.a)
		) / combined_alpha;
	}
	COLOR = vec4(combined_rgb, combined_alpha);
}
