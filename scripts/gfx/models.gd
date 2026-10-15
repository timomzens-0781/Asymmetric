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
static func _gun(mb: MeshBuilder, gun: String, tc: Color) -> void:
	var dark := Color(0.1, 0.1, 0.11)
	var steel := Color(0.22, 0.23, 0.25)
	match gun:
		"rifle", "scope":
			var gx := 0.12
			mb.box(Vector3(gx, 1.56, 0.12), Vector3(0.08, 0.16, 0.34), dark)            # Schaft
			mb.box(Vector3(gx, 1.61, 0.52), Vector3(0.09, 0.15, 0.46), steel)           # Gehaeuse
			mb.box(Vector3(gx, 1.60, 0.9), Vector3(0.1, 0.1, 0.34), dark)               # Handschutz
			mb.cyl(Vector3(gx, 1.62, 1.25), 0.022, 0.02, 0.5, steel, 6, 2)              # Lauf
			mb.cyl(Vector3(gx, 1.62, 1.5), 0.035, 0.035, 0.09, dark, 6, 2)              # Muendungsfeuerdaempfer
			mb.box_t(Vector3(gx, 1.44, 0.52), Vector3(0.06, 0.24, 0.1), dark, Vector3(8, 0, 0))   # Magazin
			mb.box_t(Vector3(gx, 1.48, 0.28), Vector3(0.05, 0.14, 0.07), dark, Vector3(-18, 0, 0))  # Griff
			mb.box(Vector3(gx, 1.72, 0.52), Vector3(0.07, 0.07, 0.2), steel)            # Optik
			if gun == "scope":
				mb.cyl(Vector3(gx, 1.74, 0.55), 0.045, 0.05, 0.42, Color(0.08, 0.08, 0.1), 8, 2)
				mb.cyl(Vector3(gx, 1.74, 0.78), 0.06, 0.06, 0.05, Color(0.2, 0.4, 0.8), 8, 2)
				mb.box_t(Vector3(gx, 1.5, 1.0), Vector3(0.03, 0.2, 0.03), dark, Vector3(0, 0, 0))   # Zweibein
		"ak":
			var gx2 := 0.12
			mb.box(Vector3(gx2, 1.57, 0.14), Vector3(0.08, 0.15, 0.36), Color(0.42, 0.26, 0.13))    # Holzschaft
			mb.box(Vector3(gx2, 1.6, 0.52), Vector3(0.09, 0.13, 0.44), Color(0.14, 0.13, 0.12))     # Gehaeuse
			mb.box(Vector3(gx2, 1.585, 0.88), Vector3(0.1, 0.09, 0.3), Color(0.4, 0.24, 0.12))      # Handschutz
			mb.cyl(Vector3(gx2, 1.61, 1.15), 0.02, 0.02, 0.42, steel, 6, 2)
			mb.box(Vector3(gx2, 1.66, 1.0), Vector3(0.03, 0.06, 0.03), dark)                        # Korn
			mb.box_t(Vector3(gx2, 1.43, 0.58), Vector3(0.06, 0.28, 0.1), Color(0.15, 0.13, 0.1), Vector3(24, 0, 0))   # Bananenmagazin
		"rpg":
			mb.cyl(Vector3(0.3, 1.95, 0.3), 0.075, 0.075, 1.6, Color(0.22, 0.25, 0.2), 10, 2)
			mb.cyl(Vector3(0.3, 1.95, 1.2), 0.07, 0.065, 0.3, Color(0.18, 0.2, 0.17), 8, 2)
			mb.cyl(Vector3(0.3, 1.95, 1.32), 0.2, 0.06, 0.34, Color(0.32, 0.34, 0.26), 10, 2)       # Sprengkopf
			mb.cyl(Vector3(0.3, 1.95, 1.52), 0.06, 0.02, 0.18, Color(0.5, 0.45, 0.3), 8, 2)
			mb.box(Vector3(0.3, 2.04, 0.5), Vector3(0.08, 0.08, 0.16), steel)                         # Visier
			mb.box(Vector3(0.3, 1.82, 0.34), Vector3(0.08, 0.2, 0.1), dark)                           # Griff
			mb.cyl(Vector3(0.3, 1.95, -0.45), 0.1, 0.075, 0.14, dark, 8, 2)                           # Rueckstoss
		"camera":
			mb.box(Vector3(0.3, 2.04, 0.2), Vector3(0.3, 0.3, 0.5), Color(0.1, 0.1, 0.12))
			mb.box(Vector3(0.3, 2.22, 0.15), Vector3(0.08, 0.08, 0.3), dark)
			mb.cyl(Vector3(0.3, 2.04, 0.6), 0.14, 0.12, 0.32, Color(0.04, 0.04, 0.05), 10, 2)
			mb.cyl(Vector3(0.3, 2.04, 0.78), 0.17, 0.17, 0.1, Color(0.06, 0.06, 0.07), 10, 2)        # Streulichtblende
			mb.cyl(Vector3(0.3, 2.04, 0.84), 0.1, 0.1, 0.03, Color(0.2, 0.4, 0.8), 10, 2)
			mb.box(Vector3(0.3, 1.9, -0.1), Vector3(0.12, 0.16, 0.3), Color(0.15, 0.15, 0.17))      # Akku
			mb.cyl(Vector3(0.3, 2.34, 0.2), 0.012, 0.012, 0.45, dark, 4, 0)                          # Mikrofonangel
			mb.box(Vector3(0.3, 2.5, 0.2), Vector3(0.06, 0.1, 0.06), Color(0.7, 0.7, 0.7))
		"shovel":
			mb.cyl(Vector3(0.45, 1.45, 0.3), 0.03, 0.03, 1.5, Color(0.4, 0.3, 0.2), 6, 0)
			mb.box(Vector3(0.45, 0.72, 0.3), Vector3(0.22, 0.32, 0.04), steel)
			mb.cyl(Vector3(0.34, 1.0, 0.2), 0.12, 0.12, 0.1, Color(0.18, 0.16, 0.13), 8, 1)          # Kabelrolle
			mb.box(Vector3(0.52, 1.1, 0.3), Vector3(0.14, 0.1, 0.1), Color(0.6, 0.12, 0.1))          # Zuender

static func _person_parts(root: Node3D, parts: Dictionary, uniform: Color, trousers: Color, vest: Color, helmet: Color, skin: Color, accent: Color, opts: Dictionary) -> void:
	var s: float = opts.get("scale", 1.15)
	var holder := Node3D.new()
	holder.scale = Vector3(s, s, s)
	root.add_child(holder)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.22
	mb.ao_floor = 0.9
	mb.jitter = 0.025
	var robe: bool = opts.get("robe", false)
	var robe_col: Color = opts.get("robe_col", uniform)
	var gun: String = opts.get("gun", "")
	var dark := Color(0.1, 0.1, 0.11)
	var leather := Color(0.2, 0.15, 0.1)
	# ---------------- Rumpf
	if robe:
		mb.cyl(Vector3(0, 0.98, 0), 0.52, 0.34, 1.9, robe_col, 12)
		mb.box(Vector3(0, 1.68, 0), Vector3(0.74, 0.62, 0.44), robe_col * 1.04)
		mb.box(Vector3(0, 1.4, 0.23), Vector3(0.5, 0.04, 0.05), robe_col * 0.7)       # Naht
		mb.box(Vector3(0, 1.2, 0), Vector3(0.62, 0.06, 0.42), robe_col * 0.8)          # Guertel
	else:
		mb.box(Vector3(0, 1.08, 0), Vector3(0.62, 0.3, 0.4), trousers)                 # Becken
		mb.box(Vector3(0, 1.4, 0), Vector3(0.7, 0.4, 0.42), uniform)                   # Bauch
		mb.box(Vector3(0, 1.74, 0), Vector3(0.8, 0.44, 0.46), uniform * 1.04)          # Brust
		mb.box(Vector3(-0.44, 1.86, 0), Vector3(0.18, 0.2, 0.3), uniform)              # Schultern
		mb.box(Vector3(0.44, 1.86, 0), Vector3(0.18, 0.2, 0.3), uniform)
		mb.box(Vector3(0, 1.22, 0), Vector3(0.66, 0.07, 0.44), leather)                # Koppel
		mb.box(Vector3(0, 1.22, 0.23), Vector3(0.1, 0.08, 0.03), Color(0.6, 0.55, 0.3))
		if vest.a > 0.0:
			mb.box(Vector3(0, 1.66, 0.02), Vector3(0.84, 0.62, 0.52), vest)            # Weste
			mb.box(Vector3(0, 1.72, 0.29), Vector3(0.5, 0.4, 0.05), vest * 0.65)       # Frontplatte
			mb.box(Vector3(0, 1.72, -0.28), Vector3(0.5, 0.4, 0.05), vest * 0.65)      # Rueckenplatte
			mb.box(Vector3(-0.3, 1.94, 0), Vector3(0.12, 0.05, 0.5), vest * 0.8)       # Traeger
			mb.box(Vector3(0.3, 1.94, 0), Vector3(0.12, 0.05, 0.5), vest * 0.8)
			if opts.get("pouches", true):
				for i in range(4):
					mb.box(Vector3(-0.27 + i * 0.18, 1.45, 0.32), Vector3(0.14, 0.18, 0.1), vest * 0.75)
				mb.box(Vector3(-0.44, 1.5, 0.1), Vector3(0.1, 0.22, 0.14), vest * 0.7)   # Seitentasche
				mb.cyl(Vector3(0.44, 1.5, 0.1), 0.045, 0.045, 0.2, Color(0.25, 0.3, 0.2), 8)  # Granate
	# ---------------- Kopf
	mb.cyl(Vector3(0, 2.02, 0), 0.1, 0.11, 0.14, skin * 0.9, 8)                      # Hals
	mb.sphere(Vector3(0, 2.16, 0.01), 0.24, skin, Vector3(0.92, 1.08, 1.0), 7, 12)
	mb.box(Vector3(-0.23, 2.15, 0), Vector3(0.04, 0.1, 0.06), skin * 0.9)            # Ohren
	mb.box(Vector3(0.23, 2.15, 0), Vector3(0.04, 0.1, 0.06), skin * 0.9)
	mb.box(Vector3(0, 2.13, 0.24), Vector3(0.06, 0.09, 0.07), skin * 1.05)           # Nase
	mb.box(Vector3(-0.08, 2.2, 0.225), Vector3(0.06, 0.03, 0.03), Color(0.05, 0.04, 0.04))   # Augen
	mb.box(Vector3(0.08, 2.2, 0.225), Vector3(0.06, 0.03, 0.03), Color(0.05, 0.04, 0.04))
	mb.box(Vector3(0, 2.05, 0.22), Vector3(0.12, 0.025, 0.03), skin * 0.7)            # Mund
	var hair: Color = opts.get("hair", Color(0.1, 0.08, 0.06))
	if helmet.a > 0.0:
		mb.sphere(Vector3(0, 2.24, 0), 0.31, helmet, Vector3(1.0, 0.84, 1.1), 8, 14, true)
		mb.box(Vector3(0, 2.2, 0.02), Vector3(0.62, 0.045, 0.66), helmet * 0.82)
		mb.box(Vector3(0, 2.36, 0.29), Vector3(0.14, 0.1, 0.08), dark)               # NVG-Halter
		mb.box(Vector3(-0.3, 2.12, 0.02), Vector3(0.05, 0.1, 0.1), dark)              # Headset
		mb.box(Vector3(0.3, 2.12, 0.02), Vector3(0.05, 0.1, 0.1), dark)
		mb.box_t(Vector3(-0.22, 2.0, 0.2), Vector3(0.025, 0.2, 0.025), leather, Vector3(0, 0, 18))   # Kinnriemen
		mb.box_t(Vector3(0.22, 2.0, 0.2), Vector3(0.025, 0.2, 0.025), leather, Vector3(0, 0, -18))
		if opts.get("goggles", true) and team_is_adf(accent):
			mb.box(Vector3(0, 2.22, 0.27), Vector3(0.34, 0.07, 0.05), Color(0.05, 0.07, 0.09))
	elif opts.get("scarf", false):
		var sc: Color = opts.get("scarf_col", Color(0.85, 0.82, 0.75))
		mb.sphere(Vector3(0, 2.2, -0.01), 0.29, sc, Vector3(1.0, 0.9, 1.08), 7, 12, true)
		mb.box(Vector3(0, 2.1, 0.01), Vector3(0.6, 0.07, 0.56), sc * 0.9)              # Wickel
		mb.box_t(Vector3(0, 2.0, -0.3), Vector3(0.18, 0.4, 0.07), sc * 0.95, Vector3(14, 0, 0))   # Zipfel
		mb.box(Vector3(0, 2.04, 0.2), Vector3(0.38, 0.17, 0.1), sc * 0.85)             # Gesichtstuch
	else:
		mb.sphere(Vector3(0, 2.23, -0.02), 0.27, hair, Vector3(1.0, 0.72, 1.06), 6, 12, true)
		if opts.get("beard", false):
			mb.box(Vector3(0, 2.04, 0.18), Vector3(0.3, 0.14, 0.1), hair)
	if opts.get("backpack", false):
		var pk: Color = opts.get("pack_col", vest * 0.9)
		mb.box(Vector3(0, 1.62, -0.38), Vector3(0.56, 0.66, 0.28), pk)
		mb.box(Vector3(0, 1.98, -0.38), Vector3(0.5, 0.1, 0.26), pk * 0.85)
		mb.cyl(Vector3(0, 1.28, -0.42), 0.12, 0.12, 0.56, pk * 0.7, 8, 1)               # Isomatte
		mb.box(Vector3(0.3, 1.6, -0.38), Vector3(0.1, 0.34, 0.2), pk * 0.8)
	if opts.get("radio", false):
		mb.box(Vector3(-0.2, 1.7, -0.3), Vector3(0.14, 0.2, 0.1), dark)
		mb.cyl(Vector3(-0.2, 2.15, -0.34), 0.012, 0.008, 0.9, dark, 4, 0)
	if opts.get("bag", false):
		mb.box(Vector3(-0.42, 1.3, 0.05), Vector3(0.12, 0.34, 0.4), opts.get("bag_col", Color(0.5, 0.35, 0.2)))
		mb.beam(Vector3(-0.24, 1.96, 0), Vector3(-0.42, 1.48, 0.0), 0.04, leather)
	# ---------------- Arme
	var arm_col := uniform if not robe else robe_col
	var glove := skin * 0.9 if gun == "" else dark
	var rshoulder := Vector3(0.46, 1.84, 0)
	var lshoulder := Vector3(-0.46, 1.84, 0)
	var relb: Vector3
	var lelb: Vector3
	var rhand: Vector3
	var lhand: Vector3
	match gun:
		"rifle", "scope", "ak":
			relb = Vector3(0.38, 1.52, 0.2)
			lelb = Vector3(-0.34, 1.6, 0.4)
			rhand = Vector3(0.14, 1.52, 0.3)
			lhand = Vector3(0.1, 1.58, 0.85)
		"rpg":
			relb = Vector3(0.45, 1.6, 0.22)
			lelb = Vector3(-0.1, 1.7, 0.42)
			rhand = Vector3(0.3, 1.8, 0.3)
			lhand = Vector3(0.3, 1.95, 0.7)
		"camera":
			relb = Vector3(0.5, 1.66, 0.1)
			lelb = Vector3(0.1, 1.7, 0.35)
			rhand = Vector3(0.3, 1.9, 0.0)
			lhand = Vector3(0.3, 1.98, 0.5)
		_:
			relb = Vector3(0.52, 1.5, 0.04)
			lelb = Vector3(-0.52, 1.5, 0.04)
			rhand = Vector3(0.5, 1.15, 0.12)
			lhand = Vector3(-0.5, 1.15, 0.12)
	mb.beam(rshoulder, relb, 0.2, arm_col)
	mb.beam(relb, rhand, 0.17, arm_col * 0.95)
	mb.box(rhand, Vector3(0.12, 0.12, 0.12), glove)
	mb.beam(lshoulder, lelb, 0.2, arm_col)
	mb.beam(lelb, lhand, 0.17, arm_col * 0.95)
	mb.box(lhand, Vector3(0.12, 0.12, 0.12), glove)
	if accent.a > 0.0:
		mb.beam(lshoulder + Vector3(0, -0.1, 0), lshoulder + (lelb - lshoulder) * 0.4 + Vector3(0, -0.1, 0), 0.23, accent)   # Armbinde
	_gun(mb, gun, accent)
	if gun == "camera":
		mb.box(Vector3(0, 1.74, 0.0), Vector3(0.88, 0.58, 0.5), Color(0.34, 0.56, 0.85))      # Presseweste
		mb.box(Vector3(0, 1.76, 0.27), Vector3(0.56, 0.17, 0.03), Color(0.95, 0.95, 0.95))
		mb.box(Vector3(0, 2.3, 0.03), Vector3(0.64, 0.09, 0.6), Color(0.34, 0.56, 0.85))       # Helm-Ansatz
	var body := _mi(holder, mb, 0.85, 0.0)
	body.name = "Body"
	var mz_z := 1.55
	var mz_y := 1.62
	var mz_x := 0.12
	if gun == "rpg":
		mz_z = 1.65
		mz_y = 1.95
		mz_x = 0.3
	parts["muzzle"] = _marker(holder, Vector3(mz_x, mz_y, mz_z), "Muzzle")
	parts["holder"] = holder
	# ---------------- Beine (Pivot an der Huefte)
	if not robe:
		var lm := MeshBuilder.new()
		lm.ao_strength = 0.2
		lm.jitter = 0.02
		lm.box(Vector3(0, -0.22, 0), Vector3(0.28, 0.5, 0.32), trousers)             # Oberschenkel
		lm.box(Vector3(0, -0.52, 0.17), Vector3(0.24, 0.16, 0.05), trousers * 0.7)   # Kniepolster
		lm.box(Vector3(0, -0.68, -0.02), Vector3(0.24, 0.5, 0.28), trousers * 0.95)  # Unterschenkel
		lm.box(Vector3(0, -0.98, 0.0), Vector3(0.26, 0.2, 0.3), Color(0.14, 0.12, 0.1))      # Stiefelschaft
		lm.box(Vector3(0, -1.06, 0.08), Vector3(0.28, 0.12, 0.46), Color(0.14, 0.12, 0.1))   # Stiefel
		lm.box(Vector3(0, -1.11, 0.08), Vector3(0.29, 0.04, 0.48), Color(0.05, 0.05, 0.05))  # Sohle
		for sx in [-0.17, 0.17]:
			var piv := Node3D.new()
			piv.position = Vector3(sx, 1.1, 0)
			holder.add_child(piv)
			_mi(piv, lm, 0.9, 0.0)
			parts["legL" if sx < 0 else "legR"] = piv
	else:
		var fm := MeshBuilder.new()
		fm.box(Vector3(-0.18, 0.06, 0.1), Vector3(0.24, 0.12, 0.4), Color(0.14, 0.12, 0.1))
		fm.box(Vector3(0.18, 0.06, 0.1), Vector3(0.24, 0.12, 0.4), Color(0.14, 0.12, 0.1))
		_mi(holder, fm, 0.9, 0.0)

