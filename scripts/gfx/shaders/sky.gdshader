shader_type sky;

// Prozeduraler Himmel: Verlauf, Sonnenscheibe mit Hof, wandernde Wolken mit Sonnenlicht-Schattierung.
uniform vec3 top_color : source_color = vec3(0.32, 0.5, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.86, 0.78, 0.64);
uniform vec3 ground_color : source_color = vec3(0.6, 0.52, 0.4);
uniform vec3 sun_color : source_color = vec3(1.0, 0.93, 0.8);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.98, 0.94);
uniform vec3 cloud_dark : source_color = vec3(0.55, 0.6, 0.68);
uniform vec3 sun_dir = vec3(0.4, 0.6, 0.5);      // Richtung ZUR Sonne
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.42;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.02 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 sd = normalize(sun_dir);
	float sun_dot = dot(dir, sd);
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
		// Aufhellung um die Sonne
		col += sun_color * pow(max(sun_dot, 0.0), 6.0) * 0.18;
		col += sun_color * pow(max(sun_dot, 0.0), 80.0) * 0.45;
		// Sonnenscheibe
		col += sun_color * smoothstep(0.9993, 0.9998, sun_dot) * 6.0;
		// Wolken auf einer hohen Ebene
		vec2 uv = dir.xz / (h + 0.18) * 1.1 + vec2(TIME * 0.006, TIME * 0.002);
		float d = fbm(uv * 0.9);
		float thr = 1.0 - cloud_cover;
		float c = smoothstep(thr, thr + 0.22, d);
		float d2 = fbm(uv * 0.9 + sd.xz * 0.06);
		float lit = clamp(0.55 + (d - d2) * 5.0, 0.0, 1.0);
		vec3 ccol = mix(cloud_dark, cloud_light, lit);
		ccol += sun_color * pow(max(sun_dot, 0.0), 10.0) * 0.25 * (1.0 - c * 0.3);
		float fade = smoothstep(0.0, 0.2, h);
		col = mix(col, ccol, c * fade * 0.92);
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 3.0, 0.0, 1.0));
	}
	COLOR = col;
}
