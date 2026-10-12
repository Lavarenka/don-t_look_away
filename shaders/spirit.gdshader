shader_type spatial;
// Призрак: рукава провисают под своим весом, волосы и подол медленно колышутся.
// Маски запечены в COLOR (tools_bake_spirit.gd): r/g — рукава, b — волосы, a — подол.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float arm_up_l = 0.0;      // 0 — рука опущена, 1 — поднята горизонтально (из скрипта)
uniform float arm_up_r = 0.0;
uniform vec3 l0; uniform vec3 l1; uniform vec3 l2;   // плечо, локоть, кисть (пространство скелета)
uniform vec3 r0; uniform vec3 r1; uniform vec3 r2;
uniform float sag = 1.0;           // насколько рукав «повисает» на руке
uniform float drop = 2.6;          // во сколько раз ткань свисает ниже, чем отстояла от руки в покое
uniform float sway = 1.0;          // общая сила колыхания
uniform float lift = 0.0;          // испуг: волосы поднимаются
uniform float blood = 0.0;         // 0..1: кровь проступает пятнами и потёками
uniform float pallor = 0.85;       // насколько кожа мертвенно-бледная
uniform float rim = 0.06;          // холодный ореол по краю силуэта (скрипт усиливает при испуге)
uniform int debug = 0;
varying vec4 masks;
// мимика (scripts/spirit.gd, FACE): челюсть и уголки рта, в системе кости головы (метры)
uniform mat4 head_inv;             // обратная поза кости головы (пространство скелета)
uniform mat3 head_rot;             // поворот кости головы
uniform float head_k = 1.0;        // масштаб модели: единицы скелета -> метры
uniform float mouth = 0.0;         // 0 — закрыт, 1 — раскрыт в крике
uniform float grimace = 0.0;       // уголки рта вниз, губы чуть разжаты
uniform vec3 mouth_at = vec3(0.0, 0.053, 0.09);
varying float v_jaw;

