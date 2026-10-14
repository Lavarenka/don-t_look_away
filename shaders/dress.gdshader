shader_type spatial;
// Старое белое платье: слоновая кость, мелкое переплетение нитей (текстура льна, триплан —
// у модели свои выкройки, UV не подходят), пожелтевшие пятна, подол посерел от пыли,
// тонкая ткань просвечивает против света, мягкий «бархатистый» отлив по краю.
render_mode cull_back;
uniform sampler2D weave : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 ivory : source_color = vec3(0.84, 0.82, 0.77);
uniform vec3 yellowed : source_color = vec3(0.78, 0.72, 0.58);
uniform vec3 dust : source_color = vec3(0.46, 0.43, 0.38);
uniform float tile = 0.09;          // размер плитки переплетения, м
varying vec3 wp;
varying vec3 wn;
varying float h;                    // высота над полом, м

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	h = wp.y - NODE_POSITION_WORLD.y;
}

void fragment() {
	vec3 bw = pow(abs(wn), vec3(4.0));
	bw /= bw.x + bw.y + bw.z;
	vec3 t = texture(weave, wp.zy / tile).rgb * bw.x + texture(weave, wp.xz / tile).rgb * bw.y + texture(weave, wp.xy / tile).rgb * bw.z;
	float w = dot(t, vec3(0.333));
	vec3 c = ivory * mix(0.86, 1.08, w);
	// пожелтело пятнами (время, сырость)
	float st = vnoise(wp.xy * 7.0 + wp.z * 3.0) * 0.6 + vnoise(wp.xy * 23.0) * 0.4;
	c = mix(c, yellowed * mix(0.9, 1.05, w), smoothstep(0.6, 0.85, st) * 0.35);
	// подол серый от пыли, выше — светлее
	float hem = 1.0 - smoothstep(0.0, 0.3, h);
	c = mix(c, dust, hem * (0.45 + 0.3 * vnoise(wp.xz * 12.0)));
	// в складках темнее (полость)
	ALBEDO = c;
	ROUGHNESS = 0.88;
	SPECULAR = 0.3;
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO += vec3(0.07, 0.065, 0.06) * fr;               // мягкий отлив ткани по краю
	BACKLIGHT = vec3(0.42, 0.38, 0.32);                   // тонкая ткань просвечивает
}
