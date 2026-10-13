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
	custom_minimum_size = Vector2(560, 190)

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
	if e is Unit:
		var u := e as Unit
		if u.is_civ:
			return "Zivilist"
		if u.team != player.team and u.is_disguised():
			return "Zivilist"
		return u.def.get("name", u.kind)
	if e is Structure:
		var s := e as Structure
		if s.kind_class == "base":
			return s.def.get("name", s.kind)
		if s.hub and (player.team == U.TEAM_REB or s.revealed):
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
			["EINSATZZIEL", Color(0.85, 0.64, 0.25), 14],
			["Zerschlage alle Tunnelknoten der Hadar-Front – ohne die Weltöffentlichkeit zu verlieren.", Color(0.9, 0.88, 0.8), 13],
			["Zivilisten und Journalisten sind keine Ziele. Jeder Fehlschlag steigt ins Netz.", Color(0.9, 0.88, 0.8), 13],
			["Linksklick: wählen · Rahmen ziehen · Rechtsklick: Befehl · T: Angriffsbewegung", Color(0.7, 0.68, 0.6), 12],
			["F1–F6: Unterstützung · Leertaste: letzter Alarm · R: Einsatzregeln", Color(0.7, 0.68, 0.6), 12],
		]
	else:
		lines = [
			["DEIN ZIEL", Color(0.85, 0.64, 0.25), 14],
			["Du gewinnst nicht durch Panzer, sondern durch Bilder: Treibe die Empörung auf 100%.", Color(0.9, 0.88, 0.8), 13],
			["Halte Medien-Teams am Leben und veröffentliche Videomaterial (Upload).", Color(0.9, 0.88, 0.8), 13],
			["Linksklick: wählen · Rechtsklick auf Haus: Hinterhalt · G: Tarnung · B: Sprengfalle", Color(0.7, 0.68, 0.6), 12],
			["F1: Upload · F2: Spendenaufruf · V: Gebäude verlassen · Leertaste: letzter Alarm", Color(0.7, 0.68, 0.6), 12],
		]
	var y := 24.0
	for l in lines:
		draw_string(font, Vector2(14, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, l[2], l[1])
		y += 22.0 if l[2] > 12 else 20.0

func _hp_bar(p: Vector2, w: float, f: float) -> void:
	draw_rect(Rect2(p.x - 1, p.y - 1, w + 2, 12), Color(0, 0, 0, 0.8))
	var col := Color(0.4, 0.9, 0.4) if f > 0.5 else (Color(0.95, 0.8, 0.2) if f > 0.25 else Color(0.95, 0.3, 0.2))
	draw_rect(Rect2(p.x, p.y, w * clampf(f, 0, 1), 10), col)

func _draw_single(e: Entity, font: Font) -> void:
	if not is_instance_valid(e):
		return
	var tcol := U.team_color(e.team)
	var nm := _disp_name(e)
	if e.team == U.TEAM_CIV or (e is Unit and (e as Unit).is_civ) or (e is Unit and e.team != player.team and (e as Unit).is_disguised()):
		tcol = Color(0.85, 0.85, 0.8)
	draw_string(font, Vector2(14, 24), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, tcol)
	var fac := ""
	if e.team == U.TEAM_ADF:
		fac = "Aurelische Streitkräfte"
	elif e.team == U.TEAM_REB and not (e is Unit and e.team != player.team and (e as Unit).is_disguised()) and not (e is Structure and not (e as Structure).revealed and player.team == U.TEAM_ADF):
		fac = "Hadar-Front"
	elif e.team == U.TEAM_CIV or e is Structure:
		fac = "Zivilbevölkerung"
	draw_string(font, Vector2(14, 42), fac, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.68, 0.6))
	# Trefferpunkte
	if e.team == player.team or e.seen_by(player.team):
		_hp_bar(Vector2(14, 52), 250.0, e.hp / e.max_hp)
		draw_string(font, Vector2(272, 62), "%d / %d" % [int(e.hp), int(e.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.88, 0.8))
	# Symbol groß
	var ik := "inf"
	if e is Unit and not (e as Unit).is_civ:
		ik = (e as Unit).def.get("icon", "inf")
	elif e is Structure:
		ik = "base" if (e as Structure).kind_class == "base" else ("hub" if (e as Structure).hub and player.team == U.TEAM_REB else "garrison")
	if not (e is Unit and e.team != player.team and (e as Unit).is_disguised()):
		draw_rect(Rect2(size.x - 100, 12, 84, 84), Color(0.1, 0.09, 0.08))
		draw_rect(Rect2(size.x - 100, 12, 84, 84), tcol, false, 2.0)
		Icons.draw(self, ik, Rect2(size.x - 92, 20, 68, 68), tcol)
	var y := 86.0
	# Beschreibung (umbrochen)
	var d := _desc(e)
	var has_queue: bool = e is Structure and e.team == player.team and not (e as Structure).produces.is_empty()
	if d != "" and not has_queue:
		var lines := _wrap(d, font, 12.0, size.x - 140)
		for ln in lines:
			draw_string(font, Vector2(14, y), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.82, 0.8, 0.72))
			y += 15.0
	y += 4.0
	# Werte
	if e is Unit:
		var u := e as Unit
		if not u.weapons.is_empty() and u.team == player.team:
			var w: Dictionary = u.weapons[0]
			var st := "Reichweite %dm · Schaden %d · %s" % [int(w.range), int(w.damage), {"bullet": "Handfeuerwaffe", "ap": "Panzerabwehr", "he": "Flächenwirkung", "missile": "Lenkwaffe"}.get(w.type, "")]
			draw_string(font, Vector2(14, y), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.8, 1.0))
			y += 16.0
		if u.team == player.team and u.can_conceal:
			var s2 := "Getarnt" if u.concealed else ("ENTTARNT (%ds)" % ceil(u.exposed_t) if u.exposed_t > 0.0 else "Offen")
			draw_string(font, Vector2(14, y), "Tarnung: " + s2 + (" · automatisch" if u.conceal_pref else " · aus"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.95, 0.95) if u.concealed else Color(1.0, 0.6, 0.4))
		elif player.team == U.TEAM_ADF and u.team == U.TEAM_REB and u.concealed and u.exposed_t <= 0.0 and u.suspicion > 5.0:
			draw_string(font, Vector2(14, y), "Auffälligkeit: %d%% – beobachten oder Aufklärer/Drohne heranführen" % int(u.suspicion), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.4))
		elif u.press:
			draw_string(font, Vector2(14, y), "Presse: Beschuss löst größte Empörung aus!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.5, 0.4))
	elif e is Structure:
		var s := e as Structure
		if s.kind_class != "base":
			var info := _occupancy_text(s)
			draw_string(font, Vector2(14, y), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.9, 0.5))
			y += 16.0
			if s.team == player.team and s.hub:
				draw_string(font, Vector2(300, y - 16), "Besatzung: %d/%d" % [s.garrisoned.size(), s.garrison_cap], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 1.0, 0.6))
		# Warteschlange
		if s.team == player.team and not s.produces.is_empty():
			_draw_queue(s, Vector2(14, size.y - 52), font)

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
	draw_string(font, pos + Vector2(0, -4), "Produktion (Klick = abbrechen):", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.72, 0.64))
	for i in range(6):
		var r := Rect2(pos + Vector2(i * 50, 2), Vector2(44, 44))
		draw_rect(r, Color(0.1, 0.09, 0.08))
		draw_rect(r, Color(0.35, 0.3, 0.22), false, 1.5)
		if i < s.queue.size():
			var q: Dictionary = s.queue[i]
			var d: Dictionary = Data.UNITS[q.kind]
			Icons.draw(self, d.icon, r.grow(-8), Color(0.93, 0.88, 0.76))
			if i == 0:
				draw_rect(Rect2(r.position.x + 2, r.end.y - 6, (r.size.x - 4) * clampf(q.t / q.total, 0, 1), 4), Color(0.4, 0.85, 0.45))
			_hit_queue.append({"rect": r, "structure": s, "idx": i})

