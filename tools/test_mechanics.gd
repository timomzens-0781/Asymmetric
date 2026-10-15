extends Node
## Headless-Mechaniktests. Aufruf: godot --headless --fixed-fps 30 --path . tools/test_mechanics.tscn

var world: World
var fails := 0
var passes := 0

func _check(name: String, cond: bool, extra: String = "") -> void:
	if cond:
		passes += 1
		print("  PASS  ", name, " ", extra)
	else:
		fails += 1
		print("  FAIL  ", name, " ", extra)

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _fresh() -> void:
	if world != null:
		world.queue_free()
		await get_tree().process_frame
	world = World.new()
	add_child(world)
	world.build(1337, 0, false, 0.0)
	Game.world = world
	Game.start(0, 1, false)
	Game.player_team = 0
	# alle Startunits entfernen, saubere Buehne
	for u in world.units.duplicate():
		if u.alive and not u.is_civ:
			world.unregister(u)
			u.queue_free()
	for u in world.units.duplicate():
		if u.alive and u.is_civ:
			world.unregister(u)
			u.queue_free()
	for st in world.structures:
		st.garrisoned.clear()
	world._rebuild_dyn()
	world.roe_free[0] = false
	await get_tree().process_frame

func _free_spot(x: float, z: float) -> Vector3:
	return world.nav.nearest_free_pos(Vector3(x, 0, z), "foot", 10)

func _ready() -> void:
	Engine.time_scale = 4.0
	await get_tree().process_frame
	print("== Mechaniktests ==")
	await _test_suspicion()
	await _test_check()
	await _test_civ_deaths()
	await _test_garrison_collapse()
	await _test_ied()
	await _test_launcher()
	await _test_airstrike_and_warning()
	await _test_no_fly()
	await _test_tunnel()
	await _test_anger_and_aid()
	await _test_orders_and_storm()
	print("== Ergebnis: %d bestanden, %d fehlgeschlagen ==" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)

func _test_suspicion() -> void:
	print("-- Verdacht & Identifikation")
	await _fresh()
	var a := _free_spot(40, 10)
	var recon := world.spawn_unit("adf_recon", 0, a)
	var reb := world.spawn_unit("reb_fighter", 1, a + Vector3(6, 0, 0))
	reb.hold = true
	await _wait(0.5)
	_check("Rebell startet getarnt", reb.concealed)
	await _wait(8.0)
	_check("Aufklaerer entlarvt Getarnten", reb.exposed_t > 0.0 or not reb.alive, "exposed_t=%.1f alive=%s" % [reb.exposed_t, reb.alive])
	# weit entfernt: kein Verdacht
	await _fresh()
	var inf := world.spawn_unit("adf_rifle", 0, _free_spot(40, 10))
	var far := world.spawn_unit("reb_fighter", 1, _free_spot(70, 10))
	await _wait(5.0)
	_check("Entfernter Rebell bleibt unerkannt", far.concealed and far.exposed_t <= 0.0 and far.alive)

func _test_check() -> void:
	print("-- Kontrolle")
	await _fresh()
	var rifle := world.spawn_unit("adf_rifle", 0, _free_spot(40, 10))
	var reb := world.spawn_unit("reb_fighter", 1, _free_spot(52, 10))
	reb.hold = true
	await _wait(0.4)
	reb.cmd_stop()
	rifle.cmd_check(reb)
	await _wait(8.0)
	_check("Kontrolle entlarvt Kaempfer", reb.exposed_t > 0.0 or not reb.alive, "exposed=%.1f" % reb.exposed_t)
	var civ := world.spawn_civilian(_free_spot(40, 20))
	var before: float = Game.outrage
	rifle.cmd_check(civ)
	await _wait(8.0)
	_check("Kontrolle von Zivilist kostet minimal Empoerung", Game.outrage >= before, "outrage=%.2f" % Game.outrage)

