class_name Unit
extends Entity
## Bewegliche Einheit: Bewegung (A*), Kampf, Tarnung (Rebellen), Garnison, Spezialfaehigkeiten.

var spd := 5.0
var turn := 10.0
var layer := "foot"          # foot | wheel | track | air
var grid := "foot"           # Nav-Gitter: foot | veh
var weapons: Array = []
var detect_range := 0.0
var detect_rate := 0.0
var pop := 1
var is_civ := false
var press := false
var is_launcher := false
var can_ied := false
var film_range := 0.0
var manual_only := false

# --- Tarnung / Sichtbarkeit
var can_conceal := false
var conceal_pref := true
var concealed := false
var exposed_t := 0.0
var suspicion := 0.0
var combat_t := 99.0
var disguise: Node3D = null

# --- Bewegung / Befehle
var heading := 0.0
var path := PackedVector3Array()
var path_i := 0
var order_type := "idle"      # idle | move | attack | attack_move | attack_ground | garrison
var order_pos := Vector3.ZERO
var order_target: Entity = null
var target: Entity = null
var ground_target := Vector3.ZERO
var has_ground_target := false
var hold := false
var garrison: Structure = null
var tunnel_t := 0.0                 # > 0: gerade im Tunnelnetz unterwegs (Ziel = garrison)
var tunnel_dur := 0.0
var tunnel_pts := PackedVector3Array()   # Hubs der Route (fuer die Anzeige)
var tunnel_len := 0.0
var tunnel_ready := 0.0               # frueheste erneute Tunnelreise (Weltzeit)
var moving := false
var air_h := 0.0
var _acq_t := 0.0
var _stuck_t := 0.0
var _stuck_ref := Vector3.ZERO
var _repaths := 0
var _anim_t := 0.0
var _turret_rate := 3.0
var _hp_regen := 0.0
var _burst_left := 0
var _burst_t := 0.0
var _burst_w: Dictionary = {}
var _deploy := 0.0           # Raketenwerfer: 0 = verpackt, 1 = feuerbereit
var _deploy_target := 0.0
var _after_fire_t := 0.0
var _smoke: Node3D = null
var _rotor_speed := 0.0
var _flee_t := 0.0
var _civ_state := "wander"
var _civ_wait := 0.0
var _civ_home: Structure = null
var _film_t := 0.0
var _unstick_t := 0.0
var _check_t := 0.0
var _chase_t := 0.0
var _am_repaths := 0
var _check_repath := 0.0
var home_pos := Vector3.ZERO
var rally := Vector3.ZERO
var ai_role := ""
var ai_data: Dictionary = {}

func is_unit() -> bool:
	return true

func setup(k: String, t: int, w: World) -> void:
	kind = k
	team = t
	world = w
	def = Data.UNITS.get(k, {})
	max_hp = def.get("hp", 50.0)
	hp = max_hp
	spd = def.get("speed", 5.0)
	turn = def.get("turn", 8.0)
	layer = def.get("layer", "foot")
	grid = "foot" if layer == "foot" else ("veh" if layer != "air" else "air")
	radius = def.get("radius", 1.0)
	armor = def.get("armor", "inf")
	vision = def.get("vision", 20.0)
	pop = def.get("pop", 1)
	detect_range = def.get("detect_range", 0.0)
	detect_rate = def.get("detect_rate", 0.0)
	can_conceal = def.get("conceal", false)
	press = def.get("press", false)
	is_launcher = def.get("is_launcher", false)
	can_ied = def.get("ied", false)
	film_range = def.get("film_range", 0.0)
	manual_only = def.get("manual_only", false)
	for wd in def.get("weapons", []):
		var ww: Dictionary = wd.duplicate()
		ww["cdl"] = randf() * ww.get("cd", 1.0)
		weapons.append(ww)
	if layer == "air":
		air_h = 16.0 if kind == "adf_drone" else 11.0
	name = "%s_%d" % [k, id]
	_build_model()

func _build_model() -> void:
	model = Models.build_unit(kind, team, id)
	add_child(model)
	parts = model.get_meta("parts", {})
	if layer == "air":
		model.position.y = air_h
	if can_conceal and team == U.TEAM_REB:
		if is_launcher:
			disguise = Models.build_unit("civ_truck", U.TEAM_CIV, id)
		else:
			disguise = Models.build_unit("civilian", U.TEAM_CIV, id)
		add_child(disguise)
		disguise.visible = false
	_turret_rate = 2.4 if kind == "adf_mbt" else (1.6 if kind == "adf_arty" else 3.4)

func set_pos(p: Vector3) -> void:
	position = Vector3(p.x, 0.0, p.z)
	home_pos = position
	rally = position

