class_name PlayerController
extends Node
## Spielereingaben: Auswahl, Befehle, Formationen, Zielmodi fuer Faehigkeiten, Kontrollgruppen.

signal selection_changed
signal mode_changed
signal pause_requested

var world: World
var rig: RtsCamera
var team := 0
var selected: Array = []
var mode := "normal"          # normal | attack_move | ability | fire_ground | check | tunnel | patrol | storm
var patrol_wps: Array = []     # waehrend der Patrouillen-Eingabe gesetzte Wegpunkte
var ability_id := ""
var groups: Dictionary = {}
var dragging := false
var drag_start := Vector2.ZERO
var drag_rect := Rect2()
var hover_entity: Entity = null
var hover_ground := Vector3.ZERO
var hover_valid := false
var target_info: Dictionary = {}
var last_alert_pos := Vector3.ZERO
var ui_hover := false
var enabled := true
var _cursor_ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _last_click_ms := 0
var _last_click_kind := ""
var _group_tap_ms := 0
var _group_tap_n := -1

func _ready() -> void:
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_texture = Gfx.ring_tex(128, 0.06)
	_ring_mat.albedo_color = Color(1.0, 0.6, 0.2, 0.9)
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_mat.no_depth_test = true
	_cursor_ring = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	_cursor_ring.mesh = pm
	_cursor_ring.material_override = _ring_mat
	_cursor_ring.visible = false
	_cursor_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cursor_ring)
	Game.alert.connect(func(pos, _k): last_alert_pos = pos)

func attach(w: World, r: RtsCamera, t: int) -> void:
	world = w
	rig = r
	team = t
	if not world.entity_deselected.is_connected(_on_entity_deselected):
		world.entity_deselected.connect(_on_entity_deselected)

func _exit_tree() -> void:
	if is_instance_valid(_cursor_ring):
		_cursor_ring.queue_free()

func _on_entity_deselected(e: Entity) -> void:
	if e in selected:
		selected.erase(e)
		selection_changed.emit()

# ============================================================================= Hover
func _process(_dt: float) -> void:
	if world == null or rig == null or not enabled:
		return
	selected = selected.filter(func(e): return is_instance_valid(e) and e.alive)
	var mp := get_viewport().get_mouse_position()
	if ui_hover:
		hover_entity = null
		hover_valid = false
		_cursor_ring.visible = false
		return
	hover_ground = rig.ground_point(mp)
	hover_valid = true
	hover_entity = pick_at(mp)
	if mode == "ability" or mode == "fire_ground":
		_update_target_ring()
	else:
		_cursor_ring.visible = false
	if dragging:
		drag_rect = Rect2(drag_start, mp - drag_start).abs()

func _update_target_ring() -> void:
	var d: Dictionary = Data.ABILITIES.get(ability_id, {}) if mode == "ability" else {}
	var r: float = d.get("radius", 4.0) if mode == "ability" else 3.0
	_cursor_ring.visible = true
	_cursor_ring.position = hover_ground + Vector3(0, 0.35, 0)
	_cursor_ring.scale = Vector3(maxf(r, 1.0), 1, maxf(r, 1.0))
	target_info = {}
	if mode == "ability" and ability_id in ["airstrike", "precision", "salvo"]:
		target_info = risk_info(hover_ground, r)
		var danger: float = target_info.civs
		_ring_mat.albedo_color = Color(1.0, 0.25, 0.2, 0.9) if danger > 6 else (Color(1.0, 0.75, 0.2, 0.9) if danger > 0 else Color(0.4, 1.0, 0.5, 0.9))
	elif mode == "ability" and ability_id in ["scan", "convoy", "fieldhosp", "corridor"]:
		_ring_mat.albedo_color = Color(0.3, 0.9, 1.0, 0.9)
	elif mode == "ability":
		_ring_mat.albedo_color = Color(1.0, 0.9, 0.3, 0.9)
	else:
		_ring_mat.albedo_color = Color(1.0, 0.6, 0.2, 0.9)

