shader_type spatial;
// Экран старого кинескопа: выпуклое стекло с бликами, а картинка светится изнутри
// (полосы развёртки, «снег», бегущая полоса, тёмные скруглённые углы).

uniform vec4 tint : source_color = vec4(0.02, 0.02, 0.025, 1.0);
uniform float noise_amt = 0.0;          // 0 — чистая картинка, 1 — один «снег»
uniform sampler2D img : source_color, filter_linear;
uniform float has_img = 0.0;
uniform float bulge = 0.012;            // насколько стекло выпирает в центре (м)
uniform float glow = 0.85;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vec2 c = UV - 0.5;
	VERTEX.z += bulge * (1.0 - 2.4 * dot(c, c));
}

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	// бочкообразное искажение картинки, как у кинескопа
	vec2 cuv = 0.5 + c * (1.0 + 0.12 * dot(c, c));
	// скруглённые углы и затемнение к краям
	vec2 q = abs(c) * 2.0;
	float corner = 1.0 - smoothstep(0.82, 1.0, length(max(q - vec2(0.72), 0.0)) / 0.28);
	float vig = clamp(1.0 - 0.55 * pow(length(c * vec2(1.1, 1.3)), 2.2) * 2.2, 0.0, 1.0);

	vec3 pic = tint.rgb;
	// мягкий градиент передачи, чтобы цвет не был плоской заливкой
	// размытые пятна «передачи», которые медленно плывут — будто смотришь сквозь помехи
	float blob = vnoise(cuv * 3.0 + vec2(TIME * 0.15, TIME * 0.05)) * 0.6 + vnoise(cuv * 7.0 - TIME * 0.2) * 0.4;
	pic *= 0.6 + 0.3 * (1.0 - cuv.y) + 0.55 * blob;
	if (has_img > 0.5) {
		pic = texture(img, cuv).rgb * 1.3;   // скример: лицо поверх любой передачи
	}
	float t = floor(TIME * 24.0);
	float n = hash(floor(cuv * vec2(220.0, 170.0)) + t);
	float lum = max(max(tint.r, tint.g), tint.b);
	pic = mix(pic, vec3(n) * (0.4 + lum), noise_amt);
	pic += (n - 0.5) * 0.06 * lum;                                // лёгкое зерно всегда
	pic *= 0.86 + 0.14 * sin(cuv.y * 520.0);                        // строки развёртки
	pic *= 0.92 + 0.08 * smoothstep(0.0, 0.08, abs(fract(cuv.y * 0.6 - TIME * 0.18) - 0.5)); // бегущая полоса
	pic *= vig * corner;

	// само стекло: тёмное, гладкое, ловит блики фонарика
	ALBEDO = vec3(0.015, 0.017, 0.02);
	ROUGHNESS = 0.3;
	SPECULAR = 0.35;
	METALLIC = 0.0;
	EMISSION = pic * glow;
}
