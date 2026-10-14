extends RefCounted
## Zeigt alle Einheitenmodelle nebeneinander (Katalog-Screenshot).
static func run(m: Node) -> void:
	var w: World = m.world
	var rig: RtsCamera = m.rig
	await m.get_tree().create_timer(0.3).timeout
	# Bühne leeren
	for u in w.units.duplicate():
		if u.alive and not u.is_civ:
			u.queue_free()
			w.unregister(u)
		elif u.alive:
			u.queue_free()
			w.unregister(u)
	var base := Vector3(0, 0, 106)
	var adf := ["adf_rifle", "adf_recon", "adf_apc", "adf_mbt", "adf_arty", "adf_drone", "adf_viper"]
	var reb := ["reb_fighter", "reb_rpg", "reb_saboteur", "reb_media", "reb_tech", "reb_launcher"]
	var x := -18.0
	for k in adf:
		var u := w.spawn_unit(k, 0, base + Vector3(x, 0, -8))
		u.set_pos(base + Vector3(x, 0, -8))
		u.heading = 0.6
		u.set_process(false)
		u.model.rotation.y = 0.6
		x += 6.5
	x = -14.0
	for k in reb:
		var u := w.spawn_unit(k, 1, base + Vector3(x, 0, 4))
		u.conceal_pref = false
		u.concealed = false
		u.refresh_appearance()
		u.heading = 0.6
		u.set_process(false)
		u.model.rotation.y = 0.6
		x += 6.5
	# Zivilisten
	for i in range(5):
		var c := w.spawn_civilian(base + Vector3(-9 + i * 4.0, 0, 11))
		c.set_process(false)
	rig.focus = base
	rig.target_focus = base
	rig.target_dist = 30.0
	rig.dist = 30.0
	rig.yaw = 0.0
	rig.target_yaw = 0.0
	await m.get_tree().create_timer(1.0).timeout
	for u in w.units:
		if u.alive and u.position.z > 100.0:
			u.set_process(false)
	await m._take_shot_now("a")
	rig.target_dist = 20.0
	rig.dist = 20.0
	rig.focus = base + Vector3(-8, 0, -3)
	rig.target_focus = rig.focus
	await m.get_tree().create_timer(0.6).timeout
	await m._take_shot_now("b")
	rig.focus = base + Vector3(9, 0, 2)
	rig.target_focus = rig.focus
	await m.get_tree().create_timer(0.6).timeout
	await m._take_shot_now("c")
	m.get_tree().quit()
