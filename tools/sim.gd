extends Node
## Headless-Simulation: godot --headless --fixed-fps 30 --path . tools/sim.tscn -- seconds=120 side=0 speed=4
var world: World
var sim_seconds := 60.0
var report_every := 15.0
var _next_report := 15.0
var side := 0
var demo := true

func _ready() -> void:
	var speed := 4.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seconds="):
			sim_seconds = float(a.substr(8))
		elif a.begins_with("speed="):
			speed = float(a.substr(6))
		elif a.begins_with("side="):
			side = int(a.substr(5))
		elif a.begins_with("demo="):
			demo = a.substr(5) == "1"
	Engine.time_scale = speed
	var gm := get_node("/root/Game")
	world = World.new()
	world.name = "World"
	add_child(world)
	var t0 := Time.get_ticks_msec()
	world.build(1337, side, demo)
	print("world built in ", Time.get_ticks_msec() - t0, " ms: units=", world.units.size(), " structures=", world.structures.size(), " hubs=", world.hubs.size())
	gm.world = world
	gm.start(side, 1, demo)
	if ResourceLoader.exists("res://scripts/ai/ai_adf.gd"):
		var a = load("res://scripts/ai/ai_adf.gd").new()
		a.world = world
		a.team = 0
		world.add_child(a)
		world.ai_nodes.append(a)
		var b = load("res://scripts/ai/ai_rebel.gd").new()
		b.world = world
		b.team = 1
		world.add_child(b)
		world.ai_nodes.append(b)
	gm.match_ended.connect(func(r): print("MATCH ENDED: ", r))

func _process(_dt: float) -> void:
	var gm := get_node("/root/Game")
	if gm.time >= _next_report:
		_next_report += report_every
		_report(gm)
	if gm.time >= sim_seconds or gm.ended:
		_report(gm)
		print("final stats: ", gm.stats)
		get_tree().quit()

func _report(gm) -> void:
	var adf := 0
	var reb := 0
	var civ := 0
	var conc := 0
	for u in world.units:
		if not u.alive:
			continue
		if u.team == 0:
			adf += 1
		elif u.team == 1:
			reb += 1
			if u.concealed:
				conc += 1
		else:
			civ += 1
	for u in world.units:
		if u.alive and u.kind == "reb_launcher":
			print("   launcher @", u.position, " data=", u.ai_data, " order=", u.order_type, " path=", u.path.size(), "/", u.path_i, " conc=", u.concealed, " cd=", u.weapons[0].cdl)
	print("t=%d adf=%d reb=%d(conc %d) civ=%d hubs=%d outrage=%.1f footage=%.1f budget=[%d,%d] level=%d fps=%d" % [gm.time, adf, reb, conc, civ, gm.alive_hubs(), gm.outrage, gm.footage, gm.budget[0], gm.budget[1], gm.level, Engine.get_frames_per_second()])
