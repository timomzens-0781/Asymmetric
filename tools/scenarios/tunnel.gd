extends RefCounted
## Zeigt das Tunnelnetz aus Sicht der Hadar-Front. Aufruf: autostart=1 scenario=tunnel

static func run(m: Node) -> void:
	var w: World = m.world
	var rig: RtsCamera = m.rig
	await m.get_tree().create_timer(0.5).timeout
	var hub: Structure = w.hubs[0]
	var far: Structure = w.hubs[0]
	for h in w.hubs:
		if U.dist2d(h.position, hub.position) > U.dist2d(far.position, hub.position):
			far = h
	var mid := (hub.position + far.position) * 0.5
	rig.focus = mid
	rig.target_focus = mid
	rig.dist = 150.0
	rig.target_dist = 150.0
	rig.intro = 0.0
	m.player.select_list([hub])
	await m.get_tree().create_timer(0.7).timeout
	m._take_shot_now("sel")
	m.player.set_mode("tunnel")
	await m.get_tree().create_timer(0.4).timeout
	for u in hub.garrisoned.duplicate():
		(u as Unit).cmd_tunnel(far)
	await m.get_tree().create_timer(3.0).timeout
	m._take_shot_now("travel")
	m.get_tree().quit()
