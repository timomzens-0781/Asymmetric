extends RefCounted
## Zeigt Gebaeude-Verdacht und Durchsuchung aus Sicht von Aurelia. Aufruf: autostart=0 scenario=suspect

static func run(m: Node) -> void:
	var w: World = m.world
	var rig: RtsCamera = m.rig
	await m.get_tree().create_timer(0.5).timeout
	var hub: Structure = w.hubs[0]
	for st in w.structures:
		if st.kind_class == "house" and st.team == U.TEAM_CIV and not st.hub and U.dist2d(st.position, hub.position) < 40.0:
			hub = st
			break
	var p := w.nav.nearest_free_pos(hub.position + Vector3(hub.radius + 14.0, 0, 0), "foot", 8)
	for i in range(3):
		w.spawn_unit("adf_rifle", 0, w.nav.nearest_free_pos(p + Vector3(0, 0, i * 2.0), "foot", 8))
	w.spawn_unit("adf_recon", 0, w.nav.nearest_free_pos(p + Vector3(3, 0, 0), "foot", 8))
	hub.suspicion = 68.0
	rig.focus = hub.position
	rig.target_focus = hub.position
	rig.dist = 55.0
	rig.target_dist = 55.0
	rig.intro = 0.0
	m.player.select_list([hub])
	await m.get_tree().create_timer(1.0).timeout
	m._take_shot_now("marker")
	for u in w.units:
		if u.alive and u.team == 0 and u.kind == "adf_rifle":
			u.cmd_storm(hub)
	await m.get_tree().create_timer(5.0).timeout
	m._take_shot_now("search")
	m.get_tree().quit()
