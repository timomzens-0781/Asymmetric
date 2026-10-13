extends Node
## Hauptszene: Titelbild (mit laufender KI-Schlacht im Hintergrund), Briefing, Spiel, Pause, Ende.

var world: World
var rig: RtsCamera
var player: PlayerController
var hud: Hud
var screens: Screens
var state := "title"       # title | briefing | playing | paused | ended
var side := 0
var difficulty := 1
var _demo_t := 0.0
var _demo_focus := Vector3(10, 0, 0)
var _args := {}
var _shot_list: Array = []
var _shot_i := 0
var _quit_after := -1.0
var _real_t := 0.0
var _seed := 1337
var _scenario_started := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	rig = RtsCamera.new()
	rig.name = "Camera"
	rig.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(rig)
	player = PlayerController.new()
	player.name = "Player"
	add_child(player)
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	screens = Screens.new()
	screens.name = "Screens"
	add_child(screens)
	hud.set_shown(false)
	screens.start_requested.connect(_on_start_requested)
	screens.begin_requested.connect(_on_begin)
	screens.restart_requested.connect(_on_restart)
	screens.menu_requested.connect(_to_title)
	screens.resume_requested.connect(_resume)
	player.pause_requested.connect(_pause)
	hud.pause_clicked.connect(_pause)
	hud.speed_changed.connect(func(m): Engine.time_scale = m)
	Game.match_ended.connect(_on_match_ended)
	if _args.has("autostart"):
		side = int(_args["autostart"])
		difficulty = int(_args.get("diff", 1))
		_start_match(side, difficulty, true)
	else:
		_to_title()

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if _args.has("shots"):
		for t in String(_args["shots"]).split(","):
			_shot_list.append(float(t))
	if _args.has("quit_after"):
		_quit_after = float(_args["quit_after"])

# ============================================================================= Weltverwaltung
func _clear_world() -> void:
	if world != null:
		world.queue_free()
		world = null
	Game.world = null
	get_tree().paused = false
	Engine.time_scale = 1.0

func _make_world(demo: bool, play_side: int) -> void:
	_clear_world()
	world = World.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.build(_seed, play_side, demo, 0.5 if demo else float(_args.get("tod", 0.0)))
	Game.world = world
	Game.start(play_side, difficulty, demo)
	# KI-Gegner (im Demo beide Seiten)
	for t in [0, 1]:
		if demo or t != play_side or _args.has("ai_both"):
			var ai: Node = AiAdf.new() if t == 0 else AiRebel.new()
			ai.set("world", world)
			ai.set("team", t)
			world.add_child(ai)
			world.ai_nodes.append(ai)
	world.shake_requested.connect(rig.on_shake)

func _to_title() -> void:
	state = "title"
	_make_world(true, 0)
	player.enabled = false
	player.selected = []
	hud.set_shown(false)
	rig.orbit_mode = true
	rig.enabled = false
	rig.target_dist = 96.0
	rig.dist = 96.0
	rig.jump_to(Vector3(8, 0, -6))
	_demo_focus = Vector3(8, 0, -6)
	screens.show_title()
	Sfx.start_music()
	Engine.time_scale = 1.0

func _on_start_requested(s: int, d: int) -> void:
	side = s
	difficulty = d
	_start_match(s, d, false)

func _start_match(s: int, d: int, skip_brief: bool) -> void:
	side = s
	difficulty = d
	_make_world(false, s)
	player.attach(world, rig, s)
	player.team = s
	player.selected = []
	player.groups.clear()
	player.set_mode("normal")
	hud.bind(world, player, rig, s)
	rig.orbit_mode = false
	rig.enabled = true
	rig.target_dist = 52.0
	rig.dist = 105.0
	rig.intro = 4.0
	rig.yaw = 0.0 if s == U.TEAM_ADF else 0.5
	rig.target_yaw = rig.yaw
	if s == U.TEAM_ADF:
		rig.jump_to(Vector3(-60, 0, 62))
	else:
		rig.jump_to(Vector3(40, 0, -45))
	if _args.has("cam"):
		var c := String(_args["cam"]).split(",")
		rig.jump_to(Vector3(float(c[0]), 0, float(c[1])))
		rig.target_dist = float(c[2])
		rig.dist = float(c[2])
		if c.size() > 3:
			rig.yaw = float(c[3])
			rig.target_yaw = rig.yaw
	if skip_brief:
		_on_begin()
	else:
		state = "briefing"
		player.enabled = false
		hud.set_shown(false)
		screens.show_briefing(s)
		get_tree().paused = true
	Sfx.start_music()