## Schaetzung der Zivilisten und Kameras im Wirkradius (nur, was der Spieler sehen/vermuten kann).
func risk_info(pos: Vector3, r: float) -> Dictionary:
	var civs := 0.0
	var cams := false
	var sensitive := false
	for o in world.dyn.query(pos, r + 3.0):
		if not o.alive or not (o is Unit):
			continue
		var u := o as Unit
		if U.dist2d(u.position, pos) > r + u.radius:
			continue
		if u.is_civ and u.visible:
			civs += 1.0
		if u.press and u.visible:
			cams = true
		elif u.team == U.TEAM_REB and u.concealed and u.visible:
			civs += 1.0   # verdeckte Kaempfer sind von Zivilisten nicht zu unterscheiden
	for s in world.structures:
		if s.alive and s.team != team and s.edge_dist(pos) < r:
			civs += s.occupants * (0.85 if s.revealed or s.hot_t > 0.0 or s.kind_class != "house" else 0.85)
			if s.kind_class in ["hospital", "school"]:
				sensitive = true
	return {"civs": civs, "cams": cams, "sensitive": sensitive, "r": r}

# ============================================================================= Picking
func pick_at(sp: Vector2) -> Entity:
	var o := rig.cam.project_ray_origin(sp)
	var d := rig.cam.project_ray_normal(sp)
	var best: Entity = null
	var best_t := 1e9
	for e in world.all_entities:
		if not e.alive or not e.visible:
			continue
		var t := -1.0
		if e is Structure:
			var s := e as Structure
			t = _ray_box(o, d, Vector3(s.position.x, s.size.y * 0.5, s.position.z), Vector3(s.hx, s.size.y * 0.5, s.hz))
		elif e is Unit:
			var u := e as Unit
			var c := u.position + Vector3(0, (u.air_h + 1.4) if u.layer == "air" else (1.1 if u.layer == "foot" else 1.2), 0)
			var dist := rig.cam.global_position.distance_to(c)
			var r := maxf(u.radius * 0.95, 0.9) + dist * 0.014
			t = _ray_sphere(o, d, c, r)
		elif e is Mine:
			var c2: Vector3 = e.position + Vector3(0, 0.3, 0)
			t = _ray_sphere(o, d, c2, 1.0)
		if t > 0.0 and t < best_t:
			# Einheiten haben Vorrang vor Gebaeuden knapp dahinter
			best_t = t
			best = e
	return best

func _ray_sphere(o: Vector3, d: Vector3, c: Vector3, r: float) -> float:
	var oc := o - c
	var b := oc.dot(d)
	var cc := oc.dot(oc) - r * r
	var disc := b * b - cc
	if disc < 0.0:
		return -1.0
	var t := -b - sqrt(disc)
	return t if t > 0.0 else -1.0

func _ray_box(o: Vector3, d: Vector3, c: Vector3, h: Vector3) -> float:
	var tmin := 0.0
	var tmax := 1e9
	for i in range(3):
		var oi: float = o[i] - c[i]
		var di: float = d[i]
		if absf(di) < 1e-8:
			if absf(oi) > h[i]:
				return -1.0
		else:
			var t1 := (-h[i] - oi) / di
			var t2 := (h[i] - oi) / di
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return -1.0
	return tmin if tmin > 0.0 else -1.0

# ============================================================================= Eingabe
func _unhandled_input(ev: InputEvent) -> void:
	if world == null or not enabled or world.paused:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_left_press(mb)
			else:
				_left_release(mb)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_right_click(mb)
	elif ev is InputEventKey:
		var k := ev as InputEventKey
		if k.pressed and not k.echo:
			_key(k)

