class_name Mine
extends Entity
## Versteckte Sprengfalle (IED) der Hadar-Front.

var armed := true
var detected := false
var _t := 0.0
var _vis_node: MeshInstance3D

func setup_mine(w: World, p: Vector3) -> void:
	world = w
	team = U.TEAM_REB
	kind = "ied"
	position = Vector3(p.x, 0.0, p.z)
	radius = 0.6
	max_hp = 25.0
	hp = max_hp
	armor = "inf"
	vision = 0.0
	name = "IED_%d" % id
	var mb := MeshBuilder.new()
	mb.cyl(Vector3(0, 0.08, 0), 0.5, 0.5, 0.16, Color(0.2, 0.17, 0.13), 8)
	mb.box(Vector3(0.1, 0.18, 0.05), Vector3(0.25, 0.1, 0.18), Color(0.4, 0.36, 0.3))
	_vis_node = MeshInstance3D.new()
	_vis_node.mesh = mb.build(Gfx.vcol_mat(1.0, 0.0))
	add_child(_vis_node)
	model = _vis_node

func is_unit() -> bool:
	return false

func apply_visibility(player_team: int) -> void:
	visible = player_team == team or detected

func _process(dt: float) -> void:
	if not alive or world == null or world.paused:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.25
	for o in world.dyn.query(position, 6.0):
		if not (o is Unit) or not o.alive:
			continue
		var u := o as Unit
		if u.team != U.TEAM_ADF or u.layer == "air":
			continue
		var d := U.dist2d(u.position, position)
		# Entdeckung durch Aufklaerer / Infanterie in Naehe
		if not detected and u.detect_range > 0.0 and d < minf(u.detect_range * 0.5, 6.0):
			if randf() < (0.55 if u.kind == "adf_recon" else 0.2):
				detected = true
				ident_mask |= 1
				Game.message("Sprengfalle entdeckt!", "good", U.TEAM_ADF)
		if armed and d < 2.8 and u.layer != "foot":
			detonate()
			return
		elif armed and d < 1.4 and u.layer == "foot" and u.kind != "adf_recon":
			if randf() < 0.5:
				detonate()
				return

func detonate() -> void:
	if not alive:
		return
	alive = false
	world.unregister(self)
	world.explode(position, 5.5, 360.0, "ied", U.TEAM_REB, null, {"big": true, "ied": true})
	queue_free()

func take_damage(amount: float, attacker: Entity, dtype: String, from_pos: Vector3 = Vector3.ZERO) -> void:
	# Beschuss zuendet die Falle aus der Entfernung
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		detonate()
