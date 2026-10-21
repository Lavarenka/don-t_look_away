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
uniform vec3 mouth_col : source_color = vec3(0.13, 0.01, 0.008);   // цвет полости у губ
uniform float mouth_deep = 1.0;    // 0 — вся полость mouth_col, 1 — в глубине чернеет
varying float v_jaw;
varying float v_mx;          // 1 — середина рта, 0 — у краёв лица
// лицо утопленницы: мутные белые глаза во впавших тёмных глазницах, трещины, вены, синие губы, зубы
uniform vec3 eye_at = vec3(0.017, 0.098, 0.1);   // центр глаза от кости головы (м), x — в стороны
uniform float eye_r = 0.0068;                     // радиус глаза (м)
uniform float face_fx = 1.0;                      // 0 — старое лицо, 1 — новое
varying vec3 v_hp;           // точка в осях кости головы (м), до движения челюсти

void vertex() {
	masks = COLOR;
	v_jaw = 0.0;
	v_mx = 0.0;
	v_hp = (head_inv * vec4(VERTEX, 1.0)).xyz * head_k;
	// впавшие глазницы: кожа вокруг глаз уходит внутрь черепа
	if (face_fx > 0.0 && v_hp.z > 0.02 && COLOR.b < 0.5) {
		float ds = length(vec2(abs(v_hp.x) - eye_at.x, (v_hp.y - eye_at.y) * 1.25));
		float sink = 1.0 - smoothstep(eye_r * 0.6, eye_r * 2.8, ds);
		VERTEX -= head_rot * vec3(0.0, 0.0, 0.006 * sink * face_fx) / head_k;
	}
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
		v_mx = 1.0 - smoothstep(0.01, 0.024, abs(m.x));
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
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
// расстояние до ближайшей «трещины» (граница ячеек Вороного)
float crack(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 o = hash2(i + g);
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return d2 - d1;
}
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
	// пряди: слипшиеся, неровные по тону (не пластик)
	float strand = vnoise(vec2(UV.x * 420.0, UV.y * 6.0)) * 0.6 + vnoise(vec2(UV.x * 90.0, UV.y * 3.0)) * 0.4;
	float hm = max(hair, masks.b);
	col = mix(col, col * mix(0.16, 0.42, strand), hm * face_fx);
	col = mix(col, col * vec3(0.7, 0.45, 0.42), red * 0.5); // старая кровь темнее
	float rough = 0.85;
	rough = mix(rough, mix(0.48, mix(0.7, 0.42, strand), face_fx), max(hair, masks.b));
	rough = mix(rough, 0.25, red);
	rough = mix(rough, 0.6, skin);
	rough = mix(rough, 0.55, cloth * damp);
	// вся кожа (шея, руки) — такая же серая, как лицо, без шва на подбородке
	float sl0 = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(sl0) * vec3(0.86, 0.9, 1.0) * 1.1, skin * 0.5 * face_fx);
	// ---- лицо (в осях головы): только кожа спереди головы
	float facem = smoothstep(0.02, 0.05, v_hp.z) * (1.0 - masks.b) * face_fx;
	float eyem = 0.0;
	if (facem > 0.0) {
		vec3 sk = col;
		float sl = dot(sk, vec3(0.3, 0.59, 0.11));
		sk = mix(sk, vec3(sl) * vec3(0.86, 0.9, 1.0) * 1.1, 0.5);      // лицо серее, мертвее
		// вены: тонкий «гребешковый» шум, сине-фиолетовые
		float vn = 1.0 - abs(vnoise(v_hp.xy * 160.0 + 2.0) * 2.0 - 1.0);
		vn = smoothstep(0.86, 0.97, vn) * (0.5 + 0.5 * vnoise(v_hp.xy * 40.0));
		sk = mix(sk, sk * vec3(0.45, 0.42, 0.75), vn * 0.75);
		// трещины: тонкая сетка на лбу и щеках
		float cr = crack(v_hp.xy * 95.0 + vec2(3.7, 1.3));
		float crm = (1.0 - smoothstep(0.02, 0.06, cr)) * smoothstep(0.3, 0.6, vnoise(v_hp.xy * 30.0));
		sk = mix(sk, sk * 0.35, crm * 0.8);
		// синие губы
		vec2 lm = vec2(v_hp.x / 0.022, (v_hp.y - mouth_at.y) / 0.008);
		float lips = (1.0 - smoothstep(0.7, 1.0, length(lm))) * smoothstep(0.06, 0.085, v_hp.z);
		sk = mix(sk, vec3(0.3, 0.3, 0.4) * (dot(sk, vec3(0.33)) * 1.4 + 0.05), lips * 0.75);
		// впавшие тёмные глазницы
		float ds = length(vec2(abs(v_hp.x) - eye_at.x, (v_hp.y - eye_at.y) * 1.25));
		float sock = 1.0 - smoothstep(eye_r * 1.0, eye_r * 3.2, ds);
		sk = mix(sk, sk * vec3(0.16, 0.12, 0.18), sock * 0.95);
		// мутный белый глаз: белёсое бельмо, едва заметная серая радужка, точка зрачка
		float de = length(vec2(abs(v_hp.x) - eye_at.x, (v_hp.y - eye_at.y) * 1.7));      // миндалина: веки полуприкрыты
		eyem = 1.0 - smoothstep(eye_r * 0.8, eye_r, de);
		vec3 ey = vec3(0.3, 0.32, 0.32);
		ey = mix(ey, vec3(0.24, 0.26, 0.28), 1.0 - smoothstep(eye_r * 0.42, eye_r * 0.55, de));
		ey = mix(ey, vec3(0.08, 0.08, 0.09), 1.0 - smoothstep(eye_r * 0.08, eye_r * 0.15, de));
		ey *= 0.8 + 0.2 * vnoise(v_hp.xy * 900.0);                   // муть
		ey = mix(ey, ey * vec3(1.0, 0.75, 0.75), smoothstep(0.6, 0.95, de / eye_r) * 0.6);   // красные жилки по краю
		sk = mix(sk, ey, eyem);
		col = mix(col, sk, facem);
	}
	ALBEDO = col;
	SPECULAR = mix(0.5, 0.65, clamp(hair + red, 0.0, 1.0));
	SPECULAR = mix(SPECULAR, 0.3, hair * (1.0 - facem) * face_fx);     // мокрые, но не пластиковые
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
	rough = mix(rough, 0.3, eyem * facem);                 // глаз мокрый, блестит
	ROUGHNESS = rough;
	// тонкая ткань и кожа светятся насквозь, когда свет сзади
	BACKLIGHT = vec3(0.55, 0.42, 0.36) * (cloth * 0.5 + skin * 0.35);
	// холодный ореол по краю силуэта — видна в темноте, хоть и не освещена
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.45, 0.55, 0.7) * fr * rim * (1.0 - hair * 0.7);
	// раскрытый рот: растянутая полоса между губами — тёмная глотка
	float gap = smoothstep(0.08, 0.3, v_jaw) * smoothstep(0.98, 0.7, v_jaw) * clamp(mouth * 3.0 + grimace * 0.5, 0.0, 1.0) * smoothstep(0.0, 0.5, v_mx);
	// у губ — мокрое тёмно-красное (кровь, дёсны), в глубине — чёрная глотка
	float deep = smoothstep(0.34, 0.06, abs(v_jaw - 0.5)) * smoothstep(0.3, 0.8, v_mx) * mouth_deep;
	vec3 throat = mix(mouth_col, vec3(0.008, 0.002, 0.002), deep);
	// зубы: мелкие, неровные, жёлто-серые — по верхнему и нижнему краю раскрытого рта
	float tband = max(1.0 - smoothstep(0.2, 0.34, v_jaw), smoothstep(0.66, 0.8, v_jaw));
	float tcol = floor(v_hp.x * 220.0);
	float tl = 0.6 + 0.4 * hash(vec2(tcol, 1.7));
	float tooth = smoothstep(0.08, 0.2, abs(fract(v_hp.x * 220.0) - 0.5) * 2.0 * -1.0 + 1.0);
	float tm = gap * tband * tooth * step(abs(v_hp.x), 0.016) * face_fx * smoothstep(0.07, 0.08, v_hp.z) * step(mouth_at.y - 0.03, v_hp.y);
	tm *= step(v_jaw < 0.5 ? (v_jaw - 0.08) / 0.26 : (0.8 - v_jaw) / 0.14 + 0.0, tl);
	throat = mix(throat, vec3(0.42, 0.37, 0.27) * (0.6 + 0.4 * hash(vec2(tcol, 3.1))), tm);
	ALBEDO = mix(ALBEDO, throat, gap);
	ROUGHNESS = mix(ROUGHNESS, 0.18, gap);
	SPECULAR = mix(SPECULAR, 0.7, gap * (1.0 - deep));
	EMISSION *= 1.0 - gap;
	if (debug >= 4) ALBEDO = mix(ALBEDO, vec3(1.0, 0.0, 0.0), v_jaw);
	if (debug == 1) ALBEDO = masks.rgb + vec3(masks.a, masks.a, 0.0);
	if (debug == 2) ALBEDO = vec3(hair, skin, red);
	if (debug == 3 && hair > 0.5) discard;
}
