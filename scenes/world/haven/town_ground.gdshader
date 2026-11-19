shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// ЗЕМЛЯ МІСТА: трава, утоптана земля й темно-синя бруківка (мальовані
// безшовні текстури). Маска — колір вершини: r — земля, g — бруківка,
// b — тінь. Шум ламає рівні межі, щоб краї були живими.

uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cobble_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float grass_scale = 0.16;
uniform float dirt_scale = 0.18;
uniform float cobble_scale = 0.24;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = texture(detail, p * 0.045).r;
	float n2 = texture(detail, p * 0.13 + vec2(0.37, 0.71)).r;
	vec3 grass = texture(grass_tex, p * grass_scale).rgb;
	// Друга вибірка трави під кутом — менше видно повтор.
	grass = mix(grass, texture(grass_tex, vec2(p.y, -p.x) * grass_scale * 0.61).rgb, 0.35 + 0.3 * n);
	// Трава спокійніша: менш насичена й тепліша (без «кислоти»).
	float lum = dot(grass, vec3(0.3, 0.59, 0.11));
	grass = mix(vec3(lum), grass, 0.6) * vec3(0.92, 0.92, 0.78);
	vec3 dirt = texture(dirt_tex, p * dirt_scale).rgb;
	vec3 cobble = texture(cobble_tex, p * cobble_scale).rgb;
	float d = smoothstep(0.38, 0.62, COLOR.r + (n - 0.5) * 0.45 + (n2 - 0.5) * 0.15);
	float c = smoothstep(0.42, 0.58, COLOR.g + (n2 - 0.5) * 0.18);
	vec3 col = mix(grass, dirt, d);
	col = mix(col, cobble, c);
	col *= 0.9 + 0.2 * n;
	col *= 1.0 - COLOR.b * 0.45;
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
