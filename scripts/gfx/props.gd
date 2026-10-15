class_name Props
extends RefCounted
## Prozedurale Props (Palmen, Autos, Laternen, Marktstaende, Betonbarrieren ...) als gecachte Meshes.

static var _meshes: Dictionary = {}

static func get_mesh(name: String) -> ArrayMesh:
	if _meshes.has(name):
		return _meshes[name]
	var m: ArrayMesh = null
	match name:
		"car": m = _car()
		"car_wreck": m = _car(true)
		"lamp": m = _lamp()
		"pole": m = _pole()
		"stall_red": m = _stall(Color(0.78, 0.2, 0.16))
		"stall_green": m = _stall(Color(0.2, 0.55, 0.3))
		"stall_orange": m = _stall(Color(0.92, 0.55, 0.12))
		"stall_blue": m = _stall(Color(0.2, 0.4, 0.75))
		"barrier": m = _barrier()
		"sandbags": m = _sandbags()
		"crate": m = _crates()
		"barrel": m = _barrels()
		"watertank": m = _watertank()
		"dish": m = _dish()
		"solar": m = _solar()
		"hesco": m = _hesco()
		"rubble": m = _rubble()
		"dune_bush": m = _bush()
		"bench": m = _bench()
		"bin": m = _bin()
		"signpost": m = _signpost()
		"planter": m = _planter()
		"ac_wall": m = _ac_wall()
		"tent": m = _tent(false)
		"tent_big": m = _tent(true)
		"goal": m = _goal()
		"obelisk": m = _obelisk()
		"tree": m = _tree()
		"container": m = _container()
		"bus": m = _bus()
		"kiosk": m = _kiosk()
		"tribune": m = _tribune()
		"water_tank_ground": m = _ground_tank()
		"flagpole": m = _flagpole()
		_:
			m = ArrayMesh.new()
	_meshes[name] = m
	return m

