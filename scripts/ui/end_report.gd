class_name EndReport
extends Control
## Auswertung nach der Partie: Verlauf der Empoerung mit Ereignismarken, Ursachen und Wendepunkte.

const C_EDGE := Color(0.85, 0.64, 0.25)
const C_TEXT := Color(0.93, 0.9, 0.82)
const C_DIM := Color(0.62, 0.6, 0.54)

const KIND_COL := {
	"casualties": Color(1.0, 0.3, 0.25), "upload": Color(1.0, 0.62, 0.15), "evidence": Color(0.4, 0.9, 1.0),
	"level": Color(1.0, 0.35, 0.85), "hub": Color(0.45, 1.0, 0.5), "press": Color(0.85, 0.1, 0.1),
	"sensitive": Color(0.85, 0.1, 0.1), "strike": Color(1.0, 0.9, 0.3), "aid": Color(0.4, 0.7, 1.0),
	"corridor": Color(0.4, 0.7, 1.0), "briefing": Color(0.4, 0.7, 1.0), "launch": Color(1.0, 0.55, 0.3),
	"recruit": Color(0.75, 0.45, 1.0), "aid_attacked": Color(0.5, 1.0, 0.6), "hub_found": Color(0.45, 0.8, 0.45), "storm": Color(1.0, 0.45, 0.2),
}
const KIND_NAME := {
	"casualties": "Zivile Opfer", "upload": "Veröffentlichung", "evidence": "Beweise", "level": "Eskalationsstufe",
	"hub": "Tunnelknoten zerstört", "press": "Presse / Klinik / Schule", "strike": "Schlag angefordert", "aid": "Hilfsmaßnahme",
	"launch": "Raketenabschuss", "recruit": "Freiwillige", "aid_attacked": "Hilfe angegriffen", "hub_found": "Knoten entdeckt", "storm": "Häuserkampf",
}
const CAUSE_COL := {
	"strike": Color(1.0, 0.55, 0.2), "collapse": Color(0.9, 0.35, 0.3), "direct": Color(1.0, 0.25, 0.25),
	"ambiguous": Color(0.85, 0.7, 0.3), "press": Color(0.85, 0.25, 0.6), "sensitive": Color(0.7, 0.3, 0.9),
	"check": Color(0.5, 0.7, 0.9), "other": Color(0.6, 0.6, 0.6),
}

var total_time := 1.0
var samples := PackedFloat32Array()
var anger_samples := PackedFloat32Array()
var events: Array = []
var attrib: Dictionary = {}
var peak := 0.0
var _turning: Array = []

func setup(res: Dictionary) -> void:
	total_time = maxf(float(res.time), 10.0)
	samples = Game.outrage_samples.duplicate()
	anger_samples = Game.anger_samples.duplicate()
	events = Game.timeline.duplicate()
	attrib = Game.attrib.duplicate()
	peak = float(res.peak)
	_pick_turning_points()
	queue_redraw()

func _kind_score(e: Dictionary) -> float:
	var w: float = e.get("w", 0.0)
	match e.kind:
		"level": return 200.0
		"sensitive": return 160.0
		"press": return 150.0
		"hub": return 90.0
		"casualties": return 40.0 + w * 8.0
		"upload": return 30.0 + w * 4.0
		"evidence": return 30.0 + w * 3.0
		"aid_attacked": return 95.0
	return 0.0

