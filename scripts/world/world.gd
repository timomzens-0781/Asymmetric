class_name World
extends Node3D
## Die Spielwelt: Stadt, Entitaeten, Sichtbarkeit, Schaden, Zivilisten, Start-Aufstellung.

signal shake_requested(pos: Vector3, amount: float)
signal entity_deselected(e: Entity)

var rng := RandomNumberGenerator.new()
var city: City
var nav: Nav
var fx: Fx
var support: Support
var dyn := SpatialHash.new(8.0)       # Einheiten, Zivilisten, Minen
var stat := SpatialHash.new(10.0)     # Gebaeude
var units: Array = []                 # Unit (inkl. Zivilisten)
var structures: Array = []            # Structure
var mines: Array = []                 # Mine
var all_entities: Array = []
var roe_free := [false, true]         # Einsatzregeln: ADF-Gebaeude auto-beschiessen
var paused := false
var time := 0.0
var _next_id := 1
var _vis_t := 0.0
var _hash_t := 0.0
var _civ_t := 3.0
var _entities_root: Node3D
var ai_nodes: Array = []
var adf_proxy: Entity
var civ_cap := 110
var hubs: Array = []
var destroyed_rects: Array = []
var sim_speed_note := 1.0
var _last_vis_player := -1

func build(seed_value: int, side: int, demo: bool) -> void:
	rng.seed = seed_value
	nav = Nav.new()
	city = City.new()
	city.name = "City"
	add_child(city)
	city.generate(seed_value, nav)
	fx = Fx.new()
	fx.world = self
	fx.name = "Fx"
	add_child(fx)
	_entities_root = Node3D.new()
	_entities_root.name = "Entities"
	add_child(_entities_root)
	support = Support.new()
	support.world = self
	support.name = "Support"
	add_child(support)
	adf_proxy = Entity.new()
	adf_proxy.team = U.TEAM_ADF
	adf_proxy.kind = "support"
	adf_proxy.name = "AdfProxy"
	add_child(adf_proxy)
	_pick_hubs()
	_create_buildings()
	_create_adf_base()
	_spawn_start_forces()
	_spawn_initial_civilians()
	_rebuild_dyn()

# ============================================================================= Aufbau
func _pick_hubs() -> void:
	var cands: Array = []
	for b in city.buildings:
		if (b.zone == "old" or b.zone == "old_s") and b.kind == "house" and not b.shop and b.size.x >= 7.0 and b.size.z >= 7.0:
			cands.append(b)
	cands.shuffle()
	var chosen: Array = []
	# Gleichmaessig verteilen: Mindestabstand 26
	for dist in [30.0, 24.0, 18.0, 12.0]:
		for b in cands:
			if chosen.size() >= 6:
				break
			if b in chosen:
				continue
			var ok := true
			for c in chosen:
				if U.dist2d(b.center, c.center) < dist:
					ok = false
					break
			if ok:
				chosen.append(b)
	for b in chosen:
		b.hub = true

func _create_buildings() -> void:
	for b in city.buildings:
		var s := Structure.new()
		s.id = _next_id
		_next_id += 1
		s.setup_building(self, b)
		_entities_root.add_child(s)
		_register(s)
		if b.hub:
			hubs.append(s)

func _create_adf_base() -> void:
	var layout := [
		["adf_hq", Vector3(-80, 0, 82)],
		["adf_barracks", Vector3(-62, 0, 86)],
		["adf_factory", Vector3(-60, 0, 60)],
		["adf_airfield", Vector3(-84, 0, 57)],
		["adf_press", Vector3(-87, 0, 70)],
		["adf_radar", Vector3(-52, 0, 78)],
		["adf_tower", Vector3(-91, 0, 49)],
		["adf_tower", Vector3(-51, 0, 49)],
		["adf_tower", Vector3(-91, 0, 91)],
		["adf_tower", Vector3(-51, 0, 91)],
		["adf_tower", Vector3(-72, 0, 49)],
		["adf_tower", Vector3(-50, 0, 62)],
	]
	var assembly := Vector3(-62, 0, 70)
	for l in layout:
		var s := Structure.new()
		s.id = _next_id
		_next_id += 1
		s.setup_base(self, l[0], U.TEAM_ADF)
		s.position = l[1]
		_entities_root.add_child(s)
		# Front zum Sammelplatz drehen (90°-Schritte)
		if l[0] != "adf_tower" and l[0] != "adf_radar":
			var d := assembly - s.position
			var yaw := roundf(atan2(d.x, d.z) / (PI * 0.5)) * (PI * 0.5)
			s.model.rotation.y = yaw
			if absf(sin(yaw)) > 0.5:
				var t := s.size.x
				s.size.x = s.size.z
				s.size.z = t
				s.hx = s.size.x * 0.5
				s.hz = s.size.z * 0.5
		nav.block_rect(s.position.x, s.position.z, s.hx, s.hz, true)
		_register(s)
	nav.rebuild_vehicle_all()

