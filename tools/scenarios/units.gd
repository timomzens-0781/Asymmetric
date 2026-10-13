extends RefCounted
## Zeigt alle Einheitenmodelle nebeneinander (Katalog-Screenshot).
static func run(m: Node) -> void:
	var w: World = m.world
	var rig: RtsCamera = m.rig
	await m.get_tree().create_timer(0.3).timeout
	# Bühne leeren
	for u in w.units.duplicate():
		if u.alive and not u.is_civ and u.team == 1:
			u.queue_free()
			w.unregister(u)
	var base := Vector3(14, 0, 22)
	var adf := ["adf_rifle", "adf_recon", "adf_apc", "adf_mbt", "adf_arty", "adf_drone", "adf_viper"]
	var reb := ["reb_fighter", "reb_rpg", "reb_saboteur", "reb_media", "reb_tech", "reb_launcher"]
	var x := -18.0
	for k in adf:
		var u := w.spawn_unit(k, 0, base + Vector3(x, 0, -8))
		u.set_pos(base + Vector3(x, 0, -8))
		u.heading = 0.6
		x += 6.5
	x = -14.0
	for k in reb:
		var u := w.spawn_unit(k, 1, base + Vector3(x, 0, 4))
		u.conceal_pref = false
		u.concealed = false
		u.refresh_appearance()
		u.heading = 0.6
		x += 6.5
	# Zivilisten
	for i in range(6):
		var c := w.spawn_civilian(base + Vector3(-16 + i * 3.0, 0, 14))
		c._civ_wait = 999.0
	rig.jump_to(base + Vector3(0, 0, 0))
	rig.target_dist = 34.0
	rig.dist = 34.0
	rig.yaw = 0.0
	rig.target_yaw = 0.0
	await m.get_tree().create_timer(1.0).timeout
	for u in w.units:
		if u.alive and not u.is_civ:
			u.hold = true
			u.order_type = "idle"
			u.path = PackedVector3Array()
	m._take_shot_now("a")
	rig.target_dist = 20.0
	rig.dist = 20.0
	rig.jump_to(base + Vector3(-8, 0, -3))
	await m.get_tree().create_timer(0.6).timeout
	m._take_shot_now("b")
	rig.jump_to(base + Vector3(8, 0, 2))
	await m.get_tree().create_timer(0.6).timeout
	m._take_shot_now("c")
	m.get_tree().quit()