# ============================================================================= Befehle
func _clear_orders() -> void:
	order_type = "idle"
	order_target = null
	target = null
	has_ground_target = false
	path = PackedVector3Array()
	path_i = 0
	_repaths = 0
	_burst_left = 0

func cmd_stop() -> void:
	if garrison != null:
		ungarrison()
	_clear_orders()

func cmd_move(p: Vector3) -> void:
	if garrison != null:
		ungarrison()
	_clear_orders()
	order_type = "move"
	order_pos = p
	_set_path(p)
	_deploy_target = 0.0

func cmd_attack_move(p: Vector3) -> void:
	if garrison != null:
		ungarrison()
	_clear_orders()
	order_type = "attack_move"
	order_pos = p
	_am_repaths = 0
	_set_path(p)

func cmd_attack(e: Entity) -> void:
	if e == null or not e.alive or weapons.is_empty():
		return
	if garrison != null and order_type != "attack":
		pass
	else:
		_clear_orders()
	order_type = "attack"
	order_target = e
	target = e

## Person kontrollieren (ADF): hingehen, 2 s abtasten, dann Ergebnis.
func cmd_check(t: Unit) -> void:
	if t == null or not t.alive or detect_range <= 0.0 or layer != "foot":
		return
	if garrison != null:
		ungarrison()
	_clear_orders()
	order_type = "check"
	order_target = t
	_check_t = 0.0
	_check_repath = 0.0
	_set_path(t.position)

func cmd_attack_ground(p: Vector3) -> void:
	if weapons.is_empty():
		return
	if garrison != null:
		ungarrison()
	_clear_orders()
	order_type = "attack_ground"
	order_pos = p
	ground_target = p
	has_ground_target = true

func cmd_garrison(s: Structure) -> void:
	if not can_conceal or s == null or not s.alive:
		return
	if garrison != null:
		ungarrison()
	_clear_orders()
	order_type = "garrison"
	order_target = s
	_set_path(s.door_pos(position))

func cmd_toggle_conceal() -> void:
	if not can_conceal:
		return
	conceal_pref = not conceal_pref
	if conceal_pref:
		_try_conceal(true)
	else:
		reveal(0.0)

func cmd_place_ied() -> bool:
	if not can_ied:
		return false
	return world.place_ied(self)

func _set_path(dest: Vector3) -> void:
	_stuck_t = 0.0
	if layer == "air":
		path = PackedVector3Array([Vector3(dest.x, 0, dest.z)])
	else:
		path = world.nav.find_path(position, dest, grid)
	path_i = 0

# ============================================================================= Tarnung
func _try_conceal(force: bool = false) -> void:
	if not can_conceal or concealed:
		return
	if exposed_t > 0.0 and not force:
		return
	if combat_t < 2.5 and not force:
		return
	concealed = true
	suspicion = 0.0
	refresh_appearance()

func reveal(expose_secs: float = 8.0) -> void:
	if not can_conceal:
		return
	if concealed:
		concealed = false
		refresh_appearance()
	if expose_secs > 0.0:
		exposed_t = maxf(exposed_t, expose_secs)

func is_disguised() -> bool:
	return concealed and exposed_t <= 0.0

func refresh_appearance() -> void:
	if disguise == null:
		return
	var show_real := (not concealed) or (Game.player_team == team and not Game.demo_mode)
	model.visible = show_real
	disguise.visible = not show_real

## Wird nach jedem Sichtbarkeits-Tick aufgerufen.
func apply_visibility(player_team: int) -> void:
	var vis := team == player_team or seen_by(player_team)
	if garrison != null:
		vis = false
	visible = vis
	if disguise != null:
		refresh_appearance()

# ============================================================================= Garnison
func enter_garrison(s: Structure) -> void:
	if s.garrisoned.size() >= s.garrison_cap:
		_clear_orders()
		return
	garrison = s
	s.garrisoned.append(self)
	_clear_orders()
	position = Vector3(s.position.x, 0.0, s.position.z)
	visible = false
	if selected:
		world.deselect_entity(self)
	_try_conceal(true)

func ungarrison() -> void:
	if garrison == null:
		return
	tunnel_t = 0.0
	var s := garrison
	garrison = null
	s.garrisoned.erase(self)
	position = world.nav.nearest_free_pos(s.door_pos(position), grid, 8)
	visible = true