func _spawn_start_forces() -> void:
	# ADF: Sammelplatz nahe dem Nordtor
	var base := Vector3(-60, 0, 71)
	var plan := [
		["adf_mbt", 2], ["adf_apc", 2], ["adf_rifle", 6], ["adf_recon", 2], ["adf_arty", 1], ["adf_drone", 1],
	]
	var i := 0
	for pe in plan:
		for k in range(pe[1]):
			var col := i % 6
			var row := i / 6
			var p := base + Vector3(-8.0 + col * 3.6 - row * 0.0, 0, -2.0 + row * 4.0)
			var u := spawn_unit(pe[0], U.TEAM_ADF, p)
			if u != null:
				u.heading = PI * 0.5 * 0.0
			i += 1
	# Rebellen: Kaempfer garnisoniert + getarnte Patrouillen
	for h in hubs:
		for k in range(2):
			var u := spawn_unit("reb_fighter", U.TEAM_REB, h.door_pos(h.position))
			if u != null:
				u.enter_garrison(h)
	var rp: Array = []
	for b in city.buildings:
		if b.zone == "old" or b.zone == "old_s":
			rp.append(b)
	rp.shuffle()
	for k in range(7):
		var b: Dictionary = rp[k % rp.size()]
		var p := nav.nearest_free_pos(b.center + Vector3(b.size.x * 0.5 + 2.0, 0, rng.randf_range(-3, 3)), "foot", 6)
		var u := spawn_unit("reb_fighter" if k % 3 != 0 else "reb_rpg", U.TEAM_REB, p)
	for k in range(2):
		var h: Structure = hubs[k % hubs.size()]
		var p := nav.nearest_free_pos(h.exit_pos(true), "veh", 10)
		spawn_unit("reb_launcher", U.TEAM_REB, p)
	for k in range(2):
		var h2: Structure = hubs[(k + 2) % hubs.size()]
		spawn_unit("reb_media", U.TEAM_REB, h2.exit_pos(false))
	spawn_unit("reb_saboteur", U.TEAM_REB, hubs[0].exit_pos(false))
	spawn_unit("reb_tech", U.TEAM_REB, nav.nearest_free_pos(hubs[1].exit_pos(true), "veh", 10))

func _spawn_initial_civilians() -> void:
	var n := 0
	var tries := 0
	while n < 95 and tries < 600:
		tries += 1
		var p := city.random_street_point(rng)
		if nav.is_solid_at(p, "foot"):
			continue
		if BaseRectContains(p):
			continue
		spawn_civilian(p)
		n += 1

func BaseRectContains(p: Vector3) -> bool:
	return City.BASE_RECT.grow(1.0).has_point(Vector2(p.x, p.z))

# ============================================================================= Spawns
func spawn_unit(kind: String, team: int, pos: Vector3) -> Unit:
	var u := Unit.new()
	u.id = _next_id
	_next_id += 1
	u.setup(kind, team, self)
	_entities_root.add_child(u)
	u.set_pos(pos)
	_register(u)
	u.heading = rng.randf() * TAU
	if team == U.TEAM_ADF:
		u.heading = PI * 0.0
	if u.can_conceal and team == U.TEAM_REB and u.conceal_pref:
		u.call_deferred("_try_conceal", true)
	return u

func spawn_civilian(pos: Vector3) -> Civilian:
	var c := Civilian.new()
	c.id = _next_id
	_next_id += 1
	c.setup_civ(self, rng.randi())
	_entities_root.add_child(c)
	c.set_pos(pos)
	_register(c)
	return c

func release_civilian(s: Structure, flee: bool) -> void:
	if s.occupants < 0:
		return
	var p := s.door_pos(s.position + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5)))
	var c := spawn_civilian(p)
	if c != null and flee:
		c.panic_from(s.position, 7.0)