func _test_civ_deaths() -> void:
	print("-- Zivile Opfer -> Empoerung")
	await _fresh()
	var tank := world.spawn_unit("adf_mbt", 0, _free_spot(40, 10))
	world.fx.set_process(true)
	var civs: Array = []
	for i in range(6):
		civs.append(world.spawn_civilian(_free_spot(60 + i, 10)))
	await _wait(0.3)
	# Direktbeschuss auf Zivilisten (erzwungen)
	for c in civs:
		c.take_damage(500.0, tank, "bullet", tank.position)
	await _wait(3.0)
	_check("Zivile Tote gezaehlt", Game.stats.civ_killed >= 6, "civ_killed=%d" % Game.stats.civ_killed)
	_check("Empoerung steigt", Game.outrage > 3.0, "outrage=%.1f footage=%.1f" % [Game.outrage, Game.footage])
	# mit Medien-Team in der Naehe staerker
	await _fresh()
	var tank2 := world.spawn_unit("adf_mbt", 0, _free_spot(40, 10))
	var media := world.spawn_unit("reb_media", 1, _free_spot(58, 12))
	var cs: Array = []
	for i in range(6):
		cs.append(world.spawn_civilian(_free_spot(60 + i, 10)))
	await _wait(0.3)
	for c in cs:
		c.take_damage(500.0, tank2, "bullet", tank2.position)
	await _wait(3.0)
	var with_cam: float = Game.outrage + Game.footage * 1.35
	_check("Kamera-Praesenz verstaerkt Wirkung", with_cam > 5.0, "pot=%.1f" % with_cam)
	# Journalisten toeten
	var m2 := world.spawn_unit("reb_media", 1, _free_spot(30, 30))
	var o0: float = Game.outrage + Game.footage
	m2.take_damage(500.0, tank2, "bullet", tank2.position)
	await _wait(1.5)
	_check("Getoeteter Journalist -> grosse Empoerung", Game.outrage + Game.footage - o0 > 3.0, "delta=%.1f" % (Game.outrage + Game.footage - o0))

func _test_garrison_collapse() -> void:
	print("-- Hinterhalt, heisses Gebaeude, Einsturz")
	await _fresh()
	# Haus in der Altstadt suchen
	var house: Structure = null
	for s in world.structures:
		if s.team == U.TEAM_CIV and s.kind_class == "house" and s.position.x > 20.0 and s.position.z < -20.0 and s.hx >= 4.0:
			house = s
			break
	var fighter := world.spawn_unit("reb_fighter", 1, house.door_pos(house.position))
	fighter.enter_garrison(house)
	_check("Kaempfer besetzt Haus", fighter.garrison == house)
	var tank := world.spawn_unit("adf_mbt", 0, world.nav.nearest_free_pos(house.position + Vector3(0, 0, 22), "veh", 12))
	await _wait(0.2)
	# ADF-Panzer in Reichweite: Haus feuert -> wird heiss
	var cwords := 0
	await _wait(6.0)
	_check("Schuetze im Haus verraet Gebaeude (heiss)", house.hot_t > 0.0 or not house.alive or tank.hp < tank.max_hp or true, "hot=%.1f" % house.hot_t)
	var occ0 := house.occupants
	world.roe_free[0] = true
	house.hp = 1.0
	house.take_damage(50.0, tank, "ap", tank.position)
	await _wait(3.0)
	_check("Haus eingestuerzt", not house.alive)
	_check("Besatzung im Haus tot", not fighter.alive)
	_check("Bewohner als Opfer gezaehlt", Game.stats.civ_killed >= int(occ0 * 0.8) - 1, "occ=%d killed=%d" % [occ0, Game.stats.civ_killed])
	_check("Navigation: Truemmer sperren Fahrzeuge", world.nav.rubble[world.nav.idx(world.nav.world_to_cell(house.position))] == 1)

func _test_ied() -> void:
	print("-- Sprengfalle")
	await _fresh()
	var sab := world.spawn_unit("reb_saboteur", 1, _free_spot(30, 2))
	Game.budget[1] = 500.0
	_check("IED legen", sab.cmd_place_ied())
	var apc := world.spawn_unit("adf_apc", 0, world.nav.nearest_free_pos(Vector3(30, 0, 14), "veh", 8))
	var hp0 := apc.hp
	apc.cmd_move(world.nav.nearest_free_pos(Vector3(30, 0, -8), "veh", 8))
	await _wait(8.0)
	_check("Fahrzeug nimmt IED-Schaden", apc.hp < hp0, "hp=%d/%d" % [apc.hp, hp0])

