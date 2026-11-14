// Аня v3 — общее для её шейдеров: оттенок, кровь, ореол по краю, «призрачность».
uniform vec4 tint : source_color = vec4(1.0);
uniform float blood = 0.0;            // 0..1: кровь проступает (по карте порогов в текстуре)
uniform float rim = 0.06;             // холодный ореол по краю силуэта
uniform float near_cut = 0.0;         // ближе этого (м) к камере — не рисовать
uniform float ghost = 0.5;            // призрачность (только в «призрачной» версии шейдера)
varying float a3_h;                   // высота точки над ступнями (для таяния к полу у призрака)

float a3_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float a3_noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(a3_hash(i), a3_hash(i + vec2(1, 0)), f.x), mix(a3_hash(i + vec2(0, 1)), a3_hash(i + vec2(1, 1)), f.x), f.y);
}
// Сколько крови в этой точке: thr — «очередь» из текстуры (1 — проступает первой, 0 — никогда).
float a3_blood(float thr) {
	return (blood > 0.001 && thr > 0.01) ? smoothstep(-0.03, 0.04, thr + blood - 1.0) : 0.0;
}
// Цвет и блеск крови: густая — тёмная и мокрая, по краям — бурая, подсохшая.
void a3_bleed(float k, float thr, inout vec3 col, inout float rough) {
	float thick = smoothstep(0.0, 0.25, thr + blood - 1.0);
	vec3 bc = mix(vec3(0.115, 0.016, 0.010), vec3(0.050, 0.003, 0.003), thick);
	col = mix(col, bc, k * 0.94);
	rough = mix(rough, mix(0.62, 0.30, thick), k);
}