func civ_entered_building(c: Civilian) -> void:
	unregister(c)
	c.queue_free()

func random_building() -> Structure:
	for i in range(6):
		var s: Structure = structures[rng.randi() % structures.size()]
		if s.alive and s.team == U.TEAM_CIV and s.kind_class == "house":
			return s
	return null

func _civ_tick() -> void:
	var count := 0
	for u in units:
		if u.is_civ and u.alive:
			count += 1
	if count < civ_cap:
		for i in range(3):
			var s := random_building()
			if s != null and s.occupants > 1 and not s.warned:
				s.occupants -= 1
				release_civilian(s, false)
				break

func _register(e: Entity) -> void:
	e.world = self
	all_entities.append(e)
	if e is Structure:
		structures.append(e)
		stat.insert_rect(e, e.hx, e.hz)
	elif e is Mine:
		mines.append(e)
		dyn.insert(e)
	else:
		units.append(e)
		dyn.insert(e)

func unregister(e: Entity) -> void:
	all_entities.erase(e)
	if e is Structure:
		structures.erase(e)
		stat.remove_rect(e, e.hx, e.hz)
	elif e is Mine:
		mines.erase(e)
	else:
		units.erase(e)

func register_new(e: Entity) -> void:
	e.id = _next_id
	_next_id += 1
	_entities_root.add_child(e)
	_register(e)

func deselect_entity(e: Entity) -> void:
	e.set_selected(false)
	entity_deselected.emit(e)

# ============================================================================= Sim
func _process(dt: float) -> void:
	if paused:
		return
	dt = minf(dt, 0.15)
	time += dt
	_hash_t -= dt
	if _hash_t <= 0.0:
		_hash_t = 0.1
		_rebuild_dyn()
	_vis_t -= dt
	if _vis_t <= 0.0:
		_vis_t = 0.2
		_vis_tick(0.2)
	_civ_t -= dt
	if _civ_t <= 0.0:
		_civ_t = 4.0
		_civ_tick()
	if city != null:
		city.flush_scorch()

func _rebuild_dyn() -> void:
	dyn.clear()
	for u in units:
		if u.alive:
			dyn.insert(u)
	for m in mines:
		if m.alive:
			dyn.insert(m)

# ----------------------------------------------------------------------------- Sichtbarkeit
func _vis_tick(dt: float) -> void:
	for u in units:
		u.seen_mask = 0
		u.ident_mask = 0
	for m in mines:
		m.seen_mask = 0
		m.ident_mask = 1 if m.detected else 0
	for s in structures:
		# Gebaeude sind immer sichtbar (Kartengeometrie); ADF-Gebaeude kennt jeder
		s.seen_mask = 3
		if s.team == U.TEAM_ADF:
			s.ident_mask = 2 | 1
		elif s.hub:
			s.ident_mask = 2 | (1 if s.revealed else 0)
		elif s.hot_t > 0.0:
			s.ident_mask = 1
		else:
			s.ident_mask = 0
	# Beobachter sammeln
	var obs: Array = [[], []]
	for u in units:
		if not u.alive or u.vision <= 0.0:
			continue
		if u.team == U.TEAM_ADF or u.team == U.TEAM_REB:
			obs[u.team].append(u)
		elif u.is_civ:
			obs[U.TEAM_REB].append(u)   # Informanten: Zivilisten melden Bewegungen der Armee
	for s in structures:
		if s.alive and s.vision > 0.0:
			if s.team == U.TEAM_ADF:
				obs[0].append(s)
			elif s.hub:
				obs[1].append(s)
	for t in range(2):
		for o in obs[t]:
			var r: float = o.vision
			if o is Civilian:
				r = 9.0
			var near: Array = dyn.query(o.position, r + 3.0)
			for e in near:
				if not e.alive:
					continue
				if e.team == t:
					continue
				if o is Civilian and e.team != U.TEAM_ADF:
					continue
				if t == U.TEAM_ADF and e.team == U.TEAM_CIV:
					pass
				var d := U.dist2d(o.position, e.position)
				if d <= r + e.radius:
					e.seen_mask |= (1 << t)
	# Eigene Einheiten immer sichtbar fuer sich selbst, Zivilisten fuer beide ueber Sicht
	for u in units:
		if not u.alive:
			continue
		if u.team == U.TEAM_ADF or u.team == U.TEAM_REB:
			u.seen_mask |= (1 << u.team)
	# Identifikation
	for u in units:
		if not u.alive or u.is_civ:
			continue
		if u.team == U.TEAM_REB:
			var disguised: bool = u.concealed and u.exposed_t <= 0.0
			if u.seen_by(U.TEAM_ADF) and not disguised and not u.press and u.garrison == null:
				u.ident_mask |= 1
			u.ident_mask |= 2
		elif u.team == U.TEAM_ADF:
			if u.seen_by(U.TEAM_REB):
				u.ident_mask |= 2
			u.ident_mask |= 1
	# Verdacht gegen getarnte Rebellen
	_suspicion_tick(obs[0], dt)
	# Sichtbarkeit fuer den Spieler anwenden
	var pt: int = Game.player_team
	for u in units:
		u.apply_visibility(pt)
	for m in mines:
		m.apply_visibility(pt)

