class_name OutrageMeter
extends Control
## Die zentrale Leiste des Spiels: Weltoeffentlichkeit / Empoerung mit Eskalationsstufen.

var _t := 0.0
var team := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(560, 50)

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _col_at(v: float) -> Color:
	if v < 35.0:
		return Color(0.35, 0.8, 0.4).lerp(Color(0.95, 0.85, 0.25), v / 35.0)
	elif v < 65.0:
		return Color(0.95, 0.85, 0.25).lerp(Color(0.96, 0.5, 0.15), (v - 35.0) / 30.0)
	return Color(0.96, 0.5, 0.15).lerp(Color(0.9, 0.12, 0.12), (v - 65.0) / 35.0)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := size.x
	var bar := Rect2(0, 18, w, 14)
	var title := "WELTÖFFENTLICHKEIT – EMPÖRUNG" if team == U.TEAM_ADF else "WELTWEITE EMPÖRUNG – DEIN SIEGPUNKT"
	draw_string(font, Vector2(0, 12), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.93, 0.88, 0.76))
	var v := Game.outrage
	# Hintergrund
	draw_rect(bar.grow(2), Color(0.0, 0.0, 0.0, 0.8))
	draw_rect(bar, Color(0.12, 0.12, 0.12))
	# Fuellung (farbverlauf in Segmenten)
	var seg := 4.0
	var x := 0.0
	var fill_w := w * v / 100.0
	while x < fill_w:
		var ww := minf(seg, fill_w - x)
		draw_rect(Rect2(x, bar.position.y, ww, bar.size.y), _col_at(x / w * 100.0))
		x += seg
	# unveroeffentlichtes Videomaterial (potenzielle Empoerung)
	var pot := Game.footage * 1.35
	if pot > 0.2:
		var pw := minf(w * pot / 100.0, w - fill_w)
		var a := 0.35 + 0.25 * sin(_t * 4.0)
		draw_rect(Rect2(fill_w, bar.position.y, pw, bar.size.y), Color(1.0, 0.9, 0.9, a))
		for i in range(int(pw / 6.0)):
			draw_line(Vector2(fill_w + i * 6.0, bar.end.y), Vector2(fill_w + i * 6.0 + 5.0, bar.position.y), Color(1, 1, 1, 0.35), 1.0)
	# Glanz
	draw_rect(Rect2(0, bar.position.y, w, 4), Color(1, 1, 1, 0.12))
	# Stufen
	var marks := [[Data.OUTRAGE_L1, "SANKTIONEN"], [Data.OUTRAGE_L2, "FLUGVERBOT"], [100.0, "INTERVENTION"]]
	for i in range(marks.size()):
		var mv: float = marks[i][0]
		var mx := w * mv / 100.0
		var reached := v >= mv - 0.01
		var c := Color(1.0, 0.35, 0.25) if reached else Color(0.85, 0.82, 0.72, 0.8)
		draw_line(Vector2(mx - 1, bar.position.y - 4), Vector2(mx - 1, bar.end.y + 6), c, 2.0)
		var txt: String = marks[i][1]
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, Vector2(mx - tw - 4 if mv >= 99.0 else mx - tw * 0.5, bar.end.y + 16), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c)
	# Zeiger + Zahl
	var px := clampf(fill_w, 0.0, w)
	draw_colored_polygon(PackedVector2Array([Vector2(px, bar.end.y + 1), Vector2(px - 5, bar.end.y + 8), Vector2(px + 5, bar.end.y + 8)]), Color(1, 1, 1))
	var num := "%d%%" % int(round(v))
	draw_string(font, Vector2(w - 54, 12), num, HORIZONTAL_ALIGNMENT_RIGHT, 54, 14, _col_at(v))
	# Pulsieren bei Stufe >= 1
	if Game.level >= 1:
		var p := 0.5 + 0.5 * sin(_t * (3.0 + Game.level * 2.0))
		draw_rect(bar.grow(2), Color(1.0, 0.2, 0.15, 0.25 * p), false, 2.0)
