shader_type canvas_item;
// Фон инвентаря: мир позади размыт и затемнён, по краям — виньетка,
// за выбранным предметом — тёплое свечение, будто его подсвечивает фонарик.

uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 1.0;     // 0 — инвентарь закрыт, 1 — открыт полностью
uniform float glow = 1.0;       // свечение за предметом (на вкладке записок слабее)

void fragment() {
	vec3 c = textureLod(scr, SCREEN_UV, 4.5 * amount).rgb;
	c *= mix(1.0, 0.26, amount);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = (SCREEN_UV - vec2(0.5, 0.42)) * vec2(aspect, 1.0);
	c += vec3(0.79, 0.70, 0.52) * 0.11 * smoothstep(0.42, 0.0, length(d)) * amount * glow;
	float vig = smoothstep(1.05, 0.3, length((SCREEN_UV - 0.5) * vec2(1.25, 1.45)));
	c *= mix(1.0, vig, amount);
	COLOR = vec4(c, 1.0);
}