func _suspicion_tick(adf_obs: Array, dt: float) -> void:
	var detectors: Array = []
	for o in adf_obs:
		if o is Unit and (o as Unit).detect_range > 0.0:
			detectors.append(o)
	for u in units:
		if not u.alive or u.team != U.TEAM_REB or not u.concealed or u.exposed_t > 0.0:
			continue
		if u.garrison != null:
			continue
		var gain := 0.0
		for d in detectors:
			var dd: float = U.dist2d(d.position, u.position)
			var rng_d: float = d.detect_range
			if d.layer == "air":
				rng_d = d.detect_range
			if dd < rng_d:
				var k := 1.0 - dd / rng_d * 0.5
				gain += d.detect_rate * k
		if gain > 0.0:
			# Tarnung ist bei Bewegung etwas schlechter
			if u.moving:
				gain *= 1.15
			u.suspicion += gain * dt
		else:
			u.suspicion = maxf(0.0, u.suspicion - 9.0 * dt)
		if u.suspicion >= 100.0:
			u.suspicion = 60.0
			u.reveal(14.0)
			u.ident_mask |= 1
			Game.message("Verdächtige Person identifiziert", "good", U.TEAM_ADF)
			Game.alert.emit(u.position, "identified")

# ----------------------------------------------------------------------------- Zielwahl
func can_auto_target(att: Entity, e: Entity) -> bool:
	if e == null or not e.alive or att == null:
		return false
	var t: int = att.team
	if t == U.TEAM_CIV or e.team == t:
		return false
	if e is Civilian:
		return false
	if e is Mine:
		return t == U.TEAM_ADF and e.detected and U.dist2d(att.position, e.position) >= 7.0
	if e is Structure:
		var es := e as Structure
		if t == U.TEAM_ADF:
			if es.team == U.TEAM_REB:
				if not es.revealed:
					return false
			elif es.team == U.TEAM_CIV:
				if not (roe_free[0] and es.hot_t > 0.0):
					return false
			if not _weapon_ok(att, e):
				return false
			return true
		else:
			if es.team != U.TEAM_ADF:
				return false
			return _weapon_ok(att, e)
	var eu := e as Unit
	if eu == null:
		return false
	if eu.press or eu.garrison != null:
		return false
	if t == U.TEAM_ADF:
		if eu.team != U.TEAM_REB:
			return false
		if (eu.ident_mask & 1) == 0:
			return false
	else:
		if eu.team != U.TEAM_ADF or not eu.seen_by(U.TEAM_REB):
			return false
	return _weapon_ok(att, e)

func _weapon_ok(att: Entity, e: Entity) -> bool:
	var ws: Array = att.weapons
	if ws.is_empty():
		return false
	for w in ws:
		if e is Unit and (e as Unit).layer == "air":
			if w.get("air", false):
				return true
			continue
		if e is Structure:
			var mult: float = Data.DMG_MULT[w.type].get("struct", 1.0)
			if mult * w.damage >= 12.0 or mult >= 0.3:
				return true
			continue
		# Bodenziel
		if w.get("proj", "") == "arty" and (att is Unit) and (att as Unit).manual_only:
			continue
		return true
	return false