func _left_press(mb: InputEventMouseButton) -> void:
	if mode == "ability":
		var shift := Input.is_key_pressed(KEY_SHIFT)
		var id := ability_id
		if Game.use_ability(team, id, hover_ground):
			Sfx.play_ui("click")
			if not shift:
				set_mode("normal")
		else:
			Sfx.play_ui("error")
		return
	if mode == "fire_ground":
		var n := 0
		for u in _own_units():
			if u.manual_only and not u.weapons.is_empty():
				u.cmd_attack_ground(hover_ground)
				n += 1
		world.fx.ring_ping(hover_ground, 5.0, Color(1.0, 0.5, 0.2, 0.9), 0.9)
		Sfx.play_ui("click")
		set_mode("normal")
		return
	if mode == "check":
		var tgt := hover_entity
		if tgt is Unit and tgt.team != team or (tgt is Civilian):
			var best: Unit = null
			var bd := 1e9
			for u in _own_units():
				if u.detect_range > 0.0 and u.layer == "foot":
					var d := U.dist2d(u.position, tgt.position)
					if d < bd:
						bd = d
						best = u
			if best != null:
				best.cmd_check(tgt as Unit)
				world.fx.ring_ping(tgt.position, 2.0, Color(1.0, 0.9, 0.3, 0.9), 0.8)
				Sfx.play_ui("click")
		set_mode("normal")
		return
	if mode == "tunnel":
		var dest := hover_entity
		if dest is Structure and (dest as Structure).hub and dest.team == team:
			var sent := 0
			for h in _own_structures():
				if not (h as Structure).hub or h == dest:
					continue
				for u in (h as Structure).garrisoned.duplicate():
					if u is Unit and (u as Unit).cmd_tunnel(dest as Structure):
						sent += 1
			if sent > 0:
				world.fx.ring_ping(dest.position, dest.radius + 2.0, Color(1.0, 0.7, 0.25, 0.9), 0.9)
				Sfx.play_ui("click")
				Game.message("%d Kämpfer reisen durch den Tunnel" % sent, "good", team)
			else:
				Sfx.play_ui("error")
				Game.message("Tunnelreise nicht möglich: keine Verbindung, kein Platz, keine Besatzung – oder die Kämpfer ruhen noch", "warn", team)
		set_mode("normal")
		return
	if mode == "storm":
		var tgt_s := hover_entity
		if tgt_s is Structure and (tgt_s as Structure).kind_class in ["hospital", "school"]:
			Game.message("Kliniken und Schulen werden nicht gestürmt!", "warn", team)
			Sfx.play_ui("error")
		elif tgt_s is Structure and (tgt_s as Structure).kind_class == "house" and tgt_s.team != team:
			var n_st := 0
			for u in _own_units():
				if u.layer == "foot" and u.cmd_storm(tgt_s as Structure):
					n_st += 1
			if n_st > 0:
				world.fx.ring_ping(tgt_s.position, tgt_s.radius + 1.5, Color(1.0, 0.35, 0.3, 0.9), 0.9)
				Sfx.play_ui("click")
				Game.message("%d Soldaten stürmen das Haus" % n_st, "info", team)
			else:
				Sfx.play_ui("error")
		set_mode("normal")
		return
	if mode == "patrol":
		patrol_wps.append(hover_ground)
		world.fx.ring_ping(hover_ground, 2.2, Color(0.4, 0.8, 1.0, 0.9), 0.7)
		Sfx.play_ui("click", -6.0)
		if Input.is_key_pressed(KEY_SHIFT):
			return     # weitere Wegpunkte; Klick ohne Shift beendet die Eingabe
		_issue_patrol(_own_units(), patrol_wps)
		set_mode("normal")
		return
	if mode == "attack_move":
		var us := _own_units()
		_formation_order(us, hover_ground, true)
		world.fx.ring_ping(hover_ground, 3.0, Color(1.0, 0.35, 0.3, 0.9), 0.7)
		set_mode("normal")
		return
	dragging = true
	drag_start = mb.position
	drag_rect = Rect2(mb.position, Vector2.ZERO)

func _left_release(mb: InputEventMouseButton) -> void:
	if not dragging:
		return
	dragging = false
	var additive := Input.is_key_pressed(KEY_SHIFT)
	if drag_rect.size.length() < 8.0:
		_click_select(mb.position, additive)
	else:
		_box_select(drag_rect, additive)
	drag_rect = Rect2()