func _on_begin() -> void:
	screens.hide_all()
	state = "playing"
	get_tree().paused = false
	player.enabled = true
	hud.set_shown(true)
	Engine.time_scale = float(_args.get("speed", 1.0))
	Game.message("Einsatz beginnt. Viel Erfolg, Kommandeur.", "info", -1)
	Sfx.play_ui("ready")
	_show_tips(side)
	if _args.has("scenario") and not _scenario_started:
		_scenario_started = true
		var sc = load("res://tools/scenarios/%s.gd" % _args["scenario"])
		sc.run(self)

func _show_tips(s: int) -> void:
	var tips: Array = []
	if s == U.TEAM_ADF:
		tips = [
			"Tipp: Schicke die Argus-Drohne voraus – sie entlarvt Verdächtige aus der Luft.",
			"Tipp: Raketenabschüsse werden geortet. Prüfe vor dem Gegenschlag die Zivilisten im Radius!",
			"Tipp: Gelbes \"?\" über einem Kopf = Verdacht. Mit C kontrollierst du eine Person.",
			"Tipp: Kamera-Symbole zeigen Medien-Teams. Nicht schießen, wenn sie zusehen.",
		]
	else:
		tips = [
			"Tipp: Rechtsklick auf ein Haus – deine Kämpfer beziehen Stellung (Hinterhalt).",
			"Tipp: Stelle Medien-Teams in die Nähe des Geschehens und veröffentliche mit F1.",
			"Tipp: Raketenrampen (F = Feuerbefehl) provozieren – am besten aus belebten Vierteln.",
			"Tipp: G = zivile Tarnung, B = Sprengfalle, H = Feuer halten für den perfekten Hinterhalt.",
		]
	var i := 0
	for t in tips:
		i += 1
		var tm := get_tree().create_timer(4.0 + i * 7.0)
		tm.timeout.connect(func():
			if state == "playing":
				Game.message(t, "info", -1))

func _on_restart() -> void:
	_start_match(side, difficulty, false)

func _pause() -> void:
	if state != "playing":
		return
	state = "paused"
	get_tree().paused = true
	screens.show_pause()

func _resume() -> void:
	if state != "paused":
		return
	state = "playing"
	screens.hide_all()
	get_tree().paused = false

func _on_match_ended(res: Dictionary) -> void:
	if state != "playing":
		return
	state = "ended"
	await get_tree().create_timer(1.5, true, false, true).timeout
	if state != "ended":
		return
	get_tree().paused = true
	hud.set_shown(false)
	screens.show_end(res, side)
	Sfx.play_ui("level_up")

# ============================================================================= Schleife
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		var k := (ev as InputEventKey).keycode
		if k == KEY_ESCAPE and state == "paused":
			_resume()
		elif k == KEY_F11:
			var m := DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif k == KEY_PLUS or k == KEY_KP_ADD:
			Engine.time_scale = minf(Engine.time_scale + 0.5, 4.0)
		elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
			Engine.time_scale = maxf(Engine.time_scale - 0.5, 0.5)

func _process(dt: float) -> void:
	_real_t += dt
	if state == "title" and world != null:
		_demo_t -= dt
		if _demo_t <= 0.0:
			_demo_t = 7.0
			_pick_demo_focus()
		rig.target_focus = rig.target_focus.lerp(_demo_focus, 0.02)
	_handle_shots()

func _pick_demo_focus() -> void:
	# Kamera folgt dem Geschehen: zufaellige sichtbare ADF-Truppe oder Raketenwerfer
	var cands: Array = []
	for u in world.units:
		if u.alive and not u.is_civ and u.team == U.TEAM_ADF and u.layer != "air" and u.position.x > -50.0:
			cands.append(u)
	if cands.is_empty():
		_demo_focus = Vector3(8, 0, -6)
		return
	var u: Unit = cands[randi() % cands.size()]
	_demo_focus = Vector3(u.position.x, 0, u.position.z)
	rig.target_dist = randf_range(60.0, 96.0)

func _handle_shots() -> void:
	if _shot_i < _shot_list.size() and Game.time >= _shot_list[_shot_i] and (state == "playing" or state == "title"):
		_take_shot()
	if _quit_after > 0.0 and Game.time >= _quit_after:
		get_tree().quit()

func _take_shot_now(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s_%s.png" % [String(_args.get("shot", "/tmp/shot")), tag]
	img.save_png(path)
	print("shot saved: ", path)

func _take_shot() -> void:
	var idx := _shot_i
	_shot_i += 1
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s_%d.png" % [String(_args.get("shot", "/tmp/shot")), idx]
	img.save_png(path)
	print("shot saved: ", path, " t=", Game.time)