# ------------------------------------------------------------------ Palme (Stamm + Wedel)
static func palm_mesh(variant: int = 0) -> ArrayMesh:
	var key := "palm_%d" % variant
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + variant * 77
	var height := 6.5 + rng.randf() * 2.5
	var lean := Vector2(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.9, 0.9))
	# ---- Stamm
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.35
	var segs := 7
	var prev := Vector3.ZERO
	var top := Vector3.ZERO
	for i in range(segs):
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var p0 := Vector3(lean.x * t0 * t0, height * t0, lean.y * t0 * t0)
		var p1 := Vector3(lean.x * t1 * t1, height * t1, lean.y * t1 * t1)
		var r0 := 0.34 - 0.14 * t0
		var r1 := 0.34 - 0.14 * t1
		var tone := 0.0 if i % 2 == 0 else 0.05
		var col := Color(0.36 + tone, 0.27 + tone, 0.19 + tone * 0.6)
		var mid := (p0 + p1) * 0.5
		var dir := (p1 - p0)
		var tilt_x := rad_to_deg(atan2(dir.z, dir.y))
		var tilt_z := rad_to_deg(-atan2(dir.x, dir.y))
		mb.set_xf(mid, Vector3(tilt_x, 0, tilt_z))
		mb.cyl(Vector3.ZERO, r0, r1, dir.length() * 1.02, col, 7)
		prev = p1
		top = p1
	mb.reset_xf()
	# Kronenansatz
	mb.sphere(top + Vector3(0, 0.1, 0), 0.5, Color(0.3, 0.24, 0.15), Vector3(1, 0.8, 1), 4, 7)
	# Datteln
	if variant % 2 == 0:
		mb.sphere(top + Vector3(0.25, -0.2, 0.1), 0.22, Color(0.55, 0.3, 0.1), Vector3.ONE, 3, 6)
	var trunk := mb.build(Gfx.vcol_mat(0.95, 0.0))

	# ---- Wedel
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_fronds := 13
	for f in range(n_fronds):
		var ang := TAU * float(f) / n_fronds + rng.randf_range(-0.2, 0.2)
		var up_bias := rng.randf_range(0.0, 0.5) if f % 3 == 0 else rng.randf_range(-0.2, 0.25)
		var length := rng.randf_range(3.6, 4.8) if f % 3 != 0 else rng.randf_range(2.2, 3.2)
		var width := rng.randf_range(0.9, 1.2)
		var dir := Vector3(cos(ang), up_bias, sin(ang)).normalized()
		var side := Vector3(-dir.z, 0, dir.x).normalized()
		var steps := 7
		for s in range(steps):
			var t0 := float(s) / steps
			var t1 := float(s + 1) / steps
			var sp0 := top + dir * (length * t0) + Vector3(0, -length * 0.55 * t0 * t0, 0)
			var sp1 := top + dir * (length * t1) + Vector3(0, -length * 0.55 * t1 * t1, 0)
			var w0 := width * (0.25 + 0.75 * sin(PI * clampf(t0 * 0.9 + 0.1, 0.0, 1.0))) * (1.0 - 0.3 * t0)
			var w1 := width * (0.25 + 0.75 * sin(PI * clampf(t1 * 0.9 + 0.1, 0.0, 1.0))) * (1.0 - 0.3 * t1)
			var c0 := Color(0.2, 0.36, 0.12).lerp(Color(0.5, 0.58, 0.2), t0)
			var c1 := Color(0.2, 0.36, 0.12).lerp(Color(0.5, 0.58, 0.2), t1)
			var a := sp0 - side * w0
			var b := sp0 + side * w0
			var c := sp1 + side * w1
			var d := sp1 - side * w1
			var nrm := Vector3(0, 1, 0)
			# Vorder- und Rueckseite
			st.set_normal(nrm); st.set_color(c0); st.set_uv(Vector2(0, t0)); st.add_vertex(a)
			st.set_normal(nrm); st.set_color(c1); st.set_uv(Vector2(0, t1)); st.add_vertex(d)
			st.set_normal(nrm); st.set_color(c1); st.set_uv(Vector2(1, t1)); st.add_vertex(c)
			st.set_normal(nrm); st.set_color(c0); st.set_uv(Vector2(0, t0)); st.add_vertex(a)
			st.set_normal(nrm); st.set_color(c1); st.set_uv(Vector2(1, t1)); st.add_vertex(c)
			st.set_normal(nrm); st.set_color(c0); st.set_uv(Vector2(1, t0)); st.add_vertex(b)
	var fronds := st.commit()
	var mesh := ArrayMesh.new()
	var trunk_arrays := trunk.surface_get_arrays(0)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk_arrays)
	mesh.surface_set_material(0, Gfx.vcol_mat(0.95, 0.0))
	var f_arrays := fronds.surface_get_arrays(0)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, f_arrays)
	var fm := ShaderMaterial.new()
	fm.shader = load("res://scripts/gfx/shaders/foliage.gdshader")
	mesh.surface_set_material(1, fm)
	_meshes[key] = mesh
	return mesh

# ------------------------------------------------------------------ Autos
static func _car(wreck: bool = false) -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	var body := Color(1, 1, 1) if not wreck else Color(0.22, 0.17, 0.14)
	var glass := Color(0.12, 0.16, 0.2) if not wreck else Color(0.05, 0.05, 0.05)
	var dark := Color(0.08, 0.08, 0.08)
	mb.box(Vector3(0, 0.62, 0), Vector3(1.75, 0.62, 4.1), body)
	mb.box(Vector3(0, 1.15, -0.1), Vector3(1.6, 0.5, 2.2), glass, body)
	mb.box(Vector3(0, 1.17, -0.1), Vector3(1.66, 0.12, 2.1), body)
	for sx in [-0.88, 0.88]:
		for sz in [-1.3, 1.3]:
			mb.cyl(Vector3(sx, 0.36, sz), 0.38, 0.38, 0.28, dark, 8, 1)
	mb.box(Vector3(0, 0.45, 2.05), Vector3(1.7, 0.2, 0.15), dark)
	mb.box(Vector3(0, 0.45, -2.05), Vector3(1.7, 0.2, 0.15), dark)
	return mb.build(Gfx.vcol_mat(0.55, 0.3))

static func _lamp() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var steel := Color(0.28, 0.3, 0.32)
	mb.cyl(Vector3(0, 3.6, 0), 0.12, 0.08, 7.2, steel, 6)
	mb.box_t(Vector3(0.7, 7.1, 0), Vector3(1.8, 0.1, 0.12), steel, Vector3(0, 0, 8))
	mb.box(Vector3(1.5, 6.95, 0), Vector3(0.7, 0.14, 0.3), Color(0.9, 0.88, 0.7))
	return mb.build(Gfx.vcol_mat(0.6, 0.4))

