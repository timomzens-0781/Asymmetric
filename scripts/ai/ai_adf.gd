class_name AiAdf
extends Node
## KI der Supermacht: produziert, rueckt gestaffelt vor, vergilt Raketenabschuesse –
## aber zuegelt ihre Feuerkraft, wenn die Empoerung steigt (Dilemma).

var world: World
var team := 0
var _t := 1.0
var _fast_t := 0.0
var _sector_i := 0
var _army_target := Vector3.ZERO
var _army_wait := 0.0
var _sweep_t := 0.0
var _strikes: Array = []     # {t, pos, kind}
var _scan_cd := 20.0
var _last_scan_pos := Vector3.ZERO
var _warned: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _sectors: Array = []
var _op_started := false
var _hub_attack_t := 0.0

func _ready() -> void:
	_rng.randomize()
	_sectors = [
		Vector3(14, 0, 22), Vector3(2, 0, -18), Vector3(34, 0, -30), Vector3(52, 0, -52),
		Vector3(70, 0, -20), Vector3(14, 0, -56), Vector3(60, 0, 24), Vector3(-20, 0, -50),
		Vector3(80, 0, -80), Vector3(34, 0, -78), Vector3(-30, 0, -20),
	]
	_army_target = _sectors[0]

func _aggr() -> float:
	return [0.7, 1.0, 1.35][Game.difficulty]

func _process(dt: float) -> void:
	if world == null or world.paused or not Game.running:
		return
	_t -= dt
	_fast_t -= dt
	_sweep_t += dt
	if _fast_t <= 0.0:
		_fast_t = 0.4
		_run_strikes()
	if _t <= 0.0:
		_t = 1.0
		_think()

func _think() -> void:
	# Einsatzregeln: je hoeher die Empoerung, desto vorsichtiger
	world.roe_free[0] = Game.outrage < 42.0
	_produce()
	_manage_army()
	_use_support()

# ----------------------------------------------------------------------------- Produktion
func _my_units() -> Array:
	var a: Array = []
	for u in world.units:
		if u.alive and u.team == team:
			a.append(u)
	return a

func _count_kind(k: String) -> int:
	var n := 0
	for u in world.units:
		if u.alive and u.team == team and u.kind == k:
			n += 1
	for s in world.structures:
		if s.alive and s.team == team:
			for q in s.queue:
				if q.kind == k:
					n += 1
	return n

func _producer_for(k: String) -> Structure:
	var best: Structure = null
	for s in world.structures:
		if s.alive and s.team == team and s.can_produce(k):
			if best == null or s.queue.size() < best.queue.size():
				best = s
	return best

func _produce() -> void:
	var reserve := 500.0 if Game.outrage < 60.0 else 200.0
	var wish: Array = []
	var total_inf := _count_kind("adf_rifle")
	wish.append(["adf_rifle", 12, 3.0])
	wish.append(["adf_recon", 4, 2.0])
	wish.append(["adf_apc", 4, 2.2])
	wish.append(["adf_mbt", 4, 2.5])
	wish.append(["adf_arty", 2, 1.5])
	wish.append(["adf_drone", 2, 2.8])
	if not Game.no_fly_zone():
		wish.append(["adf_viper", 2, 1.5])
	# am staerksten unterbesetzte Einheit waehlen
	var best_k := ""
	var best_score := -1.0
	for w in wish:
		var have := _count_kind(w[0])
		var need: float = (float(w[1]) - have) / float(w[1])
		if need <= 0.0:
			continue
		var sc: float = need * float(w[2])
		if sc > best_score:
			best_score = sc
			best_k = w[0]
	if best_k == "":
		return
	var d: Dictionary = Data.UNITS[best_k]
	if Game.budget[team] < d.cost + reserve * 0.5:
		return
	var s := _producer_for(best_k)
	if s != null and s.queue.size() < 2:
		s.queue_unit(best_k)

# ----------------------------------------------------------------------------- Armee
func _army() -> Array:
	var a: Array = []
	for u in world.units:
		if u.alive and u.team == team and not u.weapons.is_empty() and not u.has_meta("leaving") and u.kind != "adf_arty":
			a.append(u)
	return a

