shader_type canvas_item;
render_mode blend_premul_alpha;

#include "res://Miku_Hcxmmx/Portrait/PortraitMotion.gdshaderinc"

uniform bool body_layer = false;
uniform vec4 body_uv = vec4(0.000977, 0.000977, 0.711425, 0.654785);

varying vec4 vertex_tint;
varying vec2 original_position;

void vertex() {
	vertex_tint = COLOR;
	original_position = VERTEX;
	if (body_layer) {
		VERTEX += portrait_offset(VERTEX);
	}
}

void fragment() {
	vec2 p = art_point(original_position);
	vec2 sample_uv = UV;
	if (body_layer) {
		sample_uv += speaker_uv_offset(p) * body_uv.zw;
	}
	vec4 source = texture(TEXTURE, sample_uv);
	// Preserve premultiplied filtering while removing compression residue at alpha zero.
	source.rgb = clamp(source.rgb, vec3(0.0), vec3(source.a));
	if (body_layer) {
		float flow = score_light(p, source.rgb / max(source.a, 0.0001));
		source.rgb += source.rgb * flow * 0.75 + vec3(0.40, 0.90, 1.0) * source.a * flow * 0.14;
	}
	COLOR = vec4(source.rgb * vertex_tint.rgb * vertex_tint.a, source.a * vertex_tint.a);
}
