shader_type spatial;
// Старые двери, дверные коробки и оконные рамы: поверх исходной текстуры (из набора) —
// paint > 0: крашеное дерево (масляная эмаль цвета слоновой кости, пожелтевшая), краска потрескалась
//            сеткой и сбита на рёбрах, под ней — дерево из исходной текстуры;
// paint = 0: лакированное/голое дерево — лак вытерт, царапины.
// И всегда: грязь внизу (обувь, швабра), засаленное место у ручки, пыль на горизонтальных гранях,
// тёмные поры и углы. Шумы — по координатам мира, без повторов.
render_mode depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform bool has_rough = false;
uniform int rough_ch = 0;                // канал шероховатости: 0 r, 1 g, 2 b (ORM — g)
uniform vec4 albedo_col : source_color = vec4(1.0);
uniform float rough_k = 1.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_ofs = vec3(0.0);
uniform float paint = 0.0;               // 0 — дерево, 1 — крашено
uniform vec3 paint_col : source_color = vec3(0.86, 0.82, 0.70);
uniform float age = 1.0;
uniform vec3 handle = vec3(0.0, -10.0, 0.0);   // где ручка (в осях меша — полотно поворачивается); y < -5 — нет
uniform float floor_y = 0.0;
uniform float seed = 0.0;

varying vec3 v_wp;
varying vec3 v_wn;
varying vec3 v_lp;

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_lp = VERTEX;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.07 + 13.3; a *= 0.5; }
	return s;
}
// расстояние до границы ячейки — сетка трещин в старой краске
float crack(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		float d = length(g + hash2(i + g) - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return d2 - d1;
}

void fragment() {
	vec2 uv = UV * uv_scale.xy + uv_ofs.xy;
	vec4 at = texture(albedo_tex, uv) * albedo_col;
	vec3 wood = at.rgb;
	float rough = has_rough ? texture(rough_tex, uv)[rough_ch] * rough_k : rough_k;
	vec3 Nw = normalize(v_wn);
	// координаты для шумов: плоскость, на которую смотрит грань
	vec2 q = abs(Nw.x) > abs(Nw.z) ? v_wp.zy : v_wp.xy;
	if (abs(Nw.y) > 0.7) q = v_wp.xz;
	q += seed * 7.3;
	float y = v_wp.y - floor_y;
	float n_big = fbm(q * 1.3);
	float n_mid = fbm(q * 6.0);
	float n_fine = vnoise(q * 70.0);
	// рёбра: где нормаль быстро меняется — там краска сбивается первой
	float curv = clamp(length(fwidth(NORMAL)) / max(length(fwidth(VERTEX)), 1e-5) * 0.012, 0.0, 1.0);

	vec3 col = wood;
	if (paint > 0.0) {
		// краска: несколько слоёв, пожелтевшая, неровная
		vec3 pc = paint_col * mix(0.88, 1.03, n_mid) * mix(vec3(1.0), vec3(0.95, 0.9, 0.76), n_big * age);
		float cr = crack(q * 38.0);
		float cracks = (1.0 - smoothstep(0.015, 0.05, cr)) * smoothstep(0.35, 0.7, n_big) * age;
		pc = mix(pc, pc * 0.45, cracks);
		// сколы: на рёбрах и внизу (пинали ногой), местами отслаивается чешуйками
		float chip_n = n_mid * 0.7 + n_fine * 0.3;
		float chip = smoothstep(0.62, 0.66, chip_n + curv * 0.55 + smoothstep(0.35, 0.0, y) * 0.25 + cracks * 0.15) * age * paint;
		float chip_edge = smoothstep(0.58, 0.62, chip_n + curv * 0.55 + smoothstep(0.35, 0.0, y) * 0.25) * (1.0 - chip);
		col = mix(pc, wood * 0.8, chip);
		col = mix(col, col * 0.7, chip_edge * 0.6);              // тень по краю скола
		rough = mix(0.42 + 0.2 * n_mid, rough, chip);            // эмаль глаже дерева
	} else {
		// дерево: лак вытерт пятнами, тонкие светлые царапины
		float worn = smoothstep(0.55, 0.8, n_big + curv * 0.4) * age;
		col = mix(col, col * vec3(1.18, 1.1, 1.0), worn * 0.5);
		float scr = smoothstep(0.92, 0.99, vnoise(vec2(q.x * 300.0 + q.y * 40.0, q.y * 6.0))) * age;
		col = mix(col, col * 1.5 + 0.03, scr * 0.35);
		rough = mix(rough, 0.85, worn);
	}
	// грязь внизу: тёмная полоса, брызги от швабры, царапины от обуви
	float low = smoothstep(0.45, 0.0, y);
	col *= 1.0 - 0.45 * low * (0.5 + 0.5 * n_mid) * age;
	float kick = smoothstep(0.75, 0.9, vnoise(vec2(q.x * 14.0, q.y * 3.0))) * smoothstep(0.3, 0.05, y) * age;
	col = mix(col, vec3(0.06, 0.05, 0.04), kick * 0.5);
	// засаленное у ручки
	if (handle.y > -5.0) {
		float hd = length(((MODEL_MATRIX * vec4(v_lp, 1.0)).xyz - (MODEL_MATRIX * vec4(handle, 1.0)).xyz) * vec3(1.0, 0.8, 1.0));
		float grease = smoothstep(0.28, 0.02, hd) * (0.6 + 0.4 * n_mid) * age;
		col = mix(col, col * vec3(0.55, 0.5, 0.42), grease * 0.7);
		rough = mix(rough, 0.35, grease * 0.6);
	}
	// пыль на верхних гранях; тёмные углы и поры
	float dusty = smoothstep(0.6, 0.9, Nw.y) * age;
	col = mix(col, vec3(0.42, 0.4, 0.37), dusty * 0.6 * (0.6 + 0.4 * n_fine));
	col *= 1.0 - 0.15 * (1.0 - n_fine) * age;
	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = 0.45;
	if (has_normal) NORMAL_MAP = texture(normal_tex, uv).xyz;
}
