extends RefCounted
## Sonderbefehle (Patrouille, Deckung, Verschanzen), Feldlazarett und Drohne aus Spielersicht. Aufruf: autostart=0 scenario=orders

static func run(m: Node) -> void:
	var w: World = m.world
	var rig: RtsCamera = m.rig
	Game.budget[0] = 9000.0
	await m.get_tree().create_timer(0.4).timeout
	var pc := w.city.pitch_rect.get_center()
	var base := Vector3(pc.x, 0, pc.y)
	Game.use_ability(0, "fieldhosp", base + Vector3(0, 0, -14))
	var sel: Array = []
	for i in range(4):
		var u := w.spawn_unit("adf_rifle", 0, base + Vector3(-6 + i * 3.0, 0, 6))
		sel.append(u)
	sel[0].cmd_entrench()
	sel[1].cmd_patrol([base + Vector3(-12, 0, 10), base + Vector3(12, 0, 10)])
	var dr := w.spawn_unit("adf_drone", 0, base + Vector3(0, 0, 20))
	dr.cmd_patrol([base + Vector3(-25, 0, 20), base + Vector3(25, 0, 25)])
	m.player.select_list([sel[1], sel[2], sel[3], dr])
	rig.focus = base
	rig.target_focus = base
	rig.dist = 46.0
	rig.target_dist = 46.0
	rig.yaw = 0.9
	rig.target_yaw = 0.9
	rig.intro = 0.0
	await m.get_tree().create_timer(4.0).timeout
	m._take_shot_now("orders1")
	m.player.select_list([sel[0], sel[1]])
	rig.dist = 24.0
	rig.target_dist = 24.0
	rig.focus = base + Vector3(0, 0, -6)
	rig.target_focus = rig.focus
	await m.get_tree().create_timer(1.0).timeout
	m._take_shot_now("orders2")
	m.get_tree().quit()
