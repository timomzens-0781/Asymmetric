extends SceneTree
## Entwicklungs-Tool: baut nur die Stadt und macht Screenshots.
## Aufruf: godot --rendering-driver opengl3 --path . -s tools/shot_city.gd -- out_prefix

var root_node: Node3D

func _initialize() -> void:
	root_node = Node3D.new()
	root.add_child(root_node)
	var nav := Nav.new()
	var city := City.new()
	root_node.add_child(city)
	var t0 := Time.get_ticks_msec()
	city.generate(1337, nav)
	print("city generated in ", Time.get_ticks_msec() - t0, " ms; buildings=", city.buildings.size())
	Atmosphere.setup(root_node)
	var cam := Camera3D.new()
	cam.fov = 45
	cam.far = 900
	root_node.add_child(cam)
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "/tmp/shot"
	var views := [
		[Vector3(-30, 55, 60), Vector3(-30, 0, 10), "a"],
		[Vector3(40, 28, -10), Vector3(40, 0, -45), "b"],
		[Vector3(-45, 40, 120), Vector3(-65, 0, 70), "c"],
		[Vector3(90, 130, 120), Vector3(0, 0, 0), "d"],
	]
	await process_frame
	await process_frame
	for v in views:
		cam.position = v[0]
		cam.look_at(v[1])
		for i in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s_%s.png" % [prefix, v[2]])
		print("saved ", v[2])
	quit()