## Handbefehl-Ziel gueltig? (Sichtbarkeit genuegt)
func is_valid_manual_target(att: Entity, e: Entity) -> bool:
	if e == null or not e.alive or e.team == att.team:
		return false
	if e is Structure:
		return true
	if e is Mine:
		return e.detected or att.team == U.TEAM_REB
	if e is Unit:
		var eu := e as Unit
		if eu.garrison != null:
			return false
		return eu.seen_by(att.team)
	return false

func find_target(att: Entity, rng_max: float) -> Entity:
	var best: Entity = null
	var best_score := 1e9
	var pos := att.position
	var cands: Array = dyn.query_unique(pos, rng_max + 3.0)
	cands.append_array(stat.query_unique(pos, rng_max + 14.0))
	for e in cands:
		if e == att or not e.alive:
			continue
		if not can_auto_target(att, e):
			continue
		var d: float
		if e is Structure:
			d = (e as Structure).edge_dist(pos)
		else:
			d = U.dist2d(pos, e.position) - e.radius * 0.6
		if d > rng_max:
			continue
		var score := d
		if e is Unit:
			var eu := e as Unit
			if not eu.weapons.is_empty():
				score -= 10.0
			if eu.layer == "wheel" or eu.layer == "track":
				score -= 4.0
			if eu.is_launcher:
				score -= 14.0
		elif e is Structure:
			score += 8.0
			if (e as Structure).hot_t > 0.0 or (e as Structure).kind_class == "base":
				score -= 6.0
		elif e is Mine:
			score += 20.0
		if score < best_score:
			best_score = score
			best = e
	return best

# ----------------------------------------------------------------------------- Waffenwirkung
func fire_projectile(shooter: Entity, from: Vector3, tgt: Entity, tgt_pos: Vector3, w: Dictionary) -> void:
	var p := Projectile.new()
	add_child(p)
	p.launch(w, shooter, from, tgt, tgt_pos, self)

func explode(pos: Vector3, radius: float, damage: float, dtype: String, team: int, attacker: Entity, opts: Dictionary = {}) -> void:
	var seen_civ_hit := false
	var cands: Array = dyn.query_unique(pos, radius + 4.0)
	cands.append_array(stat.query_unique(pos, radius + 14.0))
	for e in cands:
		if not e.alive:
			continue
		if e.team == team and team != U.TEAM_CIV:
			continue
		if e is Mine and dtype == "ied":
			continue
		var d: float
		if e is Structure:
			d = (e as Structure).edge_dist(pos)
			# Gebaeude: Schaden auch bei Treffern im Footprint
			if (e as Structure).contains_xz(pos, 0.5):
				d = 0.0
		else:
			d = U.dist2d(pos, e.position) - e.radius * 0.5
			if e is Unit and (e as Unit).layer == "air":
				if (e as Unit).air_h > 6.0 and absf(pos.y - (e as Unit).air_h) > 6.0:
					continue
		if d > radius:
			continue
		var frac := clampf(1.0 - maxf(d, 0.0) / maxf(radius, 0.01), 0.0, 1.0)
		var dmg := damage * (0.3 + 0.7 * frac)
		if e is Unit and (e as Unit).garrison != null:
			continue
		e.take_damage(dmg, attacker, dtype, pos)
		if e is Civilian:
			seen_civ_hit = true
	if not opts.get("no_fx", false):
		var size := radius
		if dtype == "ap" and radius < 3.0:
			size = radius * 1.3 + 0.8
		if dtype == "ied":
			size = 4.5
		fx.explosion(pos + Vector3(0, 0.4, 0), size, true)
	if not opts.get("silent", false):
		var snd := "explosion_s"
		if radius >= 5.5:
			snd = "explosion_l"
		elif radius >= 3.0:
			snd = "explosion_m"
		Sfx.play_at(snd, pos)
		shake_at(pos, clampf(radius * 0.12, 0.1, 1.2))
		noise(pos, 55.0, 3)

func noise(pos: Vector3, radius: float, kind: int) -> void:
	# Zivilisten in der Naehe geraten in Panik
	for o in dyn.query(pos, radius):
		if o is Civilian and o.alive:
			var d := U.dist2d(o.position, pos)
			if d < radius * (0.6 if kind == 1 else 1.0):
				(o as Civilian).panic_from(pos, 6.0 if kind == 1 else 9.0)

func shake_at(pos: Vector3, amount: float) -> void:
	shake_requested.emit(pos, amount)

