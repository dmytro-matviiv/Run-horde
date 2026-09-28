shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Прохід у данж: закручена магічна пелена в арці. Без текстур і без
// справжнього світла — лише математика в шейдері, тож на телефоні
// майже нічого не коштує.

uniform vec4 color_a : source_color = vec4(0.42, 0.18, 0.95, 1.0);
uniform vec4 color_b : source_color = vec4(0.15, 0.75, 1.0, 1.0);

void fragment() {
	// Форма проходу — арка: знизу прямокутник, згори півколо.
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	vec2 q = vec2(p.x, max(p.y - 0.25, 0.0) * 1.35);
	float inside = 1.0 - smoothstep(0.92, 1.0, length(q));
	inside *= 1.0 - smoothstep(0.96, 1.0, abs(p.x));

	float r = length(vec2(p.x, p.y * 0.8));
	float a = atan(p.y, p.x);
	float swirl = sin(a * 4.0 - TIME * 2.2 + r * 9.0) * 0.5 + 0.5;
	float pulse = 0.85 + 0.15 * sin(TIME * 3.1);
	vec3 color = mix(color_a.rgb, color_b.rgb, swirl * (1.0 - r * 0.7));
	color += vec3(0.9, 0.85, 1.0) * smoothstep(0.45, 0.0, r) * 0.7;
	ALBEDO = color * pulse * 1.3;
	ALPHA = inside * (0.72 + 0.28 * swirl);
}
