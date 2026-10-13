class_name Models
extends RefCounted
## Prozedurale Modelle fuer Einheiten, Zivilisten und Basis-Gebaeude.
## Jedes Modell ist ein Node3D (Blick/Front = +Z) mit Meta "parts": {turret, rotor, legL, legR, muzzle, ...}.

const SKIN := [Color(0.85, 0.66, 0.5), Color(0.72, 0.52, 0.38), Color(0.6, 0.42, 0.3), Color(0.5, 0.35, 0.25)]

static func _mi(parent: Node3D, mb: MeshBuilder, rough: float = 0.8, metal: float = 0.05) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(Gfx.vcol_mat(rough, metal))
	parent.add_child(mi)
	return mi

static func _marker(parent: Node3D, pos: Vector3, name: String) -> Node3D:
	var m := Node3D.new()
	m.position = pos
	m.name = name
	parent.add_child(m)
	return m

# =========================================================================== Einheiten
static func build_unit(kind: String, team: int, variant: int = 0) -> Node3D:
	var root := Node3D.new()
	var parts := {}
	match kind:
		"adf_rifle", "adf_recon", "reb_fighter", "reb_rpg", "reb_saboteur", "reb_media":
			_infantry(root, parts, kind, team)
		"adf_apc":
			_apc(root, parts, team)
		"adf_mbt":
			_mbt(root, parts, team)
		"adf_arty":
			_arty(root, parts, team)
		"adf_drone":
			_drone(root, parts, team)
		"adf_viper":
			_viper(root, parts, team)
		"reb_tech":
			_technical(root, parts, team)
		"reb_launcher":
			_launcher(root, parts, team)
		"civ_truck":
			_civ_truck(root, parts, variant)
		_:
			_civilian(root, parts, variant)
	root.set_meta("parts", parts)
	return root

# ------------------------------------------------------------------------ Menschen
static func _person_parts(root: Node3D, parts: Dictionary, uniform: Color, trousers: Color, vest: Color, helmet: Color, skin: Color, accent: Color, opts: Dictionary) -> void:
	var s: float = opts.get("scale", 1.15)
	var holder := Node3D.new()
	holder.scale = Vector3(s, s, s)
	root.add_child(holder)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.25
	mb.ao_floor = 0.9
	var robe: bool = opts.get("robe", false)
	var robe_col: Color = opts.get("robe_col", uniform)
	var torso_h := 0.8
	if robe:
		# langes Gewand
		mb.cyl(Vector3(0, 0.95, 0), 0.5, 0.33, 1.9, robe_col, 8)
		mb.box(Vector3(0, 1.62, 0), Vector3(0.7, 0.62, 0.42), robe_col * 1.04)
	else:
		mb.box(Vector3(0, 1.42, 0), Vector3(0.72, torso_h, 0.42), uniform)
		if vest.a > 0.0:
			mb.box(Vector3(0, 1.48, 0.02), Vector3(0.76, 0.56, 0.47), vest)
			if opts.get("pouches", true):
				for i in range(3):
					mb.box(Vector3(-0.2 + i * 0.2, 1.34, 0.27), Vector3(0.16, 0.2, 0.1), vest * 0.8)
	# Kopf
	mb.sphere(Vector3(0, 2.0, 0), 0.25, skin, Vector3(0.95, 1.1, 1.0), 5, 8)
	var hair: Color = opts.get("hair", Color(0.1, 0.08, 0.06))
	if helmet.a > 0.0:
		mb.sphere(Vector3(0, 2.06, 0), 0.31, helmet, Vector3(1.0, 0.85, 1.08), 5, 8, true)
		mb.box(Vector3(0, 2.02, 0.02), Vector3(0.62, 0.05, 0.66), helmet * 0.85)
	elif opts.get("scarf", false):
		mb.sphere(Vector3(0, 2.06, 0), 0.29, opts.get("scarf_col", Color(0.85, 0.82, 0.75)), Vector3(1.0, 0.9, 1.05), 5, 8, true)
		mb.box(Vector3(0, 1.88, 0.1), Vector3(0.46, 0.18, 0.3), opts.get("scarf_col", Color(0.85, 0.82, 0.75)))
	else:
		mb.sphere(Vector3(0, 2.07, -0.02), 0.27, hair, Vector3(1.0, 0.7, 1.05), 4, 8, true)
	# Rucksack
	if opts.get("backpack", false):
		mb.box(Vector3(0, 1.45, -0.34), Vector3(0.52, 0.62, 0.26), opts.get("pack_col", vest * 0.9))
	# Arme (angewinkelt nach vorn)
	var arm_col := uniform if not robe else robe_col
	mb.box_t(Vector3(-0.44, 1.55, 0.14), Vector3(0.2, 0.7, 0.2), arm_col, Vector3(-55, 0, -6))
	mb.box_t(Vector3(0.44, 1.55, 0.14), Vector3(0.2, 0.7, 0.2), arm_col, Vector3(-55, 0, 6))
	mb.box(Vector3(-0.44, 1.38, 0.38), Vector3(0.14, 0.14, 0.14), skin)
	mb.box(Vector3(0.44, 1.38, 0.38), Vector3(0.14, 0.14, 0.14), skin)
	# Teamfarbe (Armbinde)
	if accent.a > 0.0:
		mb.box_t(Vector3(-0.47, 1.62, 0.1), Vector3(0.23, 0.14, 0.23), accent, Vector3(-55, 0, -6))
	var gun: String = opts.get("gun", "")
	var dark := Color(0.1, 0.1, 0.11)
	match gun:
		"rifle":
			mb.box(Vector3(0.05, 1.42, 0.55), Vector3(0.1, 0.14, 1.1), dark)
			mb.box(Vector3(0.05, 1.33, 0.2), Vector3(0.09, 0.28, 0.12), dark)
		"scope":
			mb.box(Vector3(0.05, 1.42, 0.6), Vector3(0.1, 0.14, 1.25), dark)
			mb.cyl(Vector3(0.05, 1.55, 0.5), 0.06, 0.06, 0.5, Color(0.2, 0.2, 0.22), 6, 2)
			mb.cyl(Vector3(-0.35, 2.4, -0.1), 0.02, 0.02, 0.8, Color(0.3, 0.3, 0.3), 4)
		"ak":
			mb.box(Vector3(0.05, 1.42, 0.52), Vector3(0.09, 0.13, 1.0), Color(0.12, 0.1, 0.08))
			mb.box(Vector3(0.05, 1.45, 0.3), Vector3(0.1, 0.1, 0.45), Color(0.4, 0.26, 0.14))
			mb.box_t(Vector3(0.05, 1.28, 0.55), Vector3(0.07, 0.3, 0.1), dark, Vector3(15, 0, 0))
		"rpg":
			mb.cyl(Vector3(0.28, 1.92, 0.2), 0.1, 0.1, 1.5, Color(0.22, 0.25, 0.2), 8, 2)
			mb.cyl(Vector3(0.28, 1.92, 1.1), 0.22, 0.05, 0.35, Color(0.3, 0.32, 0.25), 8, 2)
			mb.box(Vector3(0.28, 1.78, 0.1), Vector3(0.1, 0.2, 0.12), dark)
		"camera":
			mb.box(Vector3(0.3, 1.95, 0.15), Vector3(0.3, 0.3, 0.55), Color(0.12, 0.12, 0.14))
			mb.cyl(Vector3(0.3, 1.95, 0.55), 0.14, 0.12, 0.3, Color(0.05, 0.05, 0.06), 8, 2)
			mb.cyl(Vector3(0.3, 1.95, 0.72), 0.1, 0.1, 0.05, Color(0.2, 0.4, 0.8), 8, 2)
			# Presse-Weste
			mb.box(Vector3(0, 1.48, 0.0), Vector3(0.78, 0.5, 0.46), Color(0.35, 0.58, 0.85))
			mb.box(Vector3(0, 1.5, 0.24), Vector3(0.5, 0.18, 0.03), Color(0.95, 0.95, 0.95))
		"shovel":
			mb.cyl(Vector3(0.4, 1.4, 0.4), 0.03, 0.03, 1.4, Color(0.4, 0.3, 0.2), 4, 0)
			mb.box(Vector3(0.4, 0.8, 0.4), Vector3(0.2, 0.3, 0.04), Color(0.3, 0.3, 0.3))
	var body := _mi(holder, mb, 0.85, 0.0)
	body.name = "Body"
	# Muzzle-Markierung
	var mz := _marker(holder, Vector3(0.05, 1.42, 1.1), "Muzzle")
	parts["muzzle"] = mz
	parts["holder"] = holder
	# Beine
	if not robe:
		var lm := MeshBuilder.new()
		lm.ao_strength = 0.2
		lm.box(Vector3(0, -0.5, 0), Vector3(0.3, 1.0, 0.32), trousers)
		lm.box(Vector3(0, -0.96, 0.06), Vector3(0.32, 0.16, 0.44), Color(0.14, 0.12, 0.1))
		for sx in [-0.2, 0.2]:
			var piv := Node3D.new()
			piv.position = Vector3(sx, 1.02, 0)
			holder.add_child(piv)
			_mi(piv, lm, 0.9, 0.0)
			parts["legL" if sx < 0 else "legR"] = piv
	else:
		var fm := MeshBuilder.new()
		fm.box(Vector3(-0.18, 0.06, 0.08), Vector3(0.24, 0.12, 0.38), Color(0.14, 0.12, 0.1))
		fm.box(Vector3(0.18, 0.06, 0.08), Vector3(0.24, 0.12, 0.38), Color(0.14, 0.12, 0.1))
		_mi(holder, fm, 0.9, 0.0)

