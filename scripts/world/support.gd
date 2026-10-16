class_name Support
extends Node3D
## Globale Unterstuetzung: Luftschlag, Praezisionsschlag, Artillerie-Salve, Warnung, Aufklaerungsflug.

var world: World

func execute(id: String, team: int, pos: Vector3) -> void:
	pos = Vector3(pos.x, 0.0, pos.z)
	match id:
		"airstrike": _airstrike(pos)
		"precision": _precision(pos)
		"salvo": _salvo(pos)
		"warning": _warning(pos)
		"scan": _scan(pos)
		"convoy": _convoy(pos)
		"fieldhosp": _fieldhosp(pos)
		"corridor": _corridor(pos)
		"shield": _shield(pos)
		"staged": _staged(pos)
		"smoke": _smoke(pos)

func _base_pos() -> Vector3:
	return world.city.base_assembly if world != null and world.city != null else Vector3.ZERO

func _timer(delay: float, f: Callable) -> void:
	var tm := Timer.new()
	tm.one_shot = true
	tm.wait_time = maxf(delay, 0.02)
	add_child(tm)
	tm.timeout.connect(func():
		f.call()
		tm.queue_free())
	tm.start()

func _jet_model() -> Node3D:
	var root := Node3D.new()
	var mb := MeshBuilder.new()
	mb.jitter = 0.02
	var grey := Color(0.5, 0.53, 0.56)
	var dark := Color(0.12, 0.12, 0.14)
	var glass := Color(0.12, 0.2, 0.26)
	var tc := U.team_color(U.TEAM_ADF)
	# Rumpf: kantige Segmente, Nase mit Radom
	mb.loft(Vector3(0, 0, -4.0), Vector2(1.7, 1.0), Vector3(0, 0.0, 1.6), Vector2(1.2, 0.85), grey)
	mb.loft(Vector3(0, 0.0, 1.6), Vector2(1.2, 0.85), Vector3(0, -0.12, 4.6), Vector2(0.4, 0.4), grey * 0.95)
	mb.loft(Vector3(0, -0.12, 4.6), Vector2(0.4, 0.4), Vector3(0, -0.14, 5.6), Vector2(0.06, 0.06), Color(0.3, 0.3, 0.32))
	# Cockpit (Blasenhaube)
	mb.prism_x([Vector2(3.4, 0.4), Vector2(2.5, 1.0), Vector2(0.6, 1.0), Vector2(-0.3, 0.42)], -0.38, 0.38, glass, Color(0.25, 0.3, 0.34))
	# Lufteinlaesse und Triebwerke
	for sx in [-1.0, 1.0]:
		mb.loft(Vector3(sx * 1.05, -0.25, -3.8), Vector2(0.8, 0.85), Vector3(sx * 0.95, -0.3, 1.0), Vector2(0.75, 0.75), grey * 0.92)
		mb.box(Vector3(sx * 0.95, -0.3, 1.02), Vector3(0.65, 0.65, 0.08), dark)
		mb.cyl(Vector3(sx * 0.8, 0.0, -4.5), 0.42, 0.34, 1.0, Color(0.25, 0.22, 0.2), 10, 2)
		mb.cyl(Vector3(sx * 0.8, 0.0, -5.0), 0.34, 0.3, 0.1, Color(0.95, 0.5, 0.15), 10, 2)
	# Tragflaechen: gepfeilt, mit Hinterkantenklappen
	for sx in [-1.0, 1.0]:
		mb.extrude([Vector2(sx * 0.9, 1.9), Vector2(sx * 7.2, -2.6), Vector2(sx * 7.2, -3.6), Vector2(sx * 0.9, -3.6)], -0.1, 0.12, grey * 0.97, grey * 1.04)
		mb.box_t(Vector3(sx * 4.2, 0.0, -3.4), Vector3(3.4, 0.05, 0.5), grey * 0.85, Vector3(0, sx * -20.0, 0))
		mb.box(Vector3(sx * 7.1, 0.0, -3.1), Vector3(0.3, 0.06, 0.7), tc)
		# Lufttankpylone: Bomben + Lenkwaffen
		for k in range(2):
			var x: float = sx * (2.6 + k * 2.2)
			mb.box(Vector3(x, -0.4, -1.0 - k * 0.5), Vector3(0.1, 0.4, 1.0), dark)
			mb.cyl(Vector3(x, -0.85, -1.0 - k * 0.5), 0.26, 0.26, 2.2, Color(0.36, 0.38, 0.34), 8, 2)
			mb.cyl(Vector3(x, -0.85, 0.2 - k * 0.5), 0.26, 0.04, 0.5, Color(0.36, 0.38, 0.34), 8, 2)
			mb.box(Vector3(x, -0.85, -2.0 - k * 0.5), Vector3(0.7, 0.04, 0.35), dark)
		mb.cyl(Vector3(sx * 7.5, 0.0, -2.9), 0.1, 0.1, 2.6, Color(0.7, 0.7, 0.72), 6, 2)     # Wingtip-Rakete
		mb.cyl(Vector3(sx * 7.5, 0.0, -1.5), 0.1, 0.0, 0.3, Color(0.7, 0.7, 0.72), 6, 2)
	# Doppeltes Seitenleitwerk (nach aussen geneigt) und Hoehenruder
	for sx in [-1.0, 1.0]:
		mb.prism_x([Vector2(-2.6, 0.5), Vector2(-4.4, 2.6), Vector2(-5.4, 2.6), Vector2(-5.0, 0.5)], sx * 1.0 - 0.06, sx * 1.0 + 0.06, grey * 1.02)
		mb.box(Vector3(sx * 1.0, 2.62, -5.0), Vector3(0.14, 0.12, 0.7), tc)
		mb.extrude([Vector2(sx * 0.7, -3.4), Vector2(sx * 3.4, -5.0), Vector2(sx * 3.4, -5.9), Vector2(sx * 0.7, -5.4)], -0.05, 0.07, grey * 0.95)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(Gfx.vcol_mat(0.45, 0.4))
	root.add_child(mi)
	return root