## Tunnelreise: aus dem Tunnelknoten, in dem die Einheit sitzt, in einen anderen Knoten des Netzes.
func cmd_tunnel(dest: Structure) -> bool:
	if team != U.TEAM_REB or layer != "foot" or garrison == null or tunnel_t > 0.0 or world.time < tunnel_ready:
		return false
	if not garrison.hub or dest == null or not dest.alive or not dest.hub or dest == garrison:
		return false
	if dest.garrisoned.size() >= dest.garrison_cap:
		return false
	var route := world.tunnel_route(garrison, dest)
	if route.size() < 2:
		return false
	var src := garrison
	src.garrisoned.erase(self)
	garrison = dest
	dest.garrisoned.append(self)
	tunnel_pts = PackedVector3Array()
	for h in route:
		tunnel_pts.append((h as Structure).position)
	tunnel_len = world.route_length(route)
	tunnel_dur = 2.5 + tunnel_len / World.TUNNEL_SPEED
	tunnel_t = tunnel_dur
	tunnel_ready = world.time + tunnel_dur + 12.0
	position = Vector3(dest.position.x, 0.0, dest.position.z)
	if selected:
		world.deselect_entity(self)
	Game.stats.tunnel_trips = int(Game.stats.get("tunnel_trips", 0)) + 1
	world.fx.dust_cloud(src.door_pos(src.position), 1.2)
	return true

## Aktuelle Position im Tunnel (fuer die Anzeige der Wanderer)
func tunnel_pos() -> Vector3:
	if tunnel_pts.size() < 2 or tunnel_dur <= 0.0:
		return position
	var k := 1.0 - tunnel_t / tunnel_dur
	var want := k * tunnel_len
	var acc := 0.0
	for i in range(tunnel_pts.size() - 1):
		var seg := U.dist2d(tunnel_pts[i], tunnel_pts[i + 1])
		if acc + seg >= want:
			return tunnel_pts[i].lerp(tunnel_pts[i + 1], clampf((want - acc) / maxf(seg, 0.01), 0.0, 1.0))
		acc += seg
	return tunnel_pts[tunnel_pts.size() - 1]

# ============================================================================= Sim
func _process(dt: float) -> void:
	if not alive or world == null or world.paused:
		return
	dt = minf(dt, 0.12)
	if hit_flash > 0.0:
		hit_flash -= dt
	combat_t += dt
	if exposed_t > 0.0:
		exposed_t -= dt
	_anim_t += dt
	if garrison != null:
		if tunnel_t > 0.0:
			tunnel_t -= dt
			if tunnel_t <= 0.0:
				tunnel_t = 0.0
				tunnel_pts = PackedVector3Array()
				if team == Game.player_team and not Game.demo_mode:
					Sfx.play_ui("ready", -10.0)
			return
		_sim_garrison(dt)
		return
	if is_civ:
		_sim_civilian(dt)
	else:
		_sim_combat(dt)
	_move(dt)
	_animate(dt)
	_update_conceal(dt)

func _update_conceal(dt: float) -> void:
	if not can_conceal or not conceal_pref or concealed:
		return
	if combat_t > 3.0 and exposed_t <= 0.0 and order_type != "attack":
		_try_conceal()