static func team_is_adf(accent: Color) -> bool:
	return accent.b > accent.r

static func _infantry(root: Node3D, parts: Dictionary, kind: String, team: int) -> void:
	var tc := U.team_color(team)
	match kind:
		"adf_rifle":
			_person_parts(root, parts, Color(0.56, 0.5, 0.36), Color(0.5, 0.45, 0.32), Color(0.27, 0.3, 0.25), Color(0.42, 0.4, 0.3), SKIN[0], tc, {"gun": "rifle", "backpack": true, "pack_col": Color(0.33, 0.33, 0.27), "radio": false})
		"adf_recon":
			_person_parts(root, parts, Color(0.34, 0.36, 0.3), Color(0.31, 0.33, 0.28), Color(0.19, 0.21, 0.19), Color(0.24, 0.26, 0.23), SKIN[1], tc, {"gun": "scope", "backpack": true, "pack_col": Color(0.2, 0.22, 0.19), "radio": true})
		"reb_fighter":
			_person_parts(root, parts, Color(0.2, 0.22, 0.17), Color(0.22, 0.2, 0.17), Color(0.4, 0.34, 0.24), Color(0, 0, 0, 0), SKIN[2], tc, {"gun": "ak", "scarf": true, "scarf_col": Color(0.12, 0.12, 0.12), "beard": false})
		"reb_rpg":
			_person_parts(root, parts, Color(0.3, 0.27, 0.2), Color(0.3, 0.28, 0.22), Color(0.3, 0.33, 0.25), Color(0, 0, 0, 0), SKIN[1], tc, {"gun": "rpg", "scarf": true, "scarf_col": Color(0.7, 0.68, 0.6), "backpack": true, "pack_col": Color(0.3, 0.3, 0.2)})
		"reb_saboteur":
			_person_parts(root, parts, Color(0.38, 0.33, 0.25), Color(0.25, 0.23, 0.2), Color(0, 0, 0, 0), Color(0, 0, 0, 0), SKIN[2], tc, {"gun": "shovel", "backpack": true, "pack_col": Color(0.35, 0.28, 0.2), "scarf": true, "scarf_col": Color(0.2, 0.2, 0.2)})
		"reb_media":
			_person_parts(root, parts, Color(0.5, 0.45, 0.38), Color(0.25, 0.28, 0.35), Color(0, 0, 0, 0), Color(0, 0, 0, 0), SKIN[0], Color(0, 0, 0, 0), {"gun": "camera", "bag": true})

