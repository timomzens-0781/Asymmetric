class_name InfoPanel
extends Control
## Auswahlinfo: Einzel- oder Mehrfachauswahl, Gebaeude mit Produktionswarteschlange.

signal pick_unit(e: Entity)
signal cancel_queue(s: Structure, idx: int)

var player: PlayerController
var world: World
var _hit_icons: Array = []     # {rect, entity}
var _hit_queue: Array = []     # {rect, structure, idx}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(400, 120)

func _process(_dt: float) -> void:
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		for h in _hit_queue:
			if h.rect.has_point(mb.position):
				cancel_queue.emit(h.structure, h.idx)
				accept_event()
				return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			for h in _hit_icons:
				if h.rect.has_point(mb.position):
					pick_unit.emit(h.entity)
					accept_event()
					return

func _disp_name(e: Entity) -> String:
	return InfoPanel.display_name(e, player.team)

static func display_name(e: Entity, pt: int) -> String:
	if e is Unit:
		var u := e as Unit
		if u.is_civ:
			return "Zivilist"
		if u.team != pt and u.is_disguised():
			return "Zivilist"
		return u.def.get("name", u.kind)
	if e is Structure:
		var s := e as Structure
		if s.kind_class == "base":
			return s.def.get("name", s.kind)
		if s.hub and (pt == U.TEAM_REB or s.revealed):
			return "Tunnelknoten" + (" (entdeckt)" if s.revealed else "")
		match s.kind_class:
			"hospital": return "Klinik"
			"school": return "Schule"
		return "Wohngebäude"
	if e is Mine:
		return "Sprengfalle"
	return e.kind

func _desc(e: Entity) -> String:
	if e is Unit:
		var u := e as Unit
		if u.is_civ or (u.team != player.team and u.is_disguised()):
			return "Unbewaffnet wirkende Person. Ob Zivilist oder getarnter Kämpfer, lässt sich nur durch Beobachtung klären."
		return u.def.get("desc", "")
	if e is Structure:
		var s := e as Structure
		if s.kind_class == "base":
			return s.def.get("desc", "")
		if s.hub and player.team == U.TEAM_REB:
			return "Verdecktes Tunnelnetz unter dem Haus. Produziert Einheiten, bietet Deckung. Wird es entdeckt, ist es verloren."
		if s.kind_class == "hospital":
			return "Zivile Einrichtung – ein Treffer wäre ein PR-Desaster."
		if s.kind_class == "school":
			return "Zivile Einrichtung – ein Treffer wäre ein PR-Desaster."
		return "Zivilgebäude. Bewohner und Nutzung unbekannt."
	return ""

func _draw() -> void:
	_hit_icons.clear()
	_hit_queue.clear()
	if player == null:
		return
	var font := ThemeDB.fallback_font
	var sel: Array = player.selected
	if sel.is_empty():
		_draw_hint(font)
		return
	if sel.size() == 1:
		_draw_single(sel[0], font)
	else:
		_draw_multi(sel, font)

