extends RefCounted
## Himmel und Horizont aus niedriger Kamera. Aufruf: autostart=0 scenario=sky

static func run(m: Node) -> void:
	var w: World = m.world
	await m.get_tree().create_timer(0.5).timeout
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 900.0
	w.add_child(cam)
	cam.global_position = Vector3(20, 22, 20)
	cam.look_at(Vector3(-60, 14, -140), Vector3.UP)
	cam.current = true
	await m.get_tree().create_timer(0.8).timeout
	m._take_shot_now("sky1")
	Atmosphere.apply_time(w.atmos, 0.75)
	await m.get_tree().create_timer(0.8).timeout
	m._take_shot_now("sky2")
	m.get_tree().quit()