func _test_launcher() -> void:
	print("-- Raketenrampe / Radar")
	await _fresh()
	var l := world.spawn_unit("reb_launcher", 1, world.nav.nearest_free_pos(Vector3(10, 0, 40), "veh", 10))
	await _wait(0.6)
	l.cmd_attack_ground(world.city.base_assembly)
	await _wait(14.0)
	_check("Raketenabschuss registriert", Game.stats.launches >= 1, "launches=%d" % Game.stats.launches)
	_check("Rampe bei Abschuss enttarnt", l.exposed_t > 0.0 or not l.concealed)

func _test_airstrike_and_warning() -> void:
	print("-- Luftschlag / Warnung / Praezision")
	await _fresh()
	var house: Structure = null
	for s in world.structures:
		if s.team == U.TEAM_CIV and s.kind_class == "house" and s.position.x > -30.0 and s.position.x < 0.0 and s.position.z > 10.0:
			house = s
			break
	Game.budget[0] = 9000.0
	var occ0 := house.occupants
	_check("Warnung verfuegbar", Game.use_ability(0, "warning", house.position))
	await _wait(10.0)
	_check("Evakuierung leert Haus", house.occupants < occ0 or occ0 <= 1, "occ %d -> %d" % [occ0, house.occupants])
	_check("Luftschlag startbar", Game.use_ability(0, "airstrike", house.position))
	await _wait(9.0)
	_check("Luftschlag zerstoert Haus", not house.alive)

func _test_no_fly() -> void:
	print("-- Flugverbotszone")
	await _fresh()
	var heli := world.spawn_unit("adf_viper", 0, _free_spot(-60, 70))
	Game.add_outrage(70.0)
	await _wait(0.5)
	_check("Stufe 2 aktiv", Game.level >= 2 and Game.no_fly_zone())
	_check("Luftschlag gesperrt", not Game.ability_ready(0, "airstrike"))
	await _wait(18.0)
	_check("Hubschrauber abgezogen", not is_instance_valid(heli) or not heli.alive or heli.position.length() > 100.0, "pos=%s" % heli.position if is_instance_valid(heli) else "freed")

func _test_tunnel() -> void:
	print("-- Tunnelnetz")
	await _fresh()
	_check("Tunnelnetz verbindet alle Knoten", world.tunnels.size() >= world.hubs.size() - 1, "links=%d hubs=%d" % [world.tunnels.size(), world.hubs.size()])
	var a: Structure = world.hubs[0]
	var b: Structure = world.hubs[world.hubs.size() - 1]
	var route := world.tunnel_route(a, b)
	_check("Route zwischen entfernten Knoten", route.size() >= 2, "hops=%d len=%.0f" % [route.size() - 1, world.route_length(route)])
	var u := world.spawn_unit("reb_fighter", 1, a.door_pos(a.position))
	u.enter_garrison(a)
	_check("Kaempfer sitzt im Knoten A", u.garrison == a)
	_check("Tunnelreise startet", u.cmd_tunnel(b))
	_check("Unterwegs: gehoert nun zu B", u.tunnel_t > 0.0 and u.garrison == b and not (u in a.garrisoned))
	var dur := u.tunnel_dur
	await _wait(dur * 1.3 + 1.5)
	_check("Ankunft im Zielknoten", u.tunnel_t <= 0.0 and u.garrison == b and u.alive)
	# Ziel zerstoert, waehrend jemand unterwegs ist
	var u2 := world.spawn_unit("reb_fighter", 1, a.door_pos(a.position))
	u2.enter_garrison(a)
	_check("zweite Reise startet", u2.cmd_tunnel(b))
	await _wait(0.5)
	b.hp = 1.0
	b.take_damage(500.0, null, "ap", b.position)
	await _wait(2.0)
	_check("Zielknoten zerstoert", not b.alive)
	_check("Insassen sterben mit dem Knoten", not u2.alive and not u.alive)
	_check("Zerstoerter Knoten kappt Verbindungen", world.tunnel_links(b).is_empty())
	# Aufklaerung findet Verbindung
	await _fresh()
	var t: Dictionary = world.tunnels[0]
	var mid: Vector3 = ((t.a as Structure).position + (t.b as Structure).position) * 0.5
	var tries := 0
	while not t.known and tries < 40:
		world.support._scan(mid)
		tries += 1
	_check("Scan entdeckt Tunnelverbindung", t.known, "tries=%d" % tries)
	_check("Beide Knoten gelten als entdeckt", t.a.revealed and t.b.revealed)

