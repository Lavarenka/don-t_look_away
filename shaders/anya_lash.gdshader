shader_type spatial;
render_mode cull_disabled;
// Аня v3: ресницы — полоски с альфа-текстурой волосков (models/spirit3/tex/lashes.png).
#include "res://shaders/anya3.gdshaderinc"
uniform sampler2D lash_tex : hint_default_white, filter_linear_mipmap;

void vertex() {
	a3_h = VERTEX.y;
}

void fragment() {
	if (near_cut > 0.0 && length(VERTEX) < near_cut) discard;
	if (texture(lash_tex, UV).a < 0.3) discard;
	ALBEDO = vec3(0.012) * tint.rgb;
	ROUGHNESS = 0.5;
	SPECULAR = 0.3;
#ifdef GHOSTLY
	ALPHA = clamp(mix(0.8, 0.4, ghost) * smoothstep(0.0, 0.5, a3_h), 0.0, 1.0);
	ALPHA_HASH_SCALE = 1.0;
#endif
}