func _click_select(sp: Vector2, additive: bool) -> void:
	var e := pick_at(sp)
	var now := Time.get_ticks_msec()
	if e == null:
		if not additive:
			select_list([])
		return
	var kind := e.kind
	var dbl := now - _last_click_ms < 350 and kind == _last_click_kind
	_last_click_ms = now
	_last_click_kind = kind
	if dbl and e is Unit and e.team == team:
		# Doppelklick: alle gleichen Einheiten auf dem Bildschirm
		var same: Array = []
		var vp := get_viewport().get_visible_rect()
		for u in world.units:
			if u.alive and u.visible and u.team == team and u.kind == kind and not rig.cam.is_position_behind(u.global_position):
				if vp.has_point(rig.cam.unproject_position(u.global_position)):
					same.append(u)
		select_list(same, additive)
		return
	if additive and e in selected:
		var arr := selected.duplicate()
		arr.erase(e)
		select_list(arr)
		return
	var list: Array = [e]
	if additive and e.team == team:
		list = selected.filter(func(x): return x.team == team)
		list.append(e)
	select_list(list)

func _box_select(r: Rect2, additive: bool) -> void:
	var list: Array = []
	for u in world.units:
		if not u.alive or not u.visible or u.team != team or u.is_civ:
			continue
		if rig.cam.is_position_behind(u.global_position + Vector3(0, 1, 0)):
			continue
		var sp := rig.cam.unproject_position(u.global_position + Vector3(0, 1.0 + (u.air_h if u.layer == "air" else 0.0), 0))
		if r.has_point(sp):
			list.append(u)
	if list.is_empty():
		return
	if additive:
		for e in selected:
			if e.team == team and e not in list:
				list.append(e)
	select_list(list)

func select_list(list: Array, additive: bool = false) -> void:
	if additive:
		for e in selected:
			if e not in list:
				list.append(e)
	for e in selected:
		if is_instance_valid(e) and e not in list:
			e.set_selected(false)
	for e in list:
		if is_instance_valid(e):
			e.set_selected(true)
	selected = list
	selection_changed.emit()
	if not list.is_empty():
		Sfx.play_ui("click", -8.0)

func _own_units() -> Array:
	var a: Array = []
	for e in selected:
		if is_instance_valid(e) and e.alive and e is Unit and e.team == team and not (e as Unit).is_civ:
			a.append(e)
	return a

func _own_structures() -> Array:
	var a: Array = []
	for e in selected:
		if is_instance_valid(e) and e.alive and e is Structure and (e.team == team or not (e as Structure).garrison_of(team).is_empty()):
			a.append(e)
	return a

# ----------------------------------------------------------------------------- Befehle
func _right_click(mb: InputEventMouseButton) -> void:
	if mode != "normal":
		set_mode("normal")
		return
	var units := _own_units()
	var e := hover_entity
	if units.is_empty():
		# Haus mit eigener Besatzung gewaehlt: Rechtsklick fuehrt die Besatzung heraus (Marsch-/Angriffsbefehl)
		for st in _own_structures():
			if not (st as Structure).hub and (st as Structure).produces.is_empty():
				units.append_array((st as Structure).garrison_of(team))
		if not units.is_empty():
			units = units.filter(func(u): return u is Unit and not (u as Unit).is_civ)
	if units.is_empty():
		# Gebaeude: Sammelpunkt setzen (Rechtsklick auf anderen Tunnelknoten: Tunnel-Sammelpunkt)
		if e is Structure and (e as Structure).hub and e.team == team and team == U.TEAM_REB:
			var n_set := 0
			for s in _own_structures():
				if s.hub and s != e and not world.tunnel_route(s, e as Structure).is_empty():
					s.rally_hub = e as Structure
					n_set += 1
			if n_set > 0:
				world.fx.ring_ping(e.position, e.radius + 2.0, Color(1.0, 0.7, 0.25, 0.9), 0.9)
				Game.message("Tunnel-Sammelpunkt gesetzt: neue Kämpfer reisen unterirdisch dorthin", "info", team)
				return
		for s in _own_structures():
			if not s.produces.is_empty():
				s.rally_hub = null
				s.rally = hover_ground
				world.fx.ring_ping(hover_ground, 2.2, Color(0.4, 1.0, 0.5, 0.9), 0.8)
		return
	var force := Input.is_key_pressed(KEY_CTRL)
	if e != null and e.team != team and (force or _is_attackable(e)):
		var armed: Array = units.filter(func(u): return not u.weapons.is_empty())
		if not armed.is_empty():
			var storm_it: bool = e is Structure and (e as Structure).kind_class == "house" and team == U.TEAM_ADF
			var n_storm := 0
			for u in armed:
				if storm_it and u.layer == "foot" and u.cmd_storm(e as Structure):
					n_storm += 1
				else:
					u.cmd_attack(e)
			if n_storm > 0:
				Game.message("%d Soldaten stürmen das Haus" % n_storm, "info", team)
			world.fx.ring_ping(e.position, maxf(e.radius * 1.4, 2.0), Color(1.0, 0.3, 0.25, 0.9), 0.6)
			Sfx.play_ui("click", -6.0)
			return
	if e != null and e is Structure and team == U.TEAM_REB and (e.team == U.TEAM_CIV or e.team == U.TEAM_REB) and e.kind_class != "base":
		var any := false
		for u in units:
			if u.can_conceal:
				u.cmd_garrison(e)
				any = true
		if any:
			world.fx.ring_ping(e.position, e.radius + 1.0, Color(0.4, 1.0, 0.5, 0.9), 0.7)
			return
	_formation_order(units, hover_ground, false)
	world.fx.ring_ping(hover_ground, 1.8, Color(0.4, 1.0, 0.5, 0.9), 0.6)

