shader_type canvas_item;

uniform sampler2D icon_texture : filter_nearest, repeat_disable;
render_mode blend_add;
varying vec4 icon_tint;

void vertex() {
	icon_tint = COLOR;
}

float ink_mask(sampler2D image, vec2 uv) {
	vec4 source = texture(image, uv);
	return (1.0 - smoothstep(0.12, 0.65, max(source.r, max(source.g, source.b)))) * source.a;
}

void fragment() {
	float ink = ink_mask(icon_texture, UV);
	float glow = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.78539816;
		vec2 offset = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * 6.0;
		glow += ink_mask(icon_texture, UV + offset) / 8.0;
	}
	COLOR = vec4(icon_tint.rgb, icon_tint.a * max(ink, glow * 0.22));
}
