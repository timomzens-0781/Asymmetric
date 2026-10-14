class_name WorldOverlay
extends Control
## 2D-Ueberlagerung der Welt: Lebensbalken, Markierungen (Tarnung, Verdacht, Kameras, Tunnelknoten),
## Auswahlrahmen, Zielinfo am Cursor.

var world: World
var player: PlayerController
var rig: RtsCamera
var _t := 0.0
var safe_rect := Rect2(0, 70, 1500, 700)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _sp(p: Vector3) -> Vector2:
	return rig.cam.unproject_position(p)

func _on_screen(p: Vector3) -> bool:
	return not rig.cam.is_position_behind(p)

func _draw() -> void:
	if world == null or rig == null or player == null:
		return
	var font := ThemeDB.fallback_font
	var vp := get_viewport_rect()
	var near := rig.dist < 78.0
	var pt := player.team
	for e in world.all_entities:
		if not e.alive or not e.visible:
			continue
		if e is Structure:
			_draw_structure(e as Structure, font, vp, pt)
		elif e is Unit:
			_draw_unit(e as Unit, font, vp, pt, near)
		elif e is Mine:
			if _on_screen(e.global_position):
				var p := _sp(e.global_position + Vector3(0, 0.6, 0))
				if vp.has_point(p):
					draw_string(font, p + Vector2(-5, 5), "✕" if false else "x", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.3, 0.2))
					draw_arc(p, 8, 0, TAU, 12, Color(1.0, 0.3, 0.2), 2.0)
	_draw_fire_alerts(font)
	# Auswahlrahmen
	if player.dragging and player.drag_rect.size.length() > 6.0:
		draw_rect(player.drag_rect, Color(0.5, 1.0, 0.55, 0.12))
		draw_rect(player.drag_rect, Color(0.5, 1.0, 0.55, 0.9), false, 1.5)
	# Namensschild am Cursor
	var he := player.hover_entity
	if he != null and is_instance_valid(he) and he.alive and player.mode == "normal" and not player.dragging:
		var nm := InfoPanel.display_name(he, pt)
		var tcol := U.team_color(he.team)
		if he.team == U.TEAM_CIV or (he is Unit and he.team != pt and (he as Unit).is_disguised()):
			tcol = Color(0.9, 0.9, 0.85)
		var hint := ""
		if he is Unit and (he as Unit).press:
			hint = "  [Presse]"
		var m2 := get_viewport().get_mouse_position()
		_label_box(font, m2 + Vector2(16, -30), nm + hint, tcol)
	# Zielinfo am Cursor
	if player.mode == "ability" and not player.target_info.is_empty():
		_draw_target_info(font)
	elif player.mode == "ability" or player.mode == "fire_ground" or player.mode == "attack_move" or player.mode == "check":
		var m := get_viewport().get_mouse_position()
		var txt: String = {"ability": "Ziel wählen – Rechtsklick/Esc bricht ab", "fire_ground": "Feuerbefehl: Bodenziel wählen", "attack_move": "Angriffsbewegung: Ziel wählen", "check": "Kontrolle: Person anklicken"}[player.mode]
		_label_box(font, m + Vector2(18, 22), txt, Color(1, 0.9, 0.5))

## Rote Pfeile am Bildschirmrand (bzw. Ringe auf dem Bildschirm) fuer Feuergefechte der eigenen Seite.
func _draw_fire_alerts(font: Font) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	for c in Game.fire_clusters:
		var age: float = Game.time - c.t
		if age > 7.0:
			continue
		var a := clampf(1.0 - age / 7.0, 0.3, 1.0)
		var p3 := Vector3(c.pos.x, 1.0, c.pos.z)
		var behind := rig.cam.is_position_behind(p3)
		var sp := rig.cam.unproject_position(p3)
		if not behind and safe_rect.has_point(sp):
			var rad := 30.0 + 5.0 * pulse
			draw_arc(sp, rad, 0, TAU, 28, Color(1.0, 0.15, 0.1, 0.85 * a), 2.5)
			for k in range(4):
				var ang := k * PI * 0.5 + _t * 0.8
				draw_line(sp + Vector2(cos(ang), sin(ang)) * (rad - 6.0), sp + Vector2(cos(ang), sin(ang)) * (rad + 8.0), Color(1.0, 0.2, 0.1, 0.9 * a), 2.5)
			continue
		var center := safe_rect.get_center()
		var d := sp - center
		if behind:
			d = -d
		if d.length() < 1.0:
			d = Vector2.UP
		var half := safe_rect.size * 0.5 - Vector2(26, 26)
		var kx: float = half.x / absf(d.x) if absf(d.x) > 0.001 else 1e9
		var ky: float = half.y / absf(d.y) if absf(d.y) > 0.001 else 1e9
		var ep := center + d * minf(kx, ky)
		var dir := d.normalized()
		var perp := Vector2(-dir.y, dir.x)
		var sc := 1.55 + 0.25 * pulse
		var tip := ep + dir * 20.0 * sc
		var b1 := ep - dir * 8.0 * sc + perp * 15.0 * sc
		var b2 := ep - dir * 8.0 * sc - perp * 15.0 * sc
		var nb := ep - dir * 1.0 * sc
		var tri := PackedVector2Array([tip, b1, nb, b2])
		draw_colored_polygon(PackedVector2Array([tip + dir * 3.0, b1 - dir * 3.0 + perp * 3.0, b2 - dir * 3.0 - perp * 3.0]), Color(0, 0, 0, 0.55 * a))
		draw_colored_polygon(tri, Color(1.0, 0.12, 0.08, 0.95 * a))
		var dist := U.dist2d(c.pos, rig.focus)
		var txt := "%dm" % int(dist)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, ep - dir * 34.0 - Vector2(tw * 0.5, -4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.7, 0.65, a))

