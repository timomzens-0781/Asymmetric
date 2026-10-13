shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

// Palmwedel: gefiederter Rand per Alpha-Scissor, sanfter Wind.

varying float tip;

void vertex() {
	float phase = MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.21;
	float k = clamp(UV.y, 0.0, 1.0);
	VERTEX.y += sin(TIME * 1.6 + phase) * 0.12 * k;
	VERTEX.x += sin(TIME * 1.1 + phase * 1.3) * 0.1 * k;
	tip = UV.y;
}

void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	// Fiederblaettchen
	float comb = 0.55 + 0.45 * step(0.5, fract(UV.y * 22.0 + UV.x * 1.5));
	float prof = (1.0 - tip * 0.85) * comb;
	if (UV.x > 0.5) { prof = (1.0 - tip * 0.85) * (0.55 + 0.45 * step(0.5, fract(UV.y * 22.0 - UV.x * 1.5))); }
	// Mittelrippe immer sichtbar
	if (across > prof && across > 0.06) {
		discard;
	}
	vec3 c = COLOR.rgb;
	c *= 0.85 + 0.3 * smoothstep(0.0, 1.0, across);
	if (across < 0.07) { c = vec3(0.45, 0.4, 0.2); }
	ALBEDO = c;
	ROUGHNESS = 0.8;
	BACKLIGHT = c * 0.25;
}