func _draw_hint(font: Font) -> void:
	var lines: Array = []
	if player.team == U.TEAM_ADF:
		lines = [
			["EINSATZZIEL", Color(0.85, 0.64, 0.25), 13],
			["Zerschlage alle Tunnelknoten der Hadar-Front – ohne die Weltöffentlichkeit zu verlieren.", Color(0.9, 0.88, 0.8), 12],
			["Zivilisten und Journalisten sind keine Ziele. Jeder Fehlschlag steigt ins Netz.", Color(0.9, 0.88, 0.8), 12],
			["Linksklick: wählen · Rahmen · Rechtsklick: Befehl · T: Angriffsbewegung · C: Person kontrollieren", Color(0.7, 0.68, 0.6), 11],
			["F1–F10: Unterstützung & Hilfe · Leertaste: letzter Alarm · R: Einsatzregeln · gelbes \"?\" = Verdacht", Color(0.7, 0.68, 0.6), 11],
		]
	else:
		lines = [
			["DEIN ZIEL", Color(0.85, 0.64, 0.25), 13],
			["Du gewinnst nicht durch Panzer, sondern durch Bilder: Treibe die Empörung auf 100%.", Color(0.9, 0.88, 0.8), 12],
			["Halte Medien-Teams am Leben und veröffentliche Videomaterial (Upload).", Color(0.9, 0.88, 0.8), 12],
			["Linksklick: wählen · Rechtsklick auf Haus: Hinterhalt · G: Tarnung · B: Sprengfalle", Color(0.7, 0.68, 0.6), 11],
			["F1: Upload · F2: Spendenaufruf · V: Gebäude verlassen · N: Tunnelreise · Leertaste: letzter Alarm", Color(0.7, 0.68, 0.6), 11],
		]
	var y := 18.0
	for l in lines:
		draw_string(font, Vector2(10, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, l[2], l[1])
		y += 20.0 if l[2] > 11 else 18.0

func _hp_bar(p: Vector2, w: float, f: float, h: float = 8.0) -> void:
	draw_rect(Rect2(p.x - 1, p.y - 1, w + 2, h + 2), Color(0, 0, 0, 0.8))
	var col := Color(0.4, 0.9, 0.4) if f > 0.5 else (Color(0.95, 0.8, 0.2) if f > 0.25 else Color(0.95, 0.3, 0.2))
	draw_rect(Rect2(p.x, p.y, w * clampf(f, 0, 1), h), col)

func _draw_single(e: Entity, font: Font) -> void:
	if not is_instance_valid(e):
		return
	var disguised: bool = e is Unit and e.team != player.team and (e as Unit).is_disguised()
	var tcol := U.team_color(e.team)
	var nm := _disp_name(e)
	if e.team == U.TEAM_CIV or (e is Unit and (e as Unit).is_civ) or disguised:
		tcol = Color(0.85, 0.85, 0.8)
	draw_string(font, Vector2(10, 18), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, tcol)
	var fac := ""
	if e.team == U.TEAM_ADF:
		fac = "Aurelische Streitkräfte"
	elif e.team == U.TEAM_REB and not disguised and not (e is Structure and not (e as Structure).revealed and player.team == U.TEAM_ADF):
		fac = "Hadar-Front"
	elif e.team == U.TEAM_CIV or e is Structure:
		fac = "Zivilbevölkerung"
	draw_string(font, Vector2(10, 32), fac, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.68, 0.6))
	if e.team == player.team or e.seen_by(player.team):
		_hp_bar(Vector2(10, 40), 200.0, e.hp / e.max_hp)
		draw_string(font, Vector2(218, 48), "%d / %d" % [int(e.hp), int(e.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.88, 0.8))
	var ik := "inf"
	if e is Unit and not (e as Unit).is_civ:
		ik = (e as Unit).def.get("icon", "inf")
	elif e is Structure:
		ik = "base" if (e as Structure).kind_class == "base" else ("hub" if (e as Structure).hub and player.team == U.TEAM_REB else "garrison")
	if not disguised:
		draw_rect(Rect2(size.x - 62, 6, 54, 54), Color(0.1, 0.09, 0.08))
		draw_rect(Rect2(size.x - 62, 6, 54, 54), tcol, false, 2.0)
		Icons.draw(self, ik, Rect2(size.x - 56, 12, 42, 42), tcol)
	var y := 64.0
	var has_queue: bool = e is Structure and e.team == player.team and not (e as Structure).produces.is_empty()
	var d := _desc(e)
	if d != "" and not has_queue:
		var lines := _wrap(d, font, 11, size.x - 80)
		for i in range(mini(lines.size(), 2)):
			draw_string(font, Vector2(10, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.82, 0.8, 0.72))
			y += 14.0
	if e is Unit:
		var u := e as Unit
		if not u.weapons.is_empty() and u.team == player.team:
			var w: Dictionary = u.weapons[0]
			var st := "Reichweite %dm · Schaden %d · %s" % [int(w.range), int(w.damage), {"bullet": "Handfeuerwaffe", "ap": "Panzerabwehr", "he": "Flächenwirkung", "missile": "Lenkwaffe"}.get(w.type, "")]
			draw_string(font, Vector2(10, y), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.8, 1.0))
			y += 14.0
		if u.team == player.team and u.can_conceal:
			var s2 := "Getarnt" if u.concealed else ("ENTTARNT (%ds)" % ceil(u.exposed_t) if u.exposed_t > 0.0 else "Offen")
			draw_string(font, Vector2(10, y), "Tarnung: " + s2 + (" · automatisch" if u.conceal_pref else " · aus"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.95, 0.95) if u.concealed else Color(1.0, 0.6, 0.4))
		elif player.team == U.TEAM_ADF and u.team == U.TEAM_REB and u.concealed and u.exposed_t <= 0.0 and u.suspicion > 5.0:
			draw_string(font, Vector2(10, y), "Auffälligkeit: %d%% – beobachten oder Aufklärer heranführen" % int(u.suspicion), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.9, 0.4))
		elif u.press:
			draw_string(font, Vector2(10, y), "Presse: Beschuss löst größte Empörung aus!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.5, 0.4))
	elif e is Structure:
		var s := e as Structure
		if s.kind_class != "base":
			draw_string(font, Vector2(10, y), _occupancy_text(s), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.9, 0.5))
			if s.team == player.team and s.hub:
				draw_string(font, Vector2(260, y), "Besatzung: %d/%d" % [s.garrisoned.size(), s.garrison_cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 1.0, 0.6))
		var gar: Array = s.garrison_of(player.team)
		if not gar.is_empty():
			var gc := 22.0 if has_queue else 30.0
			var gy := 68.0 if has_queue else size.y - 38.0
			var step := gc + 4.0
			var nshow := mini(gar.size(), 14)
			draw_string(font, Vector2(10 + nshow * step + 6.0, gy + gc * 0.5 + 4.0), "◄ Besatzung: Klick wählt, Rechtsklick (Haus gewählt) führt heraus", HORIZONTAL_ALIGNMENT_LEFT, maxf(size.x - 90.0 - nshow * step, 60.0), 10, Color(0.5, 1.0, 0.6))
			for i in range(nshow):
				var gu: Entity = gar[i]
				if not is_instance_valid(gu):
					continue
				var gr := Rect2(Vector2(10 + i * step, gy), Vector2(gc, gc))
				draw_rect(gr, Color(0.1, 0.09, 0.08))
				draw_rect(gr, U.team_color(gu.team), false, 1.5)
				Icons.draw(self, (gu as Unit).def.get("icon", "inf"), gr.grow(-4), Color(0.93, 0.88, 0.76))
				_hp_bar(Vector2(gr.position.x, gr.end.y + 1), gc, gu.hp / gu.max_hp, 3.0)
				_hit_icons.append({"rect": gr, "entity": gu})
		if has_queue:
			_draw_queue(s, Vector2(10, size.y - 40), font)