func _bar(p: Vector2, w: float, f: float, col: Color) -> void:
	draw_rect(Rect2(p.x - w * 0.5 - 1, p.y - 1, w + 2, 6), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(p.x - w * 0.5, p.y, w * clampf(f, 0.0, 1.0), 4), col)

func _draw_unit(u: Unit, font: Font, vp: Rect2, pt: int, near: bool) -> void:
	var head := u.global_position + Vector3(0, ((u.air_h + 2.8) if u.layer == "air" else (3.1 if u.layer == "foot" else 3.4)), 0)
	if not _on_screen(head):
		return
	var p := _sp(head)
	if not vp.grow(30).has_point(p):
		return
	var hp_f := u.hp / u.max_hp
	var show_bar := u.selected or u == player.hover_entity or (hp_f < 0.995 and near and not u.is_civ)
	if u.is_civ and (u.selected or u == player.hover_entity):
		show_bar = true
	var own := u.team == pt
	if show_bar:
		var col := Color(0.4, 0.9, 0.4) if hp_f > 0.5 else (Color(0.95, 0.8, 0.2) if hp_f > 0.25 else Color(0.95, 0.3, 0.2))
		var w := 34.0 if u.layer != "foot" else 26.0
		_bar(p, w, hp_f, col)
	# Marker
	var yoff := -10.0
	if u.press:
		_draw_cam_icon(p + Vector2(0, -12))
		yoff -= 14.0
	if own and u.can_conceal and u.concealed:
		draw_circle(p + Vector2(0, yoff), 5, Color(0.4, 0.9, 0.9, 0.9))
		draw_arc(p + Vector2(0, yoff), 5, 0, TAU, 10, Color(0, 0, 0, 0.7), 1.0)
	elif own and u.can_conceal and u.exposed_t > 0.0:
		draw_circle(p + Vector2(0, yoff), 5, Color(1.0, 0.35, 0.25, 0.95))
	if pt == U.TEAM_ADF and u.team == U.TEAM_REB and u.concealed and u.exposed_t <= 0.0 and u.suspicion > 14.0:
		# Verdachtsanzeige – wirkt wie jeder Zivilist, nur mit wachsendem Fragezeichen
		draw_string(font, p + Vector2(-4, yoff + 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.9, 0.3))
		_bar(p + Vector2(0, yoff + 8), 22.0, u.suspicion / 100.0, Color(1.0, 0.85, 0.25))
	elif pt == U.TEAM_ADF and u.team == U.TEAM_REB and u.exposed_t > 0.0:
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, yoff - 7), p + Vector2(7, yoff), p + Vector2(0, yoff + 7), p + Vector2(-7, yoff)]), Color(1.0, 0.25, 0.2))
		draw_string(font, p + Vector2(-4, yoff + 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
	# Verteidigung: Aufbau-Status des Raketenwerfers
	if own and u.is_launcher and u._deploy > 0.05 and u._deploy < 0.99:
		_bar(p + Vector2(0, 8), 28.0, u._deploy, Color(0.9, 0.7, 0.2))

func _draw_cam_icon(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-8, -5), Vector2(11, 9)), Color(0.95, 0.95, 0.95))
	draw_colored_polygon(PackedVector2Array([p + Vector2(3, -2), p + Vector2(9, -6), p + Vector2(9, 6), p + Vector2(3, 2)]), Color(0.95, 0.95, 0.95))
	var blink := 0.5 + 0.5 * sin(_t * 5.0)
	draw_circle(p + Vector2(-10, -8), 2.6, Color(1.0, 0.2, 0.15, 0.4 + 0.6 * blink))

