shader_type canvas_item;
render_mode unshaded;

uniform float activation_amount : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(0.08, 0.58, 1.0, 1.0);
uniform float glow_width : hint_range(0.01, 0.15) = 0.09;
uniform float glow_intensity : hint_range(0.0, 0.75) = 0.42;
uniform float edge_rim_width_ratio : hint_range(0.05, 0.4) = 0.12;
uniform float edge_rim_boost : hint_range(0.0, 1.0) = 0.78;
uniform vec4 modal_shade_color : source_color = vec4(0.02, 0.025, 0.03, 0.66);
uniform float modal_shade_amount : hint_range(0.0, 1.0) = 0.0;


void fragment() {
	// Measure from the shorter viewport dimension so the halo has the same apparent thickness on
	// every side across tall phones and squarer tablets.
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float edge_pixels = min(
		min(UV.x * screen_size.x, (1.0 - UV.x) * screen_size.x),
		min(UV.y * screen_size.y, (1.0 - UV.y) * screen_size.y)
	);
	float normalized_edge = edge_pixels / min(screen_size.x, screen_size.y);
	float eased_activation = smoothstep(0.0, 1.0, activation_amount);
	float active_width = glow_width * mix(0.28, 1.0, eased_activation);
	float soft_halo = 1.0 - smoothstep(0.0, active_width, normalized_edge);
	float bright_rim = 1.0 - smoothstep(
		0.0,
		active_width * edge_rim_width_ratio,
		normalized_edge
	);
	float glow_alpha = min(
		soft_halo * glow_intensity + bright_rim * glow_intensity * edge_rim_boost,
		1.0
	) * opacity * eased_activation * glow_color.a;

	vec3 glow_rgb = mix(
		glow_color.rgb,
		modal_shade_color.rgb,
		modal_shade_color.a * modal_shade_amount
	);
	COLOR = vec4(glow_rgb, glow_alpha);
}
