shader_type spatial;
// Детская рука из-под кровати (bed_grab.gd): бледная, серо-синяя кожа; чем дальше от запястья,
// тем темнее — рука выходит из темноты, а дальше плеча её просто нет.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 wrist = vec3(0.0);       // запястье в мире (обновляется каждый кадр)
uniform float fade0 = 0.12;           // до этого расстояния — видно полностью
uniform float fade1 = 0.27;           // дальше — ничего
uniform vec3 tint : source_color = vec3(0.95, 1.0, 1.08);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = distance(wpos, wrist);
	if (d > fade1) {
		discard;
	}
	vec3 c = texture(skin, UV).rgb;
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(g), c, 0.18) * tint;
	// грязь и синеватые прожилки — чуть неровный тон
	float n = fract(sin(dot(floor(UV * 180.0), vec2(12.9898, 78.233))) * 43758.5453);
	c *= 0.9 + 0.1 * n;
	float k = smoothstep(fade0, fade1, d);
	ALBEDO = c * (1.0 - k) * (1.0 - k);
	ROUGHNESS = 0.6;
	SPECULAR = 0.35 * (1.0 - k);
}
