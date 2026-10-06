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
uniform int debug = 0;
varying vec4 masks;

void vertex() {
	masks = COLOR;
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
	ALBEDO = c.rgb;
	ROUGHNESS = 0.85;
	if (blood > 0.0) {
		// пятна + вертикальные потёки (растянутый шум), чем больше blood — тем шире
		float n = vnoise(UV * vec2(9.0, 9.0)) * 0.6 + vnoise(UV * vec2(31.0, 31.0)) * 0.4;
		float drip = vnoise(vec2(UV.x * 70.0, UV.y * 4.0));
		float m = smoothstep(0.78 - 0.45 * blood, 0.86 - 0.4 * blood, max(n, drip * 0.95));
		m *= blood;
		m *= smoothstep(0.07, 0.2, dot(c.rgb, vec3(0.3, 0.59, 0.11)));   // по чёрным волосам кровь не видна — не красим их
		ALBEDO = mix(ALBEDO, vec3(0.22, 0.008, 0.006), m * 0.92);
		ROUGHNESS = mix(0.85, 0.3, m);
	}
	if (debug == 1) ALBEDO = masks.rgb + vec3(masks.a, masks.a, 0.0);
}
