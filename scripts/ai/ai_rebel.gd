class_name AiRebel
extends Node
## KI der Hadar-Front: Hinterhalte aus Haeusern, getarnte Patrouillen, Raketenprovokation aus dicht
## besiedelten Gebieten, Medien-Teams, Sprengfallen, Gegenangriffe.

var world: World
var team := 1
var _t := 2.0
var _fast_t := 0.0
var _launch_cd := 20.0
var _ied_cd := 45.0
var _rng := RandomNumberGenerator.new()
var _garrison_spots: Array = []
var _hot_point := Vector3.ZERO
var _hot_t := -99.0
var _tun_cd := 0.0

func _ready() -> void:
	_rng.randomize()
	_launch_cd = [50.0, 32.0, 22.0][Game.difficulty] * _rng.randf_range(0.8, 1.2) + 12.0

func _diff() -> float:
	return [0.7, 1.0, 1.4][Game.difficulty]

func _process(dt: float) -> void:
	if world == null or world.paused or not Game.running:
		return
	_t -= dt
	_fast_t -= dt
	_launch_cd -= dt
	_ied_cd -= dt
	if _fast_t <= 0.0:
		_fast_t = 0.6
		_micro()
	if _t <= 0.0:
		_t = 1.0
		_think()

func _units(kind: String) -> Array:
	var a: Array = []
	for u in world.units:
		if u.alive and u.team == team and u.kind == kind:
			a.append(u)
	return a

func _all_units() -> Array:
	var a: Array = []
	for u in world.units:
		if u.alive and u.team == team:
			a.append(u)
	return a

func _alive_hubs() -> Array:
	var a: Array = []
	for h in world.hubs:
		if h.alive:
			a.append(h)
	return a

func _think() -> void:
	_produce()
	_tunnel_ops()
	_assign_infantry()
	_launcher_ops()
	_media_ops()
	_ied_ops()
	_retreat_wounded()
	if Game.ability_ready(team, "donate") and Game.outrage >= 20.0:
		Game.use_ability(team, "donate")
	if Game.ability_ready(team, "upload") and Game.footage > 4.0:
		Game.use_ability(team, "upload")

# ----------------------------------------------------------------------------- Tunnelnetz
func _hub_threat(h: Structure) -> float:
	var th := 0.0
	for o in world.dyn.query(h.position, 44.0):
		if o is Unit and o.alive and o.team == U.TEAM_ADF and not (o as Unit).weapons.is_empty():
			if U.dist2d(o.position, h.position) < 42.0:
				th += 0.5 if (o as Unit).layer == "foot" else 1.0
	if h.hp < h.max_hp * 0.7:
		th += 1.0
	return th

## Besatzung bedrohter Knoten verschwindet durch den Tunnel in den sichersten Knoten.
func _tunnel_ops() -> void:
	_tun_cd -= 1.0
	if _tun_cd > 0.0:
		return
	var hubs := _alive_hubs()
	if hubs.size() < 2:
		return
	for h in hubs:
		if h.garrisoned.is_empty():
			continue
		if _hub_threat(h) < 1.5:
			continue
		var best: Structure = null
		var best_sc := -1e9
		for o in hubs:
			if o == h or o.garrisoned.size() >= o.garrison_cap:
				continue
			if world.tunnel_route(h, o).is_empty():
				continue
			var sc: float = -_hub_threat(o) * 60.0 + U.dist2d(o.position, h.position) * 0.15 - (o.garrisoned.size() * 3.0)
			if sc > best_sc:
				best_sc = sc
				best = o
		if best == null:
			continue
		var moved := 0
		for u in h.garrisoned.duplicate():
			if u is Unit and (u as Unit).tunnel_t <= 0.0 and (u as Unit).cmd_tunnel(best):
				moved += 1
		if moved > 0:
			_tun_cd = 6.0

# ----------------------------------------------------------------------------- Produktion
func _count_kind(k: String) -> int:
	var n := 0
	for u in world.units:
		if u.alive and u.team == team and u.kind == k:
			n += 1
	for h in world.hubs:
		if h.alive:
			for q in h.queue:
				if q.kind == k:
					n += 1
	return n

