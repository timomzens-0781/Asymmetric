extends RefCounted
## Zeigt die Tricks der Hadar-Front (Schutzschilde, Inszenierung, Rauch) und die Besatzungsleiste. Aufruf: autostart=1 scenario=tricks (als Hadar-Front starten)

static func run(m: Node) -> void:
	var w: World = m.world
	var rig: RtsCamera = m.rig
	await m.get_tree().create_timer(0.5).timeout
	Game.budget[1] = 5000.0
	var house: Structure = null
	for s in w.structures:
		if s.kind_class == "house" and s.team == U.TEAM_CIV and not s.hub and U.dist2d(s.position, w.hubs[0].position) < 60.0 and s.position.x > -20.0:
			house = s
			break
	if house == null:
		house = w.hubs[0]
	for i in range(3):
		var u := w.spawn_unit("reb_fighter", 1, house.door_pos(house.position))
		u.enter_garrison(house)
	var sn := w.spawn_unit("reb_sniper", 1, w.nav.nearest_free_pos(house.position + Vector3(10, 0, 4), "foot", 8))
	for i in range(6):
		w.spawn_civilian(w.nav.nearest_free_pos(house.position + Vector3(-8 + i * 3, 0, 12), "foot", 8))
	rig.focus = house.position
	rig.target_focus = house.position
	rig.dist = 55.0
	rig.target_dist = 55.0
	rig.intro = 0.0
	m.player.select_list([house])
	await m.get_tree().create_timer(0.8).timeout
	m._take_shot_now("house")
	Game.use_ability(1, "shield", house.position + Vector3(0, 0, 8))
	Game.use_ability(1, "smoke", house.position + Vector3(14, 0, -6))
	await m.get_tree().create_timer(4.0).timeout
	m._take_shot_now("shield")
	m.get_tree().quit()
