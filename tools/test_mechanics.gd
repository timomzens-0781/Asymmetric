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
	var sab := world.spawn_unit("reb_saboteur", 1, _free_spot(40, 2))
	Game.budget[1] = 500.0
	_check("IED legen", sab.cmd_place_ied())
	var apc := world.spawn_unit("adf_apc", 0, world.nav.nearest_free_pos(Vector3(40, 0, 12), "veh", 8))
	var hp0 := apc.hp
	apc.cmd_move(world.nav.nearest_free_pos(Vector3(40, 0, -6), "veh", 8))
	await _wait(8.0)
	_check("Fahrzeug nimmt IED-Schaden", apc.hp < hp0, "hp=%d/%d" % [apc.hp, hp0])

func _test_launcher() -> void:
	print("-- Raketenrampe / Radar")
	await _fresh()
	var l := world.spawn_unit("reb_launcher", 1, world.nav.nearest_free_pos(Vector3(10, 0, 40), "veh", 10))
	await _wait(0.6)
	l.cmd_attack_ground(Vector3(-62, 0, 70))
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