static func _pole() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var wood := Color(0.34, 0.25, 0.17)
	mb.cyl(Vector3(0, 4.5, 0), 0.2, 0.15, 9.0, wood, 6)
	mb.box(Vector3(0, 8.4, 0), Vector3(2.8, 0.14, 0.14), wood)
	mb.box(Vector3(0, 7.7, 0), Vector3(2.2, 0.12, 0.12), wood)
	for x in [-1.3, 0.0, 1.3]:
		mb.cyl(Vector3(x, 8.6, 0), 0.07, 0.07, 0.25, Color(0.8, 0.8, 0.75), 5)
	return mb.build(Gfx.vcol_mat(0.9, 0.0))

static func _stall(tarp: Color) -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.2
	var wood := Color(0.4, 0.3, 0.2)
	for sx in [-1.5, 1.5]:
		for sz in [-1.0, 1.0]:
			mb.cyl(Vector3(sx, 1.2, sz), 0.07, 0.07, 2.4, wood, 5)
	mb.box(Vector3(0, 0.9, 0.2), Vector3(3.2, 0.12, 1.2), wood)
	mb.box(Vector3(0, 0.45, 0.2), Vector3(3.0, 0.9, 1.0), wood * 0.8)
	# Tuch (leicht geneigt)
	mb.box_t(Vector3(0, 2.45, 0), Vector3(3.6, 0.1, 2.6), tarp, Vector3(8, 0, 0))
	mb.box_t(Vector3(0, 2.6, -0.3), Vector3(3.6, 0.1, 1.2), tarp * 0.85, Vector3(-18, 0, 0))
	# Waren
	for i in range(5):
		var c: Color = [Color(0.85, 0.2, 0.1), Color(0.95, 0.75, 0.15), Color(0.3, 0.6, 0.2), Color(0.9, 0.5, 0.1), Color(0.6, 0.15, 0.4)][i]
		mb.sphere(Vector3(-1.2 + i * 0.6, 1.1, 0.2), 0.2, c, Vector3.ONE, 3, 6)
	return mb.build(Gfx.vcol_mat(0.9, 0.0))

static func _barrier() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	var c := Color(0.62, 0.6, 0.56)
	mb.box(Vector3(0, 0.35, 0), Vector3(0.9, 0.7, 3.2), c)
	mb.box(Vector3(0, 1.05, 0), Vector3(0.5, 0.7, 3.2), c * 0.95)
	return mb.build(Gfx.vcol_mat(0.95, 0.0))

static func _sandbags() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.35
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for row in range(3):
		var n := 5 - row
		for i in range(n):
			var c := Color(0.62, 0.55, 0.38) * rng.randf_range(0.9, 1.08)
			var x := (i - (n - 1) * 0.5) * 0.95
			mb.sphere(Vector3(x, 0.22 + row * 0.38, 0), 0.5, c, Vector3(1.0, 0.45, 0.62), 4, 7)
	return mb.build(Gfx.vcol_mat(1.0, 0.0))

static func _crates() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.box(Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), Color(0.5, 0.38, 0.22))
	mb.box_t(Vector3(0.85, 0.35, 0.1), Vector3(0.7, 0.7, 0.7), Color(0.45, 0.4, 0.25), Vector3(0, 20, 0))
	mb.box_t(Vector3(0.3, 1.15, 0.0), Vector3(0.65, 0.65, 0.65), Color(0.55, 0.42, 0.25), Vector3(0, -12, 0))
	return mb.build(Gfx.vcol_mat(0.95, 0.0))

static func _barrels() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.cyl(Vector3(0, 0.5, 0), 0.38, 0.38, 1.0, Color(0.2, 0.35, 0.5), 8)
	mb.cyl(Vector3(0.85, 0.5, 0.2), 0.38, 0.38, 1.0, Color(0.6, 0.2, 0.12), 8)
	mb.cyl(Vector3(0.3, 0.5, 0.9), 0.38, 0.38, 1.0, Color(0.45, 0.45, 0.4), 8)
	return mb.build(Gfx.vcol_mat(0.6, 0.3))