func _produce() -> void:
	var hubs := _alive_hubs()
	if hubs.is_empty():
		return
	# Wer Geld uebrig hat, bildet mehr aus (Spenden durch Wut fliessen in die Produktion)
	var k := _diff() * (1.0 + clampf((Game.budget[team] - 1200.0) / 2500.0, 0.0, 0.9))
	var wish := [
		["reb_fighter", int(16 * k), 3.0], ["reb_rpg", int(6 * k), 2.0], ["reb_tech", int(3 * k), 1.5],
		["reb_launcher", 2 + int(_diff()), 1.8], ["reb_media", 2, 2.2], ["reb_saboteur", 1 + int(_diff()), 1.2],
	]
	var best_k := ""
	var best_sc := -1.0
	for w in wish:
		var have := _count_kind(w[0])
		if have >= w[1]:
			continue
		var sc: float = float(w[1] - have) / float(w[1]) * float(w[2])
		if sc > best_sc:
			best_sc = sc
			best_k = w[0]
	if best_k == "":
		return
	var d: Dictionary = Data.UNITS[best_k]
	if Game.budget[team] < d.cost:
		return
	var h: Structure = hubs[_rng.randi() % hubs.size()]
	for hh in hubs:
		if hh.queue.size() < h.queue.size():
			h = hh
	if h.queue.size() < 2:
		h.queue_unit(best_k)

# ----------------------------------------------------------------------------- Infanterie
func _ambush_buildings() -> Array:
	if not _garrison_spots.is_empty():
		return _garrison_spots
	# Gebaeude entlang des Anmarschwegs der Armee und rund um die Tunnelknoten
	var spots: Array = []
	var path: PackedVector3Array = world.nav.find_path(world.city.base_front, world.city.far_goal, "foot")
	for s in world.structures:
		if not s.alive or s.kind_class != "house":
			continue
		var near := false
		for i in range(0, path.size()):
			if U.dist2d(s.position, path[i]) < 16.0:
				near = true
				break
		for h in world.hubs:
			if U.dist2d(s.position, h.position) < 22.0:
				near = true
		if near and world.city.is_far_from_base(s.position, 70.0):
			spots.append(s)
	_garrison_spots = spots
	return spots

func _assign_infantry() -> void:
	var spots := _ambush_buildings()
	if spots.is_empty():
		return
	for u in _all_units():
		if u.garrison != null or not (u.kind == "reb_fighter" or u.kind == "reb_rpg"):
			continue
		if u.order_type != "idle" or u.ai_role != "":
			continue
		var roll := _rng.randf()
		if roll < 0.7:
			# Hinterhalt in einem Haus
			var s: Structure = spots[_rng.randi() % spots.size()]
			if s.alive and s.garrisoned.size() < minf(s.garrison_cap, 4):
				u.ai_role = "ambush"
				u.cmd_garrison(s)
		elif roll < 0.9:
			u.ai_role = "roam"
			u.hold = true      # Streuner schiessen erst, wenn die KI es befiehlt
			var p := world.city.random_street_point(_rng)
			if p.x > -30.0:
				u.cmd_move(p)
		else:
			var hubs := _alive_hubs()
			if not hubs.is_empty():
				var h: Structure = hubs[_rng.randi() % hubs.size()]
				u.ai_role = "guard"
				u.hold = true       # Waechter verraten den Tunnelknoten nicht durch Feuer
				u.cmd_garrison(h)
	# Rollen von Streunern auffrischen
	for u in _all_units():
		if u.ai_role == "roam" and u.order_type == "idle" and _rng.randf() < 0.15:
			var p2 := world.city.random_street_point(_rng)
			if world.city.is_far_from_base(p2, 60.0):
				u.cmd_move(p2)
		if u.ai_role == "ambush" and u.garrison == null and u.order_type == "idle":
			u.ai_role = ""

# ----------------------------------------------------------------------------- Raketen
func _civs_near(pos: Vector3, r: float) -> float:
	var n := 0.0
	for o in world.dyn.query(pos, r):
		if o is Civilian and o.alive and U.dist2d(o.position, pos) < r:
			n += 1.0
	for s in world.structures:
		if s.alive and s.team == U.TEAM_CIV and s.edge_dist(pos) < r * 0.7:
			n += s.occupants * 0.25
	return n