# ----------------------------------------------------------------------------- Gebaeude-Einsturz
func structure_destroyed(s: Structure, attacker: Entity, dtype: String) -> void:
	stat.remove_rect(s, s.hx, s.hz)
	destroyed_rects.append(Rect2(s.position.x - s.hx, s.position.z - s.hz, s.size.x, s.size.z))
	var by_team: int = attacker.team if attacker != null else U.TEAM_CIV
	# Bewohner
	var dead := 0
	if s.occupants > 0:
		dead = int(round(s.occupants * 0.85))
		s.occupants = 0
		if by_team != U.TEAM_CIV:
			Game.report_civilian_deaths(s.position, dead, by_team, "collapse", false)
		else:
			Game.stats.civ_killed += dead
	for u in s.garrisoned.duplicate():
		(u as Unit).ungarrison()
		u.take_damage(9999.0, attacker, "he", s.position)
	s.garrisoned.clear()
	fx.collapse(s.position, s.size)
	Sfx.play_at("collapse", s.position)
	shake_at(s.position, clampf(s.radius * 0.1, 0.4, 1.4))
	noise(s.position, 70.0, 3)
	# Navigation: Truemmer
	nav.block_rect(s.position.x, s.position.z, s.hx, s.hz, false)
	nav.mark_rubble(s.position.x, s.position.z, s.hx, s.hz)
	# Optik: Gebaeude durch Truemmerhaufen ersetzen
	if s.kind_class == "base":
		s.model.queue_free()
	else:
		var m := s.model
		var tw := create_tween()
		tw.tween_property(m, "scale:y", 0.04, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(m.queue_free)
	var rub := MeshInstance3D.new()
	rub.mesh = Props.get_mesh("rubble")
	rub.scale = Vector3(s.size.x / 5.0, 1.0 + s.size.y * 0.05, s.size.z / 5.0)
	rub.rotation.y = rng.randf() * TAU
	s.add_child(rub)
	if s.team == U.TEAM_REB or s.hub:
		Game.hub_destroyed(s)
	Game.structure_destroyed(s, attacker)
	if s.selected:
		deselect_entity(s)
	structures.erase(s)
	all_entities.erase(s)
	if s.kind_class == "base":
		Game.message("%s zerstört!" % s.def.get("name", "Gebäude"), "bad", U.TEAM_ADF)
		Game.alert.emit(s.position, "base")

# ----------------------------------------------------------------------------- Sonstiges
func place_ied(u: Unit) -> bool:
	var n := 0
	for m in mines:
		if m.alive:
			n += 1
	if n >= 8:
		Game.message("Maximal 8 Sprengfallen gleichzeitig", "warn", U.TEAM_REB)
		return false
	if not Game.can_afford(U.TEAM_REB, 50.0):
		Game.message("Nicht genug Budget", "warn", U.TEAM_REB)
		return false
	Game.spend(U.TEAM_REB, 50.0)
	var m := Mine.new()
	m.setup_mine(self, u.position)
	register_new(m)
	return true

func adf_has_radar() -> bool:
	for s in structures:
		if s.alive and s.kind == "adf_radar":
			return true
	return false

func enforce_no_fly_zone() -> void:
	for u in units.duplicate():
		if u.alive and u.team == U.TEAM_ADF and u.layer == "air":
			# Luftfahrzeuge werden abgezogen: fliegen vom Spielfeld
			u.cmd_stop()
			u.order_type = "move"
			u.order_pos = Vector3(-130, 0, 130)
			u.path = PackedVector3Array([Vector3(-130, 0, 130)])
			u.path_i = 0
			u.set_meta("leaving", true)
			u.spd *= 1.6
	Game.message("Luftfahrzeuge verlassen den Einsatzraum", "bad", U.TEAM_ADF)

func on_launch(pos: Vector3, u: Unit) -> void:
	for a in ai_nodes:
		if a.has_method("on_launch"):
			a.on_launch(pos, u)

func nearest_structure(pos: Vector3, max_d: float, filter: Callable = Callable()) -> Structure:
	var best: Structure = null
	var bd := max_d
	for s in structures:
		if not s.alive:
			continue
		if filter.is_valid() and not filter.call(s):
			continue
		var d: float = s.edge_dist(pos)
		if d < bd:
			bd = d
			best = s
	return best
