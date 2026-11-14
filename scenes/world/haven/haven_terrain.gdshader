shader_type spatial;
// Освітлення рахується у вершинах: земля — плавна сітка з кроком 1 м, тож
// різниці з попіксельним не видно, а піксельний шейдер (земля займає
// більшу частину екрана) стає в рази коротшим — це важливо для телефона.
render_mode cull_back, specular_disabled, vertex_lighting;

// ЗЕМЛЯ ПРИХИСТКУ — меш із пагорбами й терасами (будує HavenBuilder).
// Що де лежить, записано в кольорі вершин (його кладе будівник):
//   червоний — утоптана стежка (ґрунт);
//   зелений  — скельний схил / кам'янистий ґрунт;
//   синій    — тінь (під деревами, біля стін): темніша трава.
// Решта — трава, що переливається плямами (текстура шуму), а на крутих
// схилах сама переходить у камінь. Без складних текстур — як у Death's Door:
// прості теплі кольори, головне робить світло.

uniform sampler2D detail : filter_linear_mipmap, repeat_enable;

uniform vec3 grass_light : source_color = vec3(0.40, 0.55, 0.24);
uniform vec3 grass_dark : source_color = vec3(0.19, 0.33, 0.15);
uniform vec3 grass_warm : source_color = vec3(0.55, 0.56, 0.27);
uniform vec3 dirt_light : source_color = vec3(0.66, 0.53, 0.37);
uniform vec3 dirt_dark : source_color = vec3(0.46, 0.35, 0.25);
uniform vec3 rock_light : source_color = vec3(0.62, 0.58, 0.52);
uniform vec3 rock_dark : source_color = vec3(0.38, 0.35, 0.32);

// Координати шуму рахуємо у вершинах (три масштаби) — у пікселі лишаються
// самі вибірки текстури.
varying vec2 uv_far;
varying vec2 uv_mid;
varying vec2 uv_near;
varying float slope;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	uv_far = world_pos.xz * 0.031;
	uv_mid = world_pos.xz * 0.17;
	uv_near = world_pos.xz * 1.3;
	slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
}

void fragment() {
	float n1 = texture(detail, uv_far).r;
	float n2 = texture(detail, uv_mid).r;
	float n3 = texture(detail, uv_near).r;
	float spots = smoothstep(0.2, 0.85, n1 * 0.6 + n2 * 0.3 + n3 * 0.1);
	vec3 grass = mix(grass_dark, grass_light, spots);
	// Теплі сонячні плями на траві.
	grass = mix(grass, grass_warm, smoothstep(0.62, 0.9, n1) * 0.45);

	// Стежка: нерівний край (шум), усередині — світліший протоптаний ґрунт.
	float path = smoothstep(0.35, 0.65, COLOR.r + (n2 - 0.5) * 0.35);
	vec3 dirt = mix(dirt_dark, dirt_light, smoothstep(0.25, 0.8, n2 * 0.7 + n3 * 0.3));

	// Камінь: розмічений будівником або крутий схил.
	float rock = clamp(COLOR.g + smoothstep(0.32, 0.55, slope), 0.0, 1.0);
	rock = smoothstep(0.3, 0.7, rock + (n3 - 0.5) * 0.3);
	vec3 stone = mix(rock_dark, rock_light, smoothstep(0.2, 0.8, n2 * 0.5 + n3 * 0.5));

	vec3 col = mix(grass, dirt, path);
	col = mix(col, stone, rock);
	// Тінь під деревами й біля стін (запечена — без справжніх тіней).
	col *= 1.0 - COLOR.b * 0.45;
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
