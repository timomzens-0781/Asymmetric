extends RefCounted
## Test-Szenario: simulierte Mauseingaben durch die komplette Eingabe-Pipeline.

static func click(m: Node, pos: Vector2, button: int = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
	m.get_viewport().warp_mouse(pos)
	await m.get_tree().process_frame
	await m.get_tree().process_frame
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = button
	ev.pressed = true
	ev.shift_pressed = shift
	Input.parse_input_event(ev)
	await m.get_tree().process_frame
	var ev2 := InputEventMouseButton.new()
	ev2.position = pos
	ev2.global_position = pos
	ev2.button_index = button
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await m.get_tree().process_frame
	await m.get_tree().process_frame

static func key(m: Node, code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await m.get_tree().process_frame
	var ev2 := InputEventKey.new()
	ev2.keycode = code
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await m.get_tree().process_frame

static func run(m: Node) -> void:
	var w: World = m.world
	var p: PlayerController = m.player
	var rig: RtsCamera = m.rig
	await m.get_tree().create_timer(0.8).timeout
	# Panzer anklicken
	var tank: Unit = null
	for u in w.units:
		if u.alive and u.kind == "adf_mbt":
			tank = u
			break
	var sp := rig.cam.unproject_position(tank.global_position + Vector3(0, 1.2, 0))
	print("tank screen pos ", sp, " enabled=", p.enabled, " world=", p.world != null, " ui_hover=", p.ui_hover, " tank visible=", tank.visible)
	m.get_viewport().warp_mouse(sp)
	await m.get_tree().process_frame
	await m.get_tree().process_frame
	print("mouse pos=", m.get_viewport().get_mouse_position(), " hover=", p.hover_entity, " ui_hover=", p.ui_hover)
	await click(m, sp)
	print("selected after click: ", p.selected.size(), " ", (p.selected[0].kind if p.selected.size() > 0 else "-"))
	# Rechtsklick auf Boden: Move
	var dest := rig.cam.unproject_position(tank.global_position + Vector3(12, 0, 8))
	await click(m, dest, MOUSE_BUTTON_RIGHT)
	print("order after rmb: ", tank.order_type, " path ", tank.path.size())
	await m.get_tree().create_timer(2.0).timeout
	print("tank moved to ", tank.position, " (start ", tank.home_pos, ")")
	# Box-Auswahl: Rahmen ueber alle Einheiten ziehen
	var a := Vector2(150, 150)
	var b := Vector2(1450, 600)
	m.get_viewport().warp_mouse(a)
	await m.get_tree().process_frame
	var d1 := InputEventMouseButton.new()
	d1.position = a
	d1.button_index = MOUSE_BUTTON_LEFT
	d1.pressed = true
	Input.parse_input_event(d1)
	await m.get_tree().process_frame
	m.get_viewport().warp_mouse(b)
	await m.get_tree().process_frame
	await m.get_tree().process_frame
	m._take_shot_now("drag")
	var d2 := InputEventMouseButton.new()
	d2.position = b
	d2.button_index = MOUSE_BUTTON_LEFT
	d2.pressed = false
	Input.parse_input_event(d2)
	await m.get_tree().process_frame
	print("box selected: ", p.selected.size())
	# T + Linksklick: Angriffsbewegung
	await key(m, KEY_T)
	print("mode after T: ", p.mode)
	await click(m, Vector2(900, 300))
	var n_am := 0
	for e in p.selected:
		if e is Unit and (e as Unit).order_type == "attack_move":
			n_am += 1
	print("attack_move units: ", n_am, " mode=", p.mode)
	# Fabrik anklicken und Panzer bauen
	var fac: Structure = null
	for s in w.structures:
		if s.kind == "adf_factory":
			fac = s
	rig.jump_to(fac.position)
	await m.get_tree().create_timer(0.6).timeout
	var fp := rig.cam.unproject_position(fac.global_position + Vector3(0, 3, 0))
	await click(m, fp)
	print("selected factory? ", p.selected.size(), " ", (p.selected[0].kind if p.selected.size() > 0 else "-"))
	if p.selected.size() > 0 and p.selected[0] is Structure:
		(p.selected[0] as Structure).queue_unit("adf_mbt")
		print("queue: ", (p.selected[0] as Structure).queue.size())
	await m.get_tree().create_timer(0.5).timeout
	m._take_shot_now("fac")
	# Faehigkeit per F-Taste, dann Klick
	Game.budget[0] = 4000
	await key(m, KEY_F3)
	print("mode after F3: ", p.mode, " ability=", p.ability_id)
	await click(m, Vector2(800, 400))
	print("airstrike cooldown: ", Game.cooldowns[0].get("airstrike", 0.0))
	await m.get_tree().create_timer(6.0).timeout
	m._take_shot_now("strike")
	m.get_tree().quit()
