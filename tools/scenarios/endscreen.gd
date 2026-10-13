extends RefCounted
## Zeigt Endbildschirme (Sieg/Niederlage) und gibt Performance-Zahlen aus.
static func run(m: Node) -> void:
	await m.get_tree().create_timer(1.0).timeout
	m.rig.jump_to(Vector3(-20, 0, 20))
	m.rig.dist = 60.0
	m.rig.target_dist = 60.0
	await m.get_tree().create_timer(20.0).timeout
	print("PERF nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " drawcalls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " fps=", Performance.get_monitor(Performance.TIME_FPS), " process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	Game.add_outrage(100.0)
	await m.get_tree().create_timer(4.0).timeout
	await m._take_shot_now("lose")
	m._on_restart()
	await m.get_tree().create_timer(0.5).timeout
	m._on_begin()
	await m.get_tree().create_timer(0.5).timeout
	# Sieg: alle Tunnelknoten zerstoeren
	for h in m.world.hubs:
		h.take_damage(99999.0, m.world.adf_proxy, "he")
	await m.get_tree().create_timer(5.0).timeout
	await m._take_shot_now("win")
	m.get_tree().quit()