static func _watertank() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var steel := Color(0.25, 0.25, 0.27)
	for sx in [-0.6, 0.6]:
		for sz in [-0.6, 0.6]:
			mb.box(Vector3(sx, 0.35, sz), Vector3(0.1, 0.7, 0.1), steel)
	mb.cyl(Vector3(0, 1.3, 0), 0.95, 0.95, 1.2, Color(0.1, 0.1, 0.12), 12)
	mb.cyl(Vector3(0, 1.95, 0), 0.8, 0.5, 0.15, Color(0.1, 0.1, 0.12), 12)
	return mb.build(Gfx.vcol_mat(0.5, 0.4))

static func _dish() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.cyl(Vector3(0, 0.3, 0), 0.05, 0.05, 0.6, Color(0.5, 0.5, 0.5), 5)
	mb.set_xf(Vector3(0, 0.8, 0), Vector3(-40, 0, 0))
	mb.cyl(Vector3.ZERO, 0.15, 0.55, 0.22, Color(0.85, 0.85, 0.82), 10)
	mb.reset_xf()
	return mb.build(Gfx.vcol_mat(0.5, 0.2))

static func _solar() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.box_t(Vector3(0, 0.55, 0), Vector3(1.6, 0.08, 1.1), Color(0.1, 0.16, 0.3), Vector3(-30, 0, 0))
	mb.cyl(Vector3(0, 0.95, -0.25), 0.28, 0.28, 0.8, Color(0.85, 0.85, 0.85), 8, 1)
	mb.box(Vector3(0, 0.15, 0.2), Vector3(1.4, 0.3, 0.06), Color(0.4, 0.4, 0.4))
	return mb.build(Gfx.vcol_mat(0.4, 0.3))

static func _hesco() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.box(Vector3(0, 1.1, 0), Vector3(1.4, 2.2, 3.0), Color(0.6, 0.55, 0.4))
	mb.box(Vector3(0, 2.25, 0), Vector3(1.45, 0.1, 3.05), Color(0.45, 0.42, 0.34))
	return mb.build(Gfx.vcol_mat(1.0, 0.0))

static func _rubble() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.4
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# Schutthaufen: flacher Huegel + viele kleine Brocken
	mb.sphere(Vector3(0, 0.0, 0), 4.2, Color(0.5, 0.45, 0.38), Vector3(1.0, 0.3, 1.0), 4, 12)
	mb.sphere(Vector3(0.6, 0.0, -0.4), 2.6, Color(0.42, 0.37, 0.32), Vector3(1.0, 0.45, 1.0), 4, 10)
	for i in range(34):
		var s := rng.randf_range(0.3, 1.25)
		var c := Color(0.58, 0.52, 0.44) * rng.randf_range(0.6, 1.1)
		if i % 5 == 0:
			c = Color(0.3, 0.26, 0.23)
		elif i % 7 == 0:
			c = Color(0.62, 0.34, 0.24)   # Ziegel
		var ang := rng.randf() * TAU
		var rr := sqrt(rng.randf()) * 3.6
		var p := Vector3(cos(ang) * rr, 0.0, sin(ang) * rr)
		var h := (1.0 - rr / 4.2) * 1.1
		mb.box_t(p + Vector3(0, h + s * 0.15, 0), Vector3(s, s * 0.55, s * rng.randf_range(0.6, 1.2)), c, Vector3(rng.randf_range(-30, 30), rng.randf_range(0, 180), rng.randf_range(-30, 30)))
	# Betonplatten und Armiereisen
	for i in range(5):
		var ang2 := rng.randf() * TAU
		var rr2 := rng.randf() * 2.4
		mb.box_t(Vector3(cos(ang2) * rr2, 0.7, sin(ang2) * rr2), Vector3(rng.randf_range(1.2, 2.2), 0.18, rng.randf_range(0.9, 1.6)), Color(0.6, 0.58, 0.54), Vector3(rng.randf_range(-22, 22), rng.randf_range(0, 180), rng.randf_range(-22, 22)))
	for i in range(6):
		mb.box_t(Vector3(rng.randf_range(-2.2, 2.2), 1.1, rng.randf_range(-2.2, 2.2)), Vector3(0.05, 1.8, 0.05), Color(0.25, 0.2, 0.18), Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-40, 40)))
	return mb.build(Gfx.vcol_mat(1.0, 0.0))

