extends RefCounted
## Test-Szenario: Kartenueberblick und offene Plaetze. Aufruf: scenario=overview

static func run(m: Node) -> void:
	var w: World = m.world
	var rig: RtsCamera = m.rig
	await m.get_tree().create_timer(0.3).timeout
	var views := [
		["all", Vector3(0, 0, 0), 125.0, 0.0],
		["base", w.city.base_assembly, 40.0, 0.5],
		["park", _c3(w.city.park_rect), 48.0, 0.3],
		["pitch", _c3(w.city.pitch_rect), 46.0, 0.2],
		["square", _c3(w.city.square_rect), 46.0, -0.3],
		["camp", _c3(w.city.camp_rect), 46.0, 0.4],
		["plaza", _c3(w.city.plaza_rect), 46.0, 0.0],
	]
	for v in views:
		var p: Vector3 = v[1]
		rig.jump_to(Vector3(p.x, 0, p.z))
		rig.target_dist = v[2]
		rig.dist = v[2]
		rig.yaw = v[3]
		rig.target_yaw = v[3]
		rig.intro = 0.0
		await m.get_tree().create_timer(0.6).timeout
		m._take_shot_now(String(v[0]))
		await m.get_tree().create_timer(0.2).timeout
	m.get_tree().quit()

static func _c3(r: Rect2) -> Vector3:
	var c := r.get_center()
	return Vector3(c.x, 0, c.y)
