shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Prozedurale Fassade im nahoestlichen Stil: Putz, Fenster, Fensterlaeden, Balkone, Klimageraete,
// Ladenzone im Erdgeschoss, Flachdach mit Teerflecken. Alles in Weltkoordinaten -> keine UVs noetig.

uniform vec4 wall_color : source_color = vec4(0.82, 0.72, 0.58, 1.0);
uniform vec4 trim_color : source_color = vec4(0.92, 0.87, 0.77, 1.0);
uniform vec4 accent_color : source_color = vec4(0.18, 0.42, 0.5, 1.0);
uniform vec4 awning_color : source_color = vec4(0.75, 0.2, 0.15, 1.0);
uniform float floor_h = 3.4;
uniform float cell_w = 3.0;
uniform float building_h = 10.0;
uniform vec3 box_size = vec3(10.0, 10.0, 10.0);
uniform float seed = 0.0;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float shop = 0.0;          // 1 = Ladenzone im EG
uniform float win_density = 0.85;
uniform float emissive_win = 0.0;  // 0..1 beleuchtete Fenster (Abend)
uniform float flat_style = 0.0;    // 1 = ohne Fenster (Mauer / Lagerhalle)
uniform float cross_sign = 0.0;    // 1 = Kreuz auf dem Dach (Klinik)

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 lpos;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v;
}
float rect(vec2 p, vec2 lo, vec2 hi) {
	vec2 s = step(lo, p) * step(p, hi);
	return s.x * s.y;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	lpos = VERTEX;
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 col = wall_color.rgb;
	float rough = 0.92;
	float spec = 0.08;
	vec3 emis = vec3(0.0);
	float v = wpos.y;

	if (n.y > 0.75) {
		// ---------- DACH ----------
		vec2 q = wpos.xz;
		float tar = fbm(q * 0.35 + seed);
		vec3 roof = mix(vec3(0.55, 0.5, 0.43), vec3(0.4, 0.37, 0.33), tar);
		roof *= 0.9 + 0.2 * vnoise(q * 3.0);
		// Rand (Attika)
		vec2 hs = box_size.xz * 0.5;
		float d = min(hs.x - abs(lpos.x), hs.y - abs(lpos.z));
		float edge = smoothstep(0.55, 0.35, d);
		roof = mix(roof, trim_color.rgb * 0.95, edge);
		// Teerbahnen
		float strip = step(0.5, fract(q.x * 0.35 + seed * 3.0)) * smoothstep(0.0, 0.04, abs(fract(q.x * 0.35 + seed * 3.0) - 0.5));
		roof = mix(roof, roof * 0.82, strip * 0.5);
		if (cross_sign > 0.5) {
			vec2 c = lpos.xz;
			float cr = max(rect(c, vec2(-0.8, -3.0), vec2(0.8, 3.0)), rect(c, vec2(-3.0, -0.8), vec2(3.0, 0.8)));
			roof = mix(roof, vec3(0.85, 0.1, 0.1), cr);
		}
		col = roof;
		rough = 0.95;
	} else if (n.y < -0.5) {
		col = wall_color.rgb * 0.5;
	} else {
		// ---------- WAND ----------
		float dim = (abs(n.x) > abs(n.z)) ? box_size.z : box_size.x;
		float lu = (abs(n.x) > abs(n.z)) ? lpos.z : lpos.x;
		float ncell = max(1.0, floor(dim / cell_w + 0.5));
		float cw = dim / ncell;
		float u = lu + dim * 0.5;
		float side = (abs(n.x) > abs(n.z)) ? 1.0 : 0.0;
		float sgn = (abs(n.x) > abs(n.z)) ? sign(n.x) : sign(n.z);
		float faceid = side * 2.0 + (sgn > 0.0 ? 1.0 : 0.0);
		// Putz mit Flecken
		float pl = fbm(vec2(u, v) * 0.45 + faceid * 7.0 + seed * 13.0);
		float fine = vnoise(vec2(u, v) * 6.0);
		col = wall_color.rgb * (0.9 + 0.16 * pl + 0.05 * fine);
		// abgeplatzter Putz (Ziegel sichtbar)
		float brick_mask = smoothstep(0.64, 0.72, fbm(vec2(u, v) * 0.9 + seed * 5.0 + faceid * 3.0));
		vec2 bq = vec2(u * 2.2 + floor(v * 4.0) * 0.5, v * 4.0);
		vec3 brick = mix(vec3(0.55, 0.32, 0.22), vec3(0.65, 0.42, 0.3), hash21(floor(bq)));
		brick *= 0.85 + 0.2 * step(0.08, fract(bq.x)) * step(0.1, fract(bq.y));
		col = mix(col, brick, brick_mask * 0.85);

		float top_limit = building_h - 0.9;
		float nfl = floor(building_h / floor_h);

		if (flat_style < 0.5) {
			vec2 cell = vec2(u / cw, v / floor_h);
			vec2 id = floor(cell);
			vec2 f = fract(cell);
			float h1 = hash21(id + vec2(seed * 31.0, faceid));
			float h2 = hash21(id + vec2(seed * 17.0 + 5.0, faceid + 9.0));
			float h3 = hash21(id + vec2(seed * 7.0 + 2.0, faceid + 3.0));
			bool upper = id.y >= 1.0 || shop < 0.5;
			bool in_range = v > 0.1 && v < top_limit - 0.3 && id.y < nfl;
			if (in_range) {
				// Fenster-Rechteck
				vec2 lo = vec2(0.27, 0.32);
				vec2 hi = vec2(0.73, 0.84);
				float has_win = step(h1, win_density);
				if (id.y < 0.5 && shop > 0.5) {
					// Ladenzone: breite Auslage oder Tuer
					float door = step(0.55, h2);
					lo = vec2(0.12, 0.0);
					hi = vec2(0.88, door > 0.5 ? 0.78 : 0.62);
					has_win = 1.0;
				} else if (id.y < 0.5) {
					// Erdgeschoss: kleinere, hoehere Fenster / Tueren
					lo = vec2(0.3, 0.22);
					hi = vec2(0.7, 0.7);
					if (h2 > 0.82) { lo = vec2(0.3, 0.0); hi = vec2(0.7, 0.72); }
				}
				float in_win = rect(f, lo, hi) * has_win;
				float frame = in_win * (1.0 - rect(f, lo + vec2(0.035, 0.03), hi - vec2(0.035, 0.03)));
				float glass = in_win - frame;
				// Fensterbank + Sturz
				float sill = rect(f, vec2(lo.x - 0.05, lo.y - 0.05), vec2(hi.x + 0.05, lo.y)) * has_win;
				float lintel = rect(f, vec2(lo.x - 0.03, hi.y), vec2(hi.x + 0.03, hi.y + 0.05)) * has_win;
				col = mix(col, trim_color.rgb * 0.95, max(sill, lintel) * 0.9);
				// Schatten/Laibung
				col = mix(col, col * 0.55, step(0.5, in_win) * 0.0);
				vec3 glass_col = mix(vec3(0.05, 0.07, 0.09), vec3(0.2, 0.27, 0.32), smoothstep(lo.y, hi.y, f.y) * 0.7 + 0.15 * h3);
				if (h3 > 0.9) {
					glass_col = vec3(0.04, 0.045, 0.05); // fehlende Scheibe / dunkel
				}
				// Fensterladen
				float shutter = step(0.72, h2) * step(h2, 0.95);
				if (shutter > 0.5 && id.y > 0.5) {
					float slats = 0.8 + 0.2 * step(0.5, fract(f.y * 14.0));
					glass_col = accent_color.rgb * slats * (0.7 + 0.5 * hash11(id.x + id.y * 3.0));
				}
				// Beleuchtete Fenster (Abend)
				if (emissive_win > 0.01 && h1 < emissive_win * 0.5 && shutter < 0.5) {
					emis += vec3(1.0, 0.75, 0.4) * 0.9 * glass;
					glass_col = mix(glass_col, vec3(0.9, 0.7, 0.4), 0.8);
				}
				col = mix(col, glass_col, glass);
				col = mix(col, trim_color.rgb * 0.8, frame * 0.85);
				if (glass > 0.5) {
					rough = 0.15;
					spec = 0.7;
				}
				// Klimaanlage
				if (h2 > 0.88 && id.y > 0.5) {
					float ac = rect(f, vec2(0.76, 0.5), vec2(0.97, 0.7));
					col = mix(col, vec3(0.78, 0.78, 0.75) * (0.8 + 0.2 * step(0.5, fract(f.x * 30.0))), ac);
				}
				// Balkon
				if (upper && id.y > 0.5 && h3 > 0.78 && has_win > 0.5) {
					float slab = rect(f, vec2(0.08, 0.2), vec2(0.92, 0.28));
					float rail = rect(f, vec2(0.08, 0.28), vec2(0.92, 0.5)) * step(0.5, fract(f.x * 14.0 + 0.25)) * 0.75;
					col = mix(col, trim_color.rgb * 0.7, slab);
					col = mix(col, vec3(0.1, 0.1, 0.1), rail);
				}
				// Markise im EG
				if (id.y < 0.5 && shop > 0.5) {
					float aw = rect(f, vec2(0.05, 0.78), vec2(0.95, 0.98));
					float stripe = step(0.5, fract(f.x * 5.0 + h1));
					vec3 acol = mix(awning_color.rgb, awning_color.rgb * 0.45 + vec3(0.4), stripe);
					col = mix(col, acol, aw);
				}
			}
			// Stockwerkgesims
			float band = smoothstep(0.045, 0.0, abs(f.y - 0.02)) * step(1.0, id.y);
			col = mix(col, trim_color.rgb, band * 0.5);
		}
		// Attika / Dachkante
		float para = smoothstep(top_limit - 0.05, top_limit + 0.05, v);
		col = mix(col, trim_color.rgb * 0.97, para);
		// Sockel + Schmutz
		float dirt = smoothstep(1.6, 0.0, v) * (0.5 + 0.5 * fbm(vec2(u, v) * 1.5));
		col = mix(col, vec3(0.28, 0.24, 0.2), dirt * 0.55);
		// Regenstreifen
		float streak = fbm(vec2(u * 3.0, v * 0.25) + seed * 9.0);
		col *= 0.92 + 0.12 * streak;
		// Schaden: Russ und Einschlaege
		if (damage > 0.02) {
			float soot = smoothstep(0.35, 0.8, fbm(vec2(u, v) * 0.6 + seed * 21.0)) * damage;
			col = mix(col, vec3(0.06, 0.05, 0.045), soot * 0.85);
			vec2 pc = vec2(u, v) * 1.6;
			vec2 pid = floor(pc);
			float pock = step(0.8 - damage * 0.35, hash21(pid + seed * 50.0));
			float pd = length(fract(pc) - 0.5);
			col = mix(col, vec3(0.04, 0.035, 0.03), pock * smoothstep(0.2, 0.08, pd) * step(0.15, damage));
			// grosse Risse
			float crack = smoothstep(0.03, 0.0, abs(fbm(vec2(u * 0.8, v * 0.8) + seed * 4.0) - 0.5)) * step(0.4, damage);
			col = mix(col, vec3(0.05, 0.04, 0.04), crack * 0.8);
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emis;
}