static func _bench() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.jitter = 0.04
	var wood := Color(0.45, 0.32, 0.2)
	var steel := Color(0.2, 0.2, 0.22)
	for i in range(4):
		mb.box(Vector3(0, 0.5, -0.2 + i * 0.14), Vector3(1.8, 0.05, 0.11), wood)
	for i in range(3):
		mb.box(Vector3(0, 0.85 + i * 0.13, -0.38), Vector3(1.8, 0.1, 0.04), wood)
	for sx in [-0.8, 0.8]:
		mb.box(Vector3(sx, 0.25, 0.0), Vector3(0.06, 0.5, 0.5), steel)
		mb.box(Vector3(sx, 0.65, -0.38), Vector3(0.06, 0.8, 0.06), steel)
	return mb.build(Gfx.vcol_mat(0.9, 0.0))

static func _bin() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.cyl(Vector3(0, 0.45, 0), 0.34, 0.3, 0.9, Color(0.2, 0.32, 0.22), 10)
	mb.cyl(Vector3(0, 0.93, 0), 0.36, 0.36, 0.06, Color(0.15, 0.25, 0.17), 10)
	mb.box(Vector3(0.0, 0.6, 0.3), Vector3(0.14, 0.14, 0.02), Color(0.9, 0.9, 0.9))
	return mb.build(Gfx.vcol_mat(0.7, 0.2))

static func _signpost() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.cyl(Vector3(0, 1.4, 0), 0.04, 0.04, 2.8, Color(0.3, 0.3, 0.32), 6)
	mb.cyl(Vector3(0.0, 2.55, 0.06), 0.4, 0.4, 0.04, Color(0.85, 0.15, 0.12), 10, 2)
	mb.cyl(Vector3(0.0, 2.55, 0.09), 0.3, 0.3, 0.03, Color(0.95, 0.95, 0.95), 10, 2)
	mb.box(Vector3(0.0, 2.55, 0.12), Vector3(0.5, 0.1, 0.02), Color(0.85, 0.15, 0.12))
	mb.box(Vector3(0.6, 2.05, 0.06), Vector3(1.0, 0.3, 0.04), Color(0.15, 0.4, 0.2))
	return mb.build(Gfx.vcol_mat(0.6, 0.2))

static func _planter() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.box(Vector3(0, 0.3, 0), Vector3(1.4, 0.6, 0.8), Color(0.62, 0.58, 0.5))
	mb.box(Vector3(0, 0.55, 0), Vector3(1.2, 0.1, 0.6), Color(0.3, 0.2, 0.12))
	for i in range(6):
		mb.sphere(Vector3(-0.45 + i * 0.18, 0.78, (i % 2) * 0.12 - 0.06), 0.2, Color(0.25, 0.45, 0.2), Vector3(1, 0.8, 1), 3, 6)
	return mb.build(Gfx.vcol_mat(0.9, 0.0))

static func _ac_wall() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.box(Vector3(0, 0.3, 0.2), Vector3(0.8, 0.5, 0.4), Color(0.75, 0.75, 0.72))
	mb.cyl(Vector3(0, 0.3, 0.42), 0.2, 0.2, 0.04, Color(0.15, 0.15, 0.15), 8, 2)
	return mb.build(Gfx.vcol_mat(0.6, 0.2))

static func _bush() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(5):
		var c := Color(0.4, 0.42, 0.2) * rng.randf_range(0.8, 1.15)
		mb.sphere(Vector3(rng.randf_range(-0.5, 0.5), 0.35, rng.randf_range(-0.5, 0.5)), rng.randf_range(0.4, 0.7), c, Vector3(1, 0.7, 1), 3, 6)
	return mb.build(Gfx.vcol_mat(1.0, 0.0))

# ------------------------------------------------------------------ Plaetze, Park, Lager
static func _tent(big: bool) -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.25
	mb.jitter = 0.03
	var w := 4.2 if big else 2.8
	var l := 5.6 if big else 3.6
	var wall_h := 1.3 if big else 1.0
	var rise := 1.1 if big else 0.8
	var cloth := Color(0.86, 0.84, 0.76)
	var stripe := Color(0.2, 0.38, 0.62)
	mb.box(Vector3(0, wall_h * 0.5, 0), Vector3(w, wall_h, l), cloth * 0.93)
	mb.gable(Vector3(0, wall_h, 0), w + 0.3, l + 0.3, rise, cloth)
	# Blaues Band (Hilfswerk) und Eingang
	mb.box(Vector3(0, 0.2, l * 0.5 + 0.03), Vector3(w, 0.18, 0.03), stripe)
	mb.box(Vector3(0, wall_h * 0.5, l * 0.5 + 0.03), Vector3(0.8, wall_h * 0.95, 0.03), Color(0.15, 0.13, 0.1))
	# Abspannleinen / Heringe
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			mb.cyl(Vector3(sx * (w * 0.5 + 0.5), 0.15, sz * (l * 0.5)), 0.03, 0.03, 0.3, Color(0.4, 0.4, 0.4), 4)
	return mb.build(Gfx.vcol_mat(0.95, 0.0))