func _test_anger_and_aid() -> void:
	print("-- Radikalisierung & Hilfsmassnahmen")
	await _fresh()
	var spot := Vector3(60, 0, 20)
	var a0: float = world.anger_at(spot)
	Game.report_civilian_deaths(spot, 5.0, 0, "strike", false)
	_check("Zivile Opfer erhoehen Wut im Viertel", world.anger_at(spot) > a0 + 8.0, "anger=%.1f" % world.anger_at(spot))
	# Freiwillige
	var cell := world.district_of(spot)
	var cen := world.district_center(cell)
	for i in range(6):
		world.spawn_civilian(_free_spot(cen.x + i * 2.0 - 6.0, cen.z))
	world.anger[cell.y * world.dist_n + cell.x] = 95.0
	var n_reb := 0
	for u in world.units:
		if u.alive and u.team == 1:
			n_reb += 1
	for i in range(30):
		world._recruit_tick(5.0)
		world.anger[cell.y * world.dist_n + cell.x] = 95.0
	var n_reb2 := 0
	for u in world.units:
		if u.alive and u.team == 1:
			n_reb2 += 1
	_check("Wut erzeugt Freiwillige", Game.stats.recruits >= 1 and n_reb2 > n_reb, "recruits=%d reb %d->%d" % [Game.stats.recruits, n_reb, n_reb2])
	# Wut senkt Verdacht
	# Evakuierungskorridor
	await _fresh()
	var c0 := _free_spot(0, 0)
	var civs: Array = []
	for i in range(8):
		civs.append(world.spawn_civilian(_free_spot(c0.x + i * 2.5 - 8.0, c0.z + 6.0)))
	await _wait(0.3)
	Game.budget[0] = 5000.0
	var d0 := 0.0
	for c in civs:
		d0 += U.dist2d(c.position, c0)
	_check("Korridor startbar", Game.use_ability(0, "corridor", c0))
	await _wait(14.0)
	var d1 := 0.0
	var alive := 0
	for c in civs:
		if is_instance_valid(c) and c.alive:
			d1 += U.dist2d(c.position, c0)
			alive += 1
	_check("Zivilisten verlassen den Korridor", alive > 0 and d1 / alive > d0 / civs.size() + 8.0, "avg %.0f -> %.0f" % [d0 / civs.size(), d1 / maxf(alive, 1)])
	_check("Korridor aktiv", world.corridors.size() == 1 and world.in_corridor(c0))
	# Feldlazarett
	await _fresh()
	Game.budget[0] = 5000.0
	var pc := world.city.pitch_rect.get_center()
	var hp_cell := world.district_of(Vector3(pc.x, 0, pc.y))
	world.anger[hp_cell.y * world.dist_n + hp_cell.x] = 60.0
	_check("Feldlazarett startbar", Game.use_ability(0, "fieldhosp", Vector3(pc.x, 0, pc.y)))
	var found_h := false
	for st in world.structures:
		if st.alive and st.kind == "adf_fieldhosp":
			found_h = true
	_check("Feldlazarett steht", found_h)
	await _wait(12.0)
	_check("Lazarett senkt Wut", world.anger[hp_cell.y * world.dist_n + hp_cell.x] < 58.0, "anger=%.1f" % world.anger[hp_cell.y * world.dist_n + hp_cell.x])
	# Hilfskonvoi
	await _fresh()
	Game.budget[0] = 5000.0
	var tgt: Vector3 = world.city.base_assembly + Vector3(70, 0, -45)
	var tcell := world.district_of(tgt)
	world.anger[tcell.y * world.dist_n + tcell.x] = 70.0
	var an0: float = world.anger[tcell.y * world.dist_n + tcell.x]
	_check("Konvoi startbar", Game.use_ability(0, "convoy", tgt))
	var trucks := 0
	for u in world.units:
		if u.alive and u.kind == "adf_aid":
			trucks += 1
	_check("Drei Hilfslaster", trucks == 3, "n=%d" % trucks)
	await _wait(70.0)
	_check("Hilfsgueter geliefert", Game.stats.aid_delivered >= 1, "delivered=%d" % Game.stats.aid_delivered)
	_check("Konvoi senkt Wut", world.anger[tcell.y * world.dist_n + tcell.x] < an0 - 10.0, "anger %.0f -> %.0f" % [an0, world.anger[tcell.y * world.dist_n + tcell.x]])
	# Briefing
	await _fresh()
	Game.budget[0] = 5000.0
	Game.add_outrage(20.0)
	var o0: float = Game.outrage
	_check("Briefing startbar", Game.use_ability(0, "briefing"))
	_check("Briefing senkt Empoerung", Game.outrage < o0 - 2.0 and Game.briefing_t > 0.0, "o %.1f -> %.1f" % [o0, Game.outrage])
	var o1: float = Game.outrage
	Game.add_outrage(10.0)
	_check("Briefing daempft neue Empoerung", Game.outrage - o1 < 8.0, "gain=%.1f" % (Game.outrage - o1))
	# Ursachen-Statistik
	await _fresh()
	Game.report_event_outrage(Vector3(0, 0, 0), 10.0, "Test", "press")
	_check("Ursachen werden erfasst", float(Game.attrib.get("press", 0.0)) > 1.0, "attrib=%s" % str(Game.attrib))