# ----------------------------------------------------------------------------- Kampf
func _sim_combat(dt: float) -> void:
	for w in weapons:
		w.cdl -= dt
	# Launcher: Aufbau
	if is_launcher:
		_deploy = move_toward(_deploy, _deploy_target, dt / maxf(def.get("setup", 2.0), 0.1))
		if parts.has("rack"):
			parts.rack.rotation_degrees.x = -22.0 * _deploy
		if _after_fire_t > 0.0:
			_after_fire_t -= dt
			if _after_fire_t <= 0.0:
				_deploy_target = 0.0
	if weapons.is_empty():
		_sim_nonweapon(dt)
		return
	if order_type == "check":
		_sim_check(dt)
		return
	# Salven
	if _burst_left > 0:
		_burst_t -= dt
		if _burst_t <= 0.0:
			_fire_burst_shot()
	# Zielverwaltung
	if order_type == "attack":
		if order_target == null or not order_target.alive or not world.is_valid_manual_target(self, order_target):
			if order_target != null and order_target.alive and not order_target.seen_by(team):
				# Ziel aus den Augen verloren: zur letzten Position laufen
				order_pos = order_target.position
				order_type = "move"
				_set_path(order_pos)
			else:
				order_type = "idle"
			order_target = null
			target = null
		else:
			target = order_target
	elif order_type == "attack_ground":
		pass
	else:
		_acq_t -= dt
		if _acq_t <= 0.0:
			_acq_t = 0.25 + randf() * 0.15
			if target != null and (not target.alive or not world.can_auto_target(self, target) or not _target_still_valid(target)):
				target = null
			if target == null and not manual_only and not is_launcher and not hold:
				target = world.find_target(self, _auto_range())
	var t_pos := Vector3.ZERO
	var have_target := false
	if order_type == "attack_ground" and has_ground_target:
		t_pos = ground_target
		have_target = true
	elif target != null and target.alive:
		t_pos = target.position
		have_target = true
	if not have_target:
		if order_type == "attack_ground":
			order_type = "idle"
		return
	var d := U.dist2d(position, t_pos)
	var tr: float = 0.0
	if target != null and order_type != "attack_ground":
		tr = target.radius * 0.6
	var in_range := false
	var best: Dictionary = {}
	for w in weapons:
		var rng: float = w.range
		var mn: float = w.get("min_range", 0.0)
		if d - tr <= rng and d >= mn:
			in_range = true
			if best.is_empty() or rng > best.range:
				best = w
	# Verfolgung / Annaeherung
	var chase := order_type == "attack" or order_type == "attack_ground" or order_type == "attack_move"
	if not in_range and chase:
		_chase_t -= dt
		if _chase_t <= 0.0:
			_chase_t = 0.6
			var want := _longest_range() * 0.8
			if d > want:
				var open_path := path_i >= path.size()
				if open_path or U.dist2d(path[path.size() - 1], t_pos) > 5.0:
					var from_t := (position - t_pos)
					from_t.y = 0.0
					var app := t_pos + (from_t.normalized() if from_t.length() > 0.1 else Vector3(1, 0, 0)) * want
					_set_path(app)
					_deploy_target = 0.0
	elif in_range and chase:
		# in Reichweite: stehen bleiben und kaempfen
		path = PackedVector3Array()
		path_i = 0
	# Ausrichten + Feuern
	if in_range:
		var aimed := _aim_at(t_pos, dt)
		if is_launcher:
			_deploy_target = 1.0
			_after_fire_t = 5.0
			if _deploy < 0.98:
				aimed = false
		if manual_only and moving:
			aimed = false
		for w in weapons:
			var rng2: float = w.range
			var mn2: float = w.get("min_range", 0.0)
			if w.cdl <= 0.0 and d - tr <= rng2 and d >= mn2 and aimed and _burst_left <= 0:
				_fire(w, t_pos)
		if is_launcher and has_ground_target and _burst_left <= 0 and weapons[0].cdl > 0.0 and weapons[0].cdl > weapons[0].cd * 0.5:
			# nach der Salve: Ziel verwerfen
			if order_type == "attack_ground":
				order_type = "idle"
				has_ground_target = false
		if kind == "adf_arty" and has_ground_target and weapons[0].cdl > weapons[0].cd * 0.7:
			order_type = "idle"
			has_ground_target = false
	else:
		_idle_turret(dt)

func _sim_check(dt: float) -> void:
	var t := order_target as Unit
	if t == null or not t.alive or t.garrison != null:
		order_type = "idle"
		order_target = null
		return
	var d := U.dist2d(position, t.position)
	if d > 3.4:
		_check_t = 0.0
		_check_repath -= dt
		if _check_repath <= 0.0:
			_check_repath = 0.8
			_set_path(t.position)
		return
	# nah genug: stehen bleiben, Person ansehen
	path = PackedVector3Array()
	path_i = 0
	heading = U.angle_toward(heading, atan2(t.position.x - position.x, t.position.z - position.z), turn * dt)
	_check_t += dt
	if _check_t >= 2.2:
		order_type = "idle"
		order_target = null
		world.resolve_check(self, t)

func _sim_nonweapon(dt: float) -> void:
	if kind == "adf_aid":
		_sim_aid(dt)

func _sim_aid(dt: float) -> void:
	if not has_meta("aid_pos"):
		return
	var st: String = get_meta("aid_state", "go")
	var ap: Vector3 = get_meta("aid_pos")
	if st == "go":
		if U.dist2d(position, ap) < 16.0 or (order_type == "idle" and path_i >= path.size()):
			set_meta("aid_state", "unload")
			set_meta("aid_t", 4.0)
			cmd_stop()
	elif st == "unload":
		var t: float = get_meta("aid_t", 0.0) - dt
		set_meta("aid_t", t)
		if t <= 0.0:
			set_meta("aid_state", "done")
			world.aid_delivered(position)
			if team == Game.player_team and not Game.demo_mode:
				Game.message("Hilfsgüter verteilt", "good", team)
			if Game.time - Game._aid_news_t > 20.0:
				Game._aid_news_t = Game.time
				Game.news(Data.HEADLINES_AID[randi() % Data.HEADLINES_AID.size()], "good" if Game.player_team == U.TEAM_ADF else "info")
				Game.log_event("aid", "Hilfsgüter verteilt", position)
			world.unregister(self)
			alive = false
			if selected:
				world.deselect_entity(self)
			queue_free()

