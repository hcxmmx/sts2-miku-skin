shader_type canvas_item;
render_mode blend_add;

varying vec4 shape_data;
varying vec4 shape_tint;

void vertex() {
	shape_data = INSTANCE_CUSTOM;
	shape_tint = COLOR;
	if (shape_data.z < 1.0) {
		VERTEX.x += VERTEX.y * mix(shape_data.x, shape_data.y, UV.x);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	int kind = int(floor(shape_data.z));
	float coverage = 1.0;
	if (kind == 0) {
		float edge = abs(p.y) - shape_data.z * 2.0;
		float aa = max(fwidth(p.y) * 0.5, 0.0001);
		coverage = 1.0 - smoothstep(-aa, aa, edge - aa * 1.3);
		int caps = int(shape_data.w);
		if ((caps & 1) != 0) {
			coverage *= smoothstep(0.0, max(fwidth(UV.x), 0.0001), UV.x);
		}
		if ((caps & 2) != 0) {
			coverage *= smoothstep(0.0, max(fwidth(UV.x), 0.0001), 1.0 - UV.x);
		}
	} else if (kind == 1) {
		float radial = length(p);
		float edge = radial - shape_data.x;
		if (shape_data.w < 0.5) {
			edge = abs(edge) - shape_data.y;
		}
		float aa = max(fwidth(radial) * 0.5, 0.0001);
		coverage = 1.0 - smoothstep(-aa, aa, edge - aa * 1.3);
	} else if (kind == 2) {
		float radial = length(p);
		float half_width = fract(shape_data.z) * 2.0;
		float edge = abs(radial - shape_data.w) - half_width;
		float aa = max(fwidth(radial) * 0.5, 0.0001);
		coverage = 1.0 - smoothstep(-aa, aa, edge - aa * 1.3);
		if (shape_data.y < TAU - 0.001) {
			float angle = mod(atan(p.y, p.x) - shape_data.x + TAU * 4.0, TAU);
			coverage *= 1.0 - smoothstep(shape_data.y - max(fwidth(angle), 0.001), shape_data.y, angle);
		}
	}
	COLOR = vec4(shape_tint.rgb, shape_tint.a * coverage);
}
