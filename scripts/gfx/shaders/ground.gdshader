shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Boden: Wuestensand, Asphalt mit Markierungen, gepflasterte Flaechen und dynamische Brandspuren.
// mask.r = Strasse, mask.g = Pflaster/Platz, mask.b = weisse Markierung, mask.a = gelbe Markierung
// scorch.r = Brandspuren / Krater (dynamisch)

uniform sampler2D mask : filter_linear, repeat_disable;
uniform sampler2D scorch : filter_linear, repeat_disable;
uniform float world_half = 100.0;
uniform vec4 sand_a : source_color = vec4(0.78, 0.66, 0.46, 1.0);
uniform vec4 sand_b : source_color = vec4(0.68, 0.55, 0.37, 1.0);
uniform vec4 asphalt_col : source_color = vec4(0.2, 0.2, 0.21, 1.0);
uniform vec4 paved_col : source_color = vec4(0.72, 0.64, 0.5, 1.0);

varying vec3 wpos;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
	           mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + 17.3;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = wpos.xz;
	vec2 uv = (w + vec2(world_half)) / (2.0 * world_half);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec4 m = texture(mask, clamp(uv, 0.0, 1.0)) * inside;
	float sc = texture(scorch, clamp(uv, 0.0, 1.0)).r * inside;

	// ---- Sand ----
	float n1 = fbm(w * 0.045);
	float n2 = fbm(w * 0.35 + 3.0);
	float grain = hash21(floor(w * 14.0));
	vec3 sand = mix(sand_a.rgb, sand_b.rgb, smoothstep(0.3, 0.7, n1));
	sand *= 0.9 + 0.18 * n2 + 0.05 * grain;
	// Duenen-Rippel
	float ripple = sin(w.x * 0.9 + w.y * 0.35 + n1 * 12.0) * 0.5 + 0.5;
	sand *= 0.97 + 0.05 * ripple;
	// Steinchen / Buesche
	float pebbles = step(0.985, hash21(floor(w * 3.0)));
	sand = mix(sand, vec3(0.45, 0.4, 0.33), pebbles * 0.6);

	// ---- Asphalt ----
	float an = fbm(w * 0.9);
	vec3 asph = asphalt_col.rgb * (0.85 + 0.3 * an) * (0.95 + 0.1 * hash21(floor(w * 20.0)));
	// Reifenspuren (laengs der Fahrbahn) und Risse
	float tracks = smoothstep(0.55, 0.9, fbm(vec2(w.x * 0.15, w.y * 2.5)) * fbm(vec2(w.x * 2.5, w.y * 0.15)) * 2.2);
	asph *= 1.0 - 0.15 * tracks;
	float crack = smoothstep(0.02, 0.0, abs(fbm(w * 0.7 + 40.0) - 0.5));
	asph *= 1.0 - 0.5 * crack;
	// Sand weht auf die Strasse
	float edge_sand = smoothstep(0.55, 0.95, fbm(w * 0.5 + 9.0));
	asph = mix(asph, sand * 0.9, edge_sand * 0.35);

	// ---- Pflaster ----
	vec2 pq = w * 1.0;
	float tile = step(0.06, fract(pq.x)) * step(0.06, fract(pq.y));
	vec3 pav = paved_col.rgb * (0.88 + 0.2 * fbm(w * 0.6)) * (0.94 + 0.06 * hash21(floor(pq)));
	pav *= 0.8 + 0.2 * tile;
	pav = mix(pav, sand * 0.95, smoothstep(0.5, 0.9, fbm(w * 0.4 + 70.0)) * 0.4);

	vec3 col = sand;
	float road = smoothstep(0.35, 0.65, m.r);
	float paved = smoothstep(0.35, 0.65, m.g);
	// Kanten leicht ausfransen lassen
	col = mix(col, pav, paved);
	col = mix(col, asph, road);
	// Markierungen
	col = mix(col, vec3(0.82, 0.82, 0.78) * (0.8 + 0.2 * an), m.b * 0.85);
	col = mix(col, vec3(0.9, 0.72, 0.15) * (0.8 + 0.2 * an), m.a * 0.85);
	// Brandspuren
	float s = smoothstep(0.05, 0.9, sc);
	vec3 burnt = vec3(0.04, 0.035, 0.03);
	col = mix(col, burnt, s * 0.85);

	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.8, road);
	SPECULAR = 0.05;
}