func _target_still_valid(t: Entity) -> bool:
	if order_type == "attack_move":
		return U.dist2d(position, t.position) <= vision * 1.05
	return _in_range_any(t, 1.25)

func _in_range_any(t: Entity, mult: float) -> bool:
	var d := U.dist2d(position, t.position) - t.radius * 0.6
	for w in weapons:
		if d <= w.range * mult and d >= w.get("min_range", 0.0):
			return true
	return false

func _longest_range() -> float:
	var r := 0.0
	for w in weapons:
		r = maxf(r, w.range)
	return r

func _auto_range() -> float:
	var r := _longest_range()
	if order_type == "attack_move":
		return minf(maxf(r, vision * 0.7), vision)
	return r

func _aim_at(t_pos: Vector3, dt: float) -> bool:
	var want := atan2(t_pos.x - position.x, t_pos.z - position.z)
	if parts.has("turret"):
		var tur: Node3D = parts.turret
		var local_want := wrapf(want - heading, -PI, PI)
		tur.rotation.y = U.angle_toward(tur.rotation.y, local_want, _turret_rate * dt)
		return absf(wrapf(local_want - tur.rotation.y, -PI, PI)) < 0.12
	# Rumpf dreht sich
	var spd_turn := turn * (0.5 if layer == "air" else 1.0)
	heading = U.angle_toward(heading, want, spd_turn * dt)
	var lim := 0.25 if layer != "air" else 0.5
	return absf(wrapf(want - heading, -PI, PI)) < lim

func _idle_turret(dt: float) -> void:
	if parts.has("turret") and (order_type == "idle" or moving):
		var tur: Node3D = parts.turret
		tur.rotation.y = U.angle_toward(tur.rotation.y, 0.0, _turret_rate * 0.6 * dt)

func _muzzle_pos(idx: int = 0) -> Vector3:
	var key := "muzzle" if idx == 0 else "muzzle2"
	if parts.has(key):
		return (parts[key] as Node3D).global_position
	return global_position + Vector3(0, 1.4, 0)

func _fire(w: Dictionary, t_pos: Vector3) -> void:
	w.cdl = w.cd * randf_range(0.92, 1.12)
	combat_t = 0.0
	if can_conceal and (concealed or not (exposed_t > 0.0)):
		reveal(7.0)
	var burst: int = w.get("burst", 1)
	if burst > 1:
		_burst_left = burst
		_burst_w = w
		_burst_t = 0.0
		_fire_burst_shot()
	else:
		_do_shot(w, t_pos)

func _fire_burst_shot() -> void:
	if _burst_left <= 0:
		return
	var t_pos := ground_target if has_ground_target else (target.position if target != null and target.alive else position)
	_do_shot(_burst_w, t_pos)
	_burst_left -= 1
	_burst_t = _burst_w.get("burst_gap", 0.3)

func _do_shot(w: Dictionary, t_pos: Vector3) -> void:
	var idx := weapons.find(w)
	var from := _muzzle_pos(idx if idx <= 1 else 0)
	if garrison != null:
		from = global_position + Vector3(0, 3.0, 0)
	var proj: String = w.get("proj", "hit")
	var dist := U.dist2d(position, t_pos)
	world.noise(position, 32.0, 1)
	if is_launcher:
		Game.launch_detected(position, self)
	match proj:
		"hit":
			var acc := clampf(0.92 - 0.38 * dist / maxf(w.range, 1.0), 0.35, 0.95)
			if garrison != null:
				acc = clampf(acc + 0.05, 0.0, 0.95)
			var hit := randf() < acc
			var aim := t_pos + Vector3(0, 1.0 if (target == null or not (target is Unit) or (target as Unit).layer != "air") else (target as Unit).air_h, 0)
			if target is Structure:
				aim = t_pos + Vector3(randf_range(-1, 1), randf_range(1.0, 4.0), randf_range(-1, 1))
			if not hit:
				aim += Vector3(randf_range(-2.0, 2.0), randf_range(-0.8, 0.8), randf_range(-2.0, 2.0))
			world.fx.tracer(from, aim, w.type == "bullet" and w.damage >= 9.0)
			world.fx.muzzle_flash(from)
			Sfx.play_at("shot_mg" if w.cd < 0.3 else "shot_rifle", position)
			if hit and target != null and target.alive:
				target.take_damage(w.damage, self, w.type, position)
				world.fx.spark(aim)
		"shell":
			world.fire_projectile(self, from, target, t_pos, w)
			world.fx.muzzle_flash(from, 2.0)
			Sfx.play_at("cannon", position)
			world.shake_at(position, 0.35)
			if parts.has("turret"):
				(parts.turret as Node3D).position.z = -0.0
		"rocket", "missile":
			world.fire_projectile(self, from, target, t_pos, w)
			world.fx.muzzle_flash(from, 1.4)
			Sfx.play_at("rocket", position)
		"arty":
			world.fire_projectile(self, from, null, t_pos, w)
			world.fx.muzzle_flash(from, 2.6)
			Sfx.play_at("arty" if not is_launcher else "rocket", position)
			if not is_launcher:
				world.shake_at(position, 0.5)

