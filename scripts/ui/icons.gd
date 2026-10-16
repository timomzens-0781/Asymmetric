class_name Icons
extends RefCounted
## Vektor-Piktogramme fuer HUD-Buttons (rein prozedural gezeichnet).

static func draw(ci: CanvasItem, kind: String, r: Rect2, c: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var o := r.position + (r.size - Vector2(s, s)) * 0.5
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var lw := maxf(s * 0.07, 1.5)
	match kind:
		"inf":
			ci.draw_circle(P.call(0.5, 0.2), s * 0.11, c)
			ci.draw_rect(Rect2(P.call(0.36, 0.34), Vector2(0.28, 0.34) * s), c)
			ci.draw_line(P.call(0.42, 0.68), P.call(0.38, 0.92), c, lw * 1.4)
			ci.draw_line(P.call(0.58, 0.68), P.call(0.62, 0.92), c, lw * 1.4)
			ci.draw_line(P.call(0.6, 0.42), P.call(0.88, 0.3), c, lw)
		"eye":
			ci.draw_arc(P.call(0.5, 0.75), s * 0.42, deg_to_rad(215), deg_to_rad(325), 16, c, lw)
			ci.draw_arc(P.call(0.5, 0.25), s * 0.42, deg_to_rad(35), deg_to_rad(145), 16, c, lw)
			ci.draw_circle(P.call(0.5, 0.5), s * 0.14, c)
		"apc":
			ci.draw_rect(Rect2(P.call(0.1, 0.4), Vector2(0.8, 0.28) * s), c)
			ci.draw_rect(Rect2(P.call(0.3, 0.26), Vector2(0.3, 0.16) * s), c)
			ci.draw_line(P.call(0.6, 0.32), P.call(0.92, 0.32), c, lw)
			for x in [0.22, 0.42, 0.62, 0.8]:
				ci.draw_circle(P.call(x, 0.76), s * 0.07, c)
		"tank":
			ci.draw_rect(Rect2(P.call(0.08, 0.5), Vector2(0.84, 0.22) * s), c)
			ci.draw_rect(Rect2(P.call(0.28, 0.32), Vector2(0.34, 0.2) * s), c)
			ci.draw_line(P.call(0.6, 0.4), P.call(0.97, 0.34), c, lw * 1.3)
			ci.draw_rect(Rect2(P.call(0.1, 0.72), Vector2(0.8, 0.1) * s), c)
		"arty":
			ci.draw_rect(Rect2(P.call(0.1, 0.55), Vector2(0.62, 0.2) * s), c)
			ci.draw_line(P.call(0.4, 0.52), P.call(0.92, 0.16), c, lw * 1.6)
			for x in [0.2, 0.4, 0.6]:
				ci.draw_circle(P.call(x, 0.82), s * 0.07, c)
		"drone":
			ci.draw_line(P.call(0.04, 0.5), P.call(0.96, 0.5), c, lw * 1.2)
			ci.draw_rect(Rect2(P.call(0.4, 0.4), Vector2(0.2, 0.34) * s), c)
			ci.draw_line(P.call(0.4, 0.82), P.call(0.6, 0.82), c, lw)
		"heli":
			ci.draw_line(P.call(0.1, 0.2), P.call(0.9, 0.2), c, lw)
			ci.draw_circle(P.call(0.45, 0.55), s * 0.2, c)
			ci.draw_line(P.call(0.6, 0.5), P.call(0.95, 0.42), c, lw * 1.2)
			ci.draw_line(P.call(0.35, 0.82), P.call(0.65, 0.82), c, lw)
			ci.draw_line(P.call(0.45, 0.2), P.call(0.45, 0.4), c, lw)
		"rpg":
			ci.draw_circle(P.call(0.35, 0.2), s * 0.1, c)
			ci.draw_rect(Rect2(P.call(0.25, 0.32), Vector2(0.22, 0.34) * s), c)
			ci.draw_line(P.call(0.1, 0.42), P.call(0.85, 0.26), c, lw * 1.5)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.85, 0.2), P.call(0.97, 0.26), P.call(0.85, 0.32)]), c)
		"tech":
			ci.draw_rect(Rect2(P.call(0.08, 0.46), Vector2(0.84, 0.2) * s), c)
			ci.draw_rect(Rect2(P.call(0.62, 0.32), Vector2(0.24, 0.16) * s), c)
			ci.draw_line(P.call(0.3, 0.46), P.call(0.18, 0.2), c, lw)
			ci.draw_line(P.call(0.12, 0.2), P.call(0.36, 0.2), c, lw * 1.4)
			ci.draw_circle(P.call(0.24, 0.74), s * 0.09, c)
			ci.draw_circle(P.call(0.74, 0.74), s * 0.09, c)
		"launcher":
			ci.draw_rect(Rect2(P.call(0.08, 0.6), Vector2(0.84, 0.16) * s), c)
			for i in range(3):
				ci.draw_line(P.call(0.2 + i * 0.14, 0.58), P.call(0.55 + i * 0.14, 0.18), c, lw * 1.2)
			ci.draw_circle(P.call(0.26, 0.84), s * 0.07, c)
			ci.draw_circle(P.call(0.72, 0.84), s * 0.07, c)
		"camera":
			ci.draw_rect(Rect2(P.call(0.14, 0.34), Vector2(0.5, 0.36) * s), c)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.64, 0.46), P.call(0.9, 0.3), P.call(0.9, 0.74), P.call(0.64, 0.58)]), c)
			ci.draw_circle(P.call(0.3, 0.24), s * 0.08, c)
			ci.draw_circle(P.call(0.52, 0.24), s * 0.08, c)
		"ied":
			ci.draw_circle(P.call(0.5, 0.58), s * 0.24, c)
			ci.draw_line(P.call(0.5, 0.36), P.call(0.66, 0.16), c, lw)
			ci.draw_circle(P.call(0.7, 0.12), s * 0.06, c)
			for a in [0.0, 1.2, 2.4, 3.6, 4.8, 6.0]:
				ci.draw_line(P.call(0.5 + cos(a) * 0.3, 0.58 + sin(a) * 0.3), P.call(0.5 + cos(a) * 0.4, 0.58 + sin(a) * 0.4), c, lw * 0.8)
		"bomb":
			ci.draw_circle(P.call(0.5, 0.6), s * 0.26, c)
			ci.draw_rect(Rect2(P.call(0.44, 0.16), Vector2(0.12, 0.2) * s), c)
			ci.draw_line(P.call(0.3, 0.3), P.call(0.7, 0.3), c, lw)
			ci.draw_line(P.call(0.2, 0.9), P.call(0.8, 0.9), c, lw)
		"missile":
			ci.draw_rect(Rect2(P.call(0.44, 0.2), Vector2(0.12, 0.5) * s), c)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.44, 0.2), P.call(0.5, 0.06), P.call(0.56, 0.2)]), c)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.44, 0.58), P.call(0.28, 0.82), P.call(0.44, 0.74)]), c)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.56, 0.58), P.call(0.72, 0.82), P.call(0.56, 0.74)]), c)
			ci.draw_line(P.call(0.5, 0.74), P.call(0.5, 0.96), c, lw * 1.6)
		"horn":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.12, 0.4), P.call(0.34, 0.4), P.call(0.7, 0.2), P.call(0.7, 0.8), P.call(0.34, 0.6), P.call(0.12, 0.6)]), c)
			ci.draw_arc(P.call(0.74, 0.5), s * 0.16, -1.0, 1.0, 8, c, lw)
			ci.draw_arc(P.call(0.74, 0.5), s * 0.26, -1.0, 1.0, 8, c, lw)
		"doc":
			ci.draw_rect(Rect2(P.call(0.24, 0.1), Vector2(0.52, 0.8) * s), c, false, lw)
			for y in [0.3, 0.46, 0.62, 0.78]:
				ci.draw_line(P.call(0.34, y), P.call(0.66, y), c, lw * 0.8)
		"upload":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.1), P.call(0.78, 0.46), P.call(0.58, 0.46), P.call(0.58, 0.72), P.call(0.42, 0.72), P.call(0.42, 0.46), P.call(0.22, 0.46)]), c)
			ci.draw_line(P.call(0.2, 0.9), P.call(0.8, 0.9), c, lw * 1.2)
		"coin":
			ci.draw_circle(P.call(0.5, 0.5), s * 0.38, c)
			ci.draw_circle(P.call(0.5, 0.5), s * 0.28, Color(0, 0, 0, 0.55))
			ci.draw_line(P.call(0.5, 0.3), P.call(0.5, 0.7), c, lw * 1.2)
			ci.draw_line(P.call(0.4, 0.4), P.call(0.6, 0.4), c, lw)
			ci.draw_line(P.call(0.4, 0.6), P.call(0.6, 0.6), c, lw)
		"pause":
			ci.draw_rect(Rect2(P.call(0.26, 0.2), Vector2(0.17, 0.6) * s), c)
			ci.draw_rect(Rect2(P.call(0.57, 0.2), Vector2(0.17, 0.6) * s), c)
		"stop":
			ci.draw_rect(Rect2(P.call(0.22, 0.22), Vector2(0.56, 0.56) * s), c)
		"hold":
			ci.draw_arc(P.call(0.5, 0.5), s * 0.36, 0, TAU, 20, c, lw * 1.2)
			ci.draw_line(P.call(0.26, 0.74), P.call(0.74, 0.26), c, lw * 1.2)
		"attack_move":
			ci.draw_line(P.call(0.12, 0.8), P.call(0.8, 0.12), c, lw * 1.4)
			ci.draw_line(P.call(0.62, 0.12), P.call(0.8, 0.12), c, lw * 1.4)
			ci.draw_line(P.call(0.8, 0.12), P.call(0.8, 0.3), c, lw * 1.4)
			ci.draw_line(P.call(0.14, 0.34), P.call(0.34, 0.14), c, lw)
		"conceal":
			ci.draw_arc(P.call(0.5, 0.45), s * 0.32, PI * 0.9, PI * 2.1, 14, c, lw * 1.2)
			ci.draw_rect(Rect2(P.call(0.2, 0.46), Vector2(0.6, 0.3) * s), c)
			ci.draw_circle(P.call(0.38, 0.6), s * 0.05, Color(0, 0, 0, 0.7))
			ci.draw_circle(P.call(0.62, 0.6), s * 0.05, Color(0, 0, 0, 0.7))
		"garrison":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.1, 0.48), P.call(0.5, 0.14), P.call(0.9, 0.48)]), c)
			ci.draw_rect(Rect2(P.call(0.2, 0.46), Vector2(0.6, 0.4) * s), c)
			ci.draw_rect(Rect2(P.call(0.44, 0.62), Vector2(0.14, 0.24) * s), Color(0, 0, 0, 0.6))
		"exit":
			ci.draw_rect(Rect2(P.call(0.12, 0.18), Vector2(0.4, 0.64) * s), c, false, lw)
			ci.draw_line(P.call(0.4, 0.5), P.call(0.9, 0.5), c, lw * 1.3)
			ci.draw_line(P.call(0.74, 0.34), P.call(0.9, 0.5), c, lw * 1.3)
			ci.draw_line(P.call(0.74, 0.66), P.call(0.9, 0.5), c, lw * 1.3)
		"fire_ground":
			ci.draw_arc(P.call(0.5, 0.5), s * 0.3, 0, TAU, 20, c, lw)
			ci.draw_line(P.call(0.5, 0.08), P.call(0.5, 0.34), c, lw)
			ci.draw_line(P.call(0.5, 0.66), P.call(0.5, 0.92), c, lw)
			ci.draw_line(P.call(0.08, 0.5), P.call(0.34, 0.5), c, lw)
			ci.draw_line(P.call(0.66, 0.5), P.call(0.92, 0.5), c, lw)
		"roe":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.08), P.call(0.86, 0.22), P.call(0.8, 0.62), P.call(0.5, 0.92), P.call(0.2, 0.62), P.call(0.14, 0.22)]), c)
		"flag":
			ci.draw_line(P.call(0.2, 0.9), P.call(0.2, 0.1), c, lw * 1.4)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.2, 0.12), P.call(0.86, 0.26), P.call(0.2, 0.46)]), c)
		"hub":
			ci.draw_arc(P.call(0.5, 0.62), s * 0.34, PI, TAU, 14, c, lw * 1.4)
			ci.draw_line(P.call(0.16, 0.62), P.call(0.16, 0.88), c, lw * 1.4)
			ci.draw_line(P.call(0.84, 0.62), P.call(0.84, 0.88), c, lw * 1.4)
			ci.draw_line(P.call(0.5, 0.64), P.call(0.5, 0.96), c, lw)
		"storm":
			ci.draw_rect(Rect2(P.call(0.46, 0.2), Vector2(0.4, 0.66) * s), c, false, lw * 1.2)
			ci.draw_rect(Rect2(P.call(0.62, 0.52), Vector2(0.1, 0.34) * s), c)
			ci.draw_line(P.call(0.08, 0.5), P.call(0.42, 0.5), c, lw * 1.4)
			ci.draw_line(P.call(0.28, 0.36), P.call(0.42, 0.5), c, lw * 1.4)
			ci.draw_line(P.call(0.28, 0.64), P.call(0.42, 0.5), c, lw * 1.4)
		"patrol":
			ci.draw_line(P.call(0.18, 0.7), P.call(0.82, 0.7), c, lw * 1.2)
			ci.draw_line(P.call(0.18, 0.3), P.call(0.82, 0.3), c, lw * 1.2)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.9, 0.3), P.call(0.72, 0.18), P.call(0.72, 0.42)]), c)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.1, 0.7), P.call(0.28, 0.58), P.call(0.28, 0.82)]), c)
			ci.draw_circle(P.call(0.5, 0.5), s * 0.08, c)
		"cover":
			ci.draw_rect(Rect2(P.call(0.12, 0.2), Vector2(0.22, 0.66) * s), c)
			ci.draw_rect(Rect2(P.call(0.4, 0.5), Vector2(0.46, 0.36) * s), c)
			ci.draw_circle(P.call(0.62, 0.38), s * 0.1, c)
		"dig":
			ci.draw_arc(P.call(0.5, 0.72), s * 0.38, PI, TAU, 14, c, lw * 1.4)
			ci.draw_line(P.call(0.1, 0.72), P.call(0.9, 0.72), c, lw * 1.2)
			ci.draw_circle(P.call(0.5, 0.52), s * 0.1, c)
			ci.draw_line(P.call(0.2, 0.9), P.call(0.8, 0.9), c, lw)
		"aid":
			ci.draw_rect(Rect2(P.call(0.08, 0.34), Vector2(0.54, 0.38) * s), c)
			ci.draw_rect(Rect2(P.call(0.64, 0.46), Vector2(0.26, 0.26) * s), c)
			ci.draw_circle(P.call(0.26, 0.78), s * 0.09, c)
			ci.draw_circle(P.call(0.74, 0.78), s * 0.09, c)
			ci.draw_line(P.call(0.35, 0.4), P.call(0.35, 0.66), Color(0, 0, 0, 0.7), lw * 1.2)
			ci.draw_line(P.call(0.22, 0.53), P.call(0.48, 0.53), Color(0, 0, 0, 0.7), lw * 1.2)
		"medic":
			ci.draw_rect(Rect2(P.call(0.38, 0.14), Vector2(0.24, 0.72) * s), c)
			ci.draw_rect(Rect2(P.call(0.14, 0.38), Vector2(0.72, 0.24) * s), c)
		"corridor":
			ci.draw_line(P.call(0.5, 0.5), P.call(0.12, 0.12), c, lw * 1.2)
			ci.draw_line(P.call(0.5, 0.5), P.call(0.88, 0.12), c, lw * 1.2)
			ci.draw_line(P.call(0.5, 0.5), P.call(0.12, 0.88), c, lw * 1.2)
			ci.draw_line(P.call(0.5, 0.5), P.call(0.88, 0.88), c, lw * 1.2)
			ci.draw_circle(P.call(0.5, 0.5), s * 0.12, c)
			ci.draw_arc(P.call(0.5, 0.5), s * 0.36, 0, TAU, 18, c, lw * 0.8)
		"mic":
			ci.draw_rect(Rect2(P.call(0.38, 0.1), Vector2(0.24, 0.42) * s), c)
			ci.draw_arc(P.call(0.5, 0.45), s * 0.26, 0.2, PI - 0.2, 12, c, lw * 1.1)
			ci.draw_line(P.call(0.5, 0.72), P.call(0.5, 0.88), c, lw * 1.2)
			ci.draw_line(P.call(0.34, 0.88), P.call(0.66, 0.88), c, lw * 1.2)
		"tunnel":
			ci.draw_arc(P.call(0.22, 0.6), s * 0.18, PI, TAU, 10, c, lw * 1.3)
			ci.draw_arc(P.call(0.78, 0.6), s * 0.18, PI, TAU, 10, c, lw * 1.3)
			ci.draw_line(P.call(0.04, 0.6), P.call(0.04, 0.86), c, lw * 1.2)
			ci.draw_line(P.call(0.4, 0.6), P.call(0.6, 0.6), c, lw * 0.8)
			ci.draw_line(P.call(0.4, 0.74), P.call(0.6, 0.74), c, lw * 0.8)
			ci.draw_line(P.call(0.96, 0.6), P.call(0.96, 0.86), c, lw * 1.2)
			ci.draw_line(P.call(0.3, 0.3), P.call(0.7, 0.3), c, lw)
			ci.draw_line(P.call(0.6, 0.2), P.call(0.7, 0.3), c, lw)
			ci.draw_line(P.call(0.6, 0.4), P.call(0.7, 0.3), c, lw)
		"shield":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.18, 0.14), P.call(0.82, 0.14), P.call(0.82, 0.5), P.call(0.5, 0.9), P.call(0.18, 0.5)]), c)
			ci.draw_circle(P.call(0.5, 0.38), s * 0.09, Color(0, 0, 0, 0.6))
			ci.draw_rect(Rect2(P.call(0.41, 0.48), Vector2(0.18, 0.22) * s), Color(0, 0, 0, 0.6))
		"stage":
			ci.draw_rect(Rect2(P.call(0.1, 0.3), Vector2(0.56, 0.42) * s), c)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.68, 0.46), P.call(0.92, 0.3), P.call(0.92, 0.72), P.call(0.68, 0.56)]), c)
			ci.draw_circle(P.call(0.38, 0.51), s * 0.1, Color(0, 0, 0, 0.6))
			ci.draw_circle(P.call(0.2, 0.2), s * 0.07, c)
			ci.draw_circle(P.call(0.46, 0.2), s * 0.07, c)
		"jam":
			ci.draw_line(P.call(0.5, 0.9), P.call(0.5, 0.36), c, lw * 1.3)
			ci.draw_circle(P.call(0.5, 0.3), s * 0.07, c)
			ci.draw_arc(P.call(0.5, 0.3), s * 0.2, -0.9, 0.9 + PI, 12, c, lw)
			ci.draw_arc(P.call(0.5, 0.3), s * 0.34, -0.9, 0.9 + PI, 12, c, lw)
			ci.draw_line(P.call(0.14, 0.12), P.call(0.86, 0.88), Color(1.0, 0.3, 0.25), lw * 1.3)
		"smoke":
			ci.draw_circle(P.call(0.3, 0.62), s * 0.2, c)
			ci.draw_circle(P.call(0.52, 0.5), s * 0.26, c)
			ci.draw_circle(P.call(0.72, 0.64), s * 0.18, c)
			ci.draw_circle(P.call(0.42, 0.3), s * 0.14, c)
			ci.draw_rect(Rect2(P.call(0.14, 0.74), Vector2(0.72, 0.12) * s), c)
		"sniper":
			ci.draw_arc(P.call(0.5, 0.5), s * 0.34, 0, TAU, 20, c, lw)
			ci.draw_line(P.call(0.5, 0.06), P.call(0.5, 0.94), c, lw * 0.9)
			ci.draw_line(P.call(0.06, 0.5), P.call(0.94, 0.5), c, lw * 0.9)
			ci.draw_circle(P.call(0.5, 0.5), s * 0.06, c)
		"base":
			ci.draw_rect(Rect2(P.call(0.14, 0.34), Vector2(0.72, 0.5) * s), c)
			ci.draw_line(P.call(0.5, 0.34), P.call(0.5, 0.1), c, lw)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.1), P.call(0.8, 0.18), P.call(0.5, 0.26)]), c)
		_:
			ci.draw_circle(P.call(0.5, 0.5), s * 0.3, c)
