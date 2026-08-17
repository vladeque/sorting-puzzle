shader_type canvas_item;

uniform float content_scale : hint_range(0.8, 1.0, 0.01) = 0.92;
uniform float sharpen_strength : hint_range(0.0, 1.0, 0.05) = 0.35;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float distance_from_center = length(centered_uv);
	vec2 scaled_uv = centered_uv / content_scale + vec2(0.5);
	vec4 scaled_avatar = texture(TEXTURE, scaled_uv);
	vec2 texel_size = 1.0 / vec2(textureSize(TEXTURE, 0));
	vec3 neighbor_average = (
		texture(TEXTURE, scaled_uv + vec2(texel_size.x, 0.0)).rgb
		+ texture(TEXTURE, scaled_uv - vec2(texel_size.x, 0.0)).rgb
		+ texture(TEXTURE, scaled_uv + vec2(0.0, texel_size.y)).rgb
		+ texture(TEXTURE, scaled_uv - vec2(0.0, texel_size.y)).rgb
	) * 0.25;
	scaled_avatar.rgb = clamp(
		scaled_avatar.rgb + (scaled_avatar.rgb - neighbor_average) * sharpen_strength,
		vec3(0.0),
		vec3(1.0)
	);
	vec2 radial_direction = centered_uv / max(distance_from_center, 0.0001);
	vec3 edge_background = texture(TEXTURE, vec2(0.5) + radial_direction * 0.46).rgb;
	float background_mix = smoothstep(
		content_scale * 0.43,
		content_scale * 0.48,
		distance_from_center
	);
	vec4 tex_color = mix(scaled_avatar, vec4(edge_background, 1.0), background_mix) * COLOR;
	float circle_alpha = 1.0 - smoothstep(0.47, 0.5, distance_from_center);
	tex_color.a *= circle_alpha;
	COLOR = tex_color;
}
