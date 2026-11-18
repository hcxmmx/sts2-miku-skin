shader_type canvas_item;

uniform float scan_y = -450.0;
uniform float sprite_y = 0.0;
uniform float appearance = 1.0;
varying float actor_y;

void vertex() {
	actor_y = VERTEX.y + sprite_y;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float reveal = 1.0 - smoothstep(scan_y - 7.0, scan_y + 7.0, actor_y);
	float edge = exp(-pow((actor_y - scan_y) / 4.0, 2.0));
	float trail = exp(-pow((actor_y - scan_y + 10.0) / 13.0, 2.0));
	vec3 silhouette = vec3(0.44, 0.98, 1.0);
	vec3 color = mix(silhouette, source.rgb, reveal);
	color += vec3(0.65, 0.95, 1.0) * (edge * 1.3 + trail * 0.25);
	COLOR = vec4(color, source.a * appearance);
}
