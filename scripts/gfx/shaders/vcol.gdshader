shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Material fuer alle prozedural gebauten Meshes (Fahrzeuge, Einheiten, Props):
// Vertex-Farbe als Basis + Schmutz, Abnutzung, Kantenstaub und feine Variation.

uniform float rough = 0.8;
uniform float metal = 0.05;
uniform float grime = 1.0;

varying vec3 lpos;
varying vec3 wpos;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	lpos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float n1 = vn(lpos.xz * 2.3 + lpos.y * 1.9);
	float n2 = vn(lpos.xz * 9.0 + lpos.y * 8.0 + 3.0);
	float streak = vn(vec2(lpos.x * 6.0 + lpos.z * 5.0, lpos.y * 0.8));
	c *= 0.9 + 0.18 * n1 + 0.07 * n2;
	// Regen-/Oelstreifen
	c *= 1.0 - grime * 0.12 * smoothstep(0.5, 0.9, streak);
	// Staub nahe am Boden
	float dust = smoothstep(1.3, 0.0, wpos.y) * 0.32 * grime;
	c = mix(c, vec3(0.56, 0.48, 0.36), dust * (0.55 + 0.45 * n2));
	// Kratzer / abgeplatzte Farbe
	float chip = smoothstep(0.86, 0.95, vn(lpos.xz * 14.0 + lpos.y * 12.0 + 9.0));
	c = mix(c, c * 0.55 + vec3(0.04), chip * 0.5 * grime);
	ALBEDO = c;
	ROUGHNESS = clamp(rough * (0.92 + 0.2 * n1) + chip * 0.1, 0.05, 1.0);
	METALLIC = metal * (1.0 - dust);
	SPECULAR = 0.35;
}