func _pick_turning_points() -> void:
	var cands: Array = []
	for e in events:
		var sc := _kind_score(e)
		if sc > 0.0:
			cands.append({"e": e, "s": sc})
	cands.sort_custom(func(a, b): return a.s > b.s)
	var picked: Array = []
	for c in cands:
		# nicht mehrere Ereignisse derselben Art direkt hintereinander
		var ok := true
		for p in picked:
			if absf(p.e.t - c.e.t) < 12.0 and p.e.kind == c.e.kind:
				ok = false
				break
		if ok:
			picked.append(c)
		if picked.size() >= 7:
			break
	picked.sort_custom(func(a, b): return a.e.t < b.e.t)
	_turning = picked

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := size.x
	var y := 0.0
	# ---------------------------------------------------------------- Verlauf
	draw_string(font, Vector2(0, y + 13), "VERLAUF DER EMPÖRUNG", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_EDGE)
	y += 20.0
	var gx := 34.0
	var gy := y + 4.0
	var gw := w - gx - 96.0
	var gh := 150.0
	draw_rect(Rect2(gx, gy, gw, gh), Color(0.1, 0.09, 0.08, 0.9))
	draw_rect(Rect2(gx, gy, gw, gh), Color(0.35, 0.3, 0.2, 0.9), false, 1.0)
	# Stufenlinien
	for lv in [[35.0, "Sanktionen", Color(1.0, 0.8, 0.3)], [65.0, "Flugverbot", Color(1.0, 0.5, 0.25)], [100.0, "Intervention", Color(1.0, 0.2, 0.2)]]:
		var ly: float = gy + gh - float(lv[0]) / 100.0 * gh
		draw_dashed_line(Vector2(gx, ly), Vector2(gx + gw, ly), Color(lv[2].r, lv[2].g, lv[2].b, 0.55), 1.0, 5.0)
		draw_string(font, Vector2(gx + gw + 6, ly + 4), lv[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, lv[2])
		draw_string(font, Vector2(gx - 30, ly + 4), "%d%%" % int(lv[0]), HORIZONTAL_ALIGNMENT_RIGHT, 26, 10, C_DIM)
	draw_string(font, Vector2(gx - 30, gy + gh + 4), "0%", HORIZONTAL_ALIGNMENT_RIGHT, 26, 10, C_DIM)
	# Zeitachse
	var n_ticks := 5
	for i in range(n_ticks + 1):
		var tt := total_time * float(i) / n_ticks
		var tx := gx + gw * float(i) / n_ticks
		draw_line(Vector2(tx, gy + gh), Vector2(tx, gy + gh + 4), C_DIM, 1.0)
		draw_string(font, Vector2(tx - 20, gy + gh + 16), U.fmt_time(tt), HORIZONTAL_ALIGNMENT_CENTER, 40, 10, C_DIM)
	# Wut (relativ)
	var amax := 1.0
	for a in anger_samples:
		amax = maxf(amax, a)
	if anger_samples.size() > 2 and amax > 4.0:
		var pa := PackedVector2Array()
		for i in range(anger_samples.size()):
			var tx2 := gx + gw * clampf(float(i) * 2.0 / total_time, 0.0, 1.0)
			pa.append(Vector2(tx2, gy + gh - anger_samples[i] / amax * gh * 0.9))
		draw_polyline(pa, Color(0.9, 0.3, 0.9, 0.55), 1.3)
	# Empoerung: Flaeche + Linie
	if samples.size() > 1:
		var pts := PackedVector2Array()
		pts.append(Vector2(gx, gy + gh))
		for i in range(samples.size()):
			var tx3 := gx + gw * clampf(float(i) * 2.0 / total_time, 0.0, 1.0)
			pts.append(Vector2(tx3, gy + gh - clampf(samples[i], 0.0, 100.0) / 100.0 * gh))
		var area := pts.duplicate()
		area.append(Vector2(pts[pts.size() - 1].x, gy + gh))
		draw_colored_polygon(area, Color(1.0, 0.45, 0.2, 0.22))
		var line := pts.slice(1)
		draw_polyline(line, Color(1.0, 0.62, 0.25), 2.2, true)
	# Ereignismarken
	var used := {}
	for e in events:
		var k: String = e.kind
		if k in ["strike", "launch"] and false:
			continue
		var big := _kind_score(e) >= 60.0
		var tx4 := gx + gw * clampf(float(e.t) / total_time, 0.0, 1.0)
		var ty := gy + gh - clampf(float(e.o), 0.0, 100.0) / 100.0 * gh
		var col: Color = KIND_COL.get(k, Color(0.8, 0.8, 0.8))
		if k == "sensitive":
			k = "press"
		used[k] = col
		var r := 4.5 if big else 2.6
		draw_circle(Vector2(tx4, ty), r + 1.2, Color(0, 0, 0, 0.8))
		draw_circle(Vector2(tx4, ty), r, col)
	# Legende
	var lx := 0.0
	var ly2 := gy + gh + 26.0
	if anger_samples.size() > 2 and amax > 4.0:
		draw_line(Vector2(lx, ly2 - 4), Vector2(lx + 16, ly2 - 4), Color(0.9, 0.3, 0.9, 0.7), 2.0)
		draw_string(font, Vector2(lx + 20, ly2), "Wut in den Vierteln", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM)
		lx += 140.0
	for k in used.keys():
		draw_circle(Vector2(lx + 4, ly2 - 4), 4.0, used[k])
		var nm: String = KIND_NAME.get(k, k)
		draw_string(font, Vector2(lx + 12, ly2), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_DIM)
		lx += 26.0 + nm.length() * 6.4
		if lx > w - 140.0:
			lx = 0.0
			ly2 += 15.0
	y = ly2 + 18.0
	# ---------------------------------------------------------------- Ursachen
	draw_string(font, Vector2(0, y + 13), "WOHER KAM DIE EMPÖRUNG?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_EDGE)
	y += 22.0
	var total := 0.0
	for k in attrib.keys():
		total += float(attrib[k])
	if total < 1.0:
		draw_string(font, Vector2(0, y + 12), "Es ist keine nennenswerte Empörung entstanden.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_DIM)
		y += 22.0
	else:
		var keys := attrib.keys()
		keys.sort_custom(func(a, b): return attrib[a] > attrib[b])
		var shown := 0
		for k in keys:
			var v: float = attrib[k]
			if v < total * 0.02 or shown >= 6:
				continue
			var frac := v / total
			var bar_w := w - 300.0
			draw_string(font, Vector2(0, y + 11), Game.CAUSE_LABELS.get(k, k), HORIZONTAL_ALIGNMENT_LEFT, 232, 12, C_TEXT)
			draw_rect(Rect2(236, y + 1, bar_w, 11), Color(0.15, 0.14, 0.12))
			draw_rect(Rect2(236, y + 1, bar_w * frac, 11), CAUSE_COL.get(k, Color(0.6, 0.6, 0.6)))
			draw_string(font, Vector2(236 + bar_w + 6, y + 11), "%d%%" % int(round(frac * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_TEXT)
			y += 17.0
			shown += 1
	y += 12.0
	# ---------------------------------------------------------------- Wendepunkte
	draw_string(font, Vector2(0, y + 13), "WENDEPUNKTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, C_EDGE)
	y += 22.0
	if _turning.is_empty():
		draw_string(font, Vector2(0, y + 12), "Keine einschneidenden Ereignisse.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_DIM)
	for tp in _turning:
		var e2: Dictionary = tp.e
		var col2: Color = KIND_COL.get(e2.kind, Color(0.8, 0.8, 0.8))
		draw_circle(Vector2(5, y + 7), 3.5, col2)
		draw_string(font, Vector2(14, y + 11), U.fmt_time(e2.t), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_DIM)
		draw_string(font, Vector2(58, y + 11), String(e2.text), HORIZONTAL_ALIGNMENT_LEFT, w - 120.0, 12, C_TEXT)
		draw_string(font, Vector2(w - 56, y + 11), "%d%%" % int(round(float(e2.o))), HORIZONTAL_ALIGNMENT_RIGHT, 56, 12, Color(1.0, 0.7, 0.4))
		y += 16.0
