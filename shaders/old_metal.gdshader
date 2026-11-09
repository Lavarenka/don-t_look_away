shader_type spatial;
// Старое железо, латунь, сталь (тайник Веры: петли, накладки, замки, шпилька).
// Металл потемнел, местами — пятна ржавчины / патины (шероховатые, почти не металл);
// на рёбрах и выступах затёрт руками до блеска (кривизна — по производным нормали).
// Узор — в осях меша: детали двигаются — пятна не «плывут».
render_mode depth_draw_opaque;

uniform vec3 base_col : source_color = vec3(0.10, 0.095, 0.09);
uniform vec3 worn_col : source_color = vec3(0.42, 0.41, 0.40);   // затёртые рёбра
uniform vec3 rust_col : source_color = vec3(0.26, 0.11, 0.045);  // ржавчина / патина
uniform float metal = 0.85;
uniform float rough = 0.5;
uniform float rust = 0.45;       // 0..1 — сколько пятен
uniform float wear = 0.7;        // 0..1 — затёртость рёбер
uniform float curv_k = 0.0009;   // чувствительность к рёбрам (1/м кривизны -> 0..1)
uniform float scale = 140.0;     // частота пятен, 1/м
uniform float seed = 0.0;

varying vec3 v_lp;

void vertex() {
	v_lp = VERTEX;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
				   mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
				   mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise3(p);
		p = p * 2.07 + 7.3;
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec3 p = v_lp * scale + seed;
	float n_big = fbm3(p);
	float n_fine = fbm3(p * 4.3 + 19.0);
	float pits = smoothstep(0.62, 0.8, vnoise3(p * 22.0));
	// рёбра: кривизна поверхности (выпуклые фаски, прутки)
	float curv = clamp(length(fwidth(NORMAL)) / max(length(fwidth(VERTEX)), 1e-6) * curv_k, 0.0, 1.0);
	float worn = smoothstep(0.25, 0.85, curv + (n_fine - 0.5) * 0.5) * wear;
	// ржавчина / патина — пятнами, гуще в «складках» шума, мелкие раковины
	float r = smoothstep(0.55 - rust * 0.25, 0.75 - rust * 0.2, n_big + n_fine * 0.25) * rust;
	r = max(r, pits * rust * 0.6);
	r *= 1.0 - worn;                                  // на затёртом ржавчины нет
	vec3 col = base_col * mix(0.75, 1.15, n_fine);
	col = mix(col, worn_col, worn);
	vec3 rc = rust_col * mix(0.6, 1.3, n_fine);
	col = mix(col, rc, r);
	ALBEDO = col;
	METALLIC = mix(metal, 0.15, r);
	ROUGHNESS = clamp(mix(mix(rough, rough * 0.55, worn), 0.9, r) + (n_fine - 0.5) * 0.12, 0.05, 1.0);
}
