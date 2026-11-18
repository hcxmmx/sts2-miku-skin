shader_type canvas_item;

uniform sampler2D actor_texture : filter_nearest, repeat_disable;

uniform vec4 atlas_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float sprite_y = 0.0;
uniform float charge = 0.0;
uniform float strength = 0.0;
uniform float peak = 0.0;
varying float actor_y;

void vertex() {
	actor_y = VERTEX.y + sprite_y;
}

float body_alpha(sampler2D image, vec2 uv, vec2 pixel) {
	vec2 low = atlas_rect.xy;
	vec2 high = low + atlas_rect.zw;
	float inside = step(low.x, uv.x) * step(low.y, uv.y) * step(uv.x, high.x) * step(uv.y, high.y);
	return texture(image, clamp(uv, low + pixel * 0.5, high - pixel * 0.5)).a * inside;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float near_alpha = 0.0;
	float far_alpha = 0.0;
	float inner_alpha = source.a;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.78539816;
		vec2 direction = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		float neighbor = body_alpha(actor_texture, UV + direction * 1.5, TEXTURE_PIXEL_SIZE);
		near_alpha = max(near_alpha, neighbor);
		inner_alpha = min(inner_alpha, neighbor);
		far_alpha = max(far_alpha, body_alpha(actor_texture, UV + direction * 4.0, TEXTURE_PIXEL_SIZE));
	}
	float rise = smoothstep(mix(25.0, -420.0, charge) - 35.0, mix(25.0, -420.0, charge) + 35.0, actor_y);
	float glow = rise * strength;
	float inner_edge = max(0.0, source.a - inner_alpha);
	float outer_edge = max(0.0, near_alpha - source.a);
	float halo = max(0.0, far_alpha - source.a);
	vec3 cyan = vec3(0.30, 0.95, 1.0);
	vec3 body_color = source.rgb * (1.0 + glow * 0.12 + peak * 0.12);
	body_color += cyan * inner_edge * glow * 0.9;
	float outer_alpha = (outer_edge * 0.85 + halo * 0.22) * glow;
	vec3 color = mix(cyan * (1.0 + peak * 0.5), body_color, source.a);
	COLOR = vec4(color, max(source.a, outer_alpha));
}
