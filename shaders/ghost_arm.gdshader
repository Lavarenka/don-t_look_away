shader_type spatial;
// Детская рука из-под кровати (bed_grab.gd): бледная, серо-синяя кожа; чем дальше от запястья,
// тем темнее — рука выходит из темноты, а дальше плеча её просто нет.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 wrist = vec3(0.0);       // запястье в мире (обновляется каждый кадр)
uniform vec3 wrist2 = vec3(1e6);      // второе запястье (руки из тайника в спальне Веры), по умолчанию — нет
uniform float fade0 = 0.12;           // до этого расстояния — видно полностью
uniform float fade1 = 0.27;           // дальше — ничего
uniform vec3 tint : source_color = vec3(0.95, 1.0, 1.08);
uniform vec3 hole_at = vec3(1e6);     // руки из тайника (vera_safe.gd): темнеют к проёму — выходят из темноты, ничего не отрезается
uniform float hole_r = 0.0;           // > 0 — режим «из проёма»: радиус, на котором рука выходит из черноты
uniform float dead = 0.0;             // 1 — мёртвая кожа: серая, в синих прожилках, складки темнее, влажный блеск

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float k;
	if (hole_r > 0.0) {
		k = 1.0 - smoothstep(0.03, hole_r, distance(wpos, hole_at));
	} else {
		float d = min(distance(wpos, wrist), distance(wpos, wrist2));
		if (d > fade1) {
			discard;
		}
		k = smoothstep(fade0, fade1, d);
	}
	vec3 c = texture(skin, UV).rgb;
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(vec3(g), c, 0.18) * tint;
	// грязь и синеватые прожилки — чуть неровный тон
	float n = fract(sin(dot(floor(UV * 180.0), vec2(12.9898, 78.233))) * 43758.5453);
	c *= 0.9 + 0.1 * n;
	if (dead > 0.0) {
		float lum = dot(c, vec3(0.33));
		c = mix(c, vec3(lum) * vec3(0.78, 0.8, 0.76), dead);
		c = mix(c, c * c * 1.8, 0.35 * dead);                       // складки и тени — глубже
		float vein = smoothstep(0.93, 1.0, sin(UV.x * 410.0 + sin(UV.y * 97.0) * 3.0) * sin(UV.y * 260.0 + UV.x * 40.0));
		c = mix(c, vec3(0.16, 0.2, 0.3), vein * 0.45 * dead);
	}
	ALBEDO = c * (1.0 - k) * (1.0 - k);
	ROUGHNESS = mix(0.6, 0.38, dead);
	SPECULAR = 0.35 * (1.0 - k);
}