static func _goal() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var white := Color(0.92, 0.92, 0.9)
	var net := Color(0.8, 0.8, 0.8)
	mb.box(Vector3(-3.6, 1.2, 0), Vector3(0.12, 2.4, 0.12), white)
	mb.box(Vector3(3.6, 1.2, 0), Vector3(0.12, 2.4, 0.12), white)
	mb.box(Vector3(0, 2.4, 0), Vector3(7.3, 0.12, 0.12), white)
	for sx in [-3.6, 3.6]:
		mb.beam(Vector3(sx, 2.4, 0), Vector3(sx, 0.05, -1.8), 0.07, white)
	mb.beam(Vector3(-3.6, 2.4, 0), Vector3(-3.6, 2.35, -1.8), 0.05, white)
	mb.box(Vector3(0, 1.2, -1.8), Vector3(7.2, 2.3, 0.02), net)
	return mb.build(Gfx.vcol_mat(0.7, 0.1))

static func _obelisk() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	var stone := Color(0.78, 0.74, 0.66)
	mb.box(Vector3(0, 0.25, 0), Vector3(5.0, 0.5, 5.0), stone * 0.92)
	mb.box(Vector3(0, 0.75, 0), Vector3(4.0, 0.5, 4.0), stone * 0.96)
	mb.box(Vector3(0, 1.4, 0), Vector3(2.4, 0.9, 2.4), stone)
	mb.cyl(Vector3(0, 6.2, 0), 1.0, 0.55, 9.0, stone, 4)
	mb.cyl(Vector3(0, 11.0, 0), 0.55, 0.0, 0.9, Color(0.82, 0.7, 0.35), 4)
	# Relief-Band
	mb.box(Vector3(0, 2.2, 1.21), Vector3(1.5, 0.5, 0.04), Color(0.55, 0.5, 0.42))
	return mb.build(Gfx.vcol_mat(0.85, 0.1))

static func _tree() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	mb.cyl(Vector3(0, 1.3, 0), 0.32, 0.22, 2.6, Color(0.36, 0.28, 0.2), 7)
	mb.beam(Vector3(0, 2.3, 0), Vector3(0.9, 3.4, 0.3), 0.18, Color(0.36, 0.28, 0.2))
	mb.beam(Vector3(0, 2.4, 0), Vector3(-0.8, 3.3, -0.4), 0.16, Color(0.36, 0.28, 0.2))
	for i in range(9):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.6, 2.0)
		var c := Color(0.32, 0.44, 0.2) * rng.randf_range(0.8, 1.2)
		mb.sphere(Vector3(cos(a) * r, 3.6 + rng.randf_range(-0.2, 1.0), sin(a) * r), rng.randf_range(0.9, 1.5), c, Vector3(1, 0.7, 1), 4, 7)
	return mb.build(Gfx.vcol_mat(1.0, 0.0))

static func _container() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.25
	var col := Color(0.55, 0.22, 0.15)
	mb.box(Vector3(0, 1.3, 0), Vector3(2.4, 2.6, 6.0), col)
	for i in range(9):
		mb.box(Vector3(-1.21, 1.3, -2.6 + i * 0.65), Vector3(0.05, 2.5, 0.12), col * 0.8)
		mb.box(Vector3(1.21, 1.3, -2.6 + i * 0.65), Vector3(0.05, 2.5, 0.12), col * 0.8)
	mb.box(Vector3(0, 1.3, 3.01), Vector3(2.3, 2.5, 0.03), col * 0.7)
	mb.box(Vector3(0.5, 1.3, 3.04), Vector3(0.06, 2.3, 0.04), Color(0.5, 0.5, 0.5))
	mb.box(Vector3(-0.5, 1.3, 3.04), Vector3(0.06, 2.3, 0.04), Color(0.5, 0.5, 0.5))
	return mb.build(Gfx.vcol_mat(0.8, 0.3))