func _airstrike(pos: Vector3) -> void:
	Sfx.play_ui("jet")
	world.fx.ring_ping(pos, 14.0, Color(1.0, 0.4, 0.2, 0.8), 2.4)
	var dir := (pos - _base_pos())
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 1.0 else Vector3(1, 0, -1).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var speed := 115.0
	var lead := 170.0
	var bombs: Array = []
	for j in range(2):
		var lat := (j - 0.5) * 9.0
		var jet := _jet_model()
		jet.position = pos - dir * lead + side * lat + Vector3(0, 55, 0)
		world.add_child(jet)
		jet.look_at(jet.position - dir, Vector3.UP)   # Modell blickt nach +Z, look_at richtet -Z aus
		jet.scale = Vector3(1.4, 1.4, 1.4)
		world.fx.rocket_trail(jet, 2.2)
		var tw := create_tween()
		tw.tween_property(jet, "position", pos + dir * lead * 1.1 + side * lat + Vector3(0, 55, 0), (lead * 2.1) / speed)
		tw.tween_callback(jet.queue_free)
		for i in range(3):
			var s := (i - 1) * 8.0
			bombs.append([lat, s])
	for b in bombs:
		var lat: float = b[0]
		var s: float = b[1]
		var impact := pos + dir * s + side * lat + Vector3(world.rng.randf_range(-1.5, 1.5), 0, world.rng.randf_range(-1.5, 1.5))
		var t_rel := (lead + s) / speed
		_timer(t_rel, func():
			var w := {"proj": "bomb", "splash": 7.5, "damage": 300.0, "type": "he", "speed": 28.0}
			world.fire_projectile(world.adf_proxy, impact + Vector3(0, 52, 0), null, impact, w)
			Sfx.play_ui("bomb_fall"))
	# Zivilisten in der Naehe fliehen vor den Jets
	world.noise(pos, 50.0, 3)

