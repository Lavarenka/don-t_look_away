shader_type spatial;
// Призрак Веры: мёртвая кожа, седые космы (чуть колышутся), сырые лохмотья (подол шевелится),
// ткань и волосы просвечивают против света, холодный ореол по силуэту. Текстуры — из модели (Meshy).
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D orm_tex : hint_roughness_g, filter_linear_mipmap;      // G — шероховатость
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.8, 0.78, 0.78, 1.0);
uniform float pallor = 0.5;        // мертвенная бледность кожи
uniform float sway = 1.0;          // колыхание волос и подола
uniform float rim = 0.05;          // холодный ореол
uniform float dread = 0.0;         // 0..1 — «нагнетание»: темнеет, ореол ярче (крик, бросок)
varying float v_hair;
varying float v_low;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float hair_of(vec3 c) {
	float mx = max(c.r, max(c.g, c.b)); float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	return smoothstep(0.14, 0.06, sat) * smoothstep(0.35, 0.5, lum);
}

void vertex() {
	vec3 c = textureLod(albedo_tex, UV, 3.0).rgb;
	v_hair = hair_of(c);
	v_low = 1.0 - smoothstep(0.0, 0.45, VERTEX.y);      // подол — у самого пола
	float t = TIME;
	float ph = VERTEX.x * 19.0 + VERTEX.z * 13.0;
	// пряди — медленные волны, сильнее к концам (ниже головы)
	float tip = smoothstep(1.75, 1.2, VERTEX.y);
	VERTEX += vec3(sin(t * 0.8 + ph + VERTEX.y * 7.0), 0.0, cos(t * 0.6 + ph * 1.3)) * 0.01 * v_hair * tip * sway;
	// рваный подол — как будто снизу тянет холодом
	VERTEX += vec3(sin(t * 1.2 + ph), 0.0, cos(t * 1.0 + ph * 0.7)) * 0.012 * v_low * (1.0 - v_hair) * sway;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	float mx = max(c.r, max(c.g, c.b)); float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float hair = hair_of(c);
	float skin = smoothstep(0.12, 0.22, sat) * step(c.g * 1.02, c.r) * smoothstep(0.25, 0.42, lum) * (1.0 - hair);
	float blood = smoothstep(0.45, 0.65, sat) * step(c.g * 1.7, c.r) * (1.0 - hair);
	float cloth = clamp(1.0 - hair - skin - blood, 0.0, 1.0);
	// кожа — серо-синюшная, с трупными пятнами
	float liv = vnoise(UV * 41.0) * 0.6 + vnoise(UV * 113.0) * 0.4;
	vec3 dead = mix(vec3(lum), vec3(0.66, 0.7, 0.76) * lum * 1.15, 0.6);
	dead = mix(dead, dead * vec3(0.6, 0.52, 0.66), smoothstep(0.55, 0.8, liv) * 0.6);
	c = mix(c, dead, skin * pallor);
	// лохмотья — сырые пятна темнее
	float damp = smoothstep(0.45, 0.75, vnoise(UV * 17.0 + 5.3));
	c = mix(c, c * vec3(0.7, 0.68, 0.64), cloth * damp * 0.55);
	// седые космы — чуть желтоватые, грязные
	c = mix(c, c * vec3(0.92, 0.9, 0.82), hair * 0.6);
	c = mix(c, c * vec3(0.6, 0.35, 0.33), blood * 0.4);
	c *= tint.rgb * (1.0 - dread * 0.35);
	ALBEDO = c;
	float r = texture(orm_tex, UV).g;
	r = mix(r, 0.5, hair);                 // волосы сальные, со слабым блеском
	r = mix(r, 0.62, skin);
	r = mix(r, 0.3, blood);
	r = mix(r, min(r, 0.65), cloth * damp);
	ROUGHNESS = r;
	METALLIC = 0.0;
	SPECULAR = mix(0.45, 0.6, hair);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 1.0;
	BACKLIGHT = vec3(0.5, 0.42, 0.36) * (cloth * 0.35 + hair * 0.5 + skin * 0.25);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.45, 0.55, 0.7) * fr * (rim + dread * 0.12);
}
