shader_type spatial;
// Советская полированная мебель: шпон ореха под лаком («полировка») — волокна, свилеватость,
// глубокий блеск. За десятилетия лак пожелтел и помутнел, на выступах вытерт до матового,
// в царапинах и сколах, кольца от стаканов на горизонтальных гранях, пыль, грязь у пола.
// carcass = 1 — внутренности: светлая ДСП / фанера без лака.
// Узор — в осях меша (дверцы двигаются — волокна не «плывут»).
render_mode depth_draw_opaque;

uniform vec3 wood_a : source_color = vec3(0.30, 0.13, 0.06);     // светлые волокна
uniform vec3 wood_b : source_color = vec3(0.14, 0.055, 0.025);   // тёмные волокна
uniform float carcass = 0.0;
uniform float age = 1.0;
uniform float seed = 0.0;
uniform float grain_scale = 1.0;      // мельче/крупнее волокна (мелкие вещи — больше 1)
uniform float clearcoat_k = 1.0;      // лак: 1 — блестит, меньше — мутный, старый
uniform float rough_k = 1.0;          // шероховатость × (больше — матовее)
uniform float floor_y = 0.0;          // пол в осях мира (для грязи снизу)

varying vec3 v_lp;
varying vec3 v_ln;
varying vec3 v_wp;
varying vec3 v_wn;

void vertex() {
	v_lp = VERTEX;
	v_ln = NORMAL;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5; float s = 0.0;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.03 + 9.1; a *= 0.5; }
	return s;
}

void fragment() {
	vec3 n = normalize(v_ln);
	vec3 p = v_lp * grain_scale + seed;
	// плоскость грани и направление волокон: на вертикальных гранях — вдоль высоты, на полках — вдоль длины
	vec2 g;                   // g.x — поперёк волокон, g.y — вдоль
	if (abs(n.y) > 0.6) g = vec2(p.x, p.z);
	else if (abs(n.x) > abs(n.z)) g = vec2(p.z, p.y);
	else g = vec2(p.x, p.y);
	// волокна: годичные кольца, искажённые шумом (свилеватость), и мелкие поры
	float warp = fbm(vec2(g.x * 2.0, g.y * 0.45)) * 2.0;
	float rings = sin(g.x * 16.0 + warp * 9.0 + fbm(g * vec2(6.0, 0.8)) * 4.0);
	float ring = smoothstep(-0.6, 1.0, rings) * 0.6 + fbm(vec2(g.x * 40.0, g.y * 1.5)) * 0.4;
	float pores = smoothstep(0.75, 0.95, vnoise(vec2(g.x * 600.0, g.y * 25.0)));
	float figure = fbm(vec2(g.x * 6.0, g.y * 2.0));             // пятна-свили
	vec3 col = mix(wood_b, wood_a, clamp(ring * 0.55 + figure * 0.45, 0.0, 1.0));
	col *= 1.0 - pores * 0.25;
	float rough = 0.22;
	float spec = 0.5;
	if (carcass > 0.5) {
		// ДСП/фанера: светлая, крапчатая, матовая
		float ch = vnoise(g * 260.0) * 0.6 + vnoise(g * 60.0) * 0.4;
		col = vec3(0.33, 0.26, 0.18) * mix(0.75, 1.05, ch);
		col = mix(col, col * 0.7, smoothstep(0.6, 0.0, length(v_lp.y - 0.17)) * 0.0);
		rough = 0.85;
		spec = 0.3;
	}
	vec3 Nw = normalize(v_wn);
	vec2 q = abs(Nw.y) > 0.6 ? v_wp.xz : (abs(Nw.x) > abs(Nw.z) ? v_wp.zy : v_wp.xy);
	float n_big = fbm(q * 1.4 + seed);
	float n_mid = fbm(q * 7.0 + seed);
	float curv = clamp(length(fwidth(NORMAL)) / max(length(fwidth(VERTEX)), 1e-5) * 0.012, 0.0, 1.0);
	if (carcass < 0.5) {
		// лак: пожелтел, местами помутнел (белёсая дымка), на рёбрах вытерт до дерева
		col = mix(col, col * vec3(1.05, 0.92, 0.7), 0.4 * age);
		float haze = smoothstep(0.5, 0.8, n_big) * age;
		col = mix(col, col + vec3(0.06, 0.055, 0.05), haze * 0.5);
		rough = mix(rough, 0.55, haze);
		float worn = smoothstep(0.35, 0.8, curv + n_mid * 0.3) * age;
		col = mix(col, col * vec3(1.35, 1.25, 1.1) + 0.02, worn * 0.6);
		rough = mix(rough, 0.75, worn);
		// царапины: тонкие светлые штрихи под разными углами
		float sc1 = smoothstep(0.965, 0.995, vnoise(vec2(q.x * 180.0 + q.y * 60.0, q.y * 4.0 - q.x * 1.3)));
		float sc2 = smoothstep(0.97, 0.997, vnoise(vec2(q.y * 210.0 - q.x * 50.0, q.x * 5.0)));
		float sc = max(sc1, sc2) * smoothstep(0.3, 0.7, n_big) * age;
		col = mix(col, col * 1.6 + 0.05, sc * 0.5);
		rough = mix(rough, 0.6, sc);
		// на верхних гранях: кольца от стаканов и пыль
		if (Nw.y > 0.7) {
			vec2 cc = floor(q * 2.2) + 0.5;
			vec2 off = vec2(hash(cc), hash(cc + 3.1)) - 0.5;
			float dr = length(fract(q * 2.2) - 0.5 - off * 0.4) / 2.2;
			float ringm = smoothstep(0.004, 0.0, abs(dr - 0.034)) * step(0.7, hash(cc + 7.7)) * age;
			col = mix(col, col + 0.07, ringm * 0.7);
			rough = mix(rough, 0.6, ringm);
			float dust = (0.5 + 0.5 * n_mid) * age;
			col = mix(col, vec3(0.38, 0.36, 0.33), dust * 0.45);
			rough = mix(rough, 0.9, dust * 0.7);
		}
	}
	// грязь и потёртость у пола, пыль в углах
	float y = v_wp.y - floor_y;
	col *= 1.0 - 0.35 * smoothstep(0.25, 0.0, y) * (0.5 + 0.5 * n_mid) * age;
	ALBEDO = col;
	ROUGHNESS = clamp(rough * rough_k, 0.0, 1.0);
	SPECULAR = spec;
	CLEARCOAT = (carcass < 0.5 ? 0.5 * (1.0 - smoothstep(0.5, 0.8, n_big) * age) : 0.0) * clearcoat_k;   // слой лака сверху
	CLEARCOAT_ROUGHNESS = 0.15;
}
