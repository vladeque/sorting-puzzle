shader_type canvas_item;
render_mode unshaded;

const int MAX_TARGETS = 16;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float activation_progress : hint_range(0.0, 1.0) = 1.0;
uniform float elapsed_seconds = 0.0;
uniform vec2 activation_origin = vec2(0.64, 0.88);
uniform int target_count = 0;
uniform vec2 target_positions[MAX_TARGETS];
uniform vec4 shade_color : source_color = vec4(0.105, 0.055, 0.018, 1.0);
uniform vec4 warm_color : source_color = vec4(1.0, 0.58, 0.075, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.86, 0.32, 1.0);
uniform float shade_opacity : hint_range(0.0, 0.4) = 0.30;
uniform float edge_glow_opacity : hint_range(0.0, 0.25) = 0.12;
uniform float focus_radius : hint_range(0.05, 0.3) = 0.145;
uniform float focus_warmth : hint_range(0.0, 0.4) = 0.24;
uniform float search_opacity : hint_range(0.0, 0.3) = 0.15;
uniform float activation_opacity : hint_range(0.0, 0.6) = 0.42;


void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float short_side = min(screen_size.x, screen_size.y);
	vec2 aspect_scale = screen_size / short_side;

	float focus_cutout = 0.0;
	float focus_light = 0.0;
	float focus_core = 0.0;
	float pulse = 0.92 + 0.08 * sin(elapsed_seconds * 4.2);

	for (int target_index = 0; target_index < MAX_TARGETS; target_index++) {
		if (target_index >= target_count) {
			break;
		}
		vec2 target = target_positions[target_index];
		vec2 target_delta = (UV - target) * aspect_scale;
		float target_distance = length(target_delta);
		float pool = 1.0 - smoothstep(focus_radius * 0.42, focus_radius, target_distance);
		float core = 1.0 - smoothstep(focus_radius * 0.16, focus_radius * 0.58, target_distance);
		focus_cutout = max(focus_cutout, pool);
		focus_light = max(focus_light, pool * pulse);
		focus_core = max(focus_core, core * pulse);
	}

	// Lantern stays visibly active when no target exists yet by searching the shelves continuously.
	float search_phase = fract(elapsed_seconds / 3.8);
	float search_center = mix(-0.14, 1.14, search_phase);
	float search_line = search_center + (UV.x - 0.5) * 0.13;
	float search_beam = 1.0 - smoothstep(0.025, 0.095, abs(UV.y - search_line));
	float search_fade = smoothstep(0.0, 0.12, search_phase)
		* (1.0 - smoothstep(0.88, 1.0, search_phase));
	float targetless_search = search_beam * search_fade * (1.0 - step(0.5, float(target_count)));

	// A warm perimeter makes the mode unmistakable without covering the layer-10 HUD.
	float edge_pixels = min(
		min(UV.x * screen_size.x, (1.0 - UV.x) * screen_size.x),
		min(UV.y * screen_size.y, (1.0 - UV.y) * screen_size.y)
	);
	float edge_distance = edge_pixels / short_side;
	float edge_glow = 1.0 - smoothstep(0.015, 0.11, edge_distance);

	// Activation sends a strong expanding gold wave from the Lantern button area.
	float origin_distance = length((UV - activation_origin) * aspect_scale);
	float ring_radius = activation_progress * 1.42;
	float activation_ring = 1.0 - smoothstep(
		0.02,
		0.09,
		abs(origin_distance - ring_radius)
	);
	activation_ring *= 1.0 - smoothstep(0.74, 1.0, activation_progress);
	float origin_bloom = (1.0 - smoothstep(0.0, 0.44, origin_distance))
		* (1.0 - smoothstep(0.05, 0.62, activation_progress));
	float activation_glow = max(activation_ring, origin_bloom);

	float dark_alpha = shade_opacity * (1.0 - focus_cutout * 0.94);
	float warm_alpha = edge_glow * edge_glow_opacity
		+ focus_light * focus_warmth
		+ targetless_search * search_opacity
		+ activation_glow * activation_opacity;
	float core_alpha = focus_core * 0.12;
	float combined_weight = dark_alpha + warm_alpha + core_alpha;
	float total_alpha = clamp(combined_weight * intensity, 0.0, 0.52);
	vec3 mixed_color = vec3(0.0);
	if (combined_weight > 0.0001) {
		mixed_color = (
			shade_color.rgb * dark_alpha
			+ warm_color.rgb * warm_alpha
			+ core_color.rgb * core_alpha
		) / combined_weight;
	}
	COLOR = vec4(mixed_color, total_alpha);
}