# ----------------------------------------------------------------------------- Garnison-Sim
func _sim_garrison(dt: float) -> void:
	for w in weapons:
		w.cdl -= dt
	if weapons.is_empty():
		return
	_acq_t -= dt
	if _acq_t <= 0.0:
		_acq_t = 0.3 + randf() * 0.2
		if target != null and (not target.alive or not _in_range_any(target, 1.0) or not world.can_auto_target(self, target)):
			target = null
		if target == null and not is_launcher and not hold:
			target = world.find_target(self, _longest_range())
	if target != null and target.alive:
		var d := U.dist2d(position, target.position) - target.radius * 0.6
		for w in weapons:
			if w.cdl <= 0.0 and d <= w.range:
				w.cdl = w.cd * randf_range(0.95, 1.15)
				garrison.hot_t = 7.0
				combat_t = 0.0
				if can_conceal:
					reveal(0.0)
				_do_shot(w, target.position)

# ----------------------------------------------------------------------------- Zivilisten
func _sim_civilian(dt: float) -> void:
	_civ_wait -= dt
	if _flee_t > 0.0:
		_flee_t -= dt
		if path_i >= path.size() and _civ_state == "flee":
			_flee_to_random()
		if _flee_t <= 0.0:
			_civ_state = "wander"
			_civ_wait = randf_range(0.5, 3.0)
		return
	if _civ_state == "wander" and path_i >= path.size() and _civ_wait <= 0.0:
		if randf() < 0.08 and world.city.buildings.size() > 0:
			# nach Hause gehen
			var b: Structure = world.random_building()
			if b != null and b.alive and b.team == U.TEAM_CIV and b.kind_class == "house":
				_civ_home = b
				_civ_state = "home"
				_set_path(b.door_pos(position))
				return
		var p := world.city.random_street_point(world.rng)
		if U.dist2d(p, position) > 50.0:
			p = position + (p - position).normalized() * 30.0
		_set_path(p)
		_civ_wait = randf_range(1.0, 6.0)
	elif _civ_state == "home" and path_i >= path.size():
		if _civ_home != null and _civ_home.alive and U.dist2d(position, _civ_home.position) < _civ_home.radius + 5.0:
			_civ_home.occupants += 1
			world.civ_entered_building(self)
			return
		_civ_state = "wander"

func panic_from(src: Vector3, secs: float = 6.0) -> void:
	if not is_civ or not alive:
		return
	if garrison != null:
		return
	if _flee_t > 0.0 and randf() < 0.7:
		return
	_flee_t = secs + randf() * 3.0
	_civ_state = "flee"
	var away := (position - src)
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	var dest := position + away.normalized() * randf_range(25.0, 45.0)
	dest = Vector3(clampf(dest.x, -City.HALF + 6.0, City.HALF - 6.0), 0.0, clampf(dest.z, -City.HALF + 6.0, City.HALF - 6.0))
	_set_path(dest)

## Zivilist laeuft gezielt zu einem Ziel (Evakuierungskorridor)
func flee_to(dest: Vector3, secs: float) -> void:
	if not is_civ or not alive or garrison != null:
		return
	_flee_t = secs
	_civ_state = "flee"
	_set_path(dest)

func _flee_to_random() -> void:
	var dest := position + Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
	dest = Vector3(clampf(dest.x, -City.HALF + 6.0, City.HALF - 6.0), 0.0, clampf(dest.z, -City.HALF + 6.0, City.HALF - 6.0))
	_set_path(dest)

