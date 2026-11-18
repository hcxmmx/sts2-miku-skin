shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
uniform float show_time = -1.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 p = UV;
	float sweep = sin(clock * .18) * .13;
	float beam_width = .012 + p.y * .065;
	float cyan_distance = (p.x - (.45 + p.y * (.43 + sweep))) / beam_width;
	float pink_distance = (p.x - (.58 - p.y * (.30 - sweep))) / beam_width;
	float beam_fade = smoothstep(.10, .26, p.y) * (1.0 - smoothstep(.73, 1.0, p.y));
	vec3 beams = vec3(.10, .86, 1.0) * exp(-cyan_distance * cyan_distance) * .15;
	beams += vec3(.87, .25, .88) * exp(-pink_distance * pink_distance) * .12;
	float grid_pass = exp(-pow((p.y - fract(clock * .047)) * 19.0, 2.0));
	float grid_mask = smoothstep(.20, .53, p.y) * (1.0 - smoothstep(.86, 1.0, p.y));
	float floor_pulse = .5 + .5 * sin(clock * 1.7);
	vec2 floor_point = (p - vec2(.70, .94)) / vec2(.27, .045);
	float floor_glow = exp(-dot(floor_point, floor_point));
	vec3 color = source.rgb * (.89 + .05 * sin(clock * .63));
	color += beams * beam_fade;
	color += vec3(.025, .16, .18) * grid_pass * grid_mask;
	color += vec3(.05, .24, .27) * floor_glow * (.55 + .45 * floor_pulse);
	if (show_time >= 0.0) {
		float horizon = exp(-pow((p.y - .779) * 150.0, 2.0));
		float opening = smoothstep(0.02, .12, show_time) * (1.0 - smoothstep(.16, .5, show_time));
		float plane = clamp((p.y - .78) / .22, 0.0, 1.0);
		float arrival = clamp((show_time - .11) / .60, 0.0, 1.0);
		float floor_mask = smoothstep(.775, .80, p.y);
		float width = .12 + plane * .45;
		float lateral = (p.x - .66) / width;
		float rays = pow(.5 + .5 * cos(lateral * 64.0), 12.0);
		float crossbars = pow(.5 + .5 * cos(sqrt(plane) * 66.0), 14.0);
		float sweep_front = exp(-pow((plane - arrival) * 13.0, 2.0));
		float grid = (rays + crossbars) * exp(-lateral * lateral) * floor_mask;
		float lit_grid = smoothstep(0.0, .08, show_time) * (1.0 - smoothstep(.72, 1.15, show_time));
		color += vec3(.15, .85, 1.0) * horizon * opening * (.25 + .75 * smoothstep(.18, .68, p.x));
		color += vec3(.12, .68, .93) * grid * lit_grid * (sweep_front + .36 * step(plane, arrival));
		float top_beat = smoothstep(.79, .89, show_time) * (1.0 - smoothstep(.91, 1.19, show_time));
		vec2 neon = (p - vec2(.50, .12)) / vec2(.20, .16);
		float magenta = max(0.0, source.r - source.g);
		color += vec3(1.0, .39, .88) * exp(-dot(neon, neon)) * top_beat * (.18 + magenta * 1.7);
		float age = mod(show_time - 1.323529, 5.882353) - .09;
		vec2 floor_uv = vec2((p.x - .73) * 1.3, (p.y - .85) * 4.8);
		float radius = length(floor_uv);
		float pulse = exp(-pow((radius - max(0.0, age) * .65) * 48.0, 2.0));
		float wake = smoothstep(.0, .1, age) * (1.0 - smoothstep(.35, .95, age));
		color += mix(vec3(.14, .85, 1.0), vec3(.96, .27, .83), smoothstep(.69, .94, p.x))
			* pulse * wake * floor_mask * .75;
	}
	COLOR = vec4(color, source.a);
}