static func _civilian(root: Node3D, parts: Dictionary, variant: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = variant * 7919 + 13
	var skin: Color = SKIN[r.randi() % SKIN.size()]
	var shirt: Color = [Color(0.85, 0.85, 0.8), Color(0.3, 0.45, 0.65), Color(0.7, 0.3, 0.25), Color(0.4, 0.55, 0.35), Color(0.8, 0.7, 0.4), Color(0.55, 0.55, 0.58), Color(0.9, 0.9, 0.9), Color(0.25, 0.25, 0.3)][r.randi() % 8]
	var pants: Color = [Color(0.25, 0.25, 0.3), Color(0.35, 0.3, 0.22), Color(0.2, 0.22, 0.28), Color(0.45, 0.4, 0.3)][r.randi() % 4]
	var kind := r.randi() % 10
	var opts := {"gun": "", "pouches": false, "goggles": false}
	opts["hair"] = [Color(0.08, 0.06, 0.05), Color(0.2, 0.14, 0.1), Color(0.35, 0.3, 0.28), Color(0.55, 0.55, 0.55)][r.randi() % 4]
	if kind <= 2:
		opts["robe"] = true
		opts["robe_col"] = [Color(0.92, 0.9, 0.84), Color(0.8, 0.76, 0.66), Color(0.55, 0.58, 0.62)][r.randi() % 3]
		opts["scarf"] = r.randf() < 0.5
		opts["scarf_col"] = Color(0.9, 0.9, 0.88)
		opts["beard"] = r.randf() < 0.5
	elif kind <= 5:
		opts["robe"] = true
		opts["robe_col"] = [Color(0.12, 0.12, 0.16), Color(0.2, 0.3, 0.45), Color(0.5, 0.2, 0.25), Color(0.22, 0.4, 0.3), Color(0.55, 0.4, 0.55)][r.randi() % 5]
		opts["scarf"] = true
		opts["scarf_col"] = [Color(0.9, 0.85, 0.8), Color(0.15, 0.15, 0.2), Color(0.7, 0.3, 0.3), Color(0.3, 0.5, 0.55)][r.randi() % 4]
	else:
		opts["beard"] = r.randf() < 0.3
	if r.randf() < 0.3:
		opts["bag"] = true
		opts["bag_col"] = [Color(0.5, 0.35, 0.2), Color(0.2, 0.3, 0.5), Color(0.6, 0.2, 0.2)][r.randi() % 3]
	if kind == 9:
		opts["scale"] = 0.82
	else:
		opts["scale"] = r.randf_range(1.08, 1.2)
	_person_parts(root, parts, shirt, pants, Color(0, 0, 0, 0), Color(0, 0, 0, 0), skin, Color(0, 0, 0, 0), opts)

# ------------------------------------------------------------------------ Fahrzeug-Helfer
static func _tracks(mb: MeshBuilder, x: float, z0: float, z1: float, wr: float, n_wheels: int, dark: Color, steel: Color) -> void:
	var length := z1 - z0
	var tw := 0.64
	# Kettenband oben und unten (Glieder)
	var links := int(length / 0.34)
	for i in range(links):
		var z := z0 + (i + 0.5) * length / links
		var c := dark * (0.9 if i % 2 == 0 else 1.1)
		mb.box(Vector3(x, wr * 2.0 + 0.02, z), Vector3(tw, 0.07, length / links * 0.9), c)
		mb.box(Vector3(x, 0.04, z), Vector3(tw, 0.07, length / links * 0.9), c)
	mb.box(Vector3(x, wr + 0.04, (z0 + z1) * 0.5), Vector3(tw * 0.9, wr * 2.0 - 0.2, length - wr * 1.6), dark * 0.7)
	# Laufrollen
	for i in range(n_wheels):
		var z2 := z0 + wr + 0.1 + i * (length - wr * 2.0 - 0.2) / maxf(n_wheels - 1, 1)
		mb.cyl(Vector3(x, wr + 0.04, z2), wr, wr, tw * 0.9, dark * 1.3, 12, 1)
		mb.cyl(Vector3(x + signf(x) * 0.34, wr + 0.04, z2), wr * 0.55, wr * 0.55, 0.06, steel, 10, 1)
		mb.cyl(Vector3(x + signf(x) * 0.38, wr + 0.04, z2), wr * 0.2, wr * 0.2, 0.06, steel * 0.7, 6, 1)
	# Antriebsrad hinten und Leitrad vorn
	mb.cyl(Vector3(x, wr * 1.2, z0 + wr * 0.9), wr * 1.15, wr * 1.15, tw * 0.9, steel * 0.8, 14, 1)
	mb.cyl(Vector3(x, wr * 1.2, z1 - wr * 0.9), wr * 1.0, wr * 1.0, tw * 0.9, steel * 0.8, 14, 1)
	for i in range(12):
		var a := TAU * i / 12.0
		mb.box_t(Vector3(x, wr * 1.2 + sin(a) * wr * 1.2, z0 + wr * 0.9 + cos(a) * wr * 1.2), Vector3(tw * 0.95, 0.09, 0.1), dark * 1.4, Vector3(-rad_to_deg(a), 0, 0))
	# Stuetzrollen
	for i in range(3):
		mb.cyl(Vector3(x, wr * 2.1 + 0.18, z0 + length * (0.3 + i * 0.2)), 0.14, 0.14, 0.4, dark * 1.4, 8, 1)

static func _era_row(mb: MeshBuilder, center: Vector3, count: int, step: float, size: Vector3, col: Color, along_x: bool, tilt: float = 0.0) -> void:
	for i in range(count):
		var o := (i - (count - 1) * 0.5) * step
		var p := center + (Vector3(o, 0, 0) if along_x else Vector3(0, 0, o))
		mb.box_t(p, size, col * (0.9 if i % 2 == 0 else 1.05), Vector3(tilt, 0, 0))

static func _hatch(mb: MeshBuilder, pos: Vector3, r: float, col: Color) -> void:
	mb.cyl(pos, r, r, 0.12, col * 0.85, 12)
	mb.cyl(pos + Vector3(0, 0.07, 0), r * 0.82, r * 0.82, 0.05, col * 1.1, 12)
	mb.box(pos + Vector3(r * 0.6, 0.12, 0), Vector3(0.1, 0.06, 0.05), Color(0.1, 0.1, 0.1))

static func _lamp(mb: MeshBuilder, pos: Vector3, w: float = 0.22) -> void:
	mb.box(pos, Vector3(w, w * 0.7, 0.12), Color(0.15, 0.15, 0.15))
	mb.box(pos + Vector3(0, 0, 0.065), Vector3(w * 0.7, w * 0.45, 0.02), Color(0.95, 0.9, 0.7))

static func _antenna(mb: MeshBuilder, pos: Vector3, h: float, col: Color, tilt: float = 0.0) -> void:
	mb.cyl(pos + Vector3(0, 0.1, 0), 0.07, 0.06, 0.2, col, 6)
	mb.set_xf(pos + Vector3(0, 0.2, 0), Vector3(tilt, 0, 0))
	mb.cyl(Vector3(0, h * 0.5, 0), 0.02, 0.008, h, col * 0.8, 5)
	mb.reset_xf()

# ------------------------------------------------------------------------ Fahrzeuge
static func _apc(root: Node3D, parts: Dictionary, team: int) -> void:
	var tan := Color(0.6, 0.54, 0.4)
	var dark := Color(0.12, 0.12, 0.13)
	var steel := Color(0.3, 0.3, 0.3)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.ao_floor = 0.4
	mb.jitter = 0.03
	# Wanne
	mb.extrude([Vector2(-1.4, -3.1), Vector2(1.4, -3.1), Vector2(1.45, 1.4), Vector2(1.1, 2.7), Vector2(-1.1, 2.7), Vector2(-1.45, 1.4)], 0.6, 1.7, tan, tan * 1.1)
	mb.box(Vector3(0, 0.95, 0), Vector3(2.9, 0.5, 5.7), tan * 0.82)
	mb.wedge(Vector3(0, 1.45, 2.85), Vector3(2.2, 0.55, 0.9), tan * 1.05)             # Bugschraege
	mb.box(Vector3(0, 1.72, -0.2), Vector3(2.5, 0.08, 4.6), tan * 1.12)                # Dachplatte
	# Kotfluegel + Raeder
	for sx in [-1.45, 1.45]:
		for z in [-2.3, -0.8, 0.8, 2.3]:
			mb.wheel(Vector3(sx, 0.58, z), 0.58, 0.46, dark, steel, 16)
		for z in [-1.55, 1.55]:
			mb.box(Vector3(sx * 1.04, 1.12, z), Vector3(0.12, 0.08, 1.45), tan * 0.9)  # Kotfluegel
		mb.box(Vector3(sx * 1.02, 1.05, 0), Vector3(0.1, 0.5, 5.0), tan * 0.85)
		# Gitterpanzerung seitlich
		for i in range(9):
			mb.box(Vector3(sx * 1.08, 1.45, -2.0 + i * 0.5), Vector3(0.04, 0.5, 0.05), dark * 1.5)
		mb.box(Vector3(sx * 1.08, 1.7, 0), Vector3(0.05, 0.05, 4.6), dark * 1.5)
		mb.box(Vector3(sx * 1.08, 1.2, 0), Vector3(0.05, 0.05, 4.6), dark * 1.5)
		mb.box(Vector3(sx * 0.95, 1.75, -2.0), Vector3(0.18, 0.08, 0.5), dark)         # Seitenspiegel-Arm
	# Heck
	mb.box(Vector3(0, 1.25, -3.12), Vector3(1.7, 1.0, 0.07), tan * 0.7)                # Rampe
	mb.box(Vector3(0, 1.25, -3.17), Vector3(0.05, 0.9, 0.04), dark)
	mb.box(Vector3(0, 0.95, -3.18), Vector3(0.9, 0.06, 0.05), dark)
	mb.cyl(Vector3(-1.1, 0.8, -3.2), 0.1, 0.1, 0.5, steel, 8, 1)                       # Auspuff
	mb.beam(Vector3(0.8, 0.7, -3.2), Vector3(1.3, 0.7, -3.2), 0.07, dark * 2.0)        # Abschleppseil
	# Front: Scheinwerfer, Stossstange, Winde
	_lamp(mb, Vector3(-1.0, 1.0, 2.9))
	_lamp(mb, Vector3(1.0, 1.0, 2.9))
	mb.box(Vector3(0, 0.62, 3.0), Vector3(2.7, 0.2, 0.2), dark)
	mb.cyl(Vector3(0, 0.95, 3.05), 0.16, 0.16, 0.5, steel, 10, 1)                      # Winde
	mb.box(Vector3(0, 1.58, 2.15), Vector3(1.1, 0.14, 0.7), dark)                       # Fahrersichtfenster
	mb.box(Vector3(0, 1.62, 2.18), Vector3(0.9, 0.08, 0.5), Color(0.1, 0.16, 0.2))
	# Dach: Luken, Antennen, Optiken
	_hatch(mb, Vector3(-0.8, 1.78, -1.4), 0.34, tan)
	_hatch(mb, Vector3(0.8, 1.78, -1.9), 0.34, tan)
	_antenna(mb, Vector3(-1.1, 1.75, -2.6), 2.4, dark)
	_antenna(mb, Vector3(1.1, 1.75, -2.6), 1.6, dark, 6.0)
	mb.box(Vector3(0.9, 1.84, 0.9), Vector3(0.4, 0.14, 0.3), dark)
	mb.box(Vector3(-0.9, 1.84, 1.2), Vector3(0.4, 0.14, 0.3), dark)
	mb.box(Vector3(0, 1.74, -2.2), Vector3(1.3, 0.04, 0.7), dark * 1.3)                # Lueftergitter
	mb.box(Vector3(0, 1.76, -2.8), Vector3(0.5, 0.16, 0.4), tan * 0.8)                 # Stauraum
	mb.box(Vector3(0, 1.74, -1.6), Vector3(0.9, 0.04, 0.02), tc)
	mb.box_t(Vector3(1.38, 1.4, -1.0), Vector3(0.14, 0.2, 0.5), Color(0.25, 0.3, 0.22), Vector3(0, 0, 0))   # Kanister
	_mi(root, mb, 0.75, 0.15)
	# Turm (Waffenstation)
	var tur := Node3D.new()
	tur.position = Vector3(0, 1.74, 0.5)
	root.add_child(tur)
	var tb := MeshBuilder.new()
	tb.ao_strength = 0.2
	tb.jitter = 0.03
	tb.extrude([Vector2(-0.85, -0.9), Vector2(0.85, -0.9), Vector2(0.95, 0.5), Vector2(0.45, 0.95), Vector2(-0.45, 0.95), Vector2(-0.95, 0.5)], 0.0, 0.72, tan * 0.95, tan * 1.08)
	tb.box(Vector3(0, 0.38, 1.0), Vector3(0.7, 0.4, 0.2), tan * 0.8)                   # Blende
	tb.cyl(Vector3(0, 0.45, 1.8), 0.075, 0.07, 1.6, steel, 8, 2)                       # Kanone
	tb.cyl(Vector3(0, 0.45, 1.45), 0.12, 0.12, 0.6, dark * 1.4, 8, 2)                   # Huelse
	tb.cyl(Vector3(0, 0.45, 2.65), 0.1, 0.1, 0.14, dark, 8, 2)                          # Muendungsbremse
	tb.cyl(Vector3(0.22, 0.34, 1.35), 0.03, 0.03, 0.7, steel, 6, 2)                     # Koax-MG
	tb.box(Vector3(0.62, 0.32, 0.2), Vector3(0.22, 0.28, 0.45), dark)                   # Munitionskasten
	tb.box(Vector3(-0.5, 0.88, -0.2), Vector3(0.3, 0.26, 0.3), dark)                    # Sensorkopf
	tb.cyl(Vector3(-0.5, 0.88, -0.05), 0.08, 0.08, 0.1, Color(0.2, 0.4, 0.8), 8, 2)
	for i in range(3):                                                                 # Nebelwerfer
		tb.cyl(Vector3(-0.98, 0.5, -0.4 + i * 0.28), 0.06, 0.06, 0.2, dark, 6, 1)
		tb.cyl(Vector3(0.98, 0.5, -0.4 + i * 0.28), 0.06, 0.06, 0.2, dark, 6, 1)
	tb.cyl(Vector3(-0.2, 1.45, -0.6), 0.015, 0.01, 1.4, dark, 4)
	tb.box(Vector3(0, 0.45, 0.95), Vector3(0.7, 0.28, 0.1), tc)
	_mi(tur, tb, 0.7, 0.2)
	parts["turret"] = tur
	parts["muzzle"] = _marker(tur, Vector3(0, 0.45, 2.8), "Muzzle")

static func _mbt(root: Node3D, parts: Dictionary, team: int) -> void:
	var sand := Color(0.6, 0.53, 0.38)
	var dark := Color(0.13, 0.13, 0.14)
	var steel := Color(0.28, 0.28, 0.3)
	var era := Color(0.45, 0.4, 0.3)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.35
	mb.ao_floor = 0.3
	mb.jitter = 0.03
	# Wanne
	mb.extrude([Vector2(-1.35, -3.3), Vector2(1.35, -3.3), Vector2(1.5, 2.2), Vector2(0.9, 3.5), Vector2(-0.9, 3.5), Vector2(-1.5, 2.2)], 0.65, 1.55, sand, sand * 1.08)
	mb.wedge(Vector3(0, 1.5, 3.1), Vector3(1.9, 0.5, 0.9), sand * 1.05)
	for sx in [-1.55, 1.55]:
		_tracks(mb, sx, -3.35, 3.5, 0.42, 7, dark, steel)
		# Seitenschuerzen (segmentiert)
		for i in range(6):
			mb.box(Vector3(sx * 1.02, 1.12, -2.6 + i * 1.02), Vector3(0.12, 0.62, 0.92), sand * (0.92 if i % 2 == 0 else 1.0))
			mb.box(Vector3(sx * 1.05, 1.12, -2.6 + i * 1.02), Vector3(0.05, 0.4, 0.6), era)
		mb.box(Vector3(sx * 1.0, 1.52, 0), Vector3(0.25, 0.06, 6.2), dark * 1.2)       # Ketten-Abdeckung
	# Bug: ERA-Bloecke, Scheinwerfer, Schlepphaken
	_era_row(mb, Vector3(0, 1.62, 2.9), 6, 0.3, Vector3(0.24, 0.1, 0.4), era, true, 24.0)
	_era_row(mb, Vector3(0, 1.58, 2.5), 7, 0.34, Vector3(0.26, 0.1, 0.38), era, true, 12.0)
	_lamp(mb, Vector3(-1.1, 1.38, 3.4), 0.26)
	_lamp(mb, Vector3(1.1, 1.38, 3.4), 0.26)
	mb.beam(Vector3(-0.7, 1.0, 3.45), Vector3(-0.7, 1.0, 3.7), 0.08, steel)
	mb.beam(Vector3(0.7, 1.0, 3.45), Vector3(0.7, 1.0, 3.7), 0.08, steel)
	# Heck: Motorgitter, Kanister, Ersatzketten
	mb.box(Vector3(0, 1.6, -2.6), Vector3(2.4, 0.07, 1.4), dark)
	for i in range(10):
		mb.box(Vector3(-1.0 + i * 0.22, 1.65, -2.6), Vector3(0.03, 0.04, 1.3), steel)
	mb.cyl(Vector3(-1.0, 1.0, -3.45), 0.24, 0.24, 0.7, Color(0.25, 0.3, 0.2), 10)
	mb.cyl(Vector3(1.0, 1.0, -3.45), 0.24, 0.24, 0.7, Color(0.25, 0.3, 0.2), 10)
	mb.box(Vector3(0, 1.1, -3.45), Vector3(1.2, 0.5, 0.3), sand * 0.8)                 # Stauraum
	mb.cyl(Vector3(0.5, 0.75, -3.5), 0.14, 0.14, 0.3, steel, 8, 2)                      # Auspuff
	mb.beam(Vector3(-1.2, 0.8, -3.52), Vector3(1.2, 0.8, -3.52), 0.06, dark * 2.0)     # Abschleppseil
	_mi(root, mb, 0.75, 0.15)
	# Turm
	var tur := Node3D.new()
	tur.position = Vector3(0, 1.55, -0.2)
	root.add_child(tur)
	var tb := MeshBuilder.new()
	tb.ao_strength = 0.25
	tb.jitter = 0.03
	tb.extrude([Vector2(-1.2, -1.3), Vector2(1.2, -1.3), Vector2(1.4, 0.3), Vector2(0.9, 1.5), Vector2(-0.9, 1.5), Vector2(-1.4, 0.3)], 0.0, 1.0, sand * 0.97, sand * 1.1)
	tb.box(Vector3(0, 0.45, 1.6), Vector3(1.1, 0.7, 0.34), sand * 0.85)                # Blende
	tb.box(Vector3(0, 0.45, 1.78), Vector3(0.7, 0.55, 0.12), dark * 1.4)
	# Turmseiten-ERA und Rueckkorb
	for sx in [-1, 1]:
		for i in range(5):
			tb.box_t(Vector3(sx * 1.2, 0.55, -0.6 + i * 0.4), Vector3(0.12, 0.7, 0.34), era * (0.9 if i % 2 == 0 else 1.05), Vector3(0, 0, sx * 8.0))
	tb.box(Vector3(0, 0.55, -1.55), Vector3(2.1, 0.7, 0.5), sand * 0.88)                # Turmheck-Korb
	for i in range(8):
		tb.box(Vector3(-0.9 + i * 0.26, 0.55, -1.84), Vector3(0.03, 0.66, 0.03), dark * 1.5)
	tb.box(Vector3(0.2, 1.05, -1.5), Vector3(0.9, 0.12, 0.35), Color(0.33, 0.37, 0.27))   # Tarnnetz/Bettrolle
	# Rohr: Wiege, Auswerfer, Huelse, Muendungsbremse
	tb.cyl(Vector3(0, 0.45, 2.1), 0.2, 0.2, 0.7, dark * 1.3, 10, 2)
	tb.cyl(Vector3(0, 0.45, 3.75), 0.17, 0.16, 3.4, Color(0.22, 0.22, 0.23), 10, 2)
	tb.cyl(Vector3(0, 0.45, 3.2), 0.22, 0.22, 0.5, Color(0.2, 0.2, 0.21), 10, 2)       # Rohrauswerfer
	tb.cyl(Vector3(0, 0.45, 4.3), 0.21, 0.21, 0.7, Color(0.24, 0.24, 0.25), 10, 2)      # Waermehuelle
	tb.cyl(Vector3(0, 0.45, 5.4), 0.25, 0.25, 0.4, Color(0.15, 0.15, 0.16), 10, 2)      # Muendungsbremse
	tb.cyl(Vector3(0.38, 0.38, 2.0), 0.04, 0.04, 1.2, steel, 6, 2)                      # Koax-MG
	# Optiken, Kommandantenkuppel, Ladeluke, Flak-MG
	tb.box(Vector3(-0.55, 1.12, 0.65), Vector3(0.5, 0.22, 0.4), dark * 1.3)             # Waermebild
	tb.box(Vector3(-0.55, 1.14, 0.9), Vector3(0.4, 0.14, 0.04), Color(0.2, 0.4, 0.8))
	tb.cyl(Vector3(0.65, 1.1, -0.2), 0.42, 0.42, 0.22, sand * 0.85, 14)                 # Kommandantenring
	for i in range(8):
		var a := TAU * i / 8.0
		tb.box_t(Vector3(0.65 + cos(a) * 0.38, 1.28, -0.2 + sin(a) * 0.38), Vector3(0.14, 0.1, 0.06), Color(0.12, 0.2, 0.25), Vector3(0, -rad_to_deg(a), 0))
	tb.cyl(Vector3(0.65, 1.3, -0.2), 0.3, 0.3, 0.06, dark * 1.4, 12)
	tb.box(Vector3(0.65, 1.55, 0.05), Vector3(0.12, 0.14, 0.4), dark)                   # Flak-MG
	tb.cyl(Vector3(0.65, 1.55, 0.5), 0.025, 0.025, 0.5, steel, 6, 2)
	_hatch(tb, Vector3(-0.6, 1.02, -0.7), 0.34, sand)
	for sx in [-1, 1]:                                                                  # Nebelwerfer
		for i in range(4):
			tb.cyl(Vector3(sx * 1.38, 0.8, 0.9 + i * 0.2), 0.065, 0.065, 0.26, dark, 6, 1)
	_antenna(tb, Vector3(-0.85, 1.02, -1.15), 3.2, dark)
	_antenna(tb, Vector3(0.1, 1.02, -1.15), 2.0, dark, 5.0)
	tb.box(Vector3(1.28, 0.55, 0.7), Vector3(0.05, 0.4, 0.8), tc)
	tb.box(Vector3(-1.28, 0.55, 0.7), Vector3(0.05, 0.4, 0.8), tc)
	# kleine blaue Fahne
	tb.cyl(Vector3(-0.2, 1.7, -1.4), 0.015, 0.012, 1.4, dark, 4)
	tb.box(Vector3(0.0, 2.2, -1.4), Vector3(0.4, 0.22, 0.02), tc)
	_mi(tur, tb, 0.7, 0.2)
	parts["turret"] = tur
	parts["muzzle"] = _marker(tur, Vector3(0, 0.45, 5.7), "Muzzle")

static func _arty(root: Node3D, parts: Dictionary, team: int) -> void:
	var sand := Color(0.58, 0.52, 0.38)
	var dark := Color(0.13, 0.13, 0.14)
	var steel := Color(0.28, 0.28, 0.3)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.35
	mb.ao_floor = 0.3
	mb.jitter = 0.03
	mb.extrude([Vector2(-1.35, -3.1), Vector2(1.35, -3.1), Vector2(1.4, 2.4), Vector2(0.8, 3.2), Vector2(-0.8, 3.2), Vector2(-1.4, 2.4)], 0.65, 1.5, sand, sand * 1.08)
	for sx in [-1.5, 1.5]:
		_tracks(mb, sx, -3.1, 3.2, 0.4, 6, dark, steel)
		for i in range(5):
			mb.box(Vector3(sx * 1.02, 1.05, -2.2 + i * 1.1), Vector3(0.1, 0.5, 1.0), sand * (0.92 if i % 2 else 1.0))
	mb.box_t(Vector3(0, 0.62, -3.5), Vector3(2.4, 0.16, 0.8), dark, Vector3(-20, 0, 0))   # Erdsporn
	mb.box(Vector3(0, 1.0, -3.55), Vector3(2.0, 0.08, 0.2), steel)
	_lamp(mb, Vector3(-0.9, 1.1, 3.1))
	_lamp(mb, Vector3(0.9, 1.1, 3.1))
	mb.box(Vector3(-0.9, 1.58, 2.3), Vector3(0.9, 0.22, 0.8), dark)                      # Fahrerluke
	_hatch(mb, Vector3(0.7, 1.55, 2.2), 0.3, sand)
	mb.cyl(Vector3(-1.1, 1.0, -3.0), 0.2, 0.2, 0.7, Color(0.25, 0.3, 0.2), 10)
	_mi(root, mb, 0.75, 0.15)
	var tur := Node3D.new()
	tur.position = Vector3(0, 1.5, -0.3)
	root.add_child(tur)
	var tb := MeshBuilder.new()
	tb.ao_strength = 0.25
	tb.jitter = 0.03
	tb.extrude([Vector2(-1.4, -1.8), Vector2(1.4, -1.8), Vector2(1.5, 1.0), Vector2(0.9, 1.7), Vector2(-0.9, 1.7), Vector2(-1.5, 1.0)], 0.0, 1.7, sand * 0.98, sand * 1.08)
	tb.box(Vector3(0, 0.85, 1.7), Vector3(1.2, 1.0, 0.34), sand * 0.85)
	tb.box(Vector3(0, 0.85, -2.0), Vector3(1.6, 1.0, 0.3), sand * 0.9)                  # Munitionsklappe
	tb.box(Vector3(0, 1.75, -0.6), Vector3(1.2, 0.08, 1.0), dark * 1.3)                 # Dachluke
	_hatch(tb, Vector3(-0.7, 1.74, 0.5), 0.3, sand)
	tb.box(Vector3(0.8, 1.8, 0.8), Vector3(0.4, 0.18, 0.4), dark)
	_antenna(tb, Vector3(1.0, 1.72, -1.4), 3.0, dark)
	tb.box(Vector3(1.55, 0.8, 0.0), Vector3(0.06, 0.5, 1.0), tc)
	tb.box(Vector3(-1.55, 0.8, 0.0), Vector3(0.06, 0.5, 1.0), tc)
	_mi(tur, tb, 0.7, 0.2)
	var barrel := Node3D.new()
	barrel.position = Vector3(0, 0.85, 1.8)
	barrel.rotation_degrees.x = -28.0
	tur.add_child(barrel)
	var bb := MeshBuilder.new()
	bb.cyl(Vector3(0, 0, 0.6), 0.32, 0.3, 1.2, dark * 1.2, 10, 2)                       # Rohrwiege
	bb.cyl(Vector3(0, 0, 2.6), 0.2, 0.18, 4.0, Color(0.2, 0.2, 0.21), 10, 2)
	bb.cyl(Vector3(0, 0, 2.2), 0.26, 0.26, 0.6, Color(0.18, 0.18, 0.19), 10, 2)         # Auswerfer
	bb.cyl(Vector3(0, 0, 5.4), 0.32, 0.32, 0.6, Color(0.14, 0.14, 0.15), 10, 2)         # Muendungsbremse
	for sx in [-1, 1]:
		bb.cyl(Vector3(sx * 0.4, 0, 1.0), 0.07, 0.07, 1.4, steel, 8, 2)                  # Rohrruecklaufzylinder
	_mi(barrel, bb, 0.6, 0.3)
	parts["turret"] = tur
	parts["barrel"] = barrel
	parts["muzzle"] = _marker(barrel, Vector3(0, 0, 5.8), "Muzzle")

static func _missile(mb: MeshBuilder, base: Vector3, length: float, r: float, body: Color, tip: Color, fin: Color) -> void:
	mb.cyl(base + Vector3(0, 0, length * 0.5), r, r, length, body, 8, 2)
	mb.cyl(base + Vector3(0, 0, length + 0.09), r, 0.0, 0.18, tip, 8, 2)
	for k in range(4):
		var a := TAU * k / 4.0 + PI * 0.25
		mb.box_t(base + Vector3(cos(a) * r * 1.5, sin(a) * r * 1.5, length * 0.12), Vector3(0.015 + absf(cos(a)) * 0.2, 0.015 + absf(sin(a)) * 0.2, 0.2), fin)

static func _drone(root: Node3D, parts: Dictionary, team: int) -> void:
	var grey := Color(0.78, 0.8, 0.82)
	var tc := U.team_color(team)
	var dark := Color(0.1, 0.1, 0.12)
	var steel := Color(0.3, 0.32, 0.34)
	var mb := MeshBuilder.new()
	mb.jitter = 0.02
	mb.ao_strength = 0.1
	# Rumpf: kantige Loft-Segmente (Nase -> Mittelteil -> Heck)
	mb.loft(Vector3(0, 0.02, -1.6), Vector2(0.58, 0.6), Vector3(0, 0.08, 0.9), Vector2(0.68, 0.7), grey)
	mb.loft(Vector3(0, 0.08, 0.9), Vector2(0.68, 0.7), Vector3(0, 0.0, 1.55), Vector2(0.52, 0.55), grey * 0.97)
	mb.loft(Vector3(0, 0.0, 1.55), Vector2(0.52, 0.55), Vector3(0, -0.1, 2.0), Vector2(0.22, 0.3), grey * 0.9)
	mb.loft(Vector3(0, 0.02, -1.6), Vector2(0.58, 0.6), Vector3(0, 0.1, -3.5), Vector2(0.14, 0.2), grey * 0.95)
	# Rueckenhoecker, Lufteinlass und Satelliten-Kuppel
	mb.loft(Vector3(0, 0.38, -0.2), Vector2(0.5, 0.18), Vector3(0, 0.42, 0.8), Vector2(0.46, 0.2), grey * 1.02)
	mb.sphere(Vector3(0, 0.46, 0.35), 0.3, Color(0.88, 0.89, 0.9), Vector3(1.0, 0.6, 1.5), 4, 10, true)
	mb.box(Vector3(0, 0.34, -2.0), Vector3(0.22, 0.2, 0.5), dark)
	mb.box(Vector3(0, 0.45, -2.1), Vector3(0.08, 0.2, 0.4), grey)
	# Tragflaechen: gepfeilt und verjuengt, mit Winglets
	for sx in [-1.0, 1.0]:
		mb.extrude([Vector2(sx * 0.28, 0.55), Vector2(sx * 4.9, -0.2), Vector2(sx * 4.9, -0.52), Vector2(sx * 0.28, -0.5)], -0.04, 0.05, grey, grey * 1.05)
		mb.box_t(Vector3(sx * 4.95, 0.2, -0.38), Vector3(0.04, 0.5, 0.36), grey * 0.95, Vector3(0, sx * 12.0, sx * 8.0))
		mb.box(Vector3(sx * 4.92, 0.0, -0.36), Vector3(0.14, 0.07, 0.4), tc)                       # Randbogen-Markierung
		mb.box(Vector3(sx * 2.2, 0.06, -0.52), Vector3(3.8, 0.03, 0.16), steel)                    # Klappen
	# Hardpoints: Pylone, Lenkflugkoerper, Praezisionsbomben
	for sx in [-1.0, 1.0]:
		for k in range(2):
			var x: float = sx * (1.2 + k * 1.15)
			mb.box(Vector3(x, -0.12, 0.05), Vector3(0.06, 0.22, 0.5), dark)
			if k == 0:
				mb.cyl(Vector3(x, -0.34, 0.05), 0.12, 0.12, 1.2, Color(0.35, 0.37, 0.33), 8, 2)       # Bombe
				mb.cyl(Vector3(x, -0.34, 0.75), 0.12, 0.03, 0.3, Color(0.35, 0.37, 0.33), 8, 2)
				mb.box(Vector3(x, -0.34, -0.5), Vector3(0.3, 0.02, 0.2), dark)
				mb.box(Vector3(x, -0.34, -0.5), Vector3(0.02, 0.3, 0.2), dark)
			else:
				_missile(mb, Vector3(x, -0.3, -0.4), 1.2, 0.07, Color(0.3, 0.32, 0.28), Color(0.55, 0.22, 0.1), dark)
	# Leitwerk: umgekehrtes V
	for sx in [-1.0, 1.0]:
		mb.box_t(Vector3(sx * 0.5, -0.2, -3.2), Vector3(0.05, 1.1, 0.62), grey, Vector3(0, 0, sx * 38.0))
		mb.box_t(Vector3(sx * 0.9, -0.62, -3.3), Vector3(0.05, 0.2, 0.34), tc, Vector3(0, 0, sx * 38.0))
	mb.box(Vector3(0, 0.34, -3.3), Vector3(0.05, 0.5, 0.55), grey * 0.95)                          # Rueckenflosse
	# Sensorkugel unter der Nase (EO/IR) und Laserzielgeraet
	mb.sphere(Vector3(0, -0.34, 1.35), 0.24, dark, Vector3.ONE, 5, 10)
	mb.cyl(Vector3(0, -0.34, 1.52), 0.09, 0.09, 0.12, Color(0.2, 0.45, 0.85), 8, 2)
	mb.box(Vector3(0, -0.22, 1.3), Vector3(0.3, 0.12, 0.5), dark)
	# Fahrwerk (Bugrad + zwei Hauptfahrwerke)
	mb.beam(Vector3(0, -0.15, 1.3), Vector3(0, -0.9, 1.3), 0.05, dark)
	mb.wheel(Vector3(0, -0.95, 1.3), 0.14, 0.1, dark, steel, 8)
	for sx in [-1.0, 1.0]:
		mb.beam(Vector3(sx * 0.3, -0.1, -0.7), Vector3(sx * 0.42, -0.9, -0.75), 0.05, dark)
		mb.wheel(Vector3(sx * 0.45, -0.95, -0.75), 0.15, 0.1, dark, steel, 8)
	# Antennen und Beleuchtung
	mb.cyl(Vector3(0.1, 0.62, -0.9), 0.012, 0.01, 0.5, dark, 4)
	mb.box(Vector3(0, 0.55, 1.2), Vector3(0.05, 0.1, 0.25), steel)
	mb.box(Vector3(0, 0.1, -3.62), Vector3(0.12, 0.12, 0.2), steel)                                # Propellernabe-Gehaeuse
	var holder := Node3D.new()
	holder.scale = Vector3(1.2, 1.2, 1.2)
	root.add_child(holder)
	_mi(holder, mb, 0.5, 0.3)
	var prop := Node3D.new()
	prop.position = Vector3(0, 0.1, -3.78)
	holder.add_child(prop)
	var pb := MeshBuilder.new()
	for i in range(3):
		pb.box_t(Vector3(0, 0, 0), Vector3(0.1, 0.9, 0.025), Color(0.08, 0.08, 0.09), Vector3(0, 0, i * 120.0))
	pb.cyl(Vector3(0, 0, 0.02), 0.09, 0.09, 0.1, steel, 8, 2)
	_mi(prop, pb, 0.6, 0.0)
	parts["rotor"] = prop
	parts["rotor_axis"] = 2
	parts["muzzle"] = _marker(holder, Vector3(0, -0.34, 1.35), "Muzzle")

static func _viper(root: Node3D, parts: Dictionary, team: int) -> void:
	var body := Color(0.38, 0.41, 0.4)
	var dark := Color(0.1, 0.1, 0.12)
	var steel := Color(0.3, 0.3, 0.32)
	var tc := U.team_color(team)
	var glass := Color(0.08, 0.15, 0.2)
	var olive := Color(0.24, 0.27, 0.22)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.12
	mb.jitter = 0.025
	# --- Rumpf: schmaler, kantiger Tandem-Rumpf aus Loft-Segmenten
	mb.loft(Vector3(0, 0.1, -2.4), Vector2(0.95, 0.95), Vector3(0, 0.1, 1.7), Vector2(0.88, 0.82), body)
	mb.loft(Vector3(0, 0.05, 1.7), Vector2(0.88, 0.82), Vector3(0, -0.12, 2.6), Vector2(0.34, 0.46), body * 0.96)
	mb.loft(Vector3(0, -0.32, -1.6), Vector2(0.7, 0.2), Vector3(0, -0.4, 1.6), Vector2(0.62, 0.2), olive)        # Kiel
	for sx in [-1.0, 1.0]:
		# Seitliche Geraeteschaechte (Sponsons) und Cockpitwangen
		mb.loft(Vector3(sx * 0.62, 0.12, 0.0), Vector2(0.34, 0.55), Vector3(sx * 0.56, 0.08, 1.95), Vector2(0.26, 0.42), body * 0.94)
		mb.loft(Vector3(sx * 0.46, 0.62, 0.45), Vector2(0.18, 0.3), Vector3(sx * 0.4, 0.55, 1.5), Vector2(0.16, 0.2), olive)
		# Triebwerksgondeln mit Einlass und IR-Duese
		mb.loft(Vector3(sx * 0.66, 0.95, -2.7), Vector2(0.55, 0.62), Vector3(sx * 0.64, 0.92, 0.45), Vector2(0.62, 0.64), body * 0.9)
		mb.box(Vector3(sx * 0.64, 0.9, 0.5), Vector3(0.46, 0.46, 0.08), dark)
		mb.loft(Vector3(sx * 0.68, 0.96, -2.7), Vector2(0.5, 0.55), Vector3(sx * 0.62, 1.0, -3.5), Vector2(0.28, 0.3), steel)
		mb.box(Vector3(sx * 0.62, 1.0, -3.52), Vector3(0.22, 0.22, 0.06), dark)
		for k in range(3):
			mb.box(Vector3(sx * 0.66, 1.27, -0.4 - k * 0.5), Vector3(0.4, 0.04, 0.2), dark)               # Kuehlschlitze
	mb.loft(Vector3(0, 0.62, -2.5), Vector2(0.8, 0.45), Vector3(0, 0.6, 0.2), Vector2(0.8, 0.4), body * 1.02)   # Oberdeck
	# --- Cockpits: Schuetze vorn (tief), Pilot hinten (hoch), kantige Scheiben
	mb.prism_x([Vector2(2.1, 0.2), Vector2(1.5, 0.92), Vector2(0.95, 0.92), Vector2(0.95, 0.42), Vector2(1.95, 0.42)], -0.3, 0.3, glass, Color(0.2, 0.24, 0.26))
	mb.prism_x([Vector2(0.85, 0.45), Vector2(0.42, 1.22), Vector2(-0.35, 1.22), Vector2(-0.8, 0.72), Vector2(-0.8, 0.45)], -0.32, 0.32, glass, Color(0.2, 0.24, 0.26))
	for sx in [-0.3, 0.3]:
		mb.beam(Vector3(sx, 0.42, 1.95), Vector3(sx, 0.92, 1.5), 0.04, body * 0.8)
		mb.beam(Vector3(sx, 0.92, 1.5), Vector3(sx, 0.92, 0.95), 0.04, body * 0.8)
		mb.beam(Vector3(sx * 1.05, 0.45, 0.85), Vector3(sx * 1.05, 1.22, 0.42), 0.045, body * 0.8)
		mb.beam(Vector3(sx * 1.05, 1.22, 0.42), Vector3(sx * 1.05, 1.22, -0.35), 0.045, body * 0.8)
		mb.beam(Vector3(sx * 1.05, 1.22, -0.35), Vector3(sx * 1.05, 0.72, -0.8), 0.045, body * 0.8)
	mb.beam(Vector3(-0.3, 0.92, 1.2), Vector3(0.3, 0.92, 1.2), 0.04, body * 0.8)
	# --- Rotorkopf: Mastverkleidung, Mast, Nabe
	mb.loft(Vector3(0, 1.0, -0.4), Vector2(0.5, 0.3), Vector3(0, 1.25, 0.2), Vector2(0.3, 0.3), body * 1.05)
	mb.cyl(Vector3(0, 1.42, 0), 0.11, 0.09, 0.3, steel, 8)
	# --- Heckausleger, Rueckenkamm, Leitwerk
	mb.loft(Vector3(0, 0.8, -2.5), Vector2(0.66, 0.6), Vector3(0, 0.9, -5.5), Vector2(0.24, 0.34), body * 0.98)
	mb.loft(Vector3(0, 1.1, -2.5), Vector2(0.2, 0.12), Vector3(0, 1.1, -5.3), Vector2(0.1, 0.08), olive)
	mb.prism_x([Vector2(-4.7, 0.95), Vector2(-5.75, 2.2), Vector2(-6.25, 2.2), Vector2(-6.05, 0.95)], -0.05, 0.05, body * 1.05)
	mb.box(Vector3(0.0, 2.25, -6.05), Vector3(0.14, 0.12, 0.5), dark)                              # Positionslicht-Traeger
	mb.box(Vector3(0, 1.55, -5.95), Vector3(0.11, 0.32, 0.4), tc)                                  # Kennzeichnung
	mb.prism_x([Vector2(-5.2, 0.72), Vector2(-5.85, 0.2), Vector2(-6.15, 0.2), Vector2(-6.0, 0.72)], -0.04, 0.04, body * 0.92)
	mb.box(Vector3(0, 0.98, -5.45), Vector3(2.6, 0.07, 0.6), body)                                 # Hoehenleitwerk
	mb.box(Vector3(-1.3, 1.05, -5.45), Vector3(0.05, 0.22, 0.6), body * 0.9)
	mb.box(Vector3(1.3, 1.05, -5.45), Vector3(0.05, 0.22, 0.6), body * 0.9)
	mb.box(Vector3(0.16, 0.8, -6.15), Vector3(0.1, 0.18, 0.3), steel)                              # Heckrotor-Getriebe
	for sx in [-1.0, 1.0]:
		mb.box(Vector3(sx * 0.36, 0.84, -3.4), Vector3(0.05, 0.16, 0.5), dark)                       # Flare-Werfer
	# --- Stummelfluegel mit Pylonen, Raketenbehaeltern und Hellfire-Gestellen
	mb.box(Vector3(0, 0.05, 0.35), Vector3(4.7, 0.1, 0.85), body * 0.9)
	mb.box(Vector3(0, 0.12, 0.35), Vector3(4.7, 0.03, 0.2), steel)
	for sx in [-1.0, 1.0]:
		mb.box_t(Vector3(sx * 2.35, 0.05, 0.35), Vector3(0.12, 0.12, 0.85), body, Vector3(0, 0, 0))
		var xi: float = sx * 1.15
		var xo: float = sx * 2.0
		mb.box(Vector3(xi, -0.12, 0.35), Vector3(0.08, 0.26, 0.6), dark)
		mb.box(Vector3(xo, -0.12, 0.35), Vector3(0.08, 0.26, 0.6), dark)
		# Raketenbehaelter (19 Rohre)
		mb.cyl(Vector3(xi, -0.38, 0.5), 0.23, 0.23, 1.4, olive, 8, 2)
		mb.cyl(Vector3(xi, -0.38, 1.22), 0.23, 0.2, 0.06, dark, 8, 2)
		for k in range(6):
			var a := TAU * k / 6.0
			mb.cyl(Vector3(xi + cos(a) * 0.12, -0.38 + sin(a) * 0.12, 1.26), 0.035, 0.035, 0.04, Color(0.55, 0.28, 0.12), 6, 2)
		mb.cyl(Vector3(xi, -0.38, 1.26), 0.035, 0.035, 0.04, Color(0.55, 0.28, 0.12), 6, 2)
		# Hellfire-Gestell: 2 Lenkwaffen je Seite
		mb.box(Vector3(xo, -0.3, 0.45), Vector3(0.12, 0.1, 1.1), steel)
		for k in [-1.0, 1.0]:
			_missile(mb, Vector3(xo + k * 0.13, -0.42, -0.05), 1.55, 0.065, Color(0.26, 0.29, 0.25), Color(0.5, 0.2, 0.1), dark)
		mb.box(Vector3(sx * 2.38, 0.05, 0.35), Vector3(0.05, 0.14, 0.85), tc)                         # Fluegelspitzen-Markierung
	# --- Bug: Zielerfassungsturm (TADS/PNVS) und Maschinenkanone
	mb.loft(Vector3(0, 0.12, 2.35), Vector2(0.5, 0.44), Vector3(0, 0.04, 2.85), Vector2(0.42, 0.36), dark)
	mb.box(Vector3(0, 0.08, 2.88), Vector3(0.3, 0.22, 0.04), glass)
	mb.cyl(Vector3(0.13, 0.08, 2.9), 0.07, 0.07, 0.06, Color(0.2, 0.45, 0.85), 8, 2)
	mb.box(Vector3(0, 0.36, 2.3), Vector3(0.26, 0.22, 0.34), dark)                                 # PNVS
	mb.box(Vector3(0, -0.52, 1.4), Vector3(0.34, 0.3, 0.7), dark)                                   # Kinnturm
	mb.cyl(Vector3(0, -0.56, 2.05), 0.035, 0.03, 1.0, steel, 6, 2)
	mb.cyl(Vector3(0, -0.56, 2.6), 0.06, 0.06, 0.12, dark, 6, 2)
	# --- Fahrwerk: Hauptfahrwerk + Spornrad
	for sx in [-1, 1]:
		mb.beam(Vector3(sx * 0.6, -0.3, 0.7), Vector3(sx * 0.95, -1.15, 0.95), 0.08, dark)
		mb.beam(Vector3(sx * 0.62, -0.3, 0.3), Vector3(sx * 0.95, -1.1, 0.95), 0.05, dark)
		mb.wheel(Vector3(sx * 1.0, -1.2, 0.95), 0.2, 0.14, dark, steel, 8)
	mb.beam(Vector3(0, 0.55, -4.6), Vector3(0, -0.2, -5.0), 0.07, dark)
	mb.wheel(Vector3(0, -0.3, -5.0), 0.14, 0.1, dark, steel, 8)
	# --- Antennen, Drahtschneider, Lichter
	mb.cyl(Vector3(0, 0.62, -2.2), 0.015, 0.008, 0.7, dark, 4)
	mb.box(Vector3(0, 1.2, -3.8), Vector3(0.04, 0.16, 0.34), steel)
	mb.box(Vector3(0, -0.46, -2.6), Vector3(0.04, 0.2, 0.34), steel)
	mb.box(Vector3(0, 1.0, 0.0), Vector3(0.04, 0.2, 0.5), dark)
	mb.box(Vector3(0, 1.55, -0.55), Vector3(0.1, 0.1, 0.12), Color(0.8, 0.12, 0.1))
	for sx in [-1, 1]:
		mb.box(Vector3(sx * 0.9, 0.1, 0.55), Vector3(0.08, 0.1, 0.1), Color(0.9, 0.2, 0.15) if sx < 0 else Color(0.2, 0.8, 0.3))
	var holder := Node3D.new()
	holder.scale = Vector3(1.05, 1.05, 1.05)
	root.add_child(holder)
	_mi(holder, mb, 0.45, 0.35)
	var rot := Node3D.new()
	rot.position = Vector3(0, 1.62, 0)
	holder.add_child(rot)
	var rb := MeshBuilder.new()
	# vier verjuengte Rotorblaetter mit Blattwurzel und farbiger Spitze
	for i in range(4):
		rb.set_xf(Vector3.ZERO, Vector3(0, i * 90.0, 0))
		rb.box(Vector3(0.95, 0.0, 0.0), Vector3(1.0, 0.045, 0.42), Color(0.16, 0.16, 0.17))
		rb.box(Vector3(2.4, 0.0, 0.0), Vector3(2.0, 0.035, 0.34), Color(0.1, 0.1, 0.11))
		rb.box(Vector3(3.85, 0.0, 0.0), Vector3(1.0, 0.03, 0.3), Color(0.1, 0.1, 0.11))
		rb.box(Vector3(4.4, 0.0, 0.0), Vector3(0.2, 0.035, 0.3), tc)
		rb.box(Vector3(0.55, -0.05, 0.0), Vector3(0.3, 0.1, 0.34), steel)                             # Blattgriff
	rb.reset_xf()
	rb.cyl(Vector3(0, -0.06, 0), 0.26, 0.26, 0.14, steel, 8)
	rb.cyl(Vector3(0, 0.05, 0), 0.14, 0.1, 0.12, dark, 8)
	_mi(rot, rb, 0.6, 0.0)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.45
	cm.bottom_radius = 4.45
	cm.height = 0.02
	cm.radial_segments = 24
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.3, 0.3, 0.3, 0.1)
	disc.material_override = dm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(disc)
	disc.position = Vector3(0, 1.62, 0)
	var trot := Node3D.new()
	trot.position = Vector3(0.24, 0.8, -6.15)
	holder.add_child(trot)
	var tb := MeshBuilder.new()
	for i in range(2):
		tb.box_t(Vector3.ZERO, Vector3(0.035, 1.5, 0.12), Color(0.1, 0.1, 0.1), Vector3(i * 90.0, 0, 0))
	tb.cyl(Vector3.ZERO, 0.07, 0.07, 0.12, steel, 6, 1)
	_mi(trot, tb, 0.6, 0.0)
	parts["rotor"] = rot
	parts["rotor2"] = trot
	parts["rotor_axis"] = 0
	parts["muzzle"] = _marker(holder, Vector3(0, -0.56, 2.7), "Muzzle")
	parts["muzzle2"] = _marker(holder, Vector3(2.0, -0.42, 1.5), "Muzzle2")