# ----------------------------------------------------------------------------- Bewegung
func _move(dt: float) -> void:
	moving = false
	if layer == "air":
		_move_air(dt)
		return
	if path_i >= path.size():
		if order_type == "attack_move":
			# nach dem Gefecht zum eigentlichen Ziel weitermarschieren
			if target == null and U.dist2d(position, order_pos) > 5.0 and _am_repaths < 8:
				_am_repaths += 1
				_set_path(order_pos)
			elif target == null:
				order_type = "idle"
		elif order_type == "move":
			order_type = "idle"
		elif order_type == "garrison":
			var s := order_target as Structure
			if s != null and s.alive and U.dist2d(position, s.position) < s.radius + 5.0:
				enter_garrison(s)
			else:
				order_type = "idle"
		_separate_idle(dt)
		return
	_unstick_t -= dt
	if _unstick_t <= 0.0:
		_unstick_t = 0.5
		if world.nav.is_solid_at(position, grid):
			position = world.nav.nearest_free_pos(position, grid, 6)
	var wp := path[path_i]
	var to := wp - position
	to.y = 0.0
	var d := to.length()
	var reach := 0.7 + radius * 0.25
	if layer != "foot":
		reach = 1.6 + radius * 0.45
	if path_i == path.size() - 1:
		reach = 0.5 + radius * 0.15 if layer == "foot" else 1.2 + radius * 0.5
	if d < reach:
		path_i += 1
		return
	var want := atan2(to.x, to.z)
	var speed := spd
	if is_civ and _flee_t > 0.0:
		speed *= 1.5
	if layer == "foot":
		heading = U.angle_toward(heading, want, turn * dt)
	else:
		heading = U.angle_toward(heading, want, turn * dt)
		var diff := absf(wrapf(want - heading, -PI, PI))
		if diff > 0.5:
			speed *= maxf(0.18, 1.0 - (diff - 0.5) * 0.7)
	if is_launcher and _deploy > 0.1:
		speed *= 0.3
	var step := minf(speed * dt, d)
	var dir := Vector3(sin(heading), 0, cos(heading))
	if layer == "foot":
		dir = to / maxf(d, 0.001)
	var np := position + dir * step
	np += _separation(dt)
	_try_set_position(np)
	moving = true
	# Festgefahren?
	_stuck_t += dt
	if _stuck_t >= 1.2:
		if U.dist2d(position, _stuck_ref) < speed * 0.25 and path_i < path.size():
			_repaths += 1
			if _repaths > 4:
				# aufgeben
				path = PackedVector3Array()
				path_i = 0
				if order_type == "move" or order_type == "attack_move":
					order_type = "idle"
			else:
				var dest: Vector3 = path[path.size() - 1]
				_set_path(dest)
		_stuck_ref = position
		_stuck_t = 0.0

func _try_set_position(np: Vector3) -> void:
	np.y = 0.0
	if not world.nav.is_solid_at(np, grid):
		position = np
		return
	# Gleiten entlang der Wand
	var px := Vector3(np.x, 0, position.z)
	var pz := Vector3(position.x, 0, np.z)
	if not world.nav.is_solid_at(px, grid):
		position = px
	elif not world.nav.is_solid_at(pz, grid):
		position = pz

func _separation(dt: float) -> Vector3:
	var push := Vector3.ZERO
	var near: Array = world.dyn.query(position, radius + 3.5)
	for o in near:
		if o == self or not o.alive:
			continue
		var ou := o as Unit
		if ou == null or ou.layer == "air" or ou.garrison != null:
			continue
		var dx := position.x - ou.position.x
		var dz := position.z - ou.position.z
		var dd := sqrt(dx * dx + dz * dz)
		var minr := radius + ou.radius
		if dd < minr and dd > 0.001:
			var k := (minr - dd) / minr
			var w := 0.35 if ou.moving else 0.7
			push += Vector3(dx / dd, 0, dz / dd) * k * w * spd * dt * 2.0
	return push

func _separate_idle(dt: float) -> void:
	if layer == "air":
		return
	var push := _separation(dt)
	if push.length_squared() > 0.0000001:
		_try_set_position(position + push * 0.6)

func _move_air(dt: float) -> void:
	if path_i >= path.size():
		if order_type == "move" or order_type == "attack_move":
			order_type = "idle"
		# Hubschrauber: kreisen/schweben leicht
		return
	var wp := path[path_i]
	var to := wp - position
	to.y = 0.0
	var d := to.length()
	if d < 1.2:
		path_i += 1
		return
	var want := atan2(to.x, to.z)
	heading = U.angle_toward(heading, want, turn * dt)
	var diff := absf(wrapf(want - heading, -PI, PI))
	var speed := spd * clampf(1.2 - diff, 0.25, 1.0)
	position += Vector3(sin(heading), 0, cos(heading)) * minf(speed * dt, d)
	if has_meta("leaving"):
		if position.length() > City.HALF * 1.6:
			world.unregister(self)
			alive = false
			if selected:
				world.deselect_entity(self)
			queue_free()
		moving = true
		return
	position = Vector3(clampf(position.x, -City.HALF + 2.0, City.HALF - 2.0), 0.0, clampf(position.z, -City.HALF + 2.0, City.HALF - 2.0))
	moving = true

