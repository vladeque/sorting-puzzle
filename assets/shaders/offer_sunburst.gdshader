shader_type canvas_item;

// Warm sunburst stage behind an offer's hero art (Starter Bundle modal): a radial base gradient,
// alternating light rays, a bright centre glow, a few twinkling four-point sparkles, and a darker
// lip along the bottom edge, all masked to a rounded rectangle that matches the stage's
// StyleBoxFlat frame. Geometry is measured in units of the rect's height (recovered from UV
// derivatives), so the pattern keeps its proportions at every responsive panel scale.

uniform vec4 inner_color : source_color = vec4(1.0, 0.898, 0.541, 1.0);
uniform vec4 middle_color : source_color = vec4(0.976, 0.745, 0.306, 1.0);
uniform vec4 outer_color : source_color = vec4(0.933, 0.604, 0.204, 1.0);
uniform float middle_stop : hint_range(0.05, 0.95) = 0.6;
uniform vec4 glow_color : source_color = vec4(1.0, 0.976, 0.863, 0.95);
// Glow radius as a fraction of the distance from the centre to the farthest corner.
uniform float glow_radius : hint_range(0.0, 1.0) = 0.36;
uniform vec4 ray_color : source_color = vec4(1.0, 1.0, 1.0, 0.34);
uniform float ray_count = 24.0;
// Slow ray rotation in radians per second; 0 keeps the rays still.
uniform float ray_speed = 0.0;
uniform vec4 sparkle_color : source_color = vec4(1.0, 0.99, 0.9, 1.0);
uniform float sparkle_twinkle : hint_range(0.0, 0.5) = 0.18;
uniform vec4 lip_color : source_color = vec4(0.667, 0.353, 0.078, 0.25);
// Heights as a fraction of the rect height.
uniform float lip_height = 0.023;
uniform float corner_radius = 0.0687;
// Centre of the burst in UV space.
uniform vec2 center = vec2(0.5, 0.52);

// xy: position in UV space, z: radius as a fraction of the rect height, w: twinkle phase.
const vec4 SPARKLES[4] = vec4[4](
	vec4(0.172, 0.573, 0.050, 0.0),
	vec4(0.235, 0.366, 0.031, 1.7),
	vec4(0.809, 0.534, 0.042, 3.1),
	vec4(0.735, 0.267, 0.027, 4.4)
);

float rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 uv_step = fwidth(UV);
	float aspect = uv_step.y / max(uv_step.x, 1e-6);
	// One screen pixel, in height units.
	float px = max(uv_step.y, 1e-6);

	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	vec2 half_size = vec2(0.5 * aspect, 0.5);
	float shape = rounded_box(p, half_size, corner_radius);
	float inside = clamp(0.5 - shape / px, 0.0, 1.0);

	vec2 burst = (UV - center) * vec2(aspect, 1.0);
	float reach = length(max(abs(vec2(center.x * aspect, center.y)), abs(vec2((1.0 - center.x) * aspect, 1.0 - center.y))));
	float r = length(burst);
	float d = r / max(reach, 1e-6);

	vec3 color = d < middle_stop
		? mix(inner_color.rgb, middle_color.rgb, d / middle_stop)
		: mix(middle_color.rgb, outer_color.rgb, clamp((d - middle_stop) / (1.0 - middle_stop), 0.0, 1.0));

	float angle = atan(burst.y, burst.x) + TIME * ray_speed;
	float phase = fract(angle / TAU * ray_count);
	// Ray edge softness from the pixel's angular size, which avoids the atan seam in fwidth().
	float edge = clamp(ray_count * px / (TAU * max(r, 1e-4)), 0.0, 0.5);
	float ray = smoothstep(0.5 + edge, 0.5 - edge, phase) * smoothstep(0.0 - edge, 0.0 + edge, phase);
	color = mix(color, ray_color.rgb, ray * ray_color.a);

	float glow = (1.0 - clamp(d / max(glow_radius, 1e-4), 0.0, 1.0)) * glow_color.a;
	color = mix(color, glow_color.rgb, glow);

	for (int i = 0; i < 4; i++) {
		vec4 sparkle = SPARKLES[i];
		float size = sparkle.z * (1.0 - sparkle_twinkle + sparkle_twinkle * sin(TIME * 2.2 + sparkle.w));
		vec2 q = abs((UV - sparkle.xy) * vec2(aspect, 1.0)) / max(size, 1e-4);
		float star = sqrt(q.x + 1e-4) + sqrt(q.y + 1e-4) - 1.0;
		float star_edge = max(fwidth(star), 1e-4);
		color = mix(color, sparkle_color.rgb, (1.0 - smoothstep(-star_edge, star_edge, star)) * sparkle_color.a);
	}

	float lifted = rounded_box(p + vec2(0.0, lip_height), half_size, corner_radius);
	float lip = clamp(0.5 + lifted / px, 0.0, 1.0);
	color = mix(color, lip_color.rgb, lip * lip_color.a);

	COLOR = vec4(color, inside);
}
