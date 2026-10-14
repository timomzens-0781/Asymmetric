extends RefCounted
## Hilfsmassnahmen aus Sicht von Aurelia + Performance-Zahlen. Aufruf: autostart=0 scenario=aid

static func run(m: Node) -> void:
	var w: World = m.world
	var rig: RtsCamera = m.rig
	Game.budget[0] = 9000.0
	await m.get_tree().create_timer(0.5).timeout
	var c := w.city.park_rect.get_center()
	var center := Vector3(c.x - 30.0, 0, c.y - 10.0)
	var cell := w.district_of(center)
	w.anger[cell.y * w.dist_n + cell.x] = 72.0
	w.add_anger(center + Vector3(40, 0, 0), 40.0)
	Game.use_ability(0, "fieldhosp", Vector3(c.x, 0, c.y + 18.0))
	Game.use_ability(0, "corridor", center + Vector3(-20, 0, 15))
	rig.focus = center
	rig.target_focus = center
	rig.dist = 90.0
	rig.target_dist = 90.0
	rig.intro = 0.0
	await m.get_tree().create_timer(4.0).timeout
	print("PERF nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " drawcalls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " fps=", Performance.get_monitor(Performance.TIME_FPS))
	m._take_shot_now("aid1")
	rig.dist = 40.0
	rig.target_dist = 40.0
	rig.focus = Vector3(c.x, 0, c.y + 18.0)
	rig.target_focus = rig.focus
	await m.get_tree().create_timer(1.0).timeout
	m._take_shot_now("aid2")
	m.get_tree().quit()
