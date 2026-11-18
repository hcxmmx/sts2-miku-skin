shader_type canvas_item;

uniform sampler2D actor_texture : filter_nearest, repeat_disable;

uniform vec4 atlas_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float sprite_y = 0.0;
uniform float strength = 0.0;
uniform float effect_time = 0.0;
uniform float dim = 0.0;
varying float actor_y;

void vertex() {
	actor_y = VERTEX.y + sprite_y;
}

vec4 body_sample(sampler2D image, vec2 uv, vec2 pixel) {
	vec2 low = atlas_rect.xy;
	vec2 high = low + atlas_rect.zw;
	float inside = step(low.x, uv.x) * step(low.y, uv.y) * step(uv.x, high.x) * step(uv.y, high.y);
	vec4 value = texture(image, clamp(uv, low + pixel * 0.5, high - pixel * 0.5));
	value.a *= inside;
	return value;
}

void fragment() {
	float band = floor(actor_y / 13.0);
	float tick = floor(effect_time * 30.0);
	float noise = fract(sin(band * 73.31 + tick * 19.17) * 43758.5453);
	float shift = (noise - 0.5) * 18.0 * strength * step(0.48, noise);
	vec2 uv = UV + vec2(shift, 0.0) * TEXTURE_PIXEL_SIZE;
	vec4 body = body_sample(actor_texture, uv, TEXTURE_PIXEL_SIZE);
	vec4 red = body_sample(actor_texture, uv + vec2(4.0 * strength, 0.0) * TEXTURE_PIXEL_SIZE, TEXTURE_PIXEL_SIZE);
	vec4 blue = body_sample(actor_texture, uv - vec2(4.0 * strength, 0.0) * TEXTURE_PIXEL_SIZE, TEXTURE_PIXEL_SIZE);
	vec3 separated = vec3(red.r, body.g, blue.b);
	vec3 color = mix(body.rgb, separated, strength * 0.8);
	color += vec3(0.18, 0.01, 0.03) * strength * body.a;
	float ghost = max(red.a, blue.a) * strength * 0.55;
	if (body.a < 0.1) {
		color = mix(vec3(0.48, 0.035, 0.09), vec3(0.95, 0.16, 0.24), red.a);
	}
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(gray) * vec3(0.88, 0.94, 1.0), dim * 0.6) * (1.0 - dim * 0.5);
	COLOR = vec4(color, max(body.a, ghost));
}