void vertex() {
	masks = COLOR;
	v_jaw = 0.0;
	if (mouth + grimace > 0.001) {
		vec3 hp = (head_inv * vec4(VERTEX, 1.0)).xyz * head_k;
		vec3 m = hp - mouth_at;
		// лицо: перед головой, не волосы, по ширине рта/подбородка
		float face = smoothstep(0.0, 0.035, hp.z) * (1.0 - COLOR.b) * (1.0 - smoothstep(0.02, 0.034, abs(m.x)));
		// нижняя челюсть: ниже линии рта и выше шеи
		float w = face * smoothstep(0.003, -0.004, m.y) * smoothstep(-0.085, -0.055, m.y);
		vec3 hinge = vec3(0.0, mouth_at.y + 0.015, mouth_at.z - 0.085);
		vec3 r = hp - hinge;
		float a = mouth * 0.36;
		float c = cos(a); float sn = sin(a);
		vec3 rr = vec3(r.x, r.y * c - r.z * sn, r.y * sn + r.z * c);
		vec3 d = (hinge + rr - hp) * w;
		// уголки рта вниз
		float corner = face * smoothstep(0.008, 0.022, abs(m.x)) * (1.0 - smoothstep(0.0, 0.018, abs(m.y)));
		d.y -= corner * 0.006 * grimace;
		d.y -= w * 0.004 * grimace;
		VERTEX += head_rot * d / head_k;
		v_jaw = w;
	}
	vec3 down = normalize((inverse(MODEL_MATRIX) * vec4(0.0, -1.0, 0.0, 0.0)).xyz);
	vec3 up = -down;
	float t = TIME;
	// рукава: висящая ткань «вешается» на текущую линию руки и свисает вниз на своё расстояние
	float tt = UV2.x;
	if (COLOR.r > 0.0) {
		vec3 ap = tt < 1.0 ? mix(l0, l1, tt) : mix(l1, l2, tt - 1.0);
		VERTEX = mix(VERTEX, ap + down * UV2.y * drop, COLOR.r * sag * smoothstep(0.03, 0.3, arm_up_l));
	}
	if (COLOR.g > 0.0) {
		vec3 ap = tt < 1.0 ? mix(r0, r1, tt) : mix(r1, r2, tt - 1.0);
		VERTEX = mix(VERTEX, ap + down * UV2.y * drop, COLOR.g * sag * smoothstep(0.03, 0.3, arm_up_r));
	}
	// волосы: медленные волны, разные для разных прядей
	float hph = VERTEX.x * 23.0 + VERTEX.z * 17.0;
	vec3 hs = vec3(sin(t * 0.9 + hph + VERTEX.y * 6.0), 0.0, cos(t * 0.7 + hph * 1.3 + VERTEX.y * 5.0));
	VERTEX += hs * 0.012 * COLOR.b * sway;
	VERTEX += (up * 0.04 + vec3(VERTEX.x, 0.0, VERTEX.z) * 0.12) * COLOR.b * lift;
	// подол: как будто снизу тянет холодом
	float ph = VERTEX.x * 14.0 + VERTEX.z * 11.0;
	VERTEX += vec3(sin(t * 1.3 + ph), 0.0, cos(t * 1.1 + ph * 0.8)) * 0.009 * COLOR.a * sway;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec4 c = texture(albedo_tex, vec2(UV.x, 1.0 - UV.y)) * tint;
	vec3 col = c.rgb;
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	float mx = max(col.r, max(col.g, col.b));
	float mn = min(col.r, min(col.g, col.b));
	float sat = (mx - mn) / max(mx, 0.001);
	// что где: волосы — тёмное, кровь — насыщенно-красное, кожа — тёплая средняя, остальное — ткань
	float hair = smoothstep(0.16, 0.07, lum);
	float red = smoothstep(0.45, 0.7, sat) * step(col.g * 1.6, col.r) * (1.0 - hair);
	float skin = smoothstep(0.18, 0.32, sat) * (1.0 - smoothstep(0.5, 0.65, sat)) * smoothstep(0.1, 0.22, lum)
		* step(col.b, col.g * 1.05) * (1.0 - red) * (1.0 - hair);
	float cloth = clamp(1.0 - hair - red - skin, 0.0, 1.0);
	// кожа мёртвая: серо-синяя, с пятнами (трупные пятна, вены)
	float liv = vnoise(UV * 23.0) * 0.6 + vnoise(UV * 71.0) * 0.4;
	vec3 dead = mix(vec3(lum), vec3(0.62, 0.68, 0.74) * lum * 1.25, 0.55);
	dead = mix(dead, dead * vec3(0.55, 0.5, 0.65), smoothstep(0.55, 0.8, liv) * 0.7);
	col = mix(col, dead, skin * pallor);
	// ткань — грязная, отсыревшая, местами темнее
	float damp = smoothstep(0.45, 0.75, vnoise(UV * 13.0 + 3.1));
	col = mix(col, col * vec3(0.72, 0.7, 0.66), cloth * damp * 0.6);
	col *= mix(1.0, 0.75, hair);                           // волосы — мокрые, почти чёрные
	col = mix(col, col * vec3(0.7, 0.45, 0.42), red * 0.5); // старая кровь темнее
	float rough = 0.85;
	rough = mix(rough, 0.48, hair);
	rough = mix(rough, 0.25, red);
	rough = mix(rough, 0.6, skin);
	rough = mix(rough, 0.55, cloth * damp);
	ALBEDO = col;
	SPECULAR = mix(0.5, 0.65, clamp(hair + red, 0.0, 1.0));
	if (blood > 0.0) {
		// пятна + вертикальные потёки (растянутый шум), чем больше blood — тем шире
		float n = vnoise(UV * vec2(9.0, 9.0)) * 0.6 + vnoise(UV * vec2(31.0, 31.0)) * 0.4;
		float drip = vnoise(vec2(UV.x * 70.0, UV.y * 4.0));
		float m = smoothstep(0.78 - 0.45 * blood, 0.86 - 0.4 * blood, max(n, drip * 0.95));
		m *= blood;
		m *= 1.0 - hair;                                   // по чёрным волосам кровь не видна — не красим их
		ALBEDO = mix(ALBEDO, vec3(0.2, 0.006, 0.005), m * 0.92);
		rough = mix(rough, 0.2, m);
	}
	ROUGHNESS = rough;
	// тонкая ткань и кожа светятся насквозь, когда свет сзади
	BACKLIGHT = vec3(0.55, 0.42, 0.36) * (cloth * 0.5 + skin * 0.35);
	// холодный ореол по краю силуэта — видна в темноте, хоть и не освещена
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.45, 0.55, 0.7) * fr * rim * (1.0 - hair * 0.7);
	// раскрытый рот: растянутая полоса между губами — тёмная глотка
	float gap = smoothstep(0.08, 0.3, v_jaw) * smoothstep(0.98, 0.7, v_jaw) * clamp(mouth * 3.0 + grimace * 0.5, 0.0, 1.0);
	ALBEDO = mix(ALBEDO, vec3(0.025, 0.008, 0.008), gap);
	ROUGHNESS = mix(ROUGHNESS, 0.35, gap);
	EMISSION *= 1.0 - gap;
	if (debug >= 4) ALBEDO = mix(ALBEDO, vec3(1.0, 0.0, 0.0), v_jaw);
	if (debug == 1) ALBEDO = masks.rgb + vec3(masks.a, masks.a, 0.0);
	if (debug == 2) ALBEDO = vec3(hair, skin, red);
	if (debug == 3 && hair > 0.5) discard;
}
