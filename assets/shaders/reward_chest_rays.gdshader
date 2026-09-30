shader_type canvas_item;

// Rotating light rays and a soft core glow behind the reward chest while it opens
// (scenes/ui/reward_chest_open_ceremony.tscn). Unlike offer_sunburst.gdshader this has no framed
// stage: both the rays and the glow fade to fully transparent inside the rect's inscribed circle,
// so the effect floats over the dimmed Main Menu without a visible edge at any size.

uniform vec4 ray_color : source_color = vec4(1.0, 0.85, 0.4, 0.5);
uniform vec4 glow_color : source_color = vec4(1.0, 0.95, 0.72, 0.9);
uniform float ray_count = 14.0;
// Share of each ray-plus-gap period that is lit.
uniform float ray_width : hint_range(0.05, 0.95) = 0.42;
// Rotation in radians per second; 0 keeps the rays still.
uniform float ray_speed = 0.32;
// Glow radius as a fraction of the inscribed circle's radius.
uniform float glow_radius : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 p = UV - vec2(0.5);
	// 0 at the centre, 1 on the inscribed circle.
	float r = length(p) * 2.0;

	float angle = atan(p.y, p.x) + TIME * ray_speed;
	float phase = fract(angle / TAU * ray_count);
	float edge = 0.06;
	float ray = smoothstep(0.0, edge, phase) * (1.0 - smoothstep(ray_width - edge, ray_width, phase));
	float ray_alpha = ray * (1.0 - smoothstep(0.12, 1.0, r)) * ray_color.a;

	float glow = pow(1.0 - clamp(r / max(glow_radius, 1e-4), 0.0, 1.0), 1.7) * glow_color.a;

	float alpha = clamp(ray_alpha + glow, 0.0, 1.0);
	vec3 color = mix(ray_color.rgb, glow_color.rgb, glow / max(ray_alpha + glow, 1e-4));
	COLOR = vec4(color, alpha * COLOR.a);
}