func _launcher_ops() -> void:
	for l in _units("reb_launcher"):
		var d: Dictionary = l.ai_data
		var st: String = d.get("state", "idle")
		match st:
			"idle":
				if _launch_cd <= 0.0 and l.order_type == "idle":
					_start_launch(l)
			"go":
				if l.order_type == "idle" and U.dist2d(l.position, d.spot) < 8.0:
					# Feuerbefehl auf ADF-Ziel
					var tgt := _pick_adf_target(l.position)
					if tgt != null:
						l.cmd_attack_ground(tgt.position + Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4)))
						d["state"] = "fire"
						d["t"] = Game.time
					else:
						d["state"] = "return"
				elif l.order_type == "idle":
					l.cmd_move(d.spot)
				if Game.time - d.get("go_t", Game.time) > 70.0:
					d["state"] = "return"
			"fire":
				if l.order_type == "idle" and Game.time - d.t > 3.0:
					d["state"] = "return"
				if Game.time - d.t > 25.0:
					d["state"] = "return"
			"return":
				var hubs := _alive_hubs()
				if not hubs.is_empty():
					var h: Structure = hubs[_rng.randi() % hubs.size()]
					for hh in hubs:
						if U.dist2d(hh.position, l.position) < U.dist2d(h.position, l.position):
							h = hh
					l.cmd_move(world.nav.nearest_free_pos(h.exit_pos(true), "veh", 10))
				d["state"] = "home"
				d["home_t"] = Game.time
			"home":
				if Game.time - d.home_t > 14.0 or l.order_type == "idle":
					d["state"] = "idle"

func _start_launch(l: Unit) -> void:
	# Abschussposition: dicht besiedeltes Gebiet in Raketenreichweite der Basis
	var best := Vector3.ZERO
	var best_sc := -1.0
	var base: Vector3 = world.city.base_assembly
	for i in range(8):
		var p := world.city.random_street_point(_rng)
		var dist := U.dist2d(p, base)
		if dist < 70.0 or dist > 128.0:
			continue
		p = world.nav.nearest_free_pos(p, "veh", 6)
		if world.nav.is_solid_at(p, "veh"):
			continue
		var sc := _civs_near(p, 22.0) + _rng.randf() * 2.0
		if sc > best_sc:
			best_sc = sc
			best = p
	if best_sc < 0.0:
		return
	_launch_cd = [60.0, 38.0, 26.0][Game.difficulty] * _rng.randf_range(0.8, 1.25)
	# Gleichzeitig nur ein Werfer unterwegs
	l.ai_data["state"] = "go"
	l.ai_data["spot"] = best
	l.ai_data["go_t"] = Game.time
	l.cmd_move(best)

func _pick_adf_target(from: Vector3) -> Structure:
	var cands: Array = []
	for s in world.structures:
		if s.alive and s.team == U.TEAM_ADF and s.kind != "adf_fieldhosp" and U.dist2d(s.position, from) < 135.0 and U.dist2d(s.position, from) > 36.0:
			cands.append(s)
	if cands.is_empty():
		return null
	return cands[_rng.randi() % cands.size()]

# ----------------------------------------------------------------------------- Medien
func _media_ops() -> void:
	# Brennpunkt: Schwerpunkt sichtbarer ADF-Truppen; sonst letzter Abschussort / Marktplatz
	var c := Vector3.ZERO
	var n := 0
	for u in world.units:
		if u.alive and u.team == U.TEAM_ADF and u.seen_by(team) and u.layer != "air" and world.city.is_far_from_base(u.position, 50.0):
			c += u.position
			n += 1
	if n > 0:
		_hot_point = c / n
		_hot_t = Game.time
	var media := _units("reb_media")
	var idx := 0
	for m in media:
		var spot: Vector3 = _hot_point
		if Game.time - _hot_t >= 40.0:
			var pc: Vector2 = world.city.plaza_rect.get_center()
			spot = Vector3(pc.x, 0, pc.y)
		# 25 m vom Brennpunkt, in Sichtweite aber nicht im Feuer
		var off := Vector3(cos(idx * 2.1 + 1.0), 0, sin(idx * 2.1 + 1.0)) * (24.0 + idx * 6.0)
		var dest: Vector3 = world.nav.nearest_free_pos(spot + off, "foot", 10)
		if m.order_type == "idle" and U.dist2d(m.position, dest) > 12.0:
			m.cmd_move(dest)
		idx += 1