static func _technical(root: Node3D, parts: Dictionary, team: int) -> void:
	var body_c := Color(0.82, 0.78, 0.68)
	var rust := Color(0.5, 0.3, 0.16)
	var dark := Color(0.1, 0.1, 0.1)
	var steel := Color(0.28, 0.28, 0.3)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.35
	mb.ao_floor = 0.3
	mb.jitter = 0.05
	# Fahrgestell
	mb.box(Vector3(0, 0.62, 0), Vector3(1.5, 0.16, 5.2), steel)
	mb.box(Vector3(0, 0.82, 0), Vector3(2.0, 0.4, 5.0), body_c * 0.9)
	# Fahrerhaus
	mb.box(Vector3(0, 1.4, 1.25), Vector3(1.9, 0.9, 1.5), body_c)
	mb.box(Vector3(0, 1.2, 2.05), Vector3(1.9, 0.5, 0.9), body_c * 0.96)                   # Motorhaube
	mb.box(Vector3(0, 1.0, 2.55), Vector3(1.7, 0.4, 0.1), dark)                            # Kuehlergrill
	for i in range(6):
		mb.box(Vector3(-0.7 + i * 0.28, 1.0, 2.6), Vector3(0.04, 0.34, 0.03), steel * 1.4)
	_lamp(mb, Vector3(-0.7, 1.15, 2.62))
	_lamp(mb, Vector3(0.7, 1.15, 2.62))
	mb.box(Vector3(0, 0.62, 2.7), Vector3(2.0, 0.18, 0.18), dark)                          # Stossstange
	mb.box(Vector3(0, 1.62, 1.6), Vector3(1.7, 0.45, 0.06), Color(0.1, 0.14, 0.17))        # Frontscheibe
	for sx in [-1, 1]:
		mb.box(Vector3(sx * 0.96, 1.62, 1.25), Vector3(0.05, 0.4, 0.9), Color(0.1, 0.14, 0.17))
		mb.box(Vector3(sx * 0.96, 1.15, 1.25), Vector3(0.06, 0.5, 0.95), body_c * 0.85)     # Tuer
		mb.box(Vector3(sx * 1.05, 1.5, 1.8), Vector3(0.1, 0.18, 0.14), dark)               # Spiegel
	mb.box(Vector3(0, 1.88, 1.2), Vector3(1.9, 0.07, 1.6), body_c * 1.05)                  # Dach
	mb.box(Vector3(0, 1.55, 0.5), Vector3(1.7, 0.45, 0.06), Color(0.1, 0.14, 0.17))        # Heckscheibe
	# Ladeflaeche + Seitenwaende (verrostet, verbeult)
	mb.box(Vector3(0, 0.96, -1.2), Vector3(2.0, 0.1, 2.4), steel)
	for sx in [-1.0, 1.0]:
		mb.box(Vector3(sx, 1.28, -1.2), Vector3(0.09, 0.55, 2.5), body_c * 0.95)
		mb.box_t(Vector3(sx, 1.2, -1.0), Vector3(0.1, 0.3, 0.9), rust, Vector3(0, 0, 0))
	mb.box(Vector3(0, 1.28, -2.45), Vector3(2.0, 0.55, 0.09), body_c * 0.95)
	mb.box(Vector3(0, 1.28, -0.0), Vector3(2.0, 0.55, 0.09), body_c * 0.95)
	mb.box(Vector3(0.3, 1.1, -1.2), Vector3(0.5, 0.06, 2.3), tc)                           # Streifen
	# Wagenheber, Reservereifen, Saecke, Fass
	mb.wheel(Vector3(0, 1.45, -2.52), 0.46, 0.34, dark, steel, 12)
	mb.box(Vector3(-0.5, 1.15, -1.5), Vector3(0.7, 0.3, 0.5), Color(0.3, 0.25, 0.18))
	mb.cyl(Vector3(0.55, 1.25, -1.9), 0.28, 0.28, 0.6, Color(0.25, 0.3, 0.4), 10)
	# Raeder mit Profil
	for sx in [-1.12, 1.12]:
		for z in [-1.5, 1.7]:
			mb.wheel(Vector3(sx, 0.52, z), 0.52, 0.42, dark, steel, 14)
			mb.box(Vector3(sx * 0.93, 0.98, z), Vector3(0.18, 0.1, 1.1), body_c * 0.85)     # Kotfluegel
	# Ueberrollbuegel
	mb.beam(Vector3(-0.9, 1.3, 0.1), Vector3(-0.9, 2.2, 0.1), 0.09, steel)
	mb.beam(Vector3(0.9, 1.3, 0.1), Vector3(0.9, 2.2, 0.1), 0.09, steel)
	mb.beam(Vector3(-0.9, 2.2, 0.1), Vector3(0.9, 2.2, 0.1), 0.09, steel)
	# Antenne + kleine Fahne
	_antenna(mb, Vector3(-0.95, 1.9, 0.9), 2.5, dark, -4.0)
	mb.box(Vector3(-0.95, 3.5, 0.9), Vector3(0.02, 0.3, 0.45), tc)
	_mi(root, mb, 0.8, 0.1)
	# Dreh-MG mit Schuetze
	var tur := Node3D.new()
	tur.position = Vector3(0, 1.4, -1.2)
	root.add_child(tur)
	var tb := MeshBuilder.new()
	tb.jitter = 0.04
	tb.cyl(Vector3(0, 0.25, 0), 0.09, 0.09, 0.5, steel, 6)
	tb.box(Vector3(0, 0.6, 0.1), Vector3(0.22, 0.3, 0.6), dark)
	tb.cyl(Vector3(0, 0.62, 1.1), 0.07, 0.06, 1.5, steel, 8, 2)
	tb.cyl(Vector3(0, 0.62, 1.9), 0.1, 0.1, 0.16, dark, 8, 2)
	tb.box(Vector3(0, 0.72, 0.2), Vector3(0.14, 0.12, 0.6), steel)                         # Spanngriff
	tb.box(Vector3(0.28, 0.5, 0.1), Vector3(0.24, 0.3, 0.3), Color(0.25, 0.3, 0.2))        # Munitionskasten
	tb.box(Vector3(0, 0.78, -0.25), Vector3(0.8, 0.5, 0.06), dark * 1.2)                   # Schutzschild
	for i in range(8):                                                                     # Gurt
		tb.box(Vector3(0.14, 0.5 - i * 0.015, 0.05 + i * 0.03), Vector3(0.05, 0.05, 0.05), Color(0.8, 0.65, 0.2))
	# Schuetze (Oberkoerper)
	tb.box(Vector3(0, 0.55, -0.55), Vector3(0.6, 0.7, 0.4), Color(0.2, 0.22, 0.17))
	tb.sphere(Vector3(0, 1.05, -0.55), 0.2, SKIN[2], Vector3(0.95, 1.1, 1.0), 6, 10)
	tb.sphere(Vector3(0, 1.1, -0.57), 0.24, Color(0.12, 0.12, 0.12), Vector3(1, 0.9, 1.05), 6, 10, true)
	tb.beam(Vector3(0.28, 0.75, -0.55), Vector3(0.1, 0.65, 0.1), 0.14, Color(0.2, 0.22, 0.17))
	tb.beam(Vector3(-0.28, 0.75, -0.55), Vector3(-0.1, 0.65, 0.1), 0.14, Color(0.2, 0.22, 0.17))
	_mi(tur, tb, 0.6, 0.3)
	parts["turret"] = tur
	parts["muzzle"] = _marker(tur, Vector3(0, 0.62, 2.0), "Muzzle")

