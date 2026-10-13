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

func _base_pos() -> Vector3:
	return Vector3(-72.0, 0.0, 70.0)

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
	var grey := Color(0.5, 0.52, 0.55)
	mb.cyl(Vector3(0, 0, 0), 0.9, 0.35, 11.0, grey, 8, 2)
	mb.sphere(Vector3(0, 0.45, 2.8), 0.6, Color(0.1, 0.16, 0.2), Vector3(0.8, 0.7, 1.7), 4, 8)
	mb.extrude([Vector2(0, 3.5), Vector2(-7.0, -3.8), Vector2(7.0, -3.8)], -0.1, 0.18, grey * 0.95)
	mb.box(Vector3(0, 1.0, -4.4), Vector3(0.12, 1.8, 1.8), grey)
	mb.box(Vector3(-1.0, 0.8, -4.2), Vector3(0.12, 1.5, 1.6), grey)
	mb.box(Vector3(1.0, 0.8, -4.2), Vector3(0.12, 1.5, 1.6), grey)
	mb.box(Vector3(0, 0.0, -5.6), Vector3(0.9, 0.9, 0.3), Color(0.15, 0.1, 0.08))
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
		jet.look_at(jet.position + dir, Vector3.UP)
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
				s.revealed = true
				hubs_found += 1
	if hubs_found > 0:
		Game.message("Aufklärung: %d Tunnelsignatur(en) entdeckt!" % hubs_found, "good", U.TEAM_ADF)
	elif found > 0:
		Game.message("Aufklärung: %d verdächtige Personen markiert" % found, "good", U.TEAM_ADF)
	else:
		Game.message("Aufklärung: nichts Auffälliges", "info", U.TEAM_ADF)
