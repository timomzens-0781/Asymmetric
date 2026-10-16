class_name Structure
extends Entity
## Gebaeude: zivile Haeuser (mit Bewohnern), Rebellen-Tunnelknoten, Krankenhaus/Schule, ADF-Basisgebaeude.

var kind_class := "house"       # house | hospital | school | base
var size := Vector3(8, 8, 8)
var hx := 4.0
var hz := 4.0
var occupants := 0
var hub := false
var revealed := false           # Tunnelknoten fuer ADF entlarvt
var suspicion := 0.0             # Verdacht der Armee gegen dieses Haus (0..130), durch Beobachtung
var search_t := 0.0              # Fortschritt der Durchsuchung (Sekunden ohne Widerstand)
var _obs_t := 0.0
var _susp_warned := false
const SEARCH_TIME := 5.0
var _staged_ping := 0.0
var _staged_pings := 0
var staged_t := 0.0             # Klinik/Schule inszeniert (Koeder + Propaganda)
var hot_t := 0.0                # Gebaeude hat gerade geschossen (feindliche Aktivitaet)
var warned := false
var garrisoned: Array = []
var stormers: Array = []          # Angreifer, die gerade im Haus kaempfen (Haeuserkampf)
var _storm_round_t := 0.0
var searched_t := 0.0             # Haus wurde durchsucht/gesichert
var garrison_cap := 5
var queue: Array = []           # {kind, t, total}
var rally := Vector3.ZERO
var rally_hub: Structure = null   # Neuzugaenge (Infanterie) reisen durch den Tunnel zu diesem Knoten
var produces: Array = []
var weapons: Array = []
var target: Entity = null
var mat: ShaderMaterial = null
var building_id := -1
var _acq_t := 0.0
var _smoke: Node3D = null
var _fire: Node3D = null
var _evac_left := 0
var _evac_t := 0.0
var _spawn_flip := false
var _dmg_vis := 0.0
var prod_pause := false

func is_structure() -> bool:
	return true

func setup_building(w: World, b: Dictionary) -> void:
	world = w
	kind = b.kind
	kind_class = b.kind if b.kind in ["hospital", "school"] else "house"
	size = b.size
	hx = size.x * 0.5
	hz = size.z * 0.5
	radius = maxf(hx, hz) * 0.95
	team = U.TEAM_CIV
	armor = "struct"
	max_hp = b.hp
	hp = max_hp
	occupants = b.occ
	hub = b.hub
	if hub:
		team = U.TEAM_REB
		max_hp *= 1.6
		hp = max_hp
		produces = ["reb_fighter", "reb_rpg", "reb_sniper", "reb_tech", "reb_launcher", "reb_media", "reb_saboteur"]
	garrison_cap = clampi(int(size.x * size.z / 22.0), 3, 8)
	position = b.center
	model = b.node
	mat = b.mat
	building_id = b.id
	vision = 18.0 if hub else 0.0
	name = "B%d" % building_id
	model.set_meta("structure", self)

func setup_base(w: World, k: String, t: int) -> void:
	world = w
	kind = k
	team = t
	kind_class = "base"
	def = Data.STRUCTS[k]
	size = def.size
	hx = size.x * 0.5
	hz = size.z * 0.5
	radius = maxf(hx, hz) * 0.95
	armor = "struct"
	max_hp = def.hp
	hp = max_hp
	vision = def.vision
	produces = def.get("produces", [])
	for wd in def.get("weapons", []):
		var ww: Dictionary = wd.duplicate()
		ww["cdl"] = randf() * ww.cd
		weapons.append(ww)
	model = Models.build_structure(k, t)
	add_child(model)
	parts = model.get_meta("parts", {})
	name = "%s_%d" % [k, id]