func _draw_multi(sel: Array, font: Font) -> void:
	var n := sel.size()
	draw_string(font, Vector2(14, 24), "%d Einheiten ausgewählt" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.93, 0.88, 0.76))
	# Zusammenfassung nach Typ
	var counts: Dictionary = {}
	for e in sel:
		if is_instance_valid(e):
			var k: String = (e as Entity).kind
			counts[k] = counts.get(k, 0) + 1
	var parts: Array = []
	for k in counts.keys():
		var nm: String = Data.UNITS[k].name if Data.UNITS.has(k) else (Data.STRUCTS[k].name if Data.STRUCTS.has(k) else k)
		parts.append("%d× %s" % [counts[k], nm])
	draw_string(font, Vector2(14, 42), ", ".join(parts), HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 12, Color(0.75, 0.72, 0.64))
	var cols := 12
	var cell := 42.0
	for i in range(mini(n, 36)):
		var e: Entity = sel[i]
		if not is_instance_valid(e):
			continue
		var r := Rect2(Vector2(14 + (i % cols) * (cell + 3), 56 + (i / cols) * (cell + 8)), Vector2(cell, cell))
		draw_rect(r, Color(0.1, 0.09, 0.08))
		draw_rect(r, U.team_color(e.team), false, 1.5)
		var ik := "inf"
		if e is Unit:
			ik = (e as Unit).def.get("icon", "inf")
		elif e is Structure:
			ik = "base"
		Icons.draw(self, ik, r.grow(-7), Color(0.93, 0.88, 0.76))
		_hp_bar(Vector2(r.position.x, r.end.y + 1), cell, e.hp / e.max_hp)
		_hit_icons.append({"rect": r, "entity": e})