static func _infantry(root: Node3D, parts: Dictionary, kind: String, team: int) -> void:
	var tc := U.team_color(team)
	match kind:
		"adf_rifle":
			_person_parts(root, parts, Color(0.55, 0.5, 0.36), Color(0.5, 0.45, 0.32), Color(0.28, 0.3, 0.26), Color(0.42, 0.4, 0.3), SKIN[0], tc, {"gun": "rifle", "backpack": true, "pack_col": Color(0.33, 0.33, 0.27)})
		"adf_recon":
			_person_parts(root, parts, Color(0.35, 0.36, 0.3), Color(0.32, 0.33, 0.28), Color(0.2, 0.22, 0.2), Color(0.25, 0.27, 0.24), SKIN[1], tc, {"gun": "scope", "backpack": true, "pack_col": Color(0.22, 0.24, 0.2)})
		"reb_fighter":
			_person_parts(root, parts, Color(0.2, 0.22, 0.17), Color(0.22, 0.2, 0.17), Color(0.4, 0.35, 0.25), Color(0, 0, 0, 0), SKIN[2], tc, {"gun": "ak", "scarf": true, "scarf_col": Color(0.12, 0.12, 0.12)})
		"reb_rpg":
			_person_parts(root, parts, Color(0.3, 0.27, 0.2), Color(0.3, 0.28, 0.22), Color(0.3, 0.33, 0.25), Color(0, 0, 0, 0), SKIN[1], tc, {"gun": "rpg", "scarf": true, "scarf_col": Color(0.7, 0.68, 0.6), "backpack": true, "pack_col": Color(0.3, 0.3, 0.2)})
		"reb_saboteur":
			_person_parts(root, parts, Color(0.38, 0.33, 0.25), Color(0.25, 0.23, 0.2), Color(0, 0, 0, 0), Color(0, 0, 0, 0), SKIN[2], tc, {"gun": "shovel", "backpack": true, "pack_col": Color(0.35, 0.28, 0.2), "scarf": true, "scarf_col": Color(0.2, 0.2, 0.2)})
		"reb_media":
			_person_parts(root, parts, Color(0.5, 0.45, 0.38), Color(0.25, 0.28, 0.35), Color(0, 0, 0, 0), Color(0, 0, 0, 0), SKIN[0], Color(0, 0, 0, 0), {"gun": "camera"})

