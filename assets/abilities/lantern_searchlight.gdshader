shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float activation_progress : hint_range(0.0, 1.0) = 1.0;
uniform float elapsed_seconds = 0.0;
uniform vec2 activation_origin = vec2(0.64, 0.88);
uniform vec4 vignette_color : source_color = vec4(0.12, 0.045, 0.005, 1.0);
uniform vec4 warm_color : source_color = vec4(1.0, 0.56, 0.08, 1.0);
uniform float vignette_opacity : hint_range(0.0, 0.25) = 0.12;
uniform float ambient_warmth : hint_range(0.0, 0.15) = 0.045;
uniform float sweep_opacity : hint_range(0.0, 0.2) = 0.085;
uniform float activation_opacity : hint_range(0.0, 0.5) = 0.30;


void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float short_side = min(screen_size.x, screen_size.y);
	vec2 aspect_scale = screen_size / short_side;

	// A pixel-consistent edge treatment stays narrow on both tall phones and squarer tablets.
	float edge_pixels = min(
		min(UV.x * screen_size.x, (1.0 - UV.x) * screen_size.x),
		min(UV.y * screen_size.y, (1.0 - UV.y) * screen_size.y)
	);
	float edge_distance = edge_pixels / short_side;
	float vignette = 1.0 - smoothstep(0.015, 0.14, edge_distance);

	// Keep a very light warm wash through the play area without flattening item colors.
	float center_distance = length((UV - vec2(0.5, 0.52)) * aspect_scale);
	float center_warmth = 1.0 - smoothstep(0.08, 0.78, center_distance);

	// A soft diagonal beam periodically searches down the shelves.
	float sweep_phase = fract(elapsed_seconds / 6.4);
	float sweep_center = mix(-0.12, 1.12, sweep_phase);
	float sweep_line = sweep_center + (UV.x - 0.5) * 0.10;
	float sweep = 1.0 - smoothstep(0.018, 0.075, abs(UV.y - sweep_line));
	float sweep_fade = smoothstep(0.0, 0.12, sweep_phase)
		* (1.0 - smoothstep(0.88, 1.0, sweep_phase));
	sweep *= sweep_fade;

	// The activation ring blooms from the Lantern button's normalized screen position.
	float origin_distance = length((UV - activation_origin) * aspect_scale);
	float ring_radius = activation_progress * 1.35;
	float activation_ring = 1.0 - smoothstep(
		0.018,
		0.075,
		abs(origin_distance - ring_radius)
	);
	activation_ring *= 1.0 - smoothstep(0.72, 1.0, activation_progress);
	float origin_bloom = (1.0 - smoothstep(0.0, 0.38, origin_distance))
		* (1.0 - smoothstep(0.05, 0.58, activation_progress));
	float activation_glow = max(activation_ring, origin_bloom);

	float dark_alpha = vignette * vignette_opacity;
	float warm_alpha = center_warmth * ambient_warmth
		+ sweep * sweep_opacity
		+ activation_glow * activation_opacity;
	float total_alpha = clamp((dark_alpha + warm_alpha) * intensity, 0.0, 0.38);
	vec3 mixed_color = vec3(0.0);
	if (dark_alpha + warm_alpha > 0.0001) {
		mixed_color = (
			vignette_color.rgb * dark_alpha
			+ warm_color.rgb * warm_alpha
		) / (dark_alpha + warm_alpha);
	}
	COLOR = vec4(mixed_color, total_alpha);
}