## Patrouille: jede Einheit pendelt zwischen ihrem Startpunkt und den Wegpunkten (Gruppenform bleibt erhalten).
func _issue_patrol(units: Array, wps: Array) -> void:
	var can: Array = units.filter(func(u): return u.can_patrol())
	if can.is_empty() or wps.is_empty():
		return
	var cen := Vector3.ZERO
	for u in can:
		cen += u.position
	cen /= can.size()
	for u in can:
		var off: Vector3 = (u.position - cen)
		off.y = 0.0
		if off.length() > 7.0:
			off = off.normalized() * 7.0
		var pts: Array = []
		for w in wps:
			var p: Vector3 = (w as Vector3) + (off if u.layer != "air" else Vector3.ZERO)
			if u.layer != "air":
				p = world.nav.nearest_free_pos(p, u.grid, 8)
			pts.append(p)
		u.cmd_patrol(pts)
	Game.message("Patrouille: %d Einheiten, %d Wegpunkt(e)" % [can.size(), wps.size()], "info", team)

func _is_attackable(e: Entity) -> bool:
	if e is Structure:
		var s := e as Structure
		if team == U.TEAM_ADF:
			return (s.team == U.TEAM_REB and s.revealed) or (s.team == U.TEAM_CIV and s.hot_t > 0.0)
		return s.team == U.TEAM_ADF
	if e is Unit:
		var u := e as Unit
		if u.is_civ or u.press:
			return false
		if team == U.TEAM_ADF:
			return u.team == U.TEAM_REB and (u.ident_mask & 1) != 0
		return u.team == U.TEAM_ADF
	if e is Mine:
		return e.detected
	return false

func _formation_order(units: Array, dest: Vector3, attack_move: bool) -> void:
	if units.is_empty():
		return
	var n := units.size()
	var cen := Vector3.ZERO
	for u in units:
		cen += u.position
	cen /= n
	var dir := U.dir2d(cen, dest)
	var side := Vector3(-dir.z, 0, dir.x)
	var cols := int(ceil(sqrt(float(n))))
	var maxr := 0.8
	for u in units:
		maxr = maxf(maxr, u.radius)
	var spacing := maxr * 2.0 + 1.1
	# sortieren: Fahrzeuge vorn
	var sorted := units.duplicate()
	sorted.sort_custom(func(a, b): return (a.layer != "foot") and (b.layer == "foot"))
	for i in range(n):
		var u: Unit = sorted[i]
		var row := i / cols
		var col := i % cols
		var off := side * ((col - (cols - 1) * 0.5) * spacing) - dir * (row * spacing)
		var p := dest + off
		if n == 1:
			p = dest
		if u.layer != "air":
			p = world.nav.nearest_free_pos(p, u.grid, 10)
		if attack_move:
			u.cmd_attack_move(p)
		else:
			u.cmd_move(p)
	if units.size() > 0 and units[0].layer == "foot":
		pass

