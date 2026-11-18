shader_type canvas_item;
render_mode blend_add;
varying vec4 ghost_tint;

void vertex() {
	ghost_tint = COLOR;
}

void fragment() {
	float mask = texture(TEXTURE, UV).a;
	COLOR = vec4(ghost_tint.rgb, mask * ghost_tint.a);
}
