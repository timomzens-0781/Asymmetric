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
var hot_t := 0.0                # Gebaeude hat gerade geschossen (feindliche Aktivitaet)
var warned := false
var garrisoned: Array = []
var garrison_cap := 5
var queue: Array = []           # {kind, t, total}
var rally := Vector3.ZERO
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
		produces = ["reb_fighter", "reb_rpg", "reb_tech", "reb_launcher", "reb_media", "reb_saboteur"]
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
		p = Vector3(position.x + randf_range(-hx * 0.6, hx * 0.6), 0, position.z + hz + (3.5 if vehicle else 2.0))
	else:
		# Rebellen: Tuer zur naechsten Strasse / Mitte
		var ang := randf() * TAU
		p = position + Vector3(cos(ang) * (hx + 2.0), 0, sin(ang) * (hz + 2.0))
	return world.nav.nearest_free_pos(p, "veh" if vehicle else "foot", 12)

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

func _tunnel_emerge(u: Unit) -> void:
	# ADF sieht Einheit aus dem Haus kommen -> Verdacht / Entdeckung
	if revealed:
		return
	for o in world.dyn.query(position, 26.0):
		if o is Unit and o.alive and o.team == U.TEAM_ADF and U.dist2d(o.position, position) < 22.0:
			revealed = true
			ident_mask |= 1
			Game.message("Tunnelzugang entdeckt!", "good", U.TEAM_ADF)
			Game.news("Soldaten beobachten Bewaffnete beim Verlassen eines Wohnhauses", "info")
			return

# ============================================================================= Sim
func _process(dt: float) -> void:
	if not alive or world == null or world.paused:
		return
	dt = minf(dt, 0.12)
	if hot_t > 0.0:
		hot_t -= dt
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

func die(attacker: Entity, dtype: String) -> void:
	if not alive:
		return
	alive = false
	world.structure_destroyed(self, attacker, dtype)