# ----------------------------------------------------------------------------- Sprengfallen
func _ied_ops() -> void:
	for s in _units("reb_saboteur"):
		var d: Dictionary = s.ai_data
		var st: String = d.get("state", "idle")
		if st == "idle" and _ied_cd <= 0.0 and s.order_type == "idle":
			var path: PackedVector3Array = world.nav.find_path(world.city.base_front, world.city.far_goal, "veh")
			if path.size() > 3:
				var pt: Vector3 = path[_rng.randi_range(1, path.size() - 2)]
				if world.city.is_far_from_base(pt, 60.0):
					s.ai_data = {"state": "go", "spot": pt}
					s.cmd_move(pt)
					_ied_cd = _rng.randf_range(35.0, 60.0) / _diff()
		elif st == "go" and s.order_type == "idle":
			s.cmd_place_ied()
			var hubs := _alive_hubs()
			if not hubs.is_empty():
				s.cmd_move(world.nav.nearest_free_pos(hubs[_rng.randi() % hubs.size()].exit_pos(false), "foot", 8))
			s.ai_data = {"state": "idle"}

# ----------------------------------------------------------------------------- Gefecht
func _retreat_wounded() -> void:
	var hubs := _alive_hubs()
	if hubs.is_empty():
		return
	for u in _all_units():
		if u.garrison != null or u.weapons.is_empty() or u.is_launcher:
			continue
		if u.hp < u.max_hp * 0.3 and u.ai_role != "retreat":
			var h: Structure = hubs[0]
			for hh in hubs:
				if U.dist2d(hh.position, u.position) < U.dist2d(h.position, u.position):
					h = hh
			u.ai_role = "retreat"
			if u.can_conceal:
				u.cmd_garrison(h)
			else:
				u.cmd_move(h.exit_pos(u.layer != "foot"))

func _micro() -> void:
	# Sichtbare ADF-Einheiten in der Naehe unserer Zonen angreifen
	var enemies: Array = []
	for u in world.units:
		if u.alive and u.team == U.TEAM_ADF and u.seen_by(team) and u.layer != "air":
			enemies.append(u)
	if enemies.is_empty():
		return
	var mine := _all_units()
	# Waechter in Tunnelknoten oeffnen das Feuer erst, wenn der Feind nah ist
	for u in mine:
		if u.garrison != null and u.ai_role == "guard" and u.hold:
			for e in enemies:
				if U.dist2d(e.position, u.garrison.position) < 17.0:
					u.hold = false
					break
	for u in mine:
		if u.garrison != null or u.weapons.is_empty() or u.is_launcher or u.ai_role == "retreat":
			continue
		if u.order_type == "attack" and u.order_target != null and u.order_target.alive:
			continue
		var best: Unit = null
		var bd := 1e9
		for e in enemies:
			var d: float = U.dist2d(u.position, e.position)
			if d < bd:
				bd = d
				best = e
		if best == null:
			continue
		match u.kind:
			"reb_rpg":
				# Panzerjaeger: nur gegen Fahrzeuge aktiv, wenn nah genug
				var veh: Unit = null
				var vd := 1e9
				for e in enemies:
					if e.layer == "track" or e.layer == "wheel":
						var d2: float = U.dist2d(u.position, e.position)
						if d2 < vd:
							vd = d2
							veh = e
				if veh != null and vd < 30.0 and u.garrison == null:
					u.cmd_attack(veh)
			"reb_tech":
				if bd < 45.0 and _local_odds(best.position) > 0.8:
					u.cmd_attack(best)
				elif bd < 20.0:
					u.cmd_move(Vector3(clampf(u.position.x + 25.0, -City.HALF + 10.0, City.HALF - 10.0), 0, clampf(u.position.z - 25.0, -City.HALF + 10.0, City.HALF - 10.0)))
			"reb_fighter":
				# Streuner greifen an, wenn sie in der Ueberzahl sind
				if u.ai_role == "roam" and bd < 22.0 and _local_odds(best.position) > 1.4:
					u.hold = false
					u.cmd_attack(best)

func _local_odds(p: Vector3) -> float:
	var mine := 0.0
	var theirs := 0.0
	for u in world.units:
		if not u.alive or u.weapons.is_empty():
			continue
		if U.dist2d(u.position, p) < 35.0:
			if u.team == team:
				mine += 1.0 if u.layer == "foot" else 2.0
			elif u.team == U.TEAM_ADF:
				theirs += 1.0 if u.layer == "foot" else 2.5
	return mine / maxf(theirs, 1.0)

func on_launch(_pos: Vector3, _u: Unit) -> void:
	pass