func _precision(pos: Vector3) -> void:
	world.fx.ring_ping(pos, 6.5, Color(1.0, 0.25, 0.2, 0.9), 1.1)
	Sfx.play_ui("lock")
	_timer(1.1, func():
		var w := {"proj": "missile", "splash": 5.2, "damage": 760.0, "type": "he", "speed": 150.0}
		world.fire_projectile(world.adf_proxy, pos + Vector3(-22, 100, -34), null, pos, w))

func _salvo(pos: Vector3) -> void:
	world.fx.ring_ping(pos, 15.0, Color(1.0, 0.7, 0.2, 0.8), 3.0)
	Sfx.play_ui("arty_far")
	for i in range(7):
		_timer(0.7 + i * 0.45, func():
			var ang := world.rng.randf() * TAU
			var d := sqrt(world.rng.randf()) * 14.0
			var impact := pos + Vector3(cos(ang) * d, 0, sin(ang) * d)
			var from := _base_pos() + Vector3(0, 3, 0)
			var w := {"proj": "arty", "splash": 6.0, "damage": 125.0, "type": "he", "speed": 60.0, "spread": 0.0}
			world.fire_projectile(world.adf_proxy, from, null, impact, w))

func _warning(pos: Vector3) -> void:
	var s: Structure = world.nearest_structure(pos, 12.0, func(st): return st.kind_class != "base")
	if s == null:
		Game.message("Kein Gebäude im Zielbereich", "warn", U.TEAM_ADF)
		Game.refund(U.TEAM_ADF, Data.ABILITIES["warning"].cost)
		Game.cooldowns[0]["warning"] = 0.0
		return
	var roof := s.position + Vector3(0, s.size.y + 0.8, 0)
	world.fx.flash(roof, 3.0, 0.2)
	world.fx.spark(roof)
	Sfx.play_at("explosion_s", s.position)
	s.evacuate()
	Game.stats.shots_warned += 1
	Game.message("Warnung abgegeben – Bewohner verlassen das Gebäude", "good", U.TEAM_ADF)
	# Auch die Rebellen werden gewarnt: verdeckte Kaempfer verlassen ggf. das Haus
	if s.hub:
		s.revealed = s.revealed
	world.fx.ring_ping(s.position, s.radius + 4.0, Color(1.0, 0.9, 0.2, 0.9), 1.6)

func _scan(pos: Vector3) -> void:
	world.fx.ring_ping(pos, 26.0, Color(0.3, 0.9, 1.0, 0.9), 1.6)
	Sfx.play_ui("scan")
	var found := 0
	for u in world.units:
		if u.alive and u.team == U.TEAM_REB and u.concealed and U.dist2d(u.position, pos) <= 26.0:
			u.reveal(10.0)
			u.ident_mask |= 1
			found += 1
	var hubs_found := 0
	for s in world.structures:
		if s.alive and s.hub and not s.revealed and U.dist2d(s.position, pos) <= 26.0 + s.radius * 0.5:
			if world.rng.randf() < 0.5:
				s.mark_revealed("Aufklärungsflug")
				hubs_found += 1
	# Tunnelverbindungen: Bodenradar erkennt Hohlraeume entlang der Strecke
	var links_found := 0
	for t in world.tunnels:
		if t.known or not world.tunnel_active(t):
			continue
		var a2 := Vector2(t.a.position.x, t.a.position.z)
		var b2 := Vector2(t.b.position.x, t.b.position.z)
		var c2 := Vector2(pos.x, pos.z)
		var closest := Geometry2D.get_closest_point_to_segment(c2, a2, b2)
		if closest.distance_to(c2) <= 18.0 and world.rng.randf() < 0.45:
			var newly := world.reveal_tunnel(t)
			links_found += 1
			hubs_found += newly
	if links_found > 0:
		Game.message("Aufklärung: Tunnelverbindung entdeckt – sie führt zu %d weiteren Knoten!" % hubs_found, "good", U.TEAM_ADF)
		Game.news("Bodenradar findet Hohlräume unter dem Viertel – ein Tunnelnetz?", "good")
	elif hubs_found > 0:
		Game.message("Aufklärung: %d Tunnelsignatur(en) entdeckt!" % hubs_found, "good", U.TEAM_ADF)
	elif found > 0:
		Game.message("Aufklärung: %d verdächtige Personen markiert" % found, "good", U.TEAM_ADF)
	else:
		Game.message("Aufklärung: nichts Auffälliges", "info", U.TEAM_ADF)