static func _civilian(root: Node3D, parts: Dictionary, variant: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = variant * 7919 + 13
	var skin: Color = SKIN[r.randi() % SKIN.size()]
	var shirt := [Color(0.85, 0.85, 0.8), Color(0.3, 0.45, 0.65), Color(0.7, 0.3, 0.25), Color(0.4, 0.55, 0.35), Color(0.8, 0.7, 0.4), Color(0.55, 0.55, 0.58), Color(0.9, 0.9, 0.9), Color(0.25, 0.25, 0.3)][r.randi() % 8] as Color
	var pants := [Color(0.25, 0.25, 0.3), Color(0.35, 0.3, 0.22), Color(0.2, 0.22, 0.28), Color(0.45, 0.4, 0.3)][r.randi() % 4] as Color
	var kind := r.randi() % 10
	var opts := {"gun": "", "pouches": false}
	if kind <= 2:
		opts["robe"] = true
		opts["robe_col"] = [Color(0.92, 0.9, 0.84), Color(0.8, 0.76, 0.66), Color(0.55, 0.58, 0.62)][r.randi() % 3]
		opts["scarf"] = r.randf() < 0.5
		opts["scarf_col"] = Color(0.9, 0.9, 0.88)
	elif kind <= 5:
		# langes Kleid + Kopftuch
		opts["robe"] = true
		opts["robe_col"] = [Color(0.12, 0.12, 0.16), Color(0.2, 0.3, 0.45), Color(0.5, 0.2, 0.25), Color(0.22, 0.4, 0.3), Color(0.55, 0.4, 0.55)][r.randi() % 5]
		opts["scarf"] = true
		opts["scarf_col"] = [Color(0.9, 0.85, 0.8), Color(0.15, 0.15, 0.2), Color(0.7, 0.3, 0.3), Color(0.3, 0.5, 0.55)][r.randi() % 4]
	if kind == 9:
		opts["scale"] = 0.82   # Kind
	else:
		opts["scale"] = r.randf_range(1.08, 1.2)
	_person_parts(root, parts, shirt, pants, Color(0, 0, 0, 0), Color(0, 0, 0, 0), skin, Color(0, 0, 0, 0), opts)

# ------------------------------------------------------------------------ Fahrzeuge
static func _wheels(mb: MeshBuilder, xs: Array, zs: Array, r: float, y: float, w: float, col: Color) -> void:
	for x in xs:
		for z in zs:
			mb.cyl(Vector3(x, y, z), r, r, w, col, 10, 1)
			mb.cyl(Vector3(x + signf(x) * w * 0.52, y, z), r * 0.55, r * 0.55, 0.05, Color(0.3, 0.3, 0.3), 8, 1)

static func _apc(root: Node3D, parts: Dictionary, team: int) -> void:
	var tan := Color(0.6, 0.54, 0.4)
	var dark := Color(0.12, 0.12, 0.13)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.ao_floor = 0.4
	# Wanne
	mb.extrude([Vector2(-1.4, -3.0), Vector2(1.4, -3.0), Vector2(1.4, 1.6), Vector2(1.1, 3.0), Vector2(-1.1, 3.0), Vector2(-1.4, 1.6)], 0.55, 1.75, tan, tan * 1.1)
	mb.box(Vector3(0, 1.0, 0), Vector3(2.9, 0.5, 5.6), tan * 0.85)
	# Heckklappe/Details
	mb.box(Vector3(0, 1.4, -3.02), Vector3(1.6, 0.9, 0.06), tan * 0.7)
	mb.box(Vector3(-0.9, 1.78, -1.2), Vector3(0.5, 0.12, 0.7), dark)
	mb.box(Vector3(0.9, 1.78, -1.8), Vector3(0.5, 0.12, 0.7), dark)
	mb.box(Vector3(0, 1.0, 2.9), Vector3(1.8, 0.2, 0.2), dark)
	_wheels(mb, [-1.45, 1.45], [-2.1, -0.7, 0.7, 2.1], 0.55, 0.62, 0.45, dark)
	# Teamstreifen
	mb.box(Vector3(0, 1.76, -2.2), Vector3(1.0, 0.04, 0.5), tc)
	var body := _mi(root, mb, 0.75, 0.15)
	# Turm
	var tur := Node3D.new()
	tur.position = Vector3(0, 1.75, -0.4)
	root.add_child(tur)
	var tb := MeshBuilder.new()
	tb.ao_strength = 0.2
	tb.extrude([Vector2(-0.8, -0.9), Vector2(0.8, -0.9), Vector2(0.9, 0.6), Vector2(0.4, 1.0), Vector2(-0.4, 1.0), Vector2(-0.9, 0.6)], 0.0, 0.75, tan * 0.95, tan * 1.05)
	tb.cyl(Vector3(0.0, 0.5, 1.6), 0.09, 0.07, 1.7, dark, 6, 2)
	tb.box(Vector3(0.35, 0.45, 1.0), Vector3(0.25, 0.25, 0.4), dark)
	tb.box(Vector3(-0.5, 0.88, -0.2), Vector3(0.3, 0.3, 0.3), dark)
	tb.cyl(Vector3(-0.2, 1.4, -0.6), 0.02, 0.02, 1.4, dark, 4)
	tb.box(Vector3(0, 0.4, 0.95), Vector3(0.7, 0.3, 0.12), tc)
	_mi(tur, tb, 0.7, 0.2)
	parts["turret"] = tur
	parts["muzzle"] = _marker(tur, Vector3(0, 0.5, 2.5), "Muzzle")

static func _mbt(root: Node3D, parts: Dictionary, team: int) -> void:
	var sand := Color(0.6, 0.53, 0.38)
	var dark := Color(0.13, 0.13, 0.14)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.35
	mb.ao_floor = 0.3
	# Wanne (abgeschraegt)
	mb.extrude([Vector2(-1.35, -3.3), Vector2(1.35, -3.3), Vector2(1.5, 2.2), Vector2(0.9, 3.5), Vector2(-0.9, 3.5), Vector2(-1.5, 2.2)], 0.65, 1.55, sand, sand * 1.08)
	# Ketten + Seitenschuerzen
	for sx in [-1.55, 1.55]:
		mb.box(Vector3(sx, 0.75, 0), Vector3(0.62, 1.0, 6.9), dark)
		mb.box(Vector3(sx, 1.0, 0.1), Vector3(0.7, 0.55, 5.4), sand * 0.9)
		for i in range(7):
			mb.cyl(Vector3(sx + signf(sx) * 0.33, 0.62, -2.8 + i * 0.95), 0.4, 0.4, 0.1, Color(0.2, 0.2, 0.21), 8, 1)
		mb.cyl(Vector3(sx, 0.9, -3.45), 0.55, 0.55, 0.62, dark, 10, 1)
		mb.cyl(Vector3(sx, 0.9, 3.45), 0.5, 0.5, 0.62, dark, 10, 1)
	mb.box(Vector3(0, 1.6, -3.0), Vector3(2.4, 0.2, 0.7), dark)   # Motorraum-Gitter
	mb.box(Vector3(0, 1.0, 3.3), Vector3(1.8, 0.4, 0.3), sand * 0.8)
	var body := _mi(root, mb, 0.75, 0.15)
	# Turm
	var tur := Node3D.new()
	tur.position = Vector3(0, 1.55, -0.2)
	root.add_child(tur)
	var tb := MeshBuilder.new()
	tb.ao_strength = 0.25
	tb.extrude([Vector2(-1.2, -1.3), Vector2(1.2, -1.3), Vector2(1.4, 0.3), Vector2(0.9, 1.5), Vector2(-0.9, 1.5), Vector2(-1.4, 0.3)], 0.0, 1.0, sand * 0.97, sand * 1.1)
	tb.box(Vector3(0, 0.45, 1.6), Vector3(1.1, 0.65, 0.3), sand * 0.85)    # Blende
	tb.cyl(Vector3(0, 0.45, 3.4), 0.17, 0.16, 3.8, Color(0.2, 0.2, 0.21), 8, 2)  # Rohr
	tb.cyl(Vector3(0, 0.45, 5.4), 0.24, 0.24, 0.5, Color(0.17, 0.17, 0.18), 8, 2) # Muendungsbremse
	tb.cyl(Vector3(0.7, 1.1, -0.2), 0.32, 0.32, 0.3, dark, 8)     # Kommandantenluke
	tb.box(Vector3(-0.6, 1.05, -0.5), Vector3(0.5, 0.12, 0.5), dark)
	tb.cyl(Vector3(-0.5, 1.8, -1.1), 0.02, 0.02, 1.8, dark, 4)
	for i in range(4):
		tb.cyl(Vector3(-1.38, 0.6 + i * 0.0, -0.4 + i * 0.28), 0.1, 0.1, 0.22, dark, 5, 1)
	tb.box(Vector3(1.28, 0.55, 0.5), Vector3(0.06, 0.4, 0.8), tc)         # Teamfarbe seitlich
	tb.box(Vector3(-1.28, 0.55, 0.5), Vector3(0.06, 0.4, 0.8), tc)
	_mi(tur, tb, 0.7, 0.2)
	parts["turret"] = tur
	parts["muzzle"] = _marker(tur, Vector3(0, 0.45, 5.7), "Muzzle")

static func _arty(root: Node3D, parts: Dictionary, team: int) -> void:
	var sand := Color(0.58, 0.52, 0.38)
	var dark := Color(0.13, 0.13, 0.14)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.35
	mb.ao_floor = 0.3
	mb.extrude([Vector2(-1.35, -3.1), Vector2(1.35, -3.1), Vector2(1.4, 2.4), Vector2(0.8, 3.2), Vector2(-0.8, 3.2), Vector2(-1.4, 2.4)], 0.65, 1.5, sand, sand * 1.08)
	for sx in [-1.5, 1.5]:
		mb.box(Vector3(sx, 0.75, 0), Vector3(0.6, 1.0, 6.4), dark)
		for i in range(6):
			mb.cyl(Vector3(sx + signf(sx) * 0.32, 0.62, -2.5 + i * 1.0), 0.38, 0.38, 0.1, Color(0.2, 0.2, 0.21), 8, 1)
	# Erdsporn hinten
	mb.box_t(Vector3(0, 0.6, -3.5), Vector3(2.4, 0.15, 0.7), dark, Vector3(-20, 0, 0))
	var body := _mi(root, mb, 0.75, 0.15)
	var tur := Node3D.new()
	tur.position = Vector3(0, 1.5, -0.3)
	root.add_child(tur)
	var tb := MeshBuilder.new()
	tb.ao_strength = 0.25
	tb.extrude([Vector2(-1.4, -1.6), Vector2(1.4, -1.6), Vector2(1.5, 1.0), Vector2(0.9, 1.7), Vector2(-0.9, 1.7), Vector2(-1.5, 1.0)], 0.0, 1.6, sand * 0.98, sand * 1.08)
	tb.box(Vector3(0, 0.8, 1.7), Vector3(1.0, 0.9, 0.3), sand * 0.85)
	var barrel := Node3D.new()
	barrel.position = Vector3(0, 0.85, 1.8)
	barrel.rotation_degrees.x = -28.0
	tur.add_child(barrel)
	var bb := MeshBuilder.new()
	bb.cyl(Vector3(0, 0, 2.6), 0.22, 0.2, 5.2, Color(0.2, 0.2, 0.21), 8, 2)
	bb.cyl(Vector3(0, 0, 5.3), 0.3, 0.3, 0.55, Color(0.15, 0.15, 0.16), 8, 2)
	_mi(barrel, bb, 0.6, 0.3)
	tb.box(Vector3(1.45, 0.8, 0.0), Vector3(0.06, 0.5, 1.0), tc)
	tb.box(Vector3(-1.45, 0.8, 0.0), Vector3(0.06, 0.5, 1.0), tc)
	_mi(tur, tb, 0.7, 0.2)
	parts["turret"] = tur
	parts["barrel"] = barrel
	parts["muzzle"] = _marker(barrel, Vector3(0, 0, 5.7), "Muzzle")

static func _drone(root: Node3D, parts: Dictionary, team: int) -> void:
	var grey := Color(0.78, 0.8, 0.82)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.cyl(Vector3(0, 0, 0.2), 0.32, 0.12, 3.0, grey, 8, 2)
	mb.sphere(Vector3(0, 0, 1.7), 0.32, grey * 0.9, Vector3(0.9, 0.9, 1.1), 4, 8)
	mb.box(Vector3(0, 0, -0.1), Vector3(5.8, 0.06, 0.65), grey)       # Fluegel
	mb.box(Vector3(0, 0.4, -1.3), Vector3(0.05, 0.7, 0.55), grey)     # Seitenleitwerk
	mb.box(Vector3(0, 0.0, -1.35), Vector3(1.8, 0.05, 0.4), grey)
	mb.box(Vector3(0, -0.28, 0.9), Vector3(0.3, 0.2, 0.55), Color(0.1, 0.1, 0.12))   # Sensorkugel
	mb.box(Vector3(-2.6, 0.01, -0.1), Vector3(0.5, 0.08, 0.66), tc)
	mb.box(Vector3(2.6, 0.01, -0.1), Vector3(0.5, 0.08, 0.66), tc)
	var holder := Node3D.new()
	holder.scale = Vector3(1.2, 1.2, 1.2)
	root.add_child(holder)
	_mi(holder, mb, 0.5, 0.3)
	var prop := Node3D.new()
	prop.position = Vector3(0, 0, -1.55)
	holder.add_child(prop)
	var pb := MeshBuilder.new()
	pb.box(Vector3(0, 0, 0), Vector3(0.04, 1.3, 0.05), Color(0.1, 0.1, 0.1))
	pb.box(Vector3(0, 0, 0), Vector3(1.3, 0.04, 0.05), Color(0.1, 0.1, 0.1))
	_mi(prop, pb, 0.6, 0.0)
	parts["rotor"] = prop
	parts["rotor_axis"] = 2
	parts["muzzle"] = _marker(holder, Vector3(0, -0.3, 1.0), "Muzzle")

static func _viper(root: Node3D, parts: Dictionary, team: int) -> void:
	var grey := Color(0.36, 0.4, 0.42)
	var dark := Color(0.12, 0.12, 0.14)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.15
	mb.sphere(Vector3(0, 0, 0.2), 1.05, grey, Vector3(0.95, 0.95, 2.1), 6, 10)
	mb.sphere(Vector3(0, 0.45, 1.4), 0.7, Color(0.1, 0.16, 0.2), Vector3(0.85, 0.75, 1.3), 5, 8)       # Kanzel
	mb.cyl(Vector3(0, 0.2, -3.6), 0.34, 0.14, 4.6, grey, 6, 2)                 # Heckausleger
	mb.box(Vector3(0, 0.9, -5.6), Vector3(0.08, 1.3, 0.9), grey * 1.1)          # Seitenleitwerk
	mb.box(Vector3(0, 0.5, -5.4), Vector3(1.8, 0.08, 0.5), grey)                # Hoehenleitwerk
	mb.box(Vector3(0, 0.95, 0.0), Vector3(0.7, 0.4, 1.4), grey * 0.9)           # Getriebe
	# Stummelfluegel mit Raketenbehaeltern
	mb.box(Vector3(0, 0.0, 0.1), Vector3(4.2, 0.1, 0.8), grey * 0.9)
	for sx in [-1.7, 1.7]:
		mb.cyl(Vector3(sx, -0.1, 0.4), 0.28, 0.28, 1.4, dark, 8, 2)
		mb.cyl(Vector3(sx, -0.1, 1.15), 0.2, 0.0, 0.3, Color(0.3, 0.3, 0.3), 8, 2)
	mb.box(Vector3(0, -0.55, 1.5), Vector3(0.28, 0.3, 0.5), dark)               # Kinnkanone
	mb.cyl(Vector3(0, -0.55, 2.0), 0.05, 0.05, 0.7, dark, 5, 2)
	mb.box(Vector3(1.05, 0.15, 0.2), Vector3(0.05, 0.3, 1.0), tc)
	mb.box(Vector3(-1.05, 0.15, 0.2), Vector3(0.05, 0.3, 1.0), tc)
	var holder := Node3D.new()
	holder.scale = Vector3(1.05, 1.05, 1.05)
	root.add_child(holder)
	_mi(holder, mb, 0.45, 0.35)
	# Rotor (drehend) + Unschaerfe-Scheibe
	var rot := Node3D.new()
	rot.position = Vector3(0, 1.25, 0)
	holder.add_child(rot)
	var rb := MeshBuilder.new()
	for i in range(4):
		rb.box_t(Vector3(0, 0, 0), Vector3(9.0, 0.04, 0.34), Color(0.1, 0.1, 0.1), Vector3(0, i * 45.0, 0))
	_mi(rot, rb, 0.6, 0.0)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.4
	cm.bottom_radius = 4.4
	cm.height = 0.02
	cm.radial_segments = 24
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.3, 0.3, 0.3, 0.12)
	disc.material_override = dm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(disc)
	disc.position = Vector3(0, 1.25, 0)
	var trot := Node3D.new()
	trot.position = Vector3(0.3, 0.9, -5.5)
	holder.add_child(trot)
	var tb := MeshBuilder.new()
	tb.box(Vector3.ZERO, Vector3(0.04, 1.4, 0.06), Color(0.1, 0.1, 0.1))
	tb.box(Vector3.ZERO, Vector3(0.04, 0.06, 1.4), Color(0.1, 0.1, 0.1))
	_mi(trot, tb, 0.6, 0.0)
	parts["rotor"] = rot
	parts["rotor2"] = trot
	parts["rotor_axis"] = 0
	parts["muzzle"] = _marker(holder, Vector3(0, -0.5, 2.4), "Muzzle")
	parts["muzzle2"] = _marker(holder, Vector3(1.7, -0.1, 1.5), "Muzzle2")