func _occupancy_text(s: Structure) -> String:
	if s.warned:
		return "Evakuierung angeordnet"
	# Schaetzung nur mit Sichtkontakt (Einheit in der Naehe)
	var seen := false
	for o in world.dyn.query(s.position, 34.0):
		if o is Unit and o.alive and o.team == player.team and not (o as Unit).is_civ and U.dist2d(o.position, s.position) < 34.0:
			seen = true
			break
	if player.team == U.TEAM_REB:
		return "Bewohner: %d" % s.occupants
	if not seen:
		return "Bewohner: unbekannt"
	var est := int(round(s.occupants * 0.8 / 2.0) * 2.0)
	return "Bewohner: ca. %d–%d (Schätzung)" % [maxi(est - 2, 0), est + 4]

func _wrap(text: String, font: Font, fs: float, width: float) -> Array:
	var words := text.split(" ")
	var lines: Array = []
	var cur := ""
	for w in words:
		var t := (cur + " " + w) if cur != "" else w
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x > width:
			lines.append(cur)
			cur = w
		else:
			cur = t
	if cur != "":
		lines.append(cur)
	return lines


func _draw_queue(s: Structure, pos: Vector2, font: Font) -> void:
	for i in range(6):
		var r := Rect2(pos + Vector2(i * 38, 0), Vector2(34, 34))
		draw_rect(r, Color(0.1, 0.09, 0.08))
		draw_rect(r, Color(0.35, 0.3, 0.22), false, 1.5)
		if i < s.queue.size():
			var q: Dictionary = s.queue[i]
			var d: Dictionary = Data.UNITS[q.kind]
			Icons.draw(self, d.icon, r.grow(-6), Color(0.93, 0.88, 0.76))
			if i == 0:
				draw_rect(Rect2(r.position.x + 2, r.end.y - 5, (r.size.x - 4) * clampf(q.t / q.total, 0, 1), 3), Color(0.4, 0.85, 0.45))
			_hit_queue.append({"rect": r, "structure": s, "idx": i})
	draw_string(font, pos + Vector2(6 * 38 + 6, 21), "◄ Produktion (Klick = abbrechen)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.65, 0.62, 0.55))

func _draw_multi(sel: Array, font: Font) -> void:
	var n := sel.size()
	draw_string(font, Vector2(10, 18), "%d Einheiten ausgewählt" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.93, 0.88, 0.76))
	var counts: Dictionary = {}
	for e in sel:
		if is_instance_valid(e):
			var k: String = (e as Entity).kind
			counts[k] = counts.get(k, 0) + 1
	var parts: Array = []
	for k in counts.keys():
		var nm: String = Data.UNITS[k].name if Data.UNITS.has(k) else (Data.STRUCTS[k].name if Data.STRUCTS.has(k) else k)
		parts.append("%d× %s" % [counts[k], nm])
	draw_string(font, Vector2(10, 33), ", ".join(parts), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 11, Color(0.75, 0.72, 0.64))
	var cell := 30.0
	var cols := maxi(int((size.x - 20.0) / (cell + 3.0)), 4)
	for i in range(mini(n, cols * 2)):
		var e: Entity = sel[i]
		if not is_instance_valid(e):
			continue
		var r := Rect2(Vector2(10 + (i % cols) * (cell + 3), 40 + (i / cols) * (cell + 9)), Vector2(cell, cell))
		draw_rect(r, Color(0.1, 0.09, 0.08))
		draw_rect(r, U.team_color(e.team), false, 1.5)
		var ik := "inf"
		if e is Unit:
			ik = (e as Unit).def.get("icon", "inf")
		elif e is Structure:
			ik = "base"
		Icons.draw(self, ik, r.grow(-5), Color(0.93, 0.88, 0.76))
		_hp_bar(Vector2(r.position.x, r.end.y + 1), cell, e.hp / e.max_hp, 4.0)
		_hit_icons.append({"rect": r, "entity": e})