func _centroid(a: Array) -> Vector3:
	if a.is_empty():
		return Vector3(-62, 0, 70)
	var c := Vector3.ZERO
	for u in a:
		c += u.position
	return c / a.size()

func _manage_army() -> void:
	var army := _army()
	var arty: Array = []
	var drones: Array = []
	for u in world.units:
		if not u.alive or u.team != team:
			continue
		if u.kind == "adf_arty":
			arty.append(u)
		elif u.kind == "adf_drone" and not u.has_meta("leaving"):
			drones.append(u)
	if army.size() < 5:
		return
	# Verdeckte Gefahr: Anzahl sichtbarer Feinde
	var cen := _centroid(army)
	var close_enemy := false
	for u in world.units:
		if u.alive and u.team == U.TEAM_REB and (u.ident_mask & 1) != 0 and U.dist2d(u.position, cen) < 40.0:
			close_enemy = true
			break
	var all_idle := true
	var near_target := 0
	for u in army:
		if u.order_type != "idle":
			all_idle = false
		if U.dist2d(u.position, _army_target) < 18.0:
			near_target += 1
	_army_wait -= 1.0
	var need_new := (near_target >= army.size() * 0.5 and not close_enemy) or _army_wait <= -40.0
	# Hubs bekannt? Dann gezielt dorthin
	var hub := _revealed_hub()
	if hub != null:
		if _hub_attack_t <= 0.0 or not (U.dist2d(_army_target, hub.position) < 20.0):
			_army_target = hub.door_pos(cen)
			_hub_attack_t = 30.0
			need_new = false
			_dispatch(army, _army_target, true)
			_attack_hub(army, arty, hub)
		_hub_attack_t -= 1.0
	elif need_new or (all_idle and not _op_started):
		_op_started = true
		_sector_i = (_sector_i + 1) % _sectors.size()
		_army_target = _sectors[_sector_i] + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
		_army_wait = 0.0
		_dispatch(army, _army_target, false)
	# Aufklaerung vorausschicken
	for d in drones:
		if d.order_type == "idle" or U.dist2d(d.position, _army_target) > 60.0:
			var lead := cen + (_army_target - cen).normalized() * minf(30.0, U.dist2d(cen, _army_target))
			d.cmd_move(lead)
	# Artillerie in Stellung bringen
	for a in arty:
		if a.order_type == "idle" and U.dist2d(a.position, cen) > 45.0:
			a.cmd_move(cen + (Vector3(-62, 0, 70) - cen).normalized() * 25.0)

func _dispatch(army: Array, target: Vector3, hub_mode: bool) -> void:
	# Vorsicht: Panzer zuerst langsam, Infanterie folgt
	var inf: Array = []
	var veh: Array = []
	for u in army:
		if u.layer == "foot":
			inf.append(u)
		elif u.layer != "air":
			veh.append(u)
		else:
			u.cmd_attack_move(target)
	var i := 0
	for u in veh + inf:
		var off := Vector3((i % 5) * 3.0 - 6.0, 0, (i / 5) * 3.0)
		u.cmd_attack_move(world.nav.nearest_free_pos(target + off, u.grid, 12))
		i += 1

func _revealed_hub() -> Structure:
	var best: Structure = null
	var bd := 1e9
	for h in world.hubs:
		if h.alive and h.revealed:
			var d: float = U.dist2d(h.position, Vector3(-60, 0, 70))
			if d < bd:
				bd = d
				best = h
	return best

func _attack_hub(army: Array, arty: Array, hub: Structure) -> void:
	for u in army:
		if (u.layer == "track" or u.layer == "wheel" or u.layer == "air") and not u.weapons.is_empty():
			u.cmd_attack(hub)
	for a in arty:
		if U.dist2d(a.position, hub.position) < 98.0 and Game.outrage < 62.0:
			a.cmd_attack_ground(hub.position)
	# Zivilschutz: Vorwarnung, dann Schlag
	if hub.occupants > 3 and Game.outrage > 18.0 and not _warned.has(hub.id):
		_warned[hub.id] = Game.time
		if Game.ability_ready(team, "warning"):
			Game.use_ability(team, "warning", hub.position)
	# Luft-/Praezisionsschlag nach Warnzeit
	if _warned.has(hub.id) and Game.time - _warned[hub.id] > 9.0 or hub.occupants <= 3:
		if Game.outrage < 60.0 and Game.ability_ready(team, "precision") and Game.budget[team] > 1800.0:
			Game.use_ability(team, "precision", hub.position)
		elif Game.outrage < 40.0 and Game.ability_ready(team, "airstrike") and Game.budget[team] > 1500.0:
			Game.use_ability(team, "airstrike", hub.position)