static func _technical(root: Node3D, parts: Dictionary, team: int) -> void:
	var body_c := Color(0.82, 0.78, 0.68)
	var dark := Color(0.1, 0.1, 0.1)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.35
	mb.ao_floor = 0.3
	mb.box(Vector3(0, 0.85, 0), Vector3(2.0, 0.55, 5.0), body_c * 0.9)
	mb.box(Vector3(0, 1.4, 1.2), Vector3(1.9, 0.9, 1.5), body_c)         # Fahrerhaus
	mb.box(Vector3(0, 1.62, 1.55), Vector3(1.7, 0.45, 0.7), Color(0.1, 0.14, 0.17))   # Scheiben
	mb.box(Vector3(0, 1.52, 0.5), Vector3(1.7, 0.35, 0.06), Color(0.1, 0.14, 0.17))
	mb.box(Vector3(0, 0.85, -1.2), Vector3(2.0, 0.55, 2.4), body_c)
	for sx in [-1.0, 1.0]:
		mb.box(Vector3(sx, 1.25, -1.2), Vector3(0.1, 0.5, 2.5), body_c * 0.95)
	mb.box(Vector3(0, 1.25, -2.45), Vector3(2.0, 0.5, 0.1), body_c * 0.95)
	mb.box(Vector3(0, 0.62, 2.55), Vector3(1.9, 0.25, 0.2), dark)
	mb.box(Vector3(0.3, 1.06, -1.2), Vector3(0.5, 0.06, 2.3), tc)        # Streifen
	mb.box(Vector3(-0.6, 0.95, -1.5), Vector3(0.6, 0.3, 0.5), Color(0.3, 0.25, 0.18))   # Sack
	_wheels(mb, [-1.1, 1.1], [-1.5, 1.6], 0.5, 0.52, 0.4, dark)
	_mi(root, mb, 0.8, 0.1)
	var tur := Node3D.new()
	tur.position = Vector3(0, 1.45, -1.2)
	root.add_child(tur)
	var tb := MeshBuilder.new()
	tb.cyl(Vector3(0, 0.3, 0), 0.08, 0.08, 0.6, dark, 5)
	tb.box(Vector3(0, 0.62, 0.1), Vector3(0.2, 0.26, 0.5), dark)
	tb.cyl(Vector3(0, 0.62, 1.0), 0.06, 0.06, 1.5, dark, 6, 2)
	tb.box(Vector3(0, 0.62, -0.2), Vector3(0.7, 0.45, 0.06), dark)  # Schutzschild
	_mi(tur, tb, 0.6, 0.3)
	parts["turret"] = tur
	parts["muzzle"] = _marker(tur, Vector3(0, 0.62, 1.8), "Muzzle")