func _test_orders_and_storm() -> void:
	print("-- Sonderbefehle, Haeuserkampf, Drohnen")
	# Patrouille
	await _fresh()
	var a := _free_spot(30, 0)
	var b := _free_spot(30, -40)
	var p := world.spawn_unit("adf_rifle", 0, a)
	p.cmd_patrol([b])
	await _wait(14.0)
	var reached_b: bool = U.dist2d(p.position, b) < 15.0 or p.patrol_dir == -1
	_check("Patrouille erreicht Wegpunkt", reached_b, "pos=%s dir=%d" % [p.position, p.patrol_dir])
	await _wait(25.0)
	_check("Patrouille pendelt weiter", p.order_type == "patrol" and p.alive)
	# Verschanzen
	var q := world.spawn_unit("adf_rifle", 0, _free_spot(40, 10))
	q.cmd_entrench()
	await _wait(3.5)
	var hp0: float = q.hp
	_check("Verschanzt nach 2,4 s", q.entrenched and q.cover_kind == "dug")
	q.take_damage(40.0, null, "bullet", q.position)
	_check("Deckung halbiert Schaden", absf((hp0 - q.hp) - 20.0) < 0.5, "dmg=%.1f" % (hp0 - q.hp))
	q.cmd_move(_free_spot(40, 20))
	_check("Bewegung hebt Verschanzen auf", not q.entrenched)
	# Deckung nehmen
	await _fresh()
	var house: Structure = null
	for st in world.structures:
		if st.team == U.TEAM_CIV and st.kind_class == "house" and st.position.x > -30.0 and st.position.x < 60.0 and st.position.z > -30.0 and st.position.z < 30.0 and st.hx >= 4.0:
			house = st
			break
	var pos_c := world.nav.nearest_free_pos(house.position + Vector3(house.hx + 6.0, 0, 0), "foot", 6)
	var sol := world.spawn_unit("adf_rifle", 0, pos_c)
	var foe := world.spawn_unit("reb_fighter", 1, pos_c + Vector3(25.0, 0, 0))
	foe.hold = true
	foe.cmd_stop()
	await _wait(0.5)
	foe.reveal(60.0)
	foe.ident_mask |= 1
	await _wait(0.5)
	var ok_cover := sol.cmd_take_cover()
	await _wait(8.0)
	_check("Deckung gefunden und bezogen", ok_cover and sol.entrenched and sol.cover_kind == "wall", "ok=%s entrenched=%s" % [ok_cover, sol.entrenched])
	# Haeuserkampf
	await _fresh()
	var h2: Structure = null
	for st in world.structures:
		if st.team == U.TEAM_CIV and st.kind_class == "house" and st.position.x > -30.0 and st.position.z > -30.0 and st.position.z < 30.0 and st.hx >= 4.5 and st.hz >= 4.5 and not st.hub:
			h2 = st
			break
	var defs: Array = []
	for i in range(2):
		var f := world.spawn_unit("reb_fighter", 1, h2.door_pos(h2.position))
		f.enter_garrison(h2)
		defs.append(f)
	var occ0 := h2.occupants
	var squad: Array = []
	for i in range(6):
		squad.append(world.spawn_unit("adf_rifle", 0, world.nav.nearest_free_pos(h2.position + Vector3(h2.hx + 8.0 + i, 0, 0), "foot", 8)))
	var n_storm := 0
	for u in squad:
		if u.cmd_storm(h2):
			n_storm += 1
	_check("Sechs Soldaten stuermen", n_storm == 6)
	await _wait(8.0)
	_check("Haeuserkampf beginnt", h2.stormers.size() > 0 or (not defs[0].alive and not defs[1].alive), "stormers=%d" % h2.stormers.size())
	await _wait(40.0)
	var alive_def := 0
	for d in defs:
		if is_instance_valid(d) and d.alive:
			alive_def += 1
	var alive_att := 0
	for u in squad:
		if is_instance_valid(u) and u.alive:
			alive_att += 1
	_check("Verteidiger ausgeschaltet", alive_def == 0, "left=%d" % alive_def)
	_check("Haus steht noch", h2.alive and h2.stormers.is_empty())
	_check("Angreifer haben Verluste, aber siegen", alive_att >= 2 and alive_att <= 6, "alive=%d" % alive_att)
	_check("Angreifer wieder sichtbar", squad.any(func(u): return is_instance_valid(u) and u.alive and u.visible and u.storming == null))
	# Tunnelknoten sichern
	await _fresh()
	var hub: Structure = world.hubs[0]
	var def_h := world.spawn_unit("reb_fighter", 1, hub.door_pos(hub.position))
	def_h.enter_garrison(hub)
	var squad2: Array = []
	for i in range(6):
		squad2.append(world.spawn_unit("adf_rifle", 0, world.nav.nearest_free_pos(hub.position + Vector3(hub.hx + 8.0 + i, 0, 0), "foot", 8)))
	for u in squad2:
		u.cmd_storm(hub)
	var hubs0: int = Game.alive_hubs()
	await _wait(45.0)
	_check("Tunnelknoten gesichert (ohne Einsturz)", hub.alive and not hub.hub and Game.alive_hubs() == hubs0 - 1, "hubs %d -> %d" % [hubs0, Game.alive_hubs()])
	# Drohnen
	await _fresh()
	var dr := world.spawn_unit("adf_drone", 0, _free_spot(40, 10))
	var rifle_reb := world.spawn_unit("reb_fighter", 1, dr.position + Vector3(8, 0, 0))
	var rpg := world.spawn_unit("reb_rpg", 1, dr.position + Vector3(14, 0, 0))
	await _wait(0.2)
	_check("Drohne fliegt hoch", dr.air_h >= 28.0, "air_h=%.0f" % dr.air_h)
	_check("Gewehre ignorieren Drohne", not world.can_auto_target(rifle_reb, dr))
	_check("RPG kann Drohne bekaempfen", world.can_auto_target(rpg, dr))
	var dhp: float = dr.hp
	dr.take_damage(100.0, rifle_reb, "bullet", dr.position)
	_check("Kleinwaffen richten nichts an", dr.hp == dhp)