static func _bus() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	var body := Color(0.85, 0.8, 0.6)
	var glass := Color(0.12, 0.16, 0.2)
	var dark := Color(0.08, 0.08, 0.08)
	mb.box(Vector3(0, 1.7, 0), Vector3(2.5, 2.6, 10.5), body)
	mb.box(Vector3(0, 2.1, 0), Vector3(2.56, 0.9, 9.8), glass)
	mb.box(Vector3(0, 1.0, 0), Vector3(2.56, 0.25, 10.4), Color(0.8, 0.2, 0.15))
	mb.box(Vector3(0, 2.1, 5.27), Vector3(2.3, 1.1, 0.05), glass)
	mb.box(Vector3(0, 3.05, 0), Vector3(2.2, 0.12, 9.6), body * 0.9)
	for sx in [-1.25, 1.25]:
		for sz in [-3.4, 3.4]:
			mb.cyl(Vector3(sx, 0.5, sz), 0.5, 0.5, 0.3, dark, 10, 1)
	return mb.build(Gfx.vcol_mat(0.6, 0.3))

static func _kiosk() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.box(Vector3(0, 1.2, 0), Vector3(2.6, 2.4, 2.4), Color(0.8, 0.74, 0.58))
	mb.box(Vector3(0, 1.4, 1.22), Vector3(1.8, 0.9, 0.04), Color(0.1, 0.14, 0.18))
	mb.box_t(Vector3(0, 2.2, 1.5), Vector3(3.0, 0.08, 1.4), Color(0.75, 0.2, 0.15), Vector3(10, 0, 0))
	mb.box(Vector3(0, 2.5, 0), Vector3(2.8, 0.14, 2.6), Color(0.7, 0.66, 0.55))
	mb.box(Vector3(0, 0.95, 1.4), Vector3(2.2, 0.08, 0.5), Color(0.5, 0.38, 0.25))
	return mb.build(Gfx.vcol_mat(0.9, 0.0))

static func _tribune() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	var conc := Color(0.66, 0.64, 0.6)
	for i in range(5):
		mb.box(Vector3(0, 0.3 + i * 0.45, -i * 0.9), Vector3(14.0, 0.6 + i * 0.45, 0.9), conc)
		for k in range(7):
			var c: Color = [Color(0.2, 0.4, 0.7), Color(0.8, 0.25, 0.2), Color(0.9, 0.8, 0.3)][(i + k) % 3]
			mb.box(Vector3(-5.6 + k * 1.9, 0.9 + i * 0.45, -i * 0.9 + 0.1), Vector3(0.6, 0.12, 0.35), c)
	mb.box(Vector3(0, 3.6, -3.8), Vector3(14.4, 0.15, 3.2), Color(0.35, 0.36, 0.4))
	for sx in [-6.8, 6.8]:
		mb.box(Vector3(sx, 1.8, -4.8), Vector3(0.15, 3.6, 0.15), Color(0.3, 0.3, 0.32))
	return mb.build(Gfx.vcol_mat(0.9, 0.1))

static func _ground_tank() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.cyl(Vector3(0, 1.1, 0), 1.4, 1.4, 2.2, Color(0.75, 0.78, 0.8), 14)
	mb.cyl(Vector3(0, 2.25, 0), 1.3, 0.4, 0.2, Color(0.7, 0.72, 0.74), 14)
	mb.box(Vector3(0, 0.1, 1.5), Vector3(1.4, 0.2, 1.0), Color(0.5, 0.5, 0.5))
	mb.cyl(Vector3(0, 0.55, 1.5), 0.05, 0.05, 1.0, Color(0.2, 0.3, 0.6), 5)
	return mb.build(Gfx.vcol_mat(0.5, 0.4))

static func _flagpole() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.cyl(Vector3(0, 4.5, 0), 0.07, 0.05, 9.0, Color(0.75, 0.75, 0.78), 6)
	mb.sphere(Vector3(0, 9.05, 0), 0.12, Color(0.85, 0.7, 0.3), Vector3.ONE, 3, 6)
	mb.box(Vector3(0.9, 8.2, 0), Vector3(1.8, 1.1, 0.03), Color(0.9, 0.9, 0.92))
	mb.box(Vector3(0.9, 8.2, 0), Vector3(1.8, 0.37, 0.04), Color(0.2, 0.45, 0.75))
	return mb.build(Gfx.vcol_mat(0.7, 0.2))