static func _civ_truck(root: Node3D, parts: Dictionary, variant: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = variant + 3
	var col := [Color(0.3, 0.45, 0.6), Color(0.65, 0.2, 0.15), Color(0.8, 0.78, 0.7), Color(0.4, 0.5, 0.35)][r.randi() % 4] as Color
	var dark := Color(0.1, 0.1, 0.1)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.35
	mb.ao_floor = 0.3
	mb.box(Vector3(0, 0.8, 0), Vector3(2.3, 0.4, 6.0), Color(0.25, 0.25, 0.27))
	mb.box(Vector3(0, 1.7, 2.0), Vector3(2.2, 1.5, 1.8), col)
	mb.box(Vector3(0, 1.95, 2.45), Vector3(2.0, 0.6, 0.8), Color(0.1, 0.14, 0.17))
	mb.box(Vector3(0, 1.8, -0.8), Vector3(2.3, 1.8, 3.8), Color(0.8, 0.75, 0.62))   # Plane
	mb.box(Vector3(0, 2.75, -0.8), Vector3(2.0, 0.2, 3.6), Color(0.75, 0.7, 0.58))
	_wheels(mb, [-1.2, 1.2], [-2.0, 0.0, 2.2], 0.6, 0.6, 0.45, dark)
	_mi(root, mb, 0.8, 0.1)
	parts["muzzle"] = _marker(root, Vector3(0, 1.8, 0), "Muzzle")

static func _launcher(root: Node3D, parts: Dictionary, team: int) -> void:
	var col := Color(0.4, 0.42, 0.3)
	var dark := Color(0.1, 0.1, 0.1)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.35
	mb.ao_floor = 0.3
	mb.box(Vector3(0, 0.8, 0), Vector3(2.3, 0.4, 6.4), Color(0.22, 0.22, 0.2))
	mb.box(Vector3(0, 1.65, 2.2), Vector3(2.2, 1.4, 1.8), col)
	mb.box(Vector3(0, 1.9, 2.65), Vector3(2.0, 0.55, 0.8), Color(0.1, 0.14, 0.17))
	mb.box(Vector3(0, 1.1, 2.0), Vector3(2.3, 0.15, 2.2), col * 0.8)
	mb.box(Vector3(0, 1.2, 0.0), Vector3(0.12, 0.12, 0.3), tc)
	_wheels(mb, [-1.2, 1.2], [-2.2, 0.0, 2.4], 0.6, 0.6, 0.45, dark)
	_mi(root, mb, 0.8, 0.1)
	var rack := Node3D.new()
	rack.position = Vector3(0, 1.1, -1.2)
	root.add_child(rack)
	var rb := MeshBuilder.new()
	rb.box(Vector3(0, 0.1, 0), Vector3(2.0, 0.2, 3.2), Color(0.25, 0.25, 0.22))
	for iy in range(2):
		for ix in range(3):
			rb.cyl(Vector3(-0.6 + ix * 0.6, 0.45 + iy * 0.55, 0), 0.22, 0.22, 3.4, Color(0.3, 0.32, 0.27), 8, 2)
			rb.cyl(Vector3(-0.6 + ix * 0.6, 0.45 + iy * 0.55, 1.75), 0.2, 0.2, 0.08, dark, 8, 2)
	_mi(rack, rb, 0.7, 0.2)
	parts["rack"] = rack
	parts["muzzle"] = _marker(rack, Vector3(0, 0.7, 1.9), "Muzzle")

# =========================================================================== Gebaeude (ADF-Basis)
static func build_structure(kind: String, team: int) -> Node3D:
	var root := Node3D.new()
	var parts := {}
	match kind:
		"adf_hq": _hq(root, parts, team)
		"adf_barracks": _barracks(root, parts, team)
		"adf_factory": _factory(root, parts, team)
		"adf_airfield": _airfield(root, parts, team)
		"adf_press": _press(root, parts, team)
		"adf_radar": _radar(root, parts, team)
		"adf_tower": _tower(root, parts, team)
	root.set_meta("parts", parts)
	return root

static func _flag(mb: MeshBuilder, pos: Vector3, tc: Color) -> void:
	mb.cyl(pos + Vector3(0, 4.0, 0), 0.08, 0.06, 8.0, Color(0.75, 0.75, 0.78), 6)
	mb.box(pos + Vector3(0.95, 7.0, 0), Vector3(1.8, 1.1, 0.04), Color(0.92, 0.92, 0.95))
	mb.box(pos + Vector3(0.95, 7.0, 0.01), Vector3(1.8, 0.4, 0.05), tc)
	mb.box(pos + Vector3(0.28, 7.0, 0.01), Vector3(0.5, 1.1, 0.05), tc)

static func _hq(root: Node3D, parts: Dictionary, team: int) -> void:
	var concrete := Color(0.74, 0.7, 0.62)
	var glass := Color(0.12, 0.2, 0.28)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.ao_floor = 0.5
	mb.box(Vector3(0, 2.4, 0), Vector3(15, 4.8, 12), concrete)
	mb.box(Vector3(0, 5.3, -1.0), Vector3(11, 1.0, 9), concrete * 0.95)
	mb.box(Vector3(0, 4.0, 6.05), Vector3(12.5, 1.2, 0.2), glass)        # Fensterband
	mb.box(Vector3(0, 2.2, 6.05), Vector3(12.5, 1.0, 0.2), glass)
	mb.box(Vector3(0, 6.0, -1.0), Vector3(11.4, 0.3, 9.4), concrete * 0.88)
	mb.box(Vector3(-7.55, 2.6, 0), Vector3(0.12, 3.4, 10), glass)
	mb.box(Vector3(7.55, 2.6, 0), Vector3(0.12, 3.4, 10), glass)
	mb.box(Vector3(0, 1.8, 6.4), Vector3(3.0, 3.6, 0.6), concrete * 0.8)  # Eingang
	mb.box(Vector3(0, 0.05, 0), Vector3(16, 0.1, 13), concrete * 0.6)
	mb.box(Vector3(-5.8, 5.0, 4.0), Vector3(0.5, 0.08, 1.6), tc)
	mb.box(Vector3(0, 4.9, 6.12), Vector3(12.8, 0.15, 0.1), tc)
	# Antennenfeld, Schuessel
	mb.cyl(Vector3(4.5, 9.0, -3.0), 0.1, 0.08, 6.0, Color(0.7, 0.7, 0.72), 6)
	mb.cyl(Vector3(3.5, 8.0, -4.5), 0.07, 0.07, 4.0, Color(0.7, 0.7, 0.72), 6)
	mb.set_xf(Vector3(-3.5, 7.2, -3.0), Vector3(-50, 0, 0))
	mb.cyl(Vector3.ZERO, 0.4, 1.7, 0.5, Color(0.88, 0.88, 0.86), 12)
	mb.reset_xf()
	_flag(mb, Vector3(-8.5, 0, 6.0), tc)
	_mi(root, mb, 0.8, 0.1)

static func _barracks(root: Node3D, parts: Dictionary, team: int) -> void:
	var tan := Color(0.7, 0.63, 0.47)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.ao_floor = 0.4
	for i in range(3):
		var z := -2.9 + i * 2.9
		mb.box(Vector3(-0.0, 2.1, z), Vector3(13, 4.2, 2.7), tan * (0.95 + 0.04 * i))
		mb.box(Vector3(0, 4.3, z), Vector3(13.2, 0.2, 2.9), tan * 0.8)
		for k in range(4):
			mb.box(Vector3(-4.5 + k * 3.0, 2.5, z + 1.36), Vector3(1.0, 1.0, 0.06), Color(0.15, 0.2, 0.25))
	mb.box(Vector3(6.55, 1.2, -2.9), Vector3(0.1, 2.2, 1.2), Color(0.25, 0.22, 0.2))
	mb.box(Vector3(0, 3.7, 4.3), Vector3(13.2, 0.3, 0.1), tc)
	mb.box(Vector3(-5.0, 4.8, 0), Vector3(1.6, 1.0, 1.6), Color(0.55, 0.55, 0.52))   # Klimageraet
	# Zelt davor
	mb.box_t(Vector3(0, 1.3, 7.0), Vector3(8, 0.1, 5), Color(0.5, 0.52, 0.4), Vector3(0, 0, 0))
	for sx in [-3.8, 3.8]:
		for sz in [-2.3, 2.3]:
			mb.cyl(Vector3(sx, 0.65, 7.0 + sz), 0.07, 0.07, 1.3, Color(0.3, 0.3, 0.3), 5)
	_mi(root, mb, 0.8, 0.05)

static func _factory(root: Node3D, parts: Dictionary, team: int) -> void:
	var metal := Color(0.62, 0.62, 0.58)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.ao_floor = 0.4
	mb.box(Vector3(0, 2.8, 0), Vector3(16, 5.6, 12), metal)
	# Tonnendach (Bogen) als Extrusion entlang Z
	var arch: Array = []
	for i in range(0, 11):
		var a := PI * float(i) / 10.0
		arch.append(Vector2(cos(a) * 8.0, sin(a) * 2.0))
	mb.set_xf(Vector3(0, 5.6, 0), Vector3(90, 0, 0))
	# Extrusion in XZ -> nach Rotation entlang Y->Z; Polygon (x, z)=(x, -y)
	var poly: Array = []
	for p in arch:
		poly.append(Vector2(p.x, -p.y))
	mb.extrude(poly, -6.0, 6.0, metal * 0.9)
	mb.reset_xf()
	mb.box(Vector3(0, 2.2, 6.05), Vector3(8.0, 4.4, 0.2), Color(0.28, 0.3, 0.3))   # Tor
	for i in range(5):
		mb.box(Vector3(-3.2 + i * 1.6, 2.2, 6.16), Vector3(0.08, 4.3, 0.05), Color(0.2, 0.2, 0.2))
	mb.box(Vector3(0, 4.8, 6.1), Vector3(8.4, 0.25, 0.3), tc)
	mb.box(Vector3(-7.0, 7.0, 3.0), Vector3(1.0, 1.4, 1.0), Color(0.5, 0.5, 0.48))
	mb.cyl(Vector3(6.5, 8.0, -3.0), 0.5, 0.5, 4.0, Color(0.5, 0.5, 0.5), 8)
	_mi(root, mb, 0.7, 0.2)

static func _airfield(root: Node3D, parts: Dictionary, team: int) -> void:
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.2
	mb.ao_floor = 0.1
	mb.box(Vector3(0, 0.05, 0), Vector3(14, 0.1, 14), Color(0.3, 0.3, 0.32), Color(0.3, 0.3, 0.32))
	# Landeplatz-Markierung: Ring und H
	mb.cyl(Vector3(0, 0.12, 0), 5.2, 5.2, 0.04, Color(0.85, 0.8, 0.3), 24)
	mb.cyl(Vector3(0, 0.14, 0), 4.7, 4.7, 0.04, Color(0.3, 0.3, 0.32), 24)
	mb.box(Vector3(-1.4, 0.17, 0), Vector3(0.6, 0.04, 4.2), Color(0.9, 0.85, 0.3))
	mb.box(Vector3(1.4, 0.17, 0), Vector3(0.6, 0.04, 4.2), Color(0.9, 0.85, 0.3))
	mb.box(Vector3(0, 0.17, 0), Vector3(2.2, 0.04, 0.6), Color(0.9, 0.85, 0.3))
	# Kontrollturm
	mb.box(Vector3(-5.8, 2.5, -5.5), Vector3(2.2, 5.0, 2.2), Color(0.75, 0.72, 0.65))
	mb.box(Vector3(-5.8, 5.4, -5.5), Vector3(3.0, 1.0, 3.0), Color(0.15, 0.25, 0.32))
	mb.box(Vector3(-5.8, 6.1, -5.5), Vector3(3.3, 0.25, 3.3), Color(0.7, 0.68, 0.62))
	mb.box(Vector3(-5.8, 5.0, -3.95), Vector3(3.0, 0.15, 0.1), tc)
	# Windsack
	mb.cyl(Vector3(5.8, 2.0, -5.5), 0.06, 0.06, 4.0, Color(0.8, 0.8, 0.8), 5)
	mb.cyl(Vector3(5.8, 3.9, -4.8), 0.3, 0.15, 1.4, Color(0.95, 0.5, 0.15), 6, 2)
	_mi(root, mb, 0.8, 0.05)

static func _press(root: Node3D, parts: Dictionary, team: int) -> void:
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.ao_floor = 0.4
	mb.box(Vector3(0, 2.0, 0), Vector3(10, 4.0, 7), Color(0.88, 0.88, 0.86))
	mb.box(Vector3(0, 4.15, 0), Vector3(10.4, 0.3, 7.4), Color(0.7, 0.7, 0.7))
	mb.box(Vector3(0, 2.2, 3.55), Vector3(8.0, 1.6, 0.1), Color(0.12, 0.2, 0.28))
	mb.box(Vector3(0, 3.6, 3.6), Vector3(10.0, 0.5, 0.15), tc)
	# Mikrofon/Kamera-Podest
	mb.box(Vector3(-2.0, 0.4, 6.5), Vector3(3.5, 0.8, 2.0), Color(0.3, 0.3, 0.33))
	mb.box(Vector3(-2.0, 1.4, 6.9), Vector3(1.4, 1.1, 0.1), Color(0.2, 0.3, 0.55))
	# Sendewagen + Schuessel
	mb.box(Vector3(4.0, 1.2, 6.5), Vector3(2.4, 2.0, 4.6), Color(0.92, 0.92, 0.92))
	mb.set_xf(Vector3(4.0, 3.6, 6.5), Vector3(-55, 0, 0))
	mb.cyl(Vector3.ZERO, 0.2, 1.2, 0.35, Color(0.88, 0.88, 0.86), 12)
	mb.reset_xf()
	mb.cyl(Vector3(-4.0, 6.5, -2.0), 0.08, 0.06, 5.0, Color(0.7, 0.7, 0.72), 6)
	_mi(root, mb, 0.8, 0.05)

static func _radar(root: Node3D, parts: Dictionary, team: int) -> void:
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.ao_floor = 0.4
	mb.box(Vector3(0, 1.2, 0), Vector3(6, 2.4, 6), Color(0.7, 0.67, 0.6))
	mb.cyl(Vector3(0, 3.8, 0), 0.8, 0.6, 3.0, Color(0.6, 0.6, 0.6), 8)
	mb.box(Vector3(0, 2.4, 3.05), Vector3(6.0, 0.15, 0.1), tc)
	_mi(root, mb, 0.8, 0.05)
	var dish := Node3D.new()
	dish.position = Vector3(0, 6.2, 0)
	root.add_child(dish)
	var db := MeshBuilder.new()
	db.box(Vector3(0, 0, 0), Vector3(5.4, 3.2, 0.25), Color(0.75, 0.78, 0.8))
	db.box(Vector3(0, 0, 0.4), Vector3(0.2, 0.2, 0.8), Color(0.3, 0.3, 0.3))
	db.cyl(Vector3(0, -1.5, 0), 0.25, 0.25, 1.0, Color(0.5, 0.5, 0.5), 6)
	_mi(dish, db, 0.5, 0.3)
	parts["rotor"] = dish
	parts["rotor_axis"] = 0

static func _tower(root: Node3D, parts: Dictionary, team: int) -> void:
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.ao_floor = 0.5
	mb.box(Vector3(0, 3.0, 0), Vector3(2.6, 6.0, 2.6), Color(0.66, 0.62, 0.52))
	mb.box(Vector3(0, 6.6, 0), Vector3(3.6, 1.4, 3.6), Color(0.6, 0.57, 0.48))
	mb.box(Vector3(0, 6.7, 1.82), Vector3(3.0, 0.7, 0.06), Color(0.12, 0.2, 0.28))
	mb.box(Vector3(0, 7.5, 0), Vector3(4.0, 0.25, 4.0), Color(0.4, 0.4, 0.38))
	mb.box(Vector3(0, 6.1, 1.85), Vector3(3.6, 0.15, 0.1), tc)
	for sx in [-1.6, 1.6]:
		for sz in [-1.6, 1.6]:
			mb.box(Vector3(sx, 7.9, sz), Vector3(0.6, 0.7, 0.6), Color(0.62, 0.58, 0.48))
	_mi(root, mb, 0.8, 0.05)
	var tur := Node3D.new()
	tur.position = Vector3(0, 8.1, 0)
	root.add_child(tur)
	var tb := MeshBuilder.new()
	tb.box(Vector3(0, 0.2, 0.2), Vector3(0.5, 0.45, 0.8), Color(0.15, 0.15, 0.16))
	tb.cyl(Vector3(0, 0.2, 1.0), 0.06, 0.06, 1.2, Color(0.1, 0.1, 0.1), 6, 2)
	_mi(tur, tb, 0.6, 0.3)
	parts["turret"] = tur
	parts["muzzle"] = _marker(tur, Vector3(0, 0.2, 1.6), "Muzzle")
