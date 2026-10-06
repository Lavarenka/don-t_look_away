shader_type canvas_item;
// Эффект «камеры» поверх всей картинки:
// искажение линзы, хроматическая аберрация, холодная цветокоррекция,
// виньетка, плёночное зерно и красная пелена при испуге.
// fx = сила эффекта (0 — почти без эффекта, 1 — полностью).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float red = 0.0;
uniform float fx = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);

	// линза: края кадра слегка «выпуклые»
	float k = 0.10 * fx;
	vec2 duv = c * (1.0 + k * r2) / (1.0 + k * 0.5) + 0.5;

	// хроматическая аберрация: сильнее к краям
	vec2 off = c * (0.004 + 0.022 * r2) * (fx + red * 1.5);
	vec3 col;
	col.r = texture(screen_tex, duv + off).r;
	col.g = texture(screen_tex, duv).g;
	col.b = texture(screen_tex, duv - off).b;

	// холодная цветокоррекция: приглушённые цвета, сине-зелёные тени
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, mix(0.85, 0.55, fx));
	vec3 shadows = vec3(0.0, 0.018, 0.028) * fx;
	col = col * mix(vec3(1.0), vec3(0.9, 1.0, 1.04), fx) + shadows * (1.0 - smoothstep(0.0, 0.35, l));
	col = pow(max(col, vec3(0.0)), vec3(mix(1.0, 1.08, fx)));

	// виньетка
	float d = sqrt(r2);
	col *= smoothstep(0.9 - red * 0.2, 0.22 + 0.08 * (1.0 - fx), d);

	// красная пелена
	col = mix(col, vec3(l * 1.4, 0.0, 0.0), red * 0.5);

	// зерно и редкое «дыхание» яркости, как у старой камеры
	float n = hash(uv * 1000.0 + fract(TIME * 37.0) * 17.0);
	col += (n - 0.5) * (0.04 + 0.05 * fx);
	col *= 1.0 + 0.015 * fx * sin(TIME * 23.0) * step(0.97, hash(vec2(floor(TIME * 8.0), 1.0)));

	// за краями искажённого кадра — чёрное
	float inside = step(0.0, duv.x) * step(duv.x, 1.0) * step(0.0, duv.y) * step(duv.y, 1.0);
	COLOR = vec4(col * inside, 1.0);
}