# ----------------------------------------------------------------------------- Unterstuetzung
func on_launch(pos: Vector3, u: Unit) -> void:
	# Raketenabschuss geortet -> Vergeltung nach kurzer Verzoegerung
	var delay := _rng.randf_range(4.0, 8.0) / _aggr()
	_strikes.append({"t": Game.time + delay, "pos": pos, "kind": "retaliate", "unit": u})

func _near_sensitive(pos: Vector3, r: float) -> bool:
	for s in world.structures:
		if s.alive and s.kind_class in ["hospital", "school"] and s.edge_dist(pos) < r:
			return true
	return false

func _civs_near(pos: Vector3, r: float) -> int:
	var n := 0
	for o in world.dyn.query(pos, r):
		if o is Civilian and o.alive and U.dist2d(o.position, pos) < r:
			n += 1
	for s in world.structures:
		if s.alive and s.team == U.TEAM_CIV and s.edge_dist(pos) < r * 0.6:
			n += s.occupants / 3
	return n

func _run_strikes() -> void:
	var keep: Array = []
	for st in _strikes:
		if Game.time < st.t:
			keep.append(st)
			continue
		_execute_strike(st)
	_strikes = keep

func _execute_strike(st: Dictionary) -> void:
	var pos: Vector3 = st.pos
	var u: Unit = st.unit if st.has("unit") else null
	# Ziel nachfuehren, wenn der Werfer noch lebt
	if u != null and is_instance_valid(u) and u.alive:
		pos = u.position
	var outrage := Game.outrage
	var civs := _civs_near(pos, 12.0)
	var sens := _near_sensitive(pos, 18.0)
	# Rueckhalt bei hoher Empoerung / vielen Zivilisten
	if outrage > 78.0 or sens and outrage > 30.0:
		Game.message("Vergeltungsschlag abgebrochen: zu viele Zivilisten in der Nähe", "info", -1)
		return
	if st.kind == "retaliate":
		# Entscheidung abhaengig von Risiko
		if civs <= 4 and Game.ability_ready(team, "salvo") and outrage < 55.0:
			Game.use_ability(team, "salvo", pos)
		elif Game.ability_ready(team, "precision") and Game.budget[team] > 1300.0 and (civs > 4 or outrage >= 40.0):
			Game.use_ability(team, "precision", pos)
		elif civs <= 8 and outrage < 30.0 and Game.ability_ready(team, "airstrike"):
			Game.use_ability(team, "airstrike", pos)
		else:
			# Haubitzen feuern
			for a in world.units:
				if a.alive and a.team == team and a.kind == "adf_arty" and U.dist2d(a.position, pos) < 98.0 and U.dist2d(a.position, pos) > 27.0 and outrage < 62.0:
					a.cmd_attack_ground(pos)

func _use_support() -> void:
	# Beweise veroeffentlichen
	if Game.evidence >= 3.0 and Game.ability_ready(team, "evidence") and Game.outrage > 8.0:
		Game.use_ability(team, "evidence")
	# Aufklaerungsflug
	_scan_cd -= 1.0
	if _scan_cd <= 0.0 and Game.ability_ready(team, "scan") and Game.budget[team] > 900.0 and _revealed_hub() == null:
		var army := _army()
		var cen := _centroid(army)
		var p := cen + (_army_target - cen).normalized() * minf(25.0, U.dist2d(cen, _army_target))
		if U.dist2d(p, _last_scan_pos) > 22.0:
			Game.use_ability(team, "scan", p)
			_last_scan_pos = p
			_scan_cd = 18.0
		else:
			_scan_cd = 6.0
