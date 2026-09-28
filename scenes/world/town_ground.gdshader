shader_type spatial;
render_mode cull_back, specular_disabled;

// ЗЕМЛЯ МІСТА — одна площина, одна команда малювання.
//
// Малюнок доріжок береться з маски town_paths.png (її можна
// перемалювати в будь-якому редакторі картинок):
//   червоний канал — ґрунтова доріжка;
//   зелений        — бруківка (площа й дорога до данжу);
//   синій          — тінь/темніша трава (під деревами, біля стін).
//
// За межами міста земля плавно здіймається пагорбами — місто стоїть у
// долині, і краю світу просто не видно: погляд упирається в схили, ліс
// і гори, а далі все тоне в серпанку.

uniform sampler2D path_mask : source_color, filter_linear, repeat_disable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float mask_size = 128.0;

uniform vec3 grass_light : source_color = vec3(0.47, 0.62, 0.27);
uniform vec3 grass_dark : source_color = vec3(0.2, 0.36, 0.15);
uniform vec3 dirt_light : source_color = vec3(0.58, 0.47, 0.33);
uniform vec3 dirt_dark : source_color = vec3(0.38, 0.29, 0.2);
uniform vec3 stone_light : source_color = vec3(0.7, 0.66, 0.58);
uniform vec3 stone_dark : source_color = vec3(0.42, 0.39, 0.35);

// Долина: до цього радіусу земля рівна, далі — пагорби.
uniform float valley_radius = 38.0;
uniform float hill_height = 18.0;
uniform float hill_width = 45.0;

varying vec3 world_pos;

float hill(vec2 p) {
	float r = length(p);
	float t = max(r - valley_radius, 0.0) / hill_width;
	float a = atan(p.y, p.x);
	float wobble = 0.75 + 0.2 * sin(a * 3.0 + 1.3) + 0.12 * sin(a * 7.0 + 0.4);
	return pow(t, 1.6) * hill_height * wobble;
}

void vertex() {
	vec2 p = VERTEX.xz;
	float h = hill(p);
	VERTEX.y += h;
	// Нормаль для схилів рахуємо різницею висот — інакше пагорби були б
	// освітлені як рівна земля й виглядали б пласкими.
	float e = 0.6;
	NORMAL = normalize(vec3(h - hill(p + vec2(e, 0.0)), e, h - hill(p + vec2(0.0, e))));
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / mask_size + 0.5;
	vec4 mask = texture(path_mask, uv);
	float n1 = texture(detail, world_pos.xz * 0.043).r;
	float n2 = texture(detail, world_pos.xz * 0.21).r;

	float n3 = texture(detail, world_pos.xz * 1.7).r;
	vec3 grass = mix(grass_dark, grass_light, smoothstep(0.15, 0.85, n1 * 0.6 + n2 * 0.3 + n3 * 0.1));
	// Сухі світлі плями й дрібна "шерсть" трави — щоб поле не було
	// однотонним і читалось як трава навіть зблизька.
	grass = mix(grass, grass * vec3(1.18, 1.08, 0.72), smoothstep(0.62, 0.84, n1) * 0.6);
	grass *= 0.88 + 0.24 * n3;

	vec3 dirt = mix(dirt_dark, dirt_light, smoothstep(0.2, 0.8, n2));

	// Бруківка: ряди каменів зі зсувом, темні шви між ними.
	vec2 cell = world_pos.xz * 1.75;
	cell.x += floor(cell.y) * 0.5;
	vec2 f = fract(cell);
	float seam = smoothstep(0.0, 0.08, min(min(f.x, f.y), min(1.0 - f.x, 1.0 - f.y)));
	float stone_n = texture(detail, floor(cell) * 0.137).r;
	vec3 stone = mix(stone_dark, stone_light, stone_n) * mix(0.5, 1.0, seam) * (0.9 + 0.2 * n2);

	float path_mix = smoothstep(0.35, 0.65, mask.r + (n2 - 0.5) * 0.35);
	float stone_mix = smoothstep(0.4, 0.6, mask.g + (n2 - 0.5) * 0.12);
	vec3 color = mix(grass, dirt, path_mix);
	color = mix(color, stone, stone_mix);
	color *= 1.0 - mask.b * 0.28;
	ALBEDO = color;
	ROUGHNESS = 0.92;
}