static func _civ_truck(root: Node3D, parts: Dictionary, variant: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = variant + 3
	var col: Color = [Color(0.3, 0.45, 0.6), Color(0.65, 0.2, 0.15), Color(0.8, 0.78, 0.7), Color(0.4, 0.5, 0.35)][r.randi() % 4]
	var dark := Color(0.1, 0.1, 0.1)
	var steel := Color(0.28, 0.28, 0.3)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.35
	mb.ao_floor = 0.3
	mb.jitter = 0.04
	mb.box(Vector3(0, 0.8, 0), Vector3(1.6, 0.2, 6.2), steel)
	mb.box(Vector3(0, 1.0, 0), Vector3(2.3, 0.25, 6.0), Color(0.25, 0.25, 0.27))
	mb.box(Vector3(0, 1.75, 2.1), Vector3(2.2, 1.4, 1.7), col)                              # Kabine
	mb.box(Vector3(0, 1.3, 2.9), Vector3(2.1, 0.7, 0.9), col * 0.95)                        # Haube
	mb.box(Vector3(0, 1.45, 3.4), Vector3(1.9, 0.5, 0.08), dark)
	_lamp(mb, Vector3(-0.8, 1.4, 3.42), 0.26)
	_lamp(mb, Vector3(0.8, 1.4, 3.42), 0.26)
	mb.box(Vector3(0, 2.05, 2.7), Vector3(2.0, 0.55, 0.06), Color(0.1, 0.14, 0.17))
	for sx in [-1, 1]:
		mb.box(Vector3(sx * 1.12, 2.0, 2.1), Vector3(0.05, 0.5, 1.0), Color(0.1, 0.14, 0.17))
		mb.box(Vector3(sx * 1.25, 1.9, 2.8), Vector3(0.16, 0.34, 0.14), dark)               # Spiegel
	mb.box(Vector3(0, 2.5, 2.1), Vector3(2.0, 0.1, 1.5), col * 1.05)
	mb.box(Vector3(0, 2.2, -0.9), Vector3(2.3, 1.9, 3.9), Color(0.8, 0.75, 0.62))           # Plane
	mb.box(Vector3(0, 3.2, -0.9), Vector3(2.1, 0.14, 3.7), Color(0.75, 0.7, 0.58))
	for i in range(5):
		mb.box(Vector3(0, 2.2, -2.6 + i * 0.9), Vector3(2.35, 1.95, 0.04), Color(0.7, 0.65, 0.54))   # Spriegel-Linien
	mb.cyl(Vector3(1.05, 0.95, 0.8), 0.45, 0.45, 0.8, Color(0.3, 0.3, 0.32), 10, 1)         # Tank
	for sx in [-1.2, 1.2]:
		for z in [-2.0, 0.0, 2.2]:
			mb.wheel(Vector3(sx, 0.62, z), 0.62, 0.46, dark, steel, 14)
	mb.box(Vector3(0, 1.1, -3.1), Vector3(2.3, 0.2, 0.1), Color(0.8, 0.2, 0.15))            # Heckbalken
	_mi(root, mb, 0.8, 0.1)
	parts["muzzle"] = _marker(root, Vector3(0, 1.8, 0), "Muzzle")

static func _aid_truck(root: Node3D, parts: Dictionary, team: int) -> void:
	var white := Color(0.92, 0.92, 0.9)
	var blue := Color(0.18, 0.4, 0.72)
	var dark := Color(0.1, 0.1, 0.1)
	var steel := Color(0.28, 0.28, 0.3)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.ao_floor = 0.3
	mb.jitter = 0.03
	mb.box(Vector3(0, 0.8, 0), Vector3(1.6, 0.2, 6.4), steel)
	mb.box(Vector3(0, 1.0, 0), Vector3(2.3, 0.25, 6.2), Color(0.25, 0.25, 0.27))
	mb.loft(Vector3(0, 1.55, 1.2), Vector2(2.2, 1.3), Vector3(0, 1.75, 3.0), Vector2(2.2, 1.7), white)      # Kabine
	mb.box(Vector3(0, 1.25, 3.2), Vector3(2.1, 0.7, 0.9), white * 0.96)
	mb.box(Vector3(0, 1.4, 3.66), Vector3(1.9, 0.5, 0.08), dark)
	_lamp(mb, Vector3(-0.8, 1.35, 3.7), 0.26)
	_lamp(mb, Vector3(0.8, 1.35, 3.7), 0.26)
	mb.box(Vector3(0, 2.05, 2.95), Vector3(2.0, 0.6, 0.06), Color(0.1, 0.14, 0.17))
	for sx in [-1, 1]:
		mb.box(Vector3(sx * 1.12, 2.0, 2.4), Vector3(0.05, 0.5, 1.0), Color(0.1, 0.14, 0.17))
		mb.box(Vector3(sx * 1.25, 1.9, 3.05), Vector3(0.16, 0.34, 0.14), dark)
	mb.box(Vector3(0, 2.62, 2.35), Vector3(2.0, 0.1, 1.5), white * 1.02)
	# Planenaufbau mit blauem Band und Kreuz
	mb.box(Vector3(0, 2.25, -1.0), Vector3(2.35, 2.0, 4.0), white)
	mb.box(Vector3(0, 3.3, -1.0), Vector3(2.15, 0.14, 3.8), white * 0.96)
	mb.box(Vector3(0, 1.6, -1.0), Vector3(2.4, 0.3, 4.05), blue)
	for sx in [-1.0, 1.0]:
		mb.box(Vector3(sx * 1.19, 2.45, -1.0), Vector3(0.04, 1.0, 0.18), blue)
		mb.box(Vector3(sx * 1.19, 2.45, -1.0), Vector3(0.04, 0.18, 1.0), blue)
	mb.box(Vector3(0, 2.25, -3.02), Vector3(2.0, 1.8, 0.06), white * 0.9)
	# Kisten auf der Ladefläche
	for i in range(3):
		mb.box(Vector3(-0.5 + i * 0.5, 3.45, -1.4 + (i % 2) * 0.6), Vector3(0.4, 0.3, 0.5), Color(0.55, 0.42, 0.25))
	for sx in [-1.2, 1.2]:
		for z in [-2.1, 0.0, 2.3]:
			mb.wheel(Vector3(sx, 0.62, z), 0.62, 0.46, dark, steel, 14)
	mb.box(Vector3(0, 1.1, -3.2), Vector3(2.3, 0.2, 0.1), Color(0.8, 0.2, 0.15))
	mb.box(Vector3(0, 3.5, 2.0), Vector3(0.04, 0.2, 0.7), U.team_color(team))                    # Fähnchen
	_mi(root, mb, 0.7, 0.1)
	parts["muzzle"] = _marker(root, Vector3(0, 1.8, 0), "Muzzle")

static func _fieldhosp(root: Node3D, parts: Dictionary, team: int) -> void:
	var white := Color(0.93, 0.93, 0.9)
	var blue := Color(0.18, 0.4, 0.72)
	var dark := Color(0.1, 0.1, 0.1)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.25
	mb.jitter = 0.03
	# Boden / Plane
	mb.box(Vector3(0, 0.05, 0), Vector3(9.0, 0.1, 9.0), Color(0.6, 0.57, 0.5))
	# Haupt-Zelt (Giebeldach) und zwei Nebenzelte
	for cfg in [[Vector3(0, 0, -1.2), 6.0, 5.6, 1.8, 1.3], [Vector3(-3.0, 0, 2.6), 3.2, 3.6, 1.4, 0.9], [Vector3(2.9, 0, 2.6), 3.2, 3.6, 1.4, 0.9]]:
		var c: Vector3 = cfg[0]
		var w: float = cfg[1]
		var l: float = cfg[2]
		var wall_h: float = cfg[3]
		var rise: float = cfg[4]
		mb.box(Vector3(c.x, wall_h * 0.5, c.z), Vector3(w, wall_h, l), white * 0.95)
		mb.gable(Vector3(c.x, wall_h, c.z), w + 0.4, l + 0.4, rise, white)
		mb.box(Vector3(c.x, 0.5, c.z + l * 0.5 + 0.03), Vector3(w, 0.5, 0.04), blue)
		mb.box(Vector3(c.x, wall_h * 0.45, c.z + l * 0.5 + 0.04), Vector3(0.9, wall_h * 0.85, 0.04), dark)
	# Kreuz am Haupt-Zelt und auf dem Dach
	mb.box(Vector3(0, 2.3, 1.64), Vector3(0.95, 0.3, 0.05), blue)
	mb.box(Vector3(0, 2.3, 1.64), Vector3(0.3, 0.95, 0.05), blue)
	mb.box(Vector3(0, 2.3, 1.67), Vector3(0.75, 0.15, 0.04), white)
	mb.box(Vector3(0, 2.3, 1.67), Vector3(0.15, 0.75, 0.04), white)
	# Mast mit Fahne, Generator, Wassertank, Kisten
	mb.cyl(Vector3(-3.9, 3.0, -3.8), 0.05, 0.05, 6.0, Color(0.75, 0.75, 0.78), 6)
	mb.box(Vector3(-3.3, 5.4, -3.8), Vector3(1.4, 0.8, 0.03), U.team_color(team))
	mb.box(Vector3(3.6, 0.6, -3.4), Vector3(1.2, 1.0, 0.8), Color(0.35, 0.4, 0.3))
	mb.cyl(Vector3(3.4, 0.9, -0.2), 0.7, 0.7, 1.4, Color(0.72, 0.75, 0.78), 12)
	for i in range(4):
		mb.box(Vector3(-3.6 + i * 0.6, 0.35, -3.6), Vector3(0.5, 0.5, 0.5), Color(0.55, 0.42, 0.25))
	_mi(root, mb, 0.9, 0.0)

static func _launcher(root: Node3D, parts: Dictionary, team: int) -> void:
	var col := Color(0.4, 0.42, 0.3)
	var dark := Color(0.1, 0.1, 0.1)
	var steel := Color(0.28, 0.28, 0.3)
	var tc := U.team_color(team)
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.35
	mb.ao_floor = 0.3
	mb.jitter = 0.04
	mb.box(Vector3(0, 0.8, 0), Vector3(1.6, 0.2, 6.5), steel)
	mb.box(Vector3(0, 1.0, 0), Vector3(2.3, 0.25, 6.4), Color(0.22, 0.22, 0.2))
	mb.box(Vector3(0, 1.75, 2.3), Vector3(2.2, 1.4, 1.7), col)
	mb.box(Vector3(0, 1.3, 3.1), Vector3(2.1, 0.7, 0.9), col * 0.95)
	mb.box(Vector3(0, 1.45, 3.57), Vector3(1.9, 0.5, 0.08), dark)
	_lamp(mb, Vector3(-0.8, 1.4, 3.6), 0.26)
	_lamp(mb, Vector3(0.8, 1.4, 3.6), 0.26)
	mb.box(Vector3(0, 2.05, 2.9), Vector3(2.0, 0.55, 0.06), Color(0.1, 0.14, 0.17))
	mb.box(Vector3(0, 2.5, 2.3), Vector3(2.0, 0.1, 1.5), col * 1.05)
	mb.cyl(Vector3(0, 2.6, 2.4), 0.012, 0.01, 1.4, dark, 4)
	for sx in [-1, 1]:
		mb.box(Vector3(sx * 1.12, 2.0, 2.3), Vector3(0.05, 0.5, 1.0), Color(0.1, 0.14, 0.17))
		mb.box(Vector3(sx * 1.25, 1.9, 3.0), Vector3(0.16, 0.34, 0.14), dark)
	mb.box(Vector3(0, 1.15, 2.1), Vector3(2.3, 0.15, 2.2), col * 0.8)
	mb.box(Vector3(0, 1.25, 0.0), Vector3(0.12, 0.12, 0.3), tc)
	mb.cyl(Vector3(1.15, 1.1, 0.8), 0.3, 0.3, 1.0, Color(0.3, 0.3, 0.3), 10, 2)               # Treibstoff
	for sx in [-1.2, 1.2]:
		for z in [-2.1, 0.0, 2.3]:
			mb.wheel(Vector3(sx, 0.62, z), 0.62, 0.46, dark, steel, 14)
	# Stuetzen hinten
	mb.beam(Vector3(-1.0, 1.0, -3.0), Vector3(-1.5, 0.1, -3.4), 0.12, steel)
	mb.beam(Vector3(1.0, 1.0, -3.0), Vector3(1.5, 0.1, -3.4), 0.12, steel)
	_mi(root, mb, 0.8, 0.1)
	var rack := Node3D.new()
	rack.position = Vector3(0, 1.15, -1.2)
	root.add_child(rack)
	var rb := MeshBuilder.new()
	rb.jitter = 0.04
	rb.box(Vector3(0, 0.12, 0), Vector3(2.1, 0.24, 3.4), Color(0.25, 0.25, 0.22))
	for iy in range(3):
		for ix in range(4):
			var px := -0.78 + ix * 0.52
			var py := 0.42 + iy * 0.5
			rb.cyl(Vector3(px, py, 0), 0.22, 0.22, 3.6, Color(0.3, 0.32, 0.27), 10, 2)
			rb.cyl(Vector3(px, py, 1.85), 0.2, 0.2, 0.06, dark, 10, 2)
			rb.cyl(Vector3(px, py, -1.8), 0.17, 0.17, 0.08, steel, 10, 2)
	for z in [-1.4, 0.0, 1.4]:                                                                  # Halterungen
		rb.box(Vector3(0, 0.95, z), Vector3(2.15, 0.08, 0.14), steel)
		rb.box(Vector3(-1.05, 0.7, z), Vector3(0.08, 1.0, 0.14), steel)
		rb.box(Vector3(1.05, 0.7, z), Vector3(0.08, 1.0, 0.14), steel)
	_mi(rack, rb, 0.7, 0.2)
	parts["rack"] = rack
	parts["muzzle"] = _marker(rack, Vector3(0, 0.7, 1.95), "Muzzle")

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
		"adf_fieldhosp": _fieldhosp(root, parts, team)
	_decorate(root, kind, team)
	root.set_meta("parts", parts)
	return root

static func _prop(root: Node3D, mesh_name: String, pos: Vector3, yaw_deg: float = 0.0, scl: float = 1.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Props.get_mesh(mesh_name)
	mi.position = pos
	mi.rotation_degrees.y = yaw_deg
	mi.scale = Vector3(scl, scl, scl)
	root.add_child(mi)

static func _ac_unit(db: MeshBuilder, p: Vector3) -> void:
	db.box(p + Vector3(0, 0.45, 0), Vector3(1.4, 0.9, 1.0), Color(0.72, 0.72, 0.7))
	db.cyl(p + Vector3(0, 0.92, 0), 0.4, 0.4, 0.06, Color(0.15, 0.15, 0.15), 10)
	db.box(p + Vector3(0, 0.3, 0.52), Vector3(1.2, 0.4, 0.04), Color(0.4, 0.4, 0.4))

static func _decorate(root: Node3D, kind: String, team: int) -> void:
	var db := MeshBuilder.new()
	db.ao_strength = 0.25
	db.jitter = 0.03
	var tc := U.team_color(team)
	var dark := Color(0.12, 0.12, 0.13)
	var steel := Color(0.3, 0.3, 0.32)
	match kind:
		"adf_hq":
			for i in range(11):
				db.box(Vector3(-6.0 + i * 1.2, 3.1, 6.17), Vector3(0.06, 2.9, 0.05), dark)
			db.box(Vector3(0, 2.2, 6.17), Vector3(12.5, 0.06, 0.05), dark)
			db.box(Vector3(0, 4.0, 6.17), Vector3(12.5, 0.06, 0.05), dark)
			_ac_unit(db, Vector3(-3.5, 6.0, -3.0))
			_ac_unit(db, Vector3(-1.0, 6.0, -3.2))
			_ac_unit(db, Vector3(2.5, 6.0, -2.4))
			for i in range(4):
				db.cyl(Vector3(4.0 + i * 0.5, 6.4, 1.0), 0.12, 0.12, 0.8, steel, 6)
			db.box(Vector3(0, 3.9, 7.5), Vector3(5.0, 0.16, 2.4), Color(0.6, 0.58, 0.52))        # Vordach
			for sx in [-2.2, 2.2]:
				db.cyl(Vector3(sx, 1.9, 8.5), 0.14, 0.14, 3.8, Color(0.7, 0.68, 0.6), 8)
			db.box(Vector3(0, 3.7, 8.7), Vector3(5.0, 0.2, 0.08), tc)
			db.box(Vector3(5.5, 1.1, 9.0), Vector3(2.0, 2.2, 1.6), Color(0.7, 0.66, 0.58))        # Wachhaus
			db.box(Vector3(5.5, 1.5, 9.82), Vector3(1.6, 0.8, 0.04), Color(0.1, 0.16, 0.22))
			db.box(Vector3(5.5, 2.3, 9.0), Vector3(2.3, 0.12, 1.9), Color(0.55, 0.52, 0.46))
			db.cyl(Vector3(9.0, 1.0, 1.0), 0.6, 0.6, 1.6, Color(0.3, 0.32, 0.25), 12)             # Tank
			db.box(Vector3(9.0, 0.7, -1.5), Vector3(1.6, 1.4, 1.2), Color(0.45, 0.47, 0.42))      # Generator
			for sx in [-7.9, 7.9]:
				db.cyl(Vector3(sx, 4.0, 5.8), 0.07, 0.05, 8.0, Color(0.75, 0.75, 0.78), 6)
				db.box(Vector3(sx, 8.0, 5.8), Vector3(0.5, 0.12, 0.3), Color(0.9, 0.88, 0.7))
			_prop(root, "sandbags", Vector3(-3.2, 0, 8.6), 0.0)
			_prop(root, "sandbags", Vector3(8.2, 0, 7.4), 90.0)
			_prop(root, "barrel", Vector3(-8.5, 0, 3.0), 20.0)
			_prop(root, "crate", Vector3(-9.0, 0, -2.0), 0.0)
		"adf_barracks":
			for i in range(3):
				var z := -2.9 + i * 2.9
				db.box(Vector3(-6.0, 1.3, z + 1.1), Vector3(0.9, 2.1, 0.06), Color(0.25, 0.22, 0.2))
				db.box(Vector3(6.55, 2.6, z), Vector3(0.05, 0.9, 1.2), Color(0.15, 0.2, 0.25))
				_ac_unit(db, Vector3(-4.5 + i * 4.0, 4.4, z - 0.2))
			for i in range(3):
				db.cyl(Vector3(-6.2, 4.7, -2.0 + i * 2.0), 0.1, 0.1, 0.8, steel, 6)
			db.box(Vector3(6.9, 0.5, 0.5), Vector3(0.9, 1.0, 1.0), Color(0.4, 0.42, 0.36))
			db.box(Vector3(0, 0.15, 5.3), Vector3(6.0, 0.3, 0.8), Color(0.55, 0.52, 0.46))    # Treppenabsatz
			_prop(root, "crate", Vector3(7.5, 0, -3.5), 15.0)
			_prop(root, "sandbags", Vector3(-8.0, 0, 5.0), 90.0)
			_prop(root, "barrel", Vector3(7.8, 0, 3.0), 0.0)
		"adf_factory":
			# Portalkran
			for sx in [-6.0, 6.0]:
				db.beam(Vector3(sx, 6.4, -4.5), Vector3(sx, 9.2, -4.5), 0.25, steel)
				db.beam(Vector3(sx, 6.4, 4.5), Vector3(sx, 9.2, 4.5), 0.25, steel)
			db.beam(Vector3(-6.0, 9.2, -4.5), Vector3(6.0, 9.2, -4.5), 0.3, Color(0.8, 0.65, 0.15))
			db.beam(Vector3(-6.0, 9.2, 4.5), Vector3(6.0, 9.2, 4.5), 0.3, Color(0.8, 0.65, 0.15))
			db.beam(Vector3(2.0, 9.2, -4.5), Vector3(2.0, 9.2, 4.5), 0.3, Color(0.8, 0.65, 0.15))
			db.beam(Vector3(2.0, 9.0, 0.0), Vector3(2.0, 7.0, 0.0), 0.06, dark)
			db.box(Vector3(2.0, 6.8, 0.0), Vector3(0.5, 0.3, 0.5), dark)
			for i in range(5):
				db.box(Vector3(-5.0 + i * 2.5, 7.6, 0.0), Vector3(1.4, 0.12, 4.0), Color(0.4, 0.55, 0.65))   # Oberlichter
			db.cyl(Vector3(-9.0, 1.5, -2.0), 1.0, 1.0, 3.0, Color(0.7, 0.7, 0.68), 14)            # Tanks
			db.cyl(Vector3(-9.0, 1.5, 1.5), 1.0, 1.0, 3.0, Color(0.7, 0.7, 0.68), 14)
			db.beam(Vector3(-8.0, 2.5, -2.0), Vector3(-8.0, 2.5, 1.5), 0.15, steel)
			for i in range(6):
				db.box(Vector3(-4.0 + i * 1.5, 0.45, 6.4), Vector3(0.9, 0.9, 0.9), Color(0.35 + i * 0.03, 0.4, 0.3))   # Kisten
			_prop(root, "barrel", Vector3(9.5, 0, 4.0), 0.0)
			_prop(root, "crate", Vector3(9.5, 0, -2.0), 40.0)
		"adf_airfield":
			db.box(Vector3(5.0, 0.25, 4.5), Vector3(2.6, 0.5, 5.0), Color(0.6, 0.55, 0.3))       # Tankwagen-Platz
			db.cyl(Vector3(5.0, 1.0, 4.5), 0.9, 0.9, 4.6, Color(0.7, 0.7, 0.68), 12, 2)
			for sx in [-6.6, 6.6]:
				for sz in [-6.6, 6.6]:
					db.cyl(Vector3(sx, 1.5, sz), 0.07, 0.05, 3.0, Color(0.75, 0.75, 0.78), 6)
					db.box(Vector3(sx, 3.0, sz), Vector3(0.4, 0.2, 0.4), Color(0.95, 0.9, 0.5))
			for i in range(12):
				var a := TAU * i / 12.0
				db.box(Vector3(cos(a) * 6.2, 0.14, sin(a) * 6.2), Vector3(0.3, 0.06, 0.3), Color(0.95, 0.8, 0.2))
			_prop(root, "barrel", Vector3(-6.5, 0, 6.0), 0.0)
		"adf_press":
			for i in range(8):
				db.box(Vector3(-3.5 + i * 1.0, 2.2, 3.62), Vector3(0.05, 1.5, 0.04), dark)
			_ac_unit(db, Vector3(-3.0, 4.2, 0.0))
			db.box(Vector3(-2.0, 1.8, 6.95), Vector3(0.9, 1.0, 0.1), Color(0.25, 0.25, 0.3))      # Teleprompter
			db.cyl(Vector3(-0.5, 0.9, 7.0), 0.04, 0.04, 1.8, dark, 5)                             # Mikrofon
			db.box(Vector3(-0.5, 1.8, 7.0), Vector3(0.12, 0.12, 0.1), dark)
			for i in range(3):
				db.beam(Vector3(2.0 + i * 0.4, 0.0, 8.4), Vector3(2.4 + i * 0.4, 1.6, 8.4), 0.05, steel)   # Stativ
				db.box(Vector3(2.4 + i * 0.4, 1.7, 8.4), Vector3(0.3, 0.25, 0.4), dark)               # Kameras
			_prop(root, "crate", Vector3(-4.5, 0, 5.5), 10.0)
		"adf_radar":
			for i in range(4):
				var y := 2.8 + i * 1.0
				db.beam(Vector3(-0.8, y, -0.8), Vector3(0.8, y, 0.8), 0.06, steel)
				db.beam(Vector3(0.8, y, -0.8), Vector3(-0.8, y, 0.8), 0.06, steel)
			for sx in [-0.8, 0.8]:
				for sz in [-0.8, 0.8]:
					db.beam(Vector3(sx, 2.4, sz), Vector3(sx * 0.5, 6.0, sz * 0.5), 0.1, steel)
			_prop(root, "sandbags", Vector3(0, 0, 4.4), 0.0)
		"adf_tower":
			db.box(Vector3(0, 5.2, 1.4), Vector3(0.2, 1.0, 0.04), Color(0.3, 0.3, 0.3))
			for i in range(6):
				db.box(Vector3(0, 1.0 + i * 0.9, 1.35), Vector3(1.0, 0.06, 0.05), steel)       # Leiter
			db.cyl(Vector3(1.9, 8.2, 1.9), 0.04, 0.03, 2.5, dark, 4)
			db.box(Vector3(0.0, 8.0, 0.0), Vector3(1.4, 0.05, 1.4), tc)
			_prop(root, "sandbags", Vector3(0, 0, 3.2), 0.0, 0.8)
	var mi := MeshInstance3D.new()
	mi.mesh = db.build(Gfx.vcol_mat(0.8, 0.1))
	root.add_child(mi)

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
