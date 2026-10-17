extends RefCounted
## Nahaufnahmen von Gebaeuden mit Fassadendetails (Balkone, Erker, Staffelgeschoss). Aufruf: autostart=0 scenario=facades

static func run(m: Node) -> void:
	var w: World = m.world
	var rig: RtsCamera = m.rig
	await m.get_tree().create_timer(0.5).timeout
	var picks: Array = []
	var seen_old := false
	for b in w.city.buildings:
		var node: Node3D = b.node
		if node == null or b.kind != "house":
			continue
		var n := node.get_child_count()
		if n >= 5 and picks.size() < 2 and not (b.zone in ["old", "old_s"]):
			picks.append(b)
		elif n >= 4 and (b.zone in ["old", "old_s"]) and not seen_old:
			seen_old = true
			picks.append(b)
	var i := 0
	for b in picks:
		var c: Vector3 = b.center
		rig.focus = c
		rig.target_focus = c
		rig.dist = 38.0
		rig.target_dist = 38.0
		rig.yaw = 0.6 + i * 1.3
		rig.target_yaw = rig.yaw
		rig.intro = 0.0
		await m.get_tree().create_timer(1.2).timeout
		m._take_shot_now("f%d" % i)
		i += 1
	m.get_tree().quit()
