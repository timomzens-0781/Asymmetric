extends RefCounted
## Test-Szenario: Spielfluss (Eskalationsstufen, Endbildschirm, Neustart, Rebellen-Seite).

static func run(m: Node) -> void:
	var w: World = m.world
	await m.get_tree().create_timer(1.0).timeout
	Game.add_outrage(40.0)
	await m.get_tree().create_timer(1.2).timeout
	m._take_shot_now("l1")
	Game.add_outrage(30.0)
	await m.get_tree().create_timer(1.2).timeout
	m._take_shot_now("l2")
	print("level=", Game.level, " nofly=", Game.no_fly_zone())
	await m.get_tree().create_timer(3.0).timeout
	Game.add_outrage(40.0)
	await m.get_tree().create_timer(4.0).timeout
	print("state=", m.state)
	m._take_shot_now("end")
	m._on_restart()
	await m.get_tree().create_timer(0.5).timeout
	m._on_begin()
	await m.get_tree().create_timer(2.0).timeout
	print("restarted OK, units=", m.world.units.size())
	m._to_title()
	await m.get_tree().create_timer(2.0).timeout
	m._start_match(1, 1, true)
	await m.get_tree().create_timer(2.0).timeout
	# Rebellen: Tunnelknoten anwaehlen, produzieren
	var w2: World = m.world
	var hub: Structure = w2.hubs[0]
	m.player.select_list([hub])
	Game.budget[1] = 3000
	hub.queue_unit("reb_fighter")
	hub.queue_unit("reb_media")
	hub.queue_unit("reb_launcher")
	m.rig.jump_to(hub.position)
	m.rig.target_dist = 40.0
	m.rig.dist = 40.0
	await m.get_tree().create_timer(1.5).timeout
	m._take_shot_now("reb1")
	await m.get_tree().create_timer(14.0).timeout
	m._take_shot_now("reb2")
	m.get_tree().quit()
