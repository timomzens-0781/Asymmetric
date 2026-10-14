extends RefCounted
static func run(m: Node) -> void:
	var w: World = m.world
	await m.get_tree().create_timer(0.8).timeout
	m.rig.jump_to(Vector3(-40, 0, 40))
	m.rig.dist = 55.0
	m.rig.target_dist = 55.0
	var n := 0
	for u in w.units:
		if u.alive and u.team == 0 and u.kind == "adf_rifle":
			n += 1
			if n == 1:
				u.position = Vector3(-10, 0, 20)   # weiter weg
				u.take_damage(5.0, w.adf_proxy, "bullet")
			elif n == 2:
				u.position = Vector3(-62, 0, 30)
				u.take_damage(5.0, w.adf_proxy, "bullet")
			elif n == 3:
				u.take_damage(5.0, w.adf_proxy, "bullet")
	await m.get_tree().create_timer(0.6).timeout
	await m._take_shot_now("a")
	m.get_tree().quit()
