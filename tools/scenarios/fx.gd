extends RefCounted
## Test-Szenario: Explosionen, Einsturz, Luftschlag, Hubschrauber. Aufruf: scenario=fx

static func run(m: Node) -> void:
	var w: World = m.world
	var rig: RtsCamera = m.rig
	await m.get_tree().create_timer(0.3).timeout
	# nahe Haeuser finden
	var target: Structure = null
	var best := 1e9
	for s in w.structures:
		if s.team == U.TEAM_CIV and s.kind_class == "house":
			var d := U.dist2d(s.position, Vector3(-20, 0, 25))
			if d < best:
				best = d
				target = s
	rig.jump_to(target.position)
	rig.target_dist = 42.0
	rig.dist = 42.0
	rig.yaw = 0.5
	rig.target_yaw = 0.5
	var c := target.position
	# ein paar Zivilisten + Einheiten dort
	for i in range(8):
		w.spawn_civilian(c + Vector3(randf_range(-12, 12), 0, randf_range(-12, 12)) + Vector3(0, 0, 10))
	w.spawn_unit("adf_mbt", 0, c + Vector3(-14, 0, 12))
	w.spawn_unit("adf_viper", 0, c + Vector3(-6, 0, 20))
	await m.get_tree().create_timer(1.0).timeout
	m._take_shot_now("a")
	# Luftschlag
	Game.budget[0] = 5000
	Game.use_ability(0, "airstrike", c)
	await m.get_tree().create_timer(3.4).timeout
	m._take_shot_now("b")
	await m.get_tree().create_timer(0.9).timeout
	m._take_shot_now("c")
	await m.get_tree().create_timer(1.5).timeout
	m._take_shot_now("d")
	await m.get_tree().create_timer(4.0).timeout
	m._take_shot_now("e")
	m.get_tree().quit()