# ----------------------------------------------------------------------------- Animation
func _animate(dt: float) -> void:
	if model == null:
		return
	model.rotation.y = heading
	if disguise != null:
		disguise.rotation.y = heading
	if layer == "foot":
		var holder: Node3D = parts.get("holder", model)
		var sp := spd * (1.5 if (is_civ and _flee_t > 0.0) else 1.0)
		if moving:
			var ph := _anim_t * sp * 2.0
			if parts.has("legL"):
				(parts.legL as Node3D).rotation.x = sin(ph) * 0.7
				(parts.legR as Node3D).rotation.x = -sin(ph) * 0.7
			holder.position.y = absf(sin(ph)) * 0.08
		else:
			if parts.has("legL"):
				(parts.legL as Node3D).rotation.x = lerpf((parts.legL as Node3D).rotation.x, 0.0, dt * 10.0)
				(parts.legR as Node3D).rotation.x = lerpf((parts.legR as Node3D).rotation.x, 0.0, dt * 10.0)
			holder.position.y = lerpf(holder.position.y, 0.0, dt * 10.0)
	elif layer == "air":
		var tgt := 25.0 if (moving or kind == "adf_viper") else 25.0
		if parts.has("rotor"):
			var r := parts.rotor as Node3D
			if parts.get("rotor_axis", 0) == 0:
				r.rotation.y += dt * 28.0
			else:
				r.rotation.z += dt * 40.0
		if parts.has("rotor2"):
			(parts.rotor2 as Node3D).rotation.x += dt * 35.0
		# leichtes Schweben + Neigung in Flugrichtung
		model.position.y = air_h + sin(_anim_t * 1.7 + id) * 0.25
		var pitch := -0.14 if moving else 0.0
		model.rotation.x = lerpf(model.rotation.x, pitch, dt * 3.0)
	else:
		# Fahrzeug: leichtes Wippen beim Fahren
		if moving:
			model.rotation.x = sin(_anim_t * 6.0) * 0.008
		if parts.has("barrel") and false:
			pass

# ============================================================================= Schaden / Tod
func _on_damaged(dmg: float, attacker: Entity, _dtype: String) -> void:
	if is_civ:
		panic_from(attacker.position if attacker != null else position, 8.0)
		return
	if can_conceal and concealed and false:
		reveal(4.0)
	# Gegenwehr
	if order_type == "idle" and not hold and attacker != null and attacker.alive and attacker != target and not weapons.is_empty():
		if world.can_auto_target(self, attacker) and _in_range_any(attacker, 1.2):
			target = attacker
	if layer != "foot" and hp < max_hp * 0.5 and _smoke == null:
		_smoke = world.fx.attach_smoke(self, 1.4 if hp > max_hp * 0.25 else 2.4)

func die(attacker: Entity, dtype: String) -> void:
	if not alive:
		return
	alive = false
	world.unregister(self)
	if garrison != null:
		garrison.garrisoned.erase(self)
		garrison = null
	if selected:
		world.deselect_entity(self)
	Game.unit_died(self, attacker, dtype)
	var vehicle := layer != "foot"
	if vehicle:
		world.fx.explosion(position + Vector3(0, 1.2 if layer != "air" else air_h, 0), 3.2 if layer != "air" else 3.8, false)
		world.shake_at(position, 0.6)
		Sfx.play_at("explosion_s", position)
		if layer == "air":
			# Absturz
			world.fx.crash(self)
			queue_free()
			return
		_make_wreck()
	else:
		_make_corpse()
	if _smoke != null and is_instance_valid(_smoke):
		_smoke.queue_free()

func _make_wreck() -> void:
	set_selected(false)
	if disguise != null:
		disguise.visible = false
	model.visible = true
	var charred := Gfx.flat_mat(Color(0.07, 0.065, 0.06), 1.0)
	_apply_override(model, charred)
	if parts.has("turret"):
		(parts.turret as Node3D).rotation.y += randf_range(-0.6, 0.6)
	world.fx.attach_smoke(self, 2.6, 28.0)
	var tw := create_tween()
	tw.tween_interval(26.0)
	tw.tween_property(model, "position:y", -2.5, 6.0)
	tw.tween_callback(queue_free)

func _make_corpse() -> void:
	set_selected(false)
	if disguise != null:
		disguise.visible = false
	model.visible = true
	visible = true
	var side := 1.0 if randf() < 0.5 else -1.0
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", -PI * 0.5 * side if false else -PI * 0.5, 0.25)
	tw.parallel().tween_property(model, "position:y", 0.28, 0.25)
	tw.tween_interval(22.0)
	tw.tween_property(model, "position:y", -1.0, 4.0)
	tw.tween_callback(queue_free)

func _apply_override(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_apply_override(c, mat)