func _make_selection_visual() -> void:
	var holder := Node3D.new()
	var m := Gfx.unshaded_mat(Color(0.45, 1.0, 0.5, 0.95), false, true)
	var t := 0.45
	for part in [[Vector3(0, 0.2, hz + t * 0.5), Vector3(hx * 2.0 + t * 2.0, 0.3, t)], [Vector3(0, 0.2, -hz - t * 0.5), Vector3(hx * 2.0 + t * 2.0, 0.3, t)],
				[Vector3(hx + t * 0.5, 0.2, 0), Vector3(t, 0.3, hz * 2.0)], [Vector3(-hx - t * 0.5, 0.2, 0), Vector3(t, 0.3, hz * 2.0)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[1]
		mi.mesh = bm
		mi.position = part[0]
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	add_child(holder)
	sel_node = holder

func edge_dist(p: Vector3) -> float:
	var dx := maxf(absf(p.x - position.x) - hx, 0.0)
	var dz := maxf(absf(p.z - position.z) - hz, 0.0)
	return sqrt(dx * dx + dz * dz)

func contains_xz(p: Vector3, pad: float = 0.0) -> bool:
	return absf(p.x - position.x) <= hx + pad and absf(p.z - position.z) <= hz + pad

## Punkt direkt vor der Tuer (Seite, die 'from' zugewandt ist)
func door_pos(from: Vector3) -> Vector3:
	var dx := from.x - position.x
	var dz := from.z - position.z
	var p: Vector3
	if absf(dx) / maxf(hx, 0.1) > absf(dz) / maxf(hz, 0.1):
		p = Vector3(position.x + signf(dx) * (hx + 1.5), 0, position.z + clampf(dz, -hz + 1.0, hz - 1.0))
	else:
		p = Vector3(position.x + clampf(dx, -hx + 1.0, hx - 1.0), 0, position.z + signf(dz) * (hz + 1.5))
	return world.nav.nearest_free_pos(p, "foot", 8)

func exit_pos(vehicle: bool) -> Vector3:
	var p: Vector3
	if team == U.TEAM_ADF:
		# Ausgang in Richtung Sammelplatz der Basis
		var a := world.city.base_assembly - position
		a.y = 0.0
		var dir := a.normalized() if a.length() > 1.0 else Vector3(0, 0, 1)
		var tx := hx / maxf(absf(dir.x), 0.001)
		var tz := hz / maxf(absf(dir.z), 0.001)
		var t := minf(tx, tz)
		var side := Vector3(-dir.z, 0, dir.x) * randf_range(-hx * 0.4, hx * 0.4)
		p = position + dir * (t + (4.5 if vehicle else 2.5)) + side
	else:
		# Rebellen: Tuer zur naechsten Strasse / Mitte
		var ang := randf() * TAU
		p = position + Vector3(cos(ang) * (hx + 2.0), 0, sin(ang) * (hz + 2.0))
	return world.nav.nearest_free_pos(p, "veh" if vehicle else "foot", 12)

# ============================================================================= Garnison
## Besatzung eines Teams (ohne Einheiten im Tunnel)
func garrison_of(t: int) -> Array:
	var out: Array = []
	for g in garrisoned:
		if is_instance_valid(g) and g.alive and g.team == t and g.tunnel_t <= 0.0:
			out.append(g)
	return out

## Schiessscharte: Punkt an der dem Ziel zugewandten Fassade
func window_pos(toward: Vector3) -> Vector3:
	var d := toward - position
	d.y = 0.0
	if d.length() < 0.1:
		d = Vector3(1, 0, 0)
	d = d.normalized()
	var k := minf(hx / maxf(absf(d.x), 0.001), hz / maxf(absf(d.z), 0.001))
	return position + d * (k + 0.2) + Vector3(0, clampf(size.y * 0.45, 2.2, 6.5), 0)

## Wer aus einem Haus auf die Armee schiesst, verraet es: Tunnelknoten werden sofort entdeckt.
func exposed_by_fire() -> void:
	hot_t = 12.0
	if hub and not revealed:
		mark_revealed("Feuer aus dem Haus")
		Game.message("Feuer aus einem Wohnhaus – Tunnelknoten entdeckt!", "good", U.TEAM_ADF)
		Game.alert.emit(position, "identified")

# ============================================================================= Produktion
func can_produce(k: String) -> bool:
	return k in produces

func queue_unit(k: String) -> bool:
	if not alive or not can_produce(k) or queue.size() >= 6:
		return false
	var d: Dictionary = Data.UNITS[k]
	if team == U.TEAM_ADF and k == "adf_viper" and Game.no_fly_zone():
		Game.message("Flugverbotszone: keine Luftfahrzeuge verfügbar!", "bad", team)
		return false
	if not Game.can_afford(team, d.cost):
		Game.message("Nicht genug Budget", "warn", team)
		return false
	if Game.pop_used(team) + queued_pop() + d.pop > Game.pop_cap(team):
		Game.message("Truppenobergrenze erreicht", "warn", team)
		return false
	Game.spend(team, d.cost)
	queue.append({"kind": k, "t": 0.0, "total": d.time})
	return true

func queued_pop() -> int:
	var n := 0
	for q in queue:
		n += Data.UNITS[q.kind].pop
	return n

func cancel_unit(idx: int) -> void:
	if idx < 0 or idx >= queue.size():
		return
	var q: Dictionary = queue[idx]
	Game.refund(team, Data.UNITS[q.kind].cost)
	queue.remove_at(idx)

func _tick_production(dt: float) -> void:
	if queue.is_empty():
		return
	var q: Dictionary = queue[0]
	q.t += dt * Game.prod_speed(team)
	if q.t >= q.total:
		var k: String = q.kind
		var d: Dictionary = Data.UNITS[k]
		queue.pop_front()
		var veh: bool = d.layer != "foot" and d.layer != "air"
		var p := exit_pos(veh)
		var u := world.spawn_unit(k, team, p)
		if u != null:
			if team == U.TEAM_REB and hub:
				_tunnel_emerge(u)
			if rally != Vector3.ZERO and U.dist2d(rally, p) > 3.0:
				u.cmd_move(rally)
			elif d.layer == "air":
				u.cmd_move(p + Vector3(0, 0, 14))
			if team == Game.player_team and not Game.demo_mode:
				Sfx.play_ui("ready")

## Tunnelknoten als entdeckt markieren (einmalig) und im Ereignisprotokoll festhalten
func mark_revealed(reason: String) -> void:
	if revealed:
		return
	revealed = true
	ident_mask |= 1
	Game.stats.hubs_found = int(Game.stats.get("hubs_found", 0)) + 1
	Game.log_event("hub_found", "Tunnelknoten entdeckt (%s)" % reason, position)

func _check_hub_exposed() -> void:
	# Wer aus dem Tunnelknoten schiesst, wird von der Armee in der Naehe bemerkt
	for o in world.dyn.query(position, 32.0):
		if o is Unit and o.alive and o.team == U.TEAM_ADF and U.dist2d(o.position, position) < 30.0 and (o as Unit).layer != "air":
			mark_revealed("Feuer aus dem Haus")
			Game.message("Feuer aus einem Wohnhaus – Tunnelknoten entdeckt!", "good", U.TEAM_ADF)
			Game.alert.emit(position, "identified")
			return

func _tunnel_emerge(u: Unit) -> void:
	# ADF sieht Einheit aus dem Haus kommen -> Verdacht / Entdeckung
	if revealed:
		return
	for o in world.dyn.query(position, 26.0):
		if o is Unit and o.alive and o.team == U.TEAM_ADF and U.dist2d(o.position, position) < 22.0:
			mark_revealed("Kämpfer verlassen das Haus")
			Game.message("Tunnelzugang entdeckt!", "good", U.TEAM_ADF)
			Game.news("Soldaten beobachten Bewaffnete beim Verlassen eines Wohnhauses", "info")
			return
	note_traffic(60.0, "Kämpfer verlassen das Haus")

# ============================================================================= Verdacht durch Beobachtung
## Wie gut wird das Haus von der Armee beobachtet? 0 = gar nicht; Aufklaerer und Drohnen sehen mehr
func observed_by_adf() -> float:
	var best := 0.0
	for o in world.dyn.query(position, 64.0):
		if not (o is Unit) or not o.alive or o.team != U.TEAM_ADF or o.vision <= 0.0:
			continue
		var u := o as Unit
		if u.layer == "air" and Game.jam_t > 0.0:
			continue
		var d := U.dist2d(u.position, position)
		if d > u.vision + radius:
			continue
		if d > 6.0 and not world.smokes.is_empty() and (world.in_smoke(position) or world.in_smoke(u.position)):
			continue
		var k := 1.0 if d < 32.0 else 0.55
		if u.kind == "adf_recon" or u.layer == "air":
			k *= 1.5
		best = maxf(best, k)
	return best

## Bewegung am Haus (Kaempfer gehen hinein/heraus): faellt auf, wenn jemand hinsieht
func note_traffic(v: float, reason: String) -> void:
	if team == U.TEAM_ADF or kind_class != "house" or revealed:
		return
	var ob := observed_by_adf()
	if ob > 0.0:
		add_suspicion(v * ob, reason)

func add_suspicion(v: float, reason: String) -> void:
	if team == U.TEAM_ADF or revealed or searched_t > 0.0 or kind_class != "house":
		return
	suspicion = minf(suspicion + v, 130.0)
	if suspicion >= 50.0 and not _susp_warned:
		_susp_warned = true
		Game.message("Verdächtige Aktivität an einem Gebäude – durchsuchen lassen!", "info", U.TEAM_ADF)
		Game.alert.emit(position, "identified")
	if suspicion >= 100.0:
		if hub:
			mark_revealed("Beobachtung: " + reason)
			Game.message("Beobachtung: Tunnelzugang entdeckt!", "good", U.TEAM_ADF)
			Game.news("Aufklärung beobachtet Bewaffnete an einem Wohnhaus – Tunnelzugang vermutet", "info")
		else:
			hot_t = maxf(hot_t, 15.0)
			Game.message("Bewaffnete in einem Wohnhaus beobachtet", "good", U.TEAM_ADF)
			suspicion = 65.0

func _tick_suspicion(dt: float) -> void:
	if team == U.TEAM_ADF or kind_class != "house":
		return
	var n := 0
	for g in garrison_of(U.TEAM_REB):
		if (g as Unit).tunnel_t <= 0.0:
			n += 1
	if n > 0 and not revealed and searched_t <= 0.0:
		var ob := observed_by_adf()
		if ob > 0.0:
			add_suspicion((1.5 + 0.4 * n + (0.8 if hub else 0.0)) * ob * dt, "Beobachtung")
			return
	if suspicion > 0.0:
		suspicion = maxf(0.0, suspicion - 0.6 * dt)
		if suspicion < 45.0:
			_susp_warned = false

# ============================================================================= Haeuserkampf
func can_be_stormed() -> bool:
	return alive and kind_class == "house" and stormers.size() < 8

func add_stormer(u: Unit) -> void:
	if u in stormers or stormers.size() >= 8:
		u.order_type = "idle"
		return
	stormers.append(u)
	u.storming = self
	u.order_type = "idle"
	u.path = PackedVector3Array()
	u.path_i = 0
	u.position = Vector3(position.x, 0.0, position.z)
	u.visible = false
	if u.selected:
		world.deselect_entity(u)
	hot_t = 7.0
	_storm_round_t = minf(_storm_round_t, 1.0) if stormers.size() > 1 else 1.2
	if stormers.size() == 1:
		Game.stats.storms = int(Game.stats.get("storms", 0)) + 1
		Game.message("Haus wird gestürmt", "info", u.team)
		Game.log_event("storm", "Haus gestürmt", position)

func _sim_storm(dt: float) -> void:
	stormers = stormers.filter(func(u): return is_instance_valid(u) and u.alive)
	if stormers.is_empty():
		search_t = 0.0
		return
	search_t += dt
	_storm_round_t -= dt
	if _storm_round_t > 0.0:
		return
	_storm_round_t = 2.0
	var att_team: int = stormers[0].team
	var defenders: Array = garrisoned.filter(func(g): return is_instance_valid(g) and g.alive and g.team != att_team and g.tunnel_t <= 0.0)
	hot_t = 7.0
	if defenders.is_empty():
		if search_t < SEARCH_TIME:
			_storm_round_t = 0.4     # Durchsuchen dauert: Zimmer fuer Zimmer
			return
		_storm_done()
		return
	if hub and not revealed:
		mark_revealed("Sturm auf das Haus")
		Game.message("Widerstand im Haus – Tunnelknoten entdeckt!", "good", U.TEAM_ADF)
	var a := stormers.size()
	var d := defenders.size()
	var victim: Unit = defenders[randi() % d]
	victim.take_damage(15.0 * sqrt(float(a)) * randf_range(0.7, 1.3), stormers[0], "bullet", position)
	if not stormers.is_empty():
		var att: Unit = stormers[randi() % stormers.size()]
		att.take_damage(13.0 * sqrt(float(d)) * randf_range(0.7, 1.3), defenders[0], "bullet", position)
	# Gefechtslaerm an den Fenstern
	var wp := position + Vector3(randf_range(-hx, hx) * 0.8, size.y * randf_range(0.3, 0.8), randf_range(-hz, hz) * 0.8)
	world.fx.muzzle_flash(wp)
	Sfx.play_at("shot_mg", position)
	world.noise(position, 40.0, 1)
	# Zivilisten im Haus geraten ins Feuer
	if occupants > 0 and randf() < 0.14:
		occupants -= 1
		Game.report_civilian_deaths(position, 1.0, att_team, "direct", true)
	if stormers.is_empty():
		Game.message("Sturm gescheitert – alle Angreifer gefallen", "bad", att_team)

func _storm_done() -> void:
	var team_a: int = stormers[0].team if not stormers.is_empty() else U.TEAM_ADF
	var had_fight := false
	for g in garrisoned:
		if is_instance_valid(g) and g.team != team_a:
			had_fight = true
	for u in stormers.duplicate():
		if is_instance_valid(u) and u.alive:
			u.storming = null
			u.visible = true
			u.position = world.nav.nearest_free_pos(door_pos(u.position), "foot", 8)
			u.order_type = "idle"
	stormers.clear()
	search_t = 0.0
	suspicion = 0.0
	_susp_warned = false
	searched_t = 60.0
	if hub:
		secure()
	elif occupants > 0:
		# Durchsuchung: Anwohner sind verängstigt, kleine Schikane
		Game.add_outrage(0.4, false, "check")
		world.add_anger(position, 1.5)
		Game.message("Haus durchsucht: nichts Verdächtiges", "info", team_a)
	else:
		Game.message("Haus gesichert", "good", team_a)

## Tunnelknoten im Haeuserkampf eingenommen: Zugang gesichert, Netz verliert den Knoten (ohne Einsturz).
func secure() -> void:
	if not hub:
		return
	hub = false
	revealed = false
	team = U.TEAM_CIV
	produces = []
	queue.clear()
	for g in garrisoned.duplicate():
		if is_instance_valid(g):
			(g as Unit).ungarrison()
			g.take_damage(9999.0, null, "he", position)
	garrisoned.clear()
	world.hubs.erase(self)
	Game.stats.hubs_secured = int(Game.stats.get("hubs_secured", 0)) + 1
	Game.hub_destroyed(self)
	Game.message("Tunnelzugang gesichert!", "good", U.TEAM_ADF)
	Game.log_event("hub", "Tunnelknoten im Häuserkampf gesichert", position)
	world.fx.dust_cloud(position + Vector3(0, 1.0, 0), 2.0)

# ============================================================================= Sim
func _process(dt: float) -> void:
	if not alive or world == null or world.paused:
		return
	dt = minf(dt, 0.12)
	if hot_t > 0.0:
		hot_t -= dt
		if hub and not revealed:
			_check_hub_exposed()
	if staged_t > 0.0:
		staged_t -= dt
		hot_t = maxf(hot_t, 1.0)
	if hit_flash > 0.0:
		hit_flash -= dt
	if team != U.TEAM_CIV or hub:
		_tick_production(dt)
	if not weapons.is_empty():
		_sim_weapons(dt)
	if parts.has("rotor"):
		var ax: int = parts.get("rotor_axis", 0)
		(parts.rotor as Node3D).rotation.y += dt * 1.2
	_sim_evac(dt)
	if not stormers.is_empty():
		_sim_storm(dt)
	if searched_t > 0.0:
		searched_t -= dt
	_obs_t -= dt
	if _obs_t <= 0.0:
		_obs_t = 0.5
		_tick_suspicion(0.5)
	# Rauch/Feuer bei Schaden
	var f := 1.0 - hp / max_hp
	if f > 0.45 and _smoke == null:
		_smoke = world.fx.attach_smoke(self, 2.5 + radius * 0.15, 9999.0)
	if f > 0.75 and _fire == null:
		_fire = world.fx.attach_fire(self)

func _sim_weapons(dt: float) -> void:
	for w in weapons:
		w.cdl -= dt
	_acq_t -= dt
	if _acq_t <= 0.0:
		_acq_t = 0.3 + randf() * 0.2
		if target != null and (not target.alive or edge_dist(target.position) > weapons[0].range * 1.1 or not world.can_auto_target(self, target)):
			target = null
		if target == null:
			target = world.find_target(self, weapons[0].range)
	if target != null and target.alive:
		var d := U.dist2d(position, target.position)
		if parts.has("turret"):
			var want := atan2(target.position.x - position.x, target.position.z - position.z)
			var tur := parts.turret as Node3D
			tur.rotation.y = U.angle_toward(tur.rotation.y, want, 4.0 * dt)
		for w in weapons:
			if w.cdl <= 0.0 and d <= w.range:
				w.cdl = w.cd * randf_range(0.95, 1.1)
				var from := global_position + Vector3(0, 8.3, 0)
				if parts.has("muzzle"):
					from = (parts.muzzle as Node3D).global_position
				var aim := target.position + Vector3(0, 1.0, 0)
				world.fx.tracer(from, aim, false)
				world.fx.muzzle_flash(from)
				Sfx.play_at("shot_mg", position)
				world.noise(position, 30.0, 1)
				target.take_damage(w.damage, self, w.type, position)

# ----------------------------------------------------------------------------- Evakuierung
func evacuate(secs: float = 9.0) -> void:
	if warned or occupants <= 0 and garrisoned.is_empty():
		warned = true
		return
	warned = true
	_evac_left = occupants
	_evac_t = 0.0
	# Kaempfer im Haus: schlagen Alarm, KI-Rebellen verlassen das Gebaeude
	for u in garrisoned.duplicate():
		if u.team == U.TEAM_REB and (u as Unit).ai_role != "":
			(u as Unit).ungarrison()
	world.noise(position, 40.0, 3)

func _sim_evac(dt: float) -> void:
	if _evac_left <= 0:
		return
	_evac_t -= dt
	if _evac_t <= 0.0:
		_evac_t = 0.55
		if occupants > 0:
			occupants -= 1
			_evac_left -= 1
			world.release_civilian(self, true)

# ============================================================================= Schaden
func _on_damaged(dmg: float, attacker: Entity, _dtype: String) -> void:
	if mat != null:
		var f := clampf(1.0 - hp / max_hp, 0.0, 1.0)
		if absf(f - _dmg_vis) > 0.04:
			_dmg_vis = f
			mat.set_shader_parameter("damage", f)
	if kind_class != "base" and attacker != null:
		# Zivilisten im Gebaeude geraten in Panik
		if occupants > 0 and randf() < 0.5:
			world.release_civilian(self, false)
			occupants -= 1
	if team == U.TEAM_ADF and attacker != null and attacker.team == U.TEAM_REB:
		Game.base_under_attack(self)
	if staged_t > 0.0 and attacker != null and attacker.team == U.TEAM_ADF and world.time > _staged_ping and _staged_pings < 4:
		_staged_ping = world.time + 5.0
		_staged_pings += 1
		Game.report_event_outrage(position, 1.5, "", "staged")

func die(attacker: Entity, dtype: String) -> void:
	if not alive:
		return
	alive = false
	world.structure_destroyed(self, attacker, dtype)