# ----------------------------------------------------------------------------- Hilfsmassnahmen
func _convoy(pos: Vector3) -> void:
	var origin: Vector3 = _base_pos() + Vector3(2.0, 0, -6.0)
	var dest := world.nav.nearest_free_pos(pos, "veh", 10)
	var n := 0
	for i in range(3):
		var sp := world.nav.nearest_free_pos(origin + Vector3(-2.0 + i * 4.0, 0, 0), "veh", 8)
		var t := world.spawn_unit("adf_aid", U.TEAM_ADF, sp)
		if t == null:
			continue
		t.set_meta("aid_pos", dest + Vector3((i - 1) * 6.0, 0, (i % 2) * 5.0))
		t.set_meta("aid_state", "go")
		t.cmd_move(world.nav.nearest_free_pos(t.get_meta("aid_pos"), "veh", 10))
		n += 1
	world.fx.ring_ping(pos, 14.0, Color(0.4, 0.8, 1.0, 0.85), 2.4)
	Game.message("Hilfskonvoi unterwegs (%d Lkw)" % n, "good", U.TEAM_ADF)
	Game.log_event("aid", "Hilfskonvoi entsandt", pos)

func _fieldhosp(pos: Vector3) -> void:
	if world.place_field_hospital(pos):
		Game.message("Feldlazarett errichtet", "good", U.TEAM_ADF)
		Game.news("Aurelia errichtet Feldlazarett im Zentrum von Qadira", "good")
		Game.log_event("aid", "Feldlazarett errichtet", pos)
	else:
		Game.message("Kein freier Platz für ein Feldlazarett", "warn", U.TEAM_ADF)
		Game.refund(U.TEAM_ADF, Data.ABILITIES["fieldhosp"].cost)
		Game.cooldowns[0]["fieldhosp"] = 0.0

func _corridor(pos: Vector3) -> void:
	world.corridors.append({"pos": pos, "r": 40.0, "t": 45.0, "ping": 0.0})
	world.fx.ring_ping(pos, 40.0, Color(0.4, 0.9, 1.0, 0.8), 3.0)
	Sfx.play_ui("scan")
	Game.message("Evakuierungskorridor geöffnet – wer bleibt, fällt auf", "good", U.TEAM_ADF)
	Game.news("Aurelia öffnet Evakuierungskorridor – Zivilisten verlassen das Viertel", "info")
	Game.log_event("corridor", "Evakuierungskorridor geöffnet", pos)

# ----------------------------------------------------------------------------- Tricks der Hadar-Front
func _refund_reb(id: String, why: String) -> void:
	Game.message(why, "warn", U.TEAM_REB)
	Game.refund(U.TEAM_REB, Data.ABILITIES[id].cost)
	Game.cooldowns[1][id] = 0.0