func _key(k: InputEventKey) -> void:
	var code := k.keycode
	var ctrl := k.ctrl_pressed
	if code >= KEY_1 and code <= KEY_9 and not k.shift_pressed:
		var n := code - KEY_0
		if ctrl:
			groups[n] = selected.filter(func(e): return e.team == team and not (e is Structure and false))
			Game.message("Gruppe %d gespeichert" % n, "info", team)
		elif groups.has(n):
			var arr: Array = (groups[n] as Array).filter(func(e): return is_instance_valid(e) and e.alive)
			if not arr.is_empty():
				select_list(arr)
				var now := Time.get_ticks_msec()
				if _group_tap_n == n and now - _group_tap_ms < 400:
					rig.focus_on(_centroid(arr))
				_group_tap_n = n
				_group_tap_ms = now
		return
	match code:
		KEY_ESCAPE:
			if mode != "normal":
				set_mode("normal")
			elif not selected.is_empty():
				select_list([])
			else:
				pause_requested.emit()
		KEY_X:
			for u in _own_units():
				u.cmd_stop()
		KEY_C:
			if _own_units().any(func(u): return u.detect_range > 0.0 and u.layer == "foot"):
				set_mode("check")
		KEY_T:
			if not _own_units().is_empty():
				set_mode("attack_move")
		KEY_H:
			for u in _own_units():
				u.hold = not u.hold
				if u.hold:
					u.target = null
			Game.message("Feuer halten umgeschaltet", "info", team)
		KEY_G:
			for u in _own_units():
				u.cmd_toggle_conceal()
		KEY_B:
			for u in _own_units():
				if u.can_ied:
					u.cmd_place_ied()
		KEY_V:
			for u in _own_units():
				if u.garrison != null:
					u.ungarrison()
			for s in _own_structures():
				for u in (s as Structure).garrison_of(team):
					(u as Unit).ungarrison()
		KEY_F:
			if _own_units().any(func(u): return u.manual_only):
				set_mode("fire_ground")
		KEY_R:
			if team == U.TEAM_ADF:
				world.roe_free[0] = not world.roe_free[0]
				Game.message("Einsatzregeln: %s" % ("Feuer auf aktive Gebäude frei" if world.roe_free[0] else "Streng – nur identifizierte Ziele"), "info", team)
		KEY_SPACE:
			if last_alert_pos != Vector3.ZERO:
				rig.focus_on(last_alert_pos)
		KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9, KEY_F10:
			var ids := ability_order()
			var idx: int = code - KEY_F1
			if idx < ids.size():
				begin_ability(ids[idx])
		KEY_BACKSPACE:
			if not selected.is_empty():
				rig.focus_on(_centroid(selected))

func ability_order() -> Array:
	return Data.ABILITY_ORDER[team]

func _centroid(arr: Array) -> Vector3:
	var c := Vector3.ZERO
	for e in arr:
		c += e.position
	return c / maxf(arr.size(), 1)

func set_mode(m: String, id: String = "") -> void:
	if m != "patrol":
		patrol_wps.clear()
	mode = m
	ability_id = id
	if m == "normal":
		_cursor_ring.visible = false
	mode_changed.emit()

func begin_ability(id: String) -> void:
	var d: Dictionary = Data.ABILITIES[id]
	if not Game.ability_ready(team, id):
		Sfx.play_ui("error")
		if Game.cooldowns[team].get(id, 0.0) > 0.0:
			Game.message("%s: noch nicht bereit" % d.name, "warn", team)
		elif Game.budget[team] < d.cost:
			Game.message("Nicht genug Budget", "warn", team)
		elif d.get("needs_air", false) and Game.no_fly_zone():
			Game.message("Flugverbotszone: Luftunterstützung nicht verfügbar!", "bad", team)
		elif id == "upload":
			Game.message("Kein Videomaterial oder kein Medien-Team am Leben", "warn", team)
		elif id == "donate":
			Game.message("Erst bei Empörung ab 12%", "warn", team)
		return
	if d.target:
		set_mode("ability", id)
		Sfx.play_ui("click")
	else:
		if Game.use_ability(team, id):
			Sfx.play_ui("upload" if id == "upload" else "click")
