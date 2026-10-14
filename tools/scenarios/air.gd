extends RefCounted
## Test-Szenario: Luftfahrzeuge aus der Naehe. Aufruf: scenario=air

static func run(m: Node) -> void:
	var w: World = m.world
	var rig: RtsCamera = m.rig
	await m.get_tree().create_timer(0.3).timeout
	var pc := w.city.pitch_rect.get_center()
	var c := Vector3(pc.x, 0, pc.y)
	var v := w.spawn_unit("adf_viper", 0, c)
	var d := w.spawn_unit("adf_drone", 0, c + Vector3(-22, 0, 8))
	var jet: Node3D = w.support._jet_model()
	jet.position = c + Vector3(12, 12, 30)
	jet.rotation.y = 0.8
	jet.scale = Vector3(1.0, 1.0, 1.0)
	w.add_child(jet)
	var views := [
		["v1", v.position + Vector3(0, 11, 0), 16.0, 0.6],
		["v2", v.position + Vector3(0, 11, 0), 14.0, 2.6],
		["v3", v.position + Vector3(0, 11, 0), 20.0, 4.4],
		["d1", d.position + Vector3(0, 16, 0), 18.0, 0.5],
		["d2", d.position + Vector3(0, 16, 0), 15.0, 3.0],
		["j1", jet.position, 24.0, 0.2],
	]
	for vw in views:
		var p: Vector3 = vw[1]
		rig.target_dist = vw[2]
		rig.dist = vw[2]
		rig.yaw = vw[3]
		rig.target_yaw = vw[3]
		rig.intro = 0.0
		rig.focus = p
		rig.target_focus = p
		await m.get_tree().create_timer(0.5).timeout
		m._take_shot_now(String(vw[0]))
		await m.get_tree().create_timer(0.1).timeout
	m.get_tree().quit()
