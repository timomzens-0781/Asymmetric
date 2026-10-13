extends RefCounted
## Test-Szenario: Nahaufnahme von Einheiten, Auswahl, Effekten. Aufruf: scenario=closeup

static func run(m: Node) -> void:
	var w: World = m.world
	var p: PlayerController = m.player
	var rig: RtsCamera = m.rig
	await m.get_tree().create_timer(0.5).timeout
	var sel: Array = []
	for u in w.units:
		if u.alive and u.team == 0 and u.kind in ["adf_mbt", "adf_rifle", "adf_apc"]:
			sel.append(u)
	p.select_list(sel)
	rig.jump_to(Vector3(-62, 0, 70))
	rig.target_dist = 26.0
	rig.dist = 26.0
	rig.yaw = 0.7
	rig.target_yaw = 0.7
	await m.get_tree().create_timer(1.0).timeout
	m._take_shot_now("a")
	await m.get_tree().create_timer(0.5).timeout
	# Effekte: grosse und mittlere Explosion, Einsturz
	var c := Vector3(-62, 0, 52)
	w.fx.explosion(c + Vector3(-8, 0.5, 0), 7.0)
	w.fx.explosion(c + Vector3(6, 0.5, 2), 3.0)
	w.fx.tracer(Vector3(-62, 2, 62), c + Vector3(0, 1, 0), true)
	w.fx.shockwave(c, 12.0)
	await m.get_tree().create_timer(0.35).timeout
	m._take_shot_now("b")
	await m.get_tree().create_timer(1.2).timeout
	m._take_shot_now("c")
	# Fabrik auswaehlen: Produktionsleiste
	for s in w.structures:
		if s.kind == "adf_factory":
			Game.budget[0] = 5000
			p.select_list([s])
			s.queue_unit("adf_mbt")
			s.queue_unit("adf_apc")
			s.queue_unit("adf_arty")
	await m.get_tree().create_timer(1.0).timeout
	m._take_shot_now("d")
	# Faehigkeit anvisieren
	p.begin_ability("airstrike")
	await m.get_tree().create_timer(0.8).timeout
	m._take_shot_now("e")
	m.get_tree().quit()