func _draw_structure(s: Structure, font: Font, vp: Rect2, pt: int) -> void:
	var top := s.global_position + Vector3(0, s.size.y + 1.5, 0)
	if not _on_screen(top):
		return
	var p := _sp(top)
	if not vp.grow(60).has_point(p):
		return
	var hp_f := s.hp / s.max_hp
	if s.selected or s == player.hover_entity or (hp_f < 0.995 and s.kind_class == "base"):
		var col := Color(0.4, 0.9, 0.4) if hp_f > 0.5 else (Color(0.95, 0.8, 0.2) if hp_f > 0.25 else Color(0.95, 0.3, 0.2))
		_bar(p, 54.0, hp_f, col)
	# Tunnelknoten: fuer Rebellen sichtbar, fuer ADF erst nach Entdeckung
	if s.hub and (pt == U.TEAM_REB or s.revealed):
		var c := Color(1.0, 0.55, 0.15) if pt == U.TEAM_REB else Color(1.0, 0.25, 0.2)
		var r := Rect2(p + Vector2(-13, -34), Vector2(26, 26))
		draw_rect(r, Color(0.05, 0.05, 0.05, 0.8))
		draw_rect(r, c, false, 2.0)
		Icons.draw(self, "hub", r.grow(-4), c)
		if pt == U.TEAM_ADF:
			draw_string(font, p + Vector2(-34, -38), "TUNNELKNOTEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c)
	elif s.hot_t > 0.0 and pt == U.TEAM_ADF:
		var flick := 0.6 + 0.4 * sin(_t * 9.0)
		var r2 := Rect2(p + Vector2(-12, -30), Vector2(24, 24))
		draw_rect(r2, Color(0.1, 0.02, 0.02, 0.8))
		draw_rect(r2, Color(1.0, 0.3, 0.2, flick), false, 2.0)
		draw_string(font, p + Vector2(-5, -12), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.4, 0.3, flick))
	if s.warned and s.occupants > 0 and s.kind_class != "base":
		draw_string(font, p + Vector2(-30, -6), "EVAKUIERUNG", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.9, 0.3))
	if pt == U.TEAM_REB and not s.garrisoned.is_empty() and s.team != U.TEAM_ADF:
		draw_string(font, p + Vector2(-9, -4), "%d" % s.garrisoned.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.5, 1.0, 0.6))
	if s.kind_class in ["hospital", "school"] and rig.dist < 90.0:
		var nm := "KLINIK" if s.kind_class == "hospital" else "SCHULE"
		draw_string(font, p + Vector2(-22, 6), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.95, 1.0, 0.9))

func _draw_target_info(font: Font) -> void:
	var ti := player.target_info
	var m := get_viewport().get_mouse_position() + Vector2(20, 20)
	var civs: float = ti.civs
	var lines: Array = []
	var civ_txt := "keine erkannt"
	var col := Color(0.5, 1.0, 0.55)
	if civs > 0.5:
		civ_txt = "≈ %d" % int(round(civs / 2.0) * 2.0 if civs > 6 else civs)
		col = Color(1.0, 0.75, 0.25) if civs <= 6 else Color(1.0, 0.35, 0.3)
	lines.append(["Zivilisten im Radius: " + civ_txt, col])
	lines.append(["Kameras: " + ("JA – verstärkt die Wirkung!" if ti.cams else "keine sichtbar"), Color(1.0, 0.5, 0.4) if ti.cams else Color(0.8, 0.8, 0.75)])
	if ti.sensitive:
		lines.append(["ACHTUNG: Klinik/Schule im Wirkradius!", Color(1.0, 0.25, 0.2)])
	var w := 270.0
	var h := 10.0 + lines.size() * 18.0
	draw_rect(Rect2(m, Vector2(w, h)), Color(0.05, 0.05, 0.05, 0.85))
	draw_rect(Rect2(m, Vector2(w, h)), Color(0.85, 0.64, 0.25, 0.8), false, 1.5)
	for i in range(lines.size()):
		draw_string(font, m + Vector2(8, 18 + i * 18), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, w - 12, 13, lines[i][1])

func _label_box(font: Font, p: Vector2, txt: String, col: Color) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16
	draw_rect(Rect2(p, Vector2(w, 24)), Color(0.05, 0.05, 0.05, 0.85))
	draw_rect(Rect2(p, Vector2(w, 24)), Color(0.85, 0.64, 0.25, 0.8), false, 1.0)
	draw_string(font, p + Vector2(8, 17), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