func _shield(pos: Vector3) -> void:
	var r: float = Data.ABILITIES["shield"].radius
	# Anker: Kaempfer (oder Verstecke mit Besatzung) in der Naehe
	var anchors: Array = []
	for o in world.dyn.query(pos, r + 14.0):
		if o is Unit and o.alive and o.team == U.TEAM_REB and not (o as Unit).is_civ and (o as Unit).layer == "foot" and (o as Unit).garrison == null and not (o as Unit).weapons.is_empty():
			anchors.append(o)
	for st in world.structures:
		if st.alive and st.team != U.TEAM_ADF and st.kind_class != "base" and U.dist2d(st.position, pos) < r + 14.0 and not (st as Structure).garrison_of(U.TEAM_REB).is_empty():
			anchors.append(st)
	var civs: Array = []
	for o in world.dyn.query(pos, r + 2.0):
		if o is Civilian and o.alive and (o as Unit).garrison == null and (o as Unit).shield_t <= 0.0 and U.dist2d(o.position, pos) <= r:
			civs.append(o)
	if anchors.is_empty():
		_refund_reb("shield", "Keine Kämpfer oder besetzte Verstecke im Zielgebiet")
		return
	if civs.is_empty():
		_refund_reb("shield", "Keine Zivilisten im Zielgebiet")
		return
	civs.sort_custom(func(a, b): return U.dist2d(a.position, pos) < U.dist2d(b.position, pos))
	var n := 0
	for c in civs:
		if n >= 8:
			break
		var best: Entity = null
		var bd := 1e9
		for a in anchors:
			var dd: float = U.dist2d(a.position, c.position)
			if dd < bd:
				bd = dd
				best = a
		(c as Unit).force_shield(best, 40.0)
		n += 1
	world.fx.ring_ping(pos, r, Color(1.0, 0.75, 0.2, 0.8), 2.0)
	Sfx.play_ui("lock")
	Game.stats.shields = int(Game.stats.get("shields", 0)) + n
	Game.log_event("shield", "%d Zivilisten als Schutzschilde gezwungen" % n, pos)
	# Die Armee dokumentiert den Missbrauch; die Bevoelkerung ist wuetend auf die Hadar-Front
	Game.evidence += 0.5 * n
	world.add_anger(pos, -2.0 * n)
	Game.message("%d Zivilisten als Schutzschilde aufgestellt – Aurelia sammelt Beweise" % n, "info", U.TEAM_REB)
	Game.message("Zivilisten werden als Schutzschilde missbraucht – Feuer an diesen Stellungen eingestellt", "warn", U.TEAM_ADF)

func _staged(pos: Vector3) -> void:
	var s: Structure = world.nearest_structure(pos, 14.0, func(st): return st.kind_class in ["hospital", "school"])
	if s == null:
		_refund_reb("staged", "Keine Klinik oder Schule im Zielbereich")
		return
	s.staged_t = 60.0
	s._staged_pings = 0
	s.hot_t = maxf(s.hot_t, 60.0)
	var occ: int = s.occupants
	Game.add_footage(4.0 + minf(occ * 0.25, 5.0), "staged")
	Game.evidence += 2.0
	world.add_anger(s.position, 8.0)
	world.fx.ring_ping(s.position, s.radius + 6.0, Color(1.0, 0.3, 0.7, 0.9), 2.4)
	world.fx.flash(s.position + Vector3(0, s.size.y + 1.0, 0), 3.0, 0.15)
	Sfx.play_ui("lock")
	var nm := "Klinik" if s.kind_class == "hospital" else "Schule"
	Game.message("%s inszeniert: Kameras laufen, Köder ausgelegt – Videomaterial bereit" % nm, "good", U.TEAM_REB)
	Game.message("%s meldet bewaffnete Präsenz – Vorsicht, die Bilder wirken auf die Weltöffentlichkeit" % nm, "warn", U.TEAM_ADF)
	Game.news("Hadar-Front: 'Verletzte in der %s – die Welt muss zusehen'" % nm, "info")
	Game.log_event("staged", "%s inszeniert" % nm, s.position)

func _smoke(pos: Vector3) -> void:
	var r: float = Data.ABILITIES["smoke"].radius
	world.smokes.append({"pos": pos, "r": r, "t": 25.0, "puff": 0.0})
	world.fx.ring_ping(pos, r, Color(0.8, 0.82, 0.86, 0.8), 2.0)
	Sfx.play_at("explosion_s", pos)
	Game.log_event("smoke", "Rauchschleier gelegt", pos)
	Game.message("Rauchschleier: 25 s Sichtschutz", "info", U.TEAM_REB)
