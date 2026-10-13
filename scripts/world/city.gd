class_name City
extends Node3D
## Prozedurale nahoestliche Stadt "Qadira": Strassen, Bloecke, Gebaeude, Props, Gelaende, Nav-Daten.

const HALF := 100.0
const MASK_SIZE := 1024
const SCORCH_SIZE := 512

# ---- Strassen (Mittellinie, Breite, Ausdehnung)
const V_ROADS := [
	{"x": -80.0, "w": 6.0, "z0": -96.0, "z1": 36.0, "type": "street"},
	{"x": -42.0, "w": 10.0, "z0": -96.0, "z1": 96.0, "type": "main"},
	{"x": -4.0, "w": 7.0, "z0": -96.0, "z1": 96.0, "type": "street"},
	{"x": 34.0, "w": 10.0, "z0": -96.0, "z1": 96.0, "type": "main"},
	{"x": 72.0, "w": 6.0, "z0": -96.0, "z1": 96.0, "type": "street"},
]
const H_ROADS := [
	{"z": -74.0, "w": 6.0, "x0": -96.0, "x1": 96.0, "type": "street"},
	{"z": -36.0, "w": 7.0, "x0": -96.0, "x1": 96.0, "type": "street"},
	{"z": 2.0, "w": 12.0, "x0": -96.0, "x1": 96.0, "type": "main"},
	{"z": 40.0, "w": 8.0, "x0": -96.0, "x1": 96.0, "type": "street"},
	{"z": 78.0, "w": 6.0, "x0": -37.0, "x1": 96.0, "type": "street"},
]
const BASE_RECT := Rect2(-94.0, 46.0, 47.0, 48.0)

const PALETTE := [
	Color(0.85, 0.75, 0.59), Color(0.79, 0.67, 0.5), Color(0.91, 0.85, 0.72), Color(0.73, 0.58, 0.44),
	Color(0.87, 0.81, 0.69), Color(0.72, 0.69, 0.62), Color(0.82, 0.56, 0.4), Color(0.92, 0.9, 0.84),
	Color(0.66, 0.72, 0.68), Color(0.8, 0.72, 0.6),
]
const ACCENTS := [Color(0.16, 0.42, 0.5), Color(0.35, 0.22, 0.14), Color(0.2, 0.4, 0.22), Color(0.2, 0.3, 0.55), Color(0.45, 0.15, 0.12)]
const AWNINGS := [Color(0.75, 0.2, 0.15), Color(0.2, 0.5, 0.28), Color(0.9, 0.55, 0.12), Color(0.2, 0.38, 0.7), Color(0.6, 0.2, 0.5)]

var rng := RandomNumberGenerator.new()
var nav: Nav

var roads: Array = []          # {rect: Rect2, type: String}
var blocks: Array = []         # {rect, zone, xi, zi}
var buildings: Array = []      # Dictionaries (siehe _add_building)
var civ_spots: Array = []      # Vector3: Spaziergang-Ziele im Freien
var plaza_rect := Rect2()
var hospital_pos := Vector3.ZERO
var school_pos := Vector3.ZERO
var wreck_spots: Array = []
var sandbag_spots: Array = []  # Vector3 + yaw: Stellungen der Rebellen
var spawn_edges: Array = []

var mask_img: Image
var mask_tex: ImageTexture
var scorch_img: Image
var scorch_tex: ImageTexture
var ground_mat: ShaderMaterial
var _scorch_dirty := false
var _batches: Dictionary = {}   # mesh name -> {mesh, xforms[], colors[]}
var _next_bid := 0
var palm_xforms: Array = []
var sun_dir := Vector3(-0.5, -0.8, -0.35).normalized()

func generate(seed_value: int, nav_ref: Nav) -> void:
	rng.seed = seed_value
	nav = nav_ref
	_define_roads()
	_init_mask()
	_paint_roads()
	_build_terrain()
	_define_blocks()
	for b in blocks:
		_fill_block(b)
	_build_base_walls()
	_street_props()
	_distant_skyline()
	_flush_batches()
	_finish_mask()
	nav.rebuild_vehicle_all()

# ======================================================================= Strassen & Maske
func _define_roads() -> void:
	for r in V_ROADS:
		roads.append({"rect": Rect2(r.x - r.w * 0.5, r.z0, r.w, r.z1 - r.z0), "type": r.type, "vert": true, "c": r})
	for r in H_ROADS:
		roads.append({"rect": Rect2(r.x0, r.z - r.w * 0.5, r.x1 - r.x0, r.w), "type": r.type, "vert": false, "c": r})

func _init_mask() -> void:
	mask_img = Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	mask_img.fill(Color(0, 0, 0, 0))
	scorch_img = Image.create(SCORCH_SIZE, SCORCH_SIZE, false, Image.FORMAT_R8)
	scorch_img.fill(Color(0, 0, 0, 1))
	scorch_tex = ImageTexture.create_from_image(scorch_img)

func _px(w: Vector2) -> Vector2i:
	var s := float(MASK_SIZE) / (2.0 * HALF)
	return Vector2i(int((w.x + HALF) * s), int((w.y + HALF) * s))

func _paint(r: Rect2, c: Color) -> void:
	var a := _px(r.position)
	var b := _px(r.position + r.size)
	var rect := Rect2i(a.x, a.y, maxi(b.x - a.x, 1), maxi(b.y - a.y, 1))
	mask_img.fill_rect(rect, c)

func _paint_circle(center: Vector2, rad: float, c: Color) -> void:
	var s := float(MASK_SIZE) / (2.0 * HALF)
	var cx := (center.x + HALF) * s
	var cy := (center.y + HALF) * s
	var rp := rad * s
	for y in range(int(cy - rp) - 1, int(cy + rp) + 2):
		for x in range(int(cx - rp) - 1, int(cx + rp) + 2):
			if x < 0 or y < 0 or x >= MASK_SIZE or y >= MASK_SIZE:
				continue
			if Vector2(x - cx, y - cy).length() <= rp:
				mask_img.set_pixel(x, y, c)

func _paint_roads() -> void:
	var paved := Color(0, 1, 0, 0)
	var asphalt := Color(1, 0, 0, 0)
	# Buergersteige
	for rd in roads:
		var r: Rect2 = rd.rect
		var sw := 1.4 if rd.type == "street" else 2.2
		_paint(r.grow(sw), paved)
	for rd in roads:
		_paint(rd.rect, asphalt)
	# Markierungen
	for rd in roads:
		_paint_markings(rd)
	# Zebrastreifen
	for vr in V_ROADS:
		for hr in H_ROADS:
			if vr.z0 > hr.z or vr.z1 < hr.z or hr.x0 > vr.x or hr.x1 < vr.x:
				continue
			if vr.w < 7.0 or hr.w < 7.0:
				continue
			_crosswalk(Vector2(vr.x, hr.z), vr.w, hr.w)

func _in_any_road(p: Vector2, skip: Dictionary, pad: float) -> bool:
	for rd in roads:
		if rd == skip:
			continue
		if (rd.rect as Rect2).grow(pad).has_point(p):
			return true
	return false

func _paint_markings(rd: Dictionary) -> void:
	var r: Rect2 = rd.rect
	var vert: bool = rd.vert
	var length: float = r.size.y if vert else r.size.x
	var width: float = r.size.x if vert else r.size.y
	var start: float = r.position.y if vert else r.position.x
	var center: float = (r.position.x + r.size.x * 0.5) if vert else (r.position.y + r.size.y * 0.5)
	var white := Color(1, 0, 1, 0)
	var yellow := Color(1, 0, 0, 1)
	var step := 0.5
	var t := 0.0
	while t < length:
		var along := start + t
		var skip_dash := false
		var p2 := Vector2(center, along) if vert else Vector2(along, center)
		if _in_any_road(p2, rd, 0.5):
			skip_dash = true
		if not skip_dash:
			if rd.type == "main":
				# Doppelte gelbe Mittellinie
				_line_dot(vert, center - 0.28, along, 0.14, step, yellow)
				_line_dot(vert, center + 0.28, along, 0.14, step, yellow)
				# Randlinien
				_line_dot(vert, center - width * 0.5 + 0.7, along, 0.16, step, white)
				_line_dot(vert, center + width * 0.5 - 0.7, along, 0.16, step, white)
				# Fahrstreifen gestrichelt (bei breiten Strassen)
				if width >= 11.0 and fmod(t, 6.0) < 3.0:
					_line_dot(vert, center - width * 0.25, along, 0.14, step, white)
					_line_dot(vert, center + width * 0.25, along, 0.14, step, white)
			elif fmod(t, 5.0) < 2.4:
				_line_dot(vert, center, along, 0.14, step, white)
		t += step

func _line_dot(vert: bool, across: float, along: float, w: float, l: float, c: Color) -> void:
	if vert:
		_paint(Rect2(across - w * 0.5, along, w, l), c)
	else:
		_paint(Rect2(along, across - w * 0.5, l, w), c)

func _crosswalk(center: Vector2, vw: float, hw: float) -> void:
	var white := Color(1, 0, 1, 0)
	# vier Zebrastreifen an den Kreuzungsraendern
	for side in [-1, 1]:
		var zc: float = center.y + side * (hw * 0.5 + 1.4)
		var i := -vw * 0.5 + 0.8
		while i < vw * 0.5 - 0.6:
			_paint(Rect2(center.x + i, zc - 1.0, 0.55, 2.0), white)
			i += 1.1
		var xc: float = center.x + side * (vw * 0.5 + 1.4)
		var j := -hw * 0.5 + 0.8
		while j < hw * 0.5 - 0.6:
			_paint(Rect2(xc - 1.0, center.y + j, 2.0, 0.55), white)
			j += 1.1

func _finish_mask() -> void:
	mask_tex = ImageTexture.create_from_image(mask_img)
	ground_mat.set_shader_parameter("mask", mask_tex)
	ground_mat.set_shader_parameter("scorch", scorch_tex)

# ----------------------------------------------------------------------- Brandspuren
func add_scorch(pos: Vector3, radius: float, strength: float = 1.0) -> void:
	var s := float(SCORCH_SIZE) / (2.0 * HALF)
	var cx := (pos.x + HALF) * s
	var cy := (pos.z + HALF) * s
	var rp := radius * s
	for y in range(int(cy - rp) - 1, int(cy + rp) + 2):
		for x in range(int(cx - rp) - 1, int(cx + rp) + 2):
			if x < 0 or y < 0 or x >= SCORCH_SIZE or y >= SCORCH_SIZE:
				continue
			var d := Vector2(x - cx, y - cy).length() / rp
			if d >= 1.0:
				continue
			var a := (1.0 - d * d) * strength
			var old := scorch_img.get_pixel(x, y).r
			var jitter := 0.85 + 0.3 * float((x * 7 + y * 13) % 5) / 4.0
			scorch_img.set_pixel(x, y, Color(minf(1.0, maxf(old, a * jitter)), 0, 0, 1))
	_scorch_dirty = true

func flush_scorch() -> void:
	if _scorch_dirty:
		scorch_tex.update(scorch_img)
		_scorch_dirty = false

# ======================================================================= Gelaende
func _build_terrain() -> void:
	ground_mat = Gfx.shader_mat("res://scripts/gfx/shaders/ground.gdshader")
	ground_mat.set_shader_parameter("world_half", HALF)
	# --- ebene Innenflaeche
	var inner := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(HALF * 2.0 + 24.0, HALF * 2.0 + 24.0)
	inner.mesh = pm
	inner.material_override = ground_mat
	inner.name = "GroundInner"
	add_child(inner)
	# --- Duenenring
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var noise2 := FastNoiseLite.new()
	noise2.seed = rng.randi()
	noise2.frequency = 0.045
	var ext := 330.0
	var step := 6.0
	var n := int(ext * 2.0 / step)
	var inner_half := HALF + 12.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hs: Array = []
	for iz in range(n + 1):
		for ix in range(n + 1):
			var x := -ext + ix * step
			var z := -ext + iz * step
			var d := maxf(absf(x), absf(z)) - inner_half
			var h := 0.0
			if d > 0.0:
				var k := smoothstep(0.0, 55.0, d)
				var base := (noise.get_noise_2d(x, z) * 0.5 + 0.5)
				h = k * (3.0 + base * 26.0 + noise2.get_noise_2d(x, z) * 3.0)
				h -= (1.0 - k) * 0.0
			hs.append(h)
	for iz in range(n):
		for ix in range(n):
			var x0 := -ext + ix * step
			var z0 := -ext + iz * step
			var cx := x0 + step * 0.5
			var cz := z0 + step * 0.5
			if absf(cx) < inner_half - 1.0 and absf(cz) < inner_half - 1.0:
				continue
			var i00: int = iz * (n + 1) + ix
			var p00 := Vector3(x0, hs[i00], z0)
			var p10 := Vector3(x0 + step, hs[i00 + 1], z0)
			var p01 := Vector3(x0, hs[i00 + n + 1], z0 + step)
			var p11 := Vector3(x0 + step, hs[i00 + n + 2], z0 + step)
			var nrm := (p10 - p00).cross(p01 - p00).normalized()
			if nrm.y < 0:
				nrm = -nrm
			for p in [p00, p10, p01, p10, p11, p01]:
				st.set_normal(Vector3(0, 1, 0))
				st.add_vertex(p)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = ground_mat
	mi.name = "Dunes"
	mi.position.y = -0.04
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _distant_skyline() -> void:
	var mb := MeshBuilder.new()
	var r2 := RandomNumberGenerator.new()
	r2.seed = 321
	for i in range(46):
		var ang := r2.randf() * TAU
		var dist := r2.randf_range(260.0, 340.0)
		var p := Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		var h := r2.randf_range(14.0, 46.0)
		var w := r2.randf_range(10.0, 26.0)
		var c := PALETTE[r2.randi() % PALETTE.size()] as Color
		c = c.lerp(Color(0.68, 0.64, 0.58), 0.55)
		mb.box(p + Vector3(0, h * 0.5 - 4.0, 0), Vector3(w, h, w * r2.randf_range(0.6, 1.3)), c)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(Gfx.vcol_mat(1.0, 0.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Skyline"
	add_child(mi)

# ======================================================================= Bloecke
func _define_blocks() -> void:
	var xs := [[-96.0, -83.0], [-77.0, -47.0], [-37.0, -7.5], [-0.5, 29.0], [39.0, 67.0], [75.0, 96.0]]
	var zs := [[-96.0, -77.0], [-71.0, -39.5], [-32.5, -4.0], [8.0, 36.0], [44.0, 75.0], [81.0, 96.0]]
	for xi in range(xs.size()):
		for zi in range(zs.size()):
			if xi <= 1 and zi >= 4:
				continue   # Basis
			var r := Rect2(xs[xi][0], zs[zi][0], xs[xi][1] - xs[xi][0], zs[zi][1] - zs[zi][0])
			var zone := "res"
			var cx := r.get_center().x
			var cz := r.get_center().y
			if xi == 3 and zi == 3:
				zone = "plaza"
			elif xi == 2 and zi == 2:
				zone = "hospital"
			elif xi == 4 and zi == 2:
				zone = "school"
			elif cx > 5.0 and cz < -2.0:
				zone = "old"
			elif cx > 60.0 and cz > 8.0 and cz < 40.0:
				zone = "old_s"
			if r.size.x < 5.0 or r.size.y < 5.0:
				continue
			blocks.append({"rect": r, "zone": zone, "xi": xi, "zi": zi})

func _fill_block(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	var zone: String = b.zone
	var inner := r.grow(-1.0)
	match zone:
		"plaza":
			_build_plaza(inner)
		"hospital":
			_build_hospital(inner)
		"school":
			_build_school(inner)
		_:
			var lots: Array = []
			var max_lot := 16.0
			var gap := 0.0
			if zone == "old" or zone == "old_s":
				max_lot = 12.5
				gap = 3.6
			elif zone == "res":
				max_lot = 17.0
				gap = 0.0
			_subdivide(inner, 0, max_lot, gap, zone, lots)
			for lot in lots:
				_make_lot(lot, zone)

func _subdivide(r: Rect2, depth: int, max_lot: float, gap: float, zone: String, out: Array) -> void:
	var w := r.size.x
	var h := r.size.y
	if (w <= max_lot * 1.3 and h <= max_lot * 1.3) or depth > 5:
		out.append(r)
		return
	var t := rng.randf_range(0.4, 0.6)
	if w >= h:
		var cut := w * t
		var a := Rect2(r.position.x, r.position.y, cut - gap * 0.5, h)
		var c := Rect2(r.position.x + cut + gap * 0.5, r.position.y, w - cut - gap * 0.5, h)
		if gap > 0.0:
			_paint_alley(Rect2(r.position.x + cut - gap * 0.5, r.position.y - 0.0, gap, h))
		_subdivide(a, depth + 1, max_lot, gap, zone, out)
		_subdivide(c, depth + 1, max_lot, gap, zone, out)
	else:
		var cut := h * t
		var a := Rect2(r.position.x, r.position.y, w, cut - gap * 0.5)
		var c := Rect2(r.position.x, r.position.y + cut + gap * 0.5, w, h - cut - gap * 0.5)
		if gap > 0.0:
			_paint_alley(Rect2(r.position.x, r.position.y + cut - gap * 0.5, w, gap))
		_subdivide(a, depth + 1, max_lot, gap, zone, out)
		_subdivide(c, depth + 1, max_lot, gap, zone, out)

func _paint_alley(r: Rect2) -> void:
	_paint(r, Color(0, 1, 0, 0))
	# Zivilisten-Wegpunkte in Gassen
	var c := r.get_center()
	if rng.randf() < 0.5:
		civ_spots.append(Vector3(c.x, 0, c.y))

# ----------------------------------------------------------------------- Grundstuecke
func _make_lot(lot: Rect2, zone: String) -> void:
	if lot.size.x < 4.5 or lot.size.y < 4.5:
		return
	var old := zone == "old" or zone == "old_s"
	var roll := rng.randf()
	# leere Grundstuecke / Hoefe
	if roll < (0.1 if old else 0.12):
		_empty_lot(lot, zone)
		return
	var yard := (not old) and roll < 0.3
	var rect := lot
	var m := rng.randf_range(0.2, 1.0)
	rect = rect.grow(-m)
	if yard:
		# Gebaeude nur auf einem Teil des Grundstuecks
		var frac := rng.randf_range(0.55, 0.7)
		if rect.size.x > rect.size.y:
			var bw := rect.size.x * frac
			var left := rng.randf() < 0.5
			var yard_rect := Rect2(rect.position.x + (0.0 if not left else bw), rect.position.y, rect.size.x - bw, rect.size.y)
			rect = Rect2(rect.position.x + (0.0 if left else rect.size.x - bw), rect.position.y, bw, rect.size.y)
			_yard(yard_rect)
		else:
			var bh := rect.size.y * frac
			var top := rng.randf() < 0.5
			var yard_rect2 := Rect2(rect.position.x, rect.position.y + (0.0 if not top else bh), rect.size.x, rect.size.y - bh)
			rect = Rect2(rect.position.x, rect.position.y + (0.0 if top else rect.size.y - bh), rect.size.x, bh)
			_yard(yard_rect2)
	var floors := 2
	if old:
		floors = [2, 3, 3, 4][rng.randi() % 4]
	else:
		floors = [2, 3, 3, 4, 5][rng.randi() % 5]
	if lot.size.x * lot.size.y < 80.0:
		floors = mini(floors, 3)
	var h := floors * 3.3 + 0.7
	var kind := "house"
	var shop := false
	# Ladenzeile entlang Hauptstrassen
	if zone == "res" and rng.randf() < 0.3:
		shop = true
	var b := _add_building(rect, h, kind, zone, shop)
	# Sandsaecke / Stellungen im Altstadtgebiet
	if old and rng.randf() < 0.35:
		sandbag_spots.append(Vector3(rect.get_center().x, 0, rect.get_center().y))

func _empty_lot(lot: Rect2, zone: String) -> void:
	_paint(lot, Color(0, 1, 0, 0) if rng.randf() < 0.4 else Color(0, 0, 0, 0))
	var c := lot.get_center()
	civ_spots.append(Vector3(c.x, 0, c.y))
	var n := rng.randi_range(0, 3)
	for i in range(n):
		_add_palm(Vector3(rng.randf_range(lot.position.x + 1.0, lot.end.x - 1.0), 0, rng.randf_range(lot.position.y + 1.0, lot.end.y - 1.0)))
	if rng.randf() < 0.4:
		_add_prop("crate", Vector3(c.x + rng.randf_range(-2, 2), 0, c.y + rng.randf_range(-2, 2)), rng.randf() * TAU, Color.WHITE)
	if rng.randf() < 0.3:
		_add_prop("barrel", Vector3(c.x + rng.randf_range(-3, 3), 0, c.y + rng.randf_range(-3, 3)), rng.randf() * TAU, Color.WHITE)
	if rng.randf() < 0.25 and zone != "res":
		wreck_spots.append(Vector3(c.x, 0, c.y))
		_add_prop("car_wreck", Vector3(c.x, 0, c.y), rng.randf() * TAU, Color.WHITE)

func _yard(r: Rect2) -> void:
	_paint(r, Color(0, 1, 0, 0) if rng.randf() < 0.5 else Color(0, 0, 0, 0))
	var c := r.get_center()
	civ_spots.append(Vector3(c.x, 0, c.y))
	for i in range(rng.randi_range(1, 3)):
		_add_palm(Vector3(rng.randf_range(r.position.x + 1.0, r.end.x - 1.0), 0, rng.randf_range(r.position.y + 1.0, r.end.y - 1.0)))
	if rng.randf() < 0.45 and minf(r.size.x, r.size.y) > 4.5:
		var col: Color = [Color(0.95, 0.95, 0.95), Color(0.7, 0.72, 0.75), Color(0.15, 0.15, 0.17), Color(0.7, 0.55, 0.35), Color(0.55, 0.12, 0.1), Color(0.2, 0.3, 0.55)][rng.randi() % 6]
		_add_prop("car", Vector3(c.x, 0, c.y), PI * 0.5 * rng.randi_range(0, 3), col)
	# niedrige Hofmauer an der Hinterseite (rein dekorativ, nicht blockierend)

# ----------------------------------------------------------------------- Gebaeude
func _add_building(rect: Rect2, h: float, kind: String, zone: String, shop: bool = false, wall: Color = Color(0, 0, 0, 0)) -> Dictionary:
	var c := rect.get_center()
	var b := {
		"id": _next_bid, "center": Vector3(c.x, 0.0, c.y), "size": Vector3(rect.size.x, h, rect.size.y),
		"kind": kind, "zone": zone, "shop": shop, "hub": false,
		"occ": 0, "hp": 0.0, "node": null, "mat": null, "rect": rect,
	}
	_next_bid += 1
	var vol: float = rect.size.x * rect.size.y * h
	b.hp = clampf(vol * 0.32, 340.0, 1200.0)
	b.occ = clampi(int(rect.size.x * rect.size.y / 22.0) + rng.randi_range(0, 4), 2, 18)
	if kind == "hospital":
		b.occ = 34
		b.hp = 1700.0
	elif kind == "school":
		b.occ = 42
		b.hp = 1500.0
	if kind == "house" and (zone == "old" or zone == "old_s"):
		b.occ = int(b.occ * 0.8)
	nav.block_rect(c.x, c.y, rect.size.x * 0.5, rect.size.y * 0.5, true)
	_make_building_node(b, wall)
	buildings.append(b)
	return b

func _make_building_node(b: Dictionary, wall_override: Color) -> void:
	var sz: Vector3 = b.size
	var root := Node3D.new()
	root.position = b.center
	root.name = "Building%d" % b.id
	var wall_c: Color = wall_override if wall_override.a > 0.0 else PALETTE[rng.randi() % PALETTE.size()]
	var mat := Gfx.shader_mat("res://scripts/gfx/shaders/facade.gdshader")
	mat.set_shader_parameter("wall_color", wall_c)
	mat.set_shader_parameter("trim_color", wall_c.lerp(Color(1, 0.97, 0.9), 0.55))
	mat.set_shader_parameter("accent_color", ACCENTS[rng.randi() % ACCENTS.size()])
	mat.set_shader_parameter("awning_color", AWNINGS[rng.randi() % AWNINGS.size()])
	mat.set_shader_parameter("box_size", sz)
	mat.set_shader_parameter("building_h", sz.y)
	mat.set_shader_parameter("cell_w", rng.randf_range(2.7, 3.5))
	mat.set_shader_parameter("seed", rng.randf() * 10.0)
	mat.set_shader_parameter("shop", 1.0 if b.shop else 0.0)
	mat.set_shader_parameter("win_density", rng.randf_range(0.7, 0.95))
	mat.set_shader_parameter("damage", 0.0)
	if b.kind == "hospital":
		mat.set_shader_parameter("cross_sign", 1.0)
		mat.set_shader_parameter("accent_color", Color(0.2, 0.5, 0.6))
	b.mat = mat
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = Vector3(0, sz.y * 0.5, 0)
	mi.material_override = mat
	root.add_child(mi)
	# Attika (dekorative Brustwehr)
	var trim_col := wall_c.lerp(Color(1, 0.97, 0.9), 0.55)
	var pm := Gfx.flat_mat(trim_col * 0.97, 0.95)
	var t := 0.32
	var ph := 0.85
	var parts := [
		[Vector3(0, sz.y + ph * 0.5 - 0.05, sz.z * 0.5 - t * 0.5), Vector3(sz.x, ph, t)],
		[Vector3(0, sz.y + ph * 0.5 - 0.05, -sz.z * 0.5 + t * 0.5), Vector3(sz.x, ph, t)],
		[Vector3(sz.x * 0.5 - t * 0.5, sz.y + ph * 0.5 - 0.05, 0), Vector3(t, ph, sz.z - t * 2.0)],
		[Vector3(-sz.x * 0.5 + t * 0.5, sz.y + ph * 0.5 - 0.05, 0), Vector3(t, ph, sz.z - t * 2.0)],
	]
	var pmb := MeshBuilder.new()
	for p in parts:
		pmb.box(p[0], p[1], trim_col * 0.97)
	var pmi := MeshInstance3D.new()
	pmi.mesh = pmb.build(Gfx.vcol_mat(0.95, 0.0))
	root.add_child(pmi)
	_roof_details(root, b, wall_c)
	b.node = root
	add_child(root)

func _roof_details(root: Node3D, b: Dictionary, wall_c: Color) -> void:
	var sz: Vector3 = b.size
	var y := sz.y
	var hx := sz.x * 0.5 - 1.2
	var hz := sz.z * 0.5 - 1.2
	if hx < 0.5 or hz < 0.5:
		return
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.25
	var any := false
	# Treppenhaus
	if rng.randf() < 0.55 and sz.x > 6 and sz.z > 6:
		var s := Vector3(rng.randf_range(2.0, 3.2), 2.4, rng.randf_range(2.0, 3.0))
		var p := Vector3(rng.randf_range(-hx, hx), y + s.y * 0.5, rng.randf_range(-hz, hz))
		mb.box(p, s, wall_c.lerp(Color(1, 0.97, 0.9), 0.35))
		mb.box(p + Vector3(0, -0.4, s.z * 0.5 + 0.01), Vector3(0.9, 1.4, 0.05), Color(0.2, 0.17, 0.15))
		any = true
	# Wassertank
	if rng.randf() < 0.4:
		var p := Vector3(rng.randf_range(-hx, hx), y, rng.randf_range(-hz, hz))
		_add_roof_prop(root, "watertank", p)
	if rng.randf() < 0.4:
		_add_roof_prop(root, "dish", Vector3(rng.randf_range(-hx, hx), y, rng.randf_range(-hz, hz)), rng.randf() * 360.0)
	if rng.randf() < 0.28:
		var p := Vector3(rng.randf_range(-hx, hx), y, rng.randf_range(-hz, hz))
		_add_roof_prop(root, "solar", p, 90.0 * rng.randi_range(0, 3))
	# Antennen
	if rng.randf() < 0.3:
		var p := Vector3(rng.randf_range(-hx, hx), y + 2.2, rng.randf_range(-hz, hz))
		mb.cyl(p, 0.05, 0.03, 4.4, Color(0.3, 0.3, 0.3), 4)
		mb.box(p + Vector3(0, 1.5, 0), Vector3(1.4, 0.05, 0.05), Color(0.3, 0.3, 0.3))
		any = true
	# Waescheleine mit bunten Tuechern
	if rng.randf() < 0.22 and sz.x > 7:
		var z0 := rng.randf_range(-hz, hz)
		for i in range(5):
			var cc: Color = [Color(0.9, 0.9, 0.85), Color(0.8, 0.3, 0.2), Color(0.3, 0.45, 0.75), Color(0.9, 0.8, 0.3)][rng.randi() % 4]
			mb.box(Vector3(-hx * 0.6 + i * hx * 0.3, y + 1.1, z0), Vector3(0.55, 0.8, 0.04), cc)
		mb.box(Vector3(0, y + 1.55, z0), Vector3(hx * 1.4, 0.03, 0.03), Color(0.2, 0.2, 0.2))
		any = true
	if any:
		var mi := MeshInstance3D.new()
		mi.mesh = mb.build(Gfx.vcol_mat(0.9, 0.0))
		root.add_child(mi)

func _add_roof_prop(root: Node3D, mesh_name: String, local_pos: Vector3, yaw_deg: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Props.get_mesh(mesh_name)
	mi.position = local_pos
	mi.rotation_degrees.y = yaw_deg
	root.add_child(mi)

# ----------------------------------------------------------------------- Spezialbloecke
func _build_plaza(r: Rect2) -> void:
	plaza_rect = r
	_paint(r, Color(0, 1, 0, 0))
	var c := r.get_center()
	# Brunnen
	_paint_circle(Vector2(c.x, c.y), 6.5, Color(0, 1, 0, 0))
	var mb := MeshBuilder.new()
	mb.ao_strength = 0.3
	mb.cyl(Vector3(0, 0.45, 0), 4.0, 4.0, 0.9, Color(0.78, 0.72, 0.6), 20)
	mb.cyl(Vector3(0, 0.85, 0), 3.5, 3.5, 0.1, Color(0.22, 0.4, 0.5), 20)
	mb.cyl(Vector3(0, 1.5, 0), 0.5, 0.35, 2.0, Color(0.8, 0.75, 0.62), 10)
	mb.cyl(Vector3(0, 2.7, 0), 1.6, 0.5, 0.5, Color(0.78, 0.72, 0.6), 12)
	var fm := MeshInstance3D.new()
	fm.mesh = mb.build(Gfx.vcol_mat(0.85, 0.0))
	fm.position = Vector3(c.x, 0, c.y)
	add_child(fm)
	nav.block_rect(c.x, c.y, 4.0, 4.0, true)
	# Marktstaende in Reihen
	var stall_names := ["stall_red", "stall_green", "stall_orange", "stall_blue"]
	for row in range(2):
		for i in range(5):
			var sx := r.position.x + 4.5 + i * 5.2
			var sz_ := (r.position.y + 8.5) if row == 0 else (r.end.y - 4.0)
			if absf(sx - c.x) < 6.0 and absf(sz_ - c.y) < 6.0:
				continue
			_add_prop(stall_names[rng.randi() % 4], Vector3(sx, 0, sz_), 0.0 if row == 0 else PI, Color.WHITE)
			nav.block_rect(sx, sz_, 1.8, 1.3, true)
	for row in range(2):
		for i in range(2):
			var sz2 := c.y - 5.5 + row * 11.0
			var sx2 := r.position.x + 4.0 + i * (r.size.x - 8.0)
			_add_prop(stall_names[rng.randi() % 4], Vector3(sx2, 0, sz2), PI * 0.5 if i == 0 else -PI * 0.5, Color.WHITE)
			nav.block_rect(sx2, sz2, 1.3, 1.8, true)
	# Randbebauung: Ladenzeile oben (zur Hauptstrasse) und unten
	var top_row := Rect2(r.position.x, r.position.y, r.size.x, 5.0)
	var bot_row := Rect2(r.position.x, r.end.y - 5.0, r.size.x, 5.0)
	# nur schmale Laeden in zwei Gruppen (Mitte frei fuer Eingang)
	for rr in [top_row]:
		_shop_row(rr, true)
	# Palmen auf dem Platz
	for i in range(8):
		var p := Vector3(rng.randf_range(r.position.x + 2, r.end.x - 2), 0, rng.randf_range(r.position.y + 6, r.end.y - 2))
		if Vector2(p.x - c.x, p.z - c.y).length() > 7.0:
			_add_palm(p)
	for i in range(14):
		civ_spots.append(Vector3(c.x + rng.randf_range(-12, 12), 0, c.y + rng.randf_range(-11, 11)))

func _shop_row(r: Rect2, top: bool) -> void:
	var x := r.position.x
	while x < r.end.x - 3.0:
		var w := rng.randf_range(6.0, 9.0)
		if x + w > r.end.x:
			w = r.end.x - x
		var rect := Rect2(x + 0.3, r.position.y, w - 0.6, 5.0)
		_add_building(rect, rng.randf_range(7.0, 11.0), "house", "res", true)
		x += w + rng.randf_range(0.0, 4.0)

func _build_hospital(r: Rect2) -> void:
	_paint(r, Color(0, 1, 0, 0))
	# Hauptgebaeude
	var main := Rect2(r.position.x + 2.0, r.position.y + 2.0, r.size.x - 4.0, 13.0)
	var b := _add_building(main, 3.0 * 3.4 + 1.0, "hospital", "hospital", false, Color(0.93, 0.93, 0.9))
	hospital_pos = b.center
	# Fluegel
	var wing := Rect2(r.position.x + 2.0, r.position.y + 17.0, 9.0, r.size.y - 19.0)
	_add_building(wing, 2.0 * 3.4 + 1.0, "hospital", "hospital", false, Color(0.9, 0.9, 0.86))
	# Parkplatz mit Krankenwagen
	var amb := Color(0.95, 0.95, 0.95)
	for i in range(3):
		_add_prop("car", Vector3(r.position.x + 15.0 + i * 3.8, 0, r.end.y - 4.0), PI * 0.5, amb if i < 2 else Color(0.8, 0.8, 0.82))
	for i in range(4):
		_add_prop("car", Vector3(r.position.x + 14.0 + i * 3.4, 0, r.position.y + 19.0), 0.0, [Color(0.9, 0.9, 0.9), Color(0.2, 0.2, 0.22), Color(0.6, 0.5, 0.4), Color(0.4, 0.5, 0.65)][i])
	_add_palm(Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + 17.0))
	_add_palm(Vector3(r.end.x - 3.0, 0, r.end.y - 3.0))
	civ_spots.append(Vector3(r.position.x + 14.0, 0, r.position.y + 25.0))
	civ_spots.append(Vector3(r.end.x - 5.0, 0, r.position.y + 21.0))

func _build_school(r: Rect2) -> void:
	_paint(r, Color(0, 1, 0, 0))
	var wall := Color(0.93, 0.82, 0.55)
	var main := Rect2(r.position.x + 2.0, r.position.y + 2.0, r.size.x - 4.0, 8.0)
	var b := _add_building(main, 2.0 * 3.4 + 0.8, "school", "school", false, wall)
	school_pos = b.center
	var wing := Rect2(r.position.x + 2.0, r.position.y + 10.5, 8.0, 12.0)
	_add_building(wing, 2.0 * 3.4 + 0.8, "school", "school", false, wall)
	# Pausenhof mit Spielfeld-Markierung
	_paint(Rect2(r.position.x + 12.0, r.position.y + 13.0, 12.0, 10.0), Color(0, 1, 0, 1))
	_paint(Rect2(r.position.x + 12.4, r.position.y + 13.4, 11.2, 9.2), Color(0, 1, 0, 0))
	# Fahnenmast
	var mb := MeshBuilder.new()
	mb.cyl(Vector3(0, 4.0, 0), 0.1, 0.07, 8.0, Color(0.7, 0.7, 0.72), 6)
	mb.box(Vector3(0.9, 7.2, 0), Vector3(1.8, 1.1, 0.04), Color(0.9, 0.9, 0.95))
	mb.box(Vector3(0.9, 7.2, 0.0), Vector3(1.8, 0.37, 0.05), Color(0.2, 0.45, 0.75))
	var fmi := MeshInstance3D.new()
	fmi.mesh = mb.build(Gfx.vcol_mat(0.7, 0.2))
	fmi.position = Vector3(r.position.x + 11.0, 0, r.end.y - 5.0)
	add_child(fmi)
	_add_palm(Vector3(r.end.x - 3.0, 0, r.end.y - 3.0))
	_add_palm(Vector3(r.end.x - 3.0, 0, r.position.y + 14.0))
	civ_spots.append(Vector3(r.position.x + 18.0, 0, r.position.y + 18.0))
	civ_spots.append(Vector3(r.position.x + 20.0, 0, r.position.y + 15.0))

# ======================================================================= Basis (Mauern)
func _build_base_walls() -> void:
	var r := BASE_RECT
	_paint(r, Color(0, 1, 0, 0))
	# Innenhof etwas Schotter
	var gate_e := Vector2(r.position.y + 18.0, r.position.y + 28.0)    # z-Bereich Osttor
	var gate_n := Vector2(r.position.x + 24.0, r.position.x + 34.0)   # x-Bereich Nordtor
	var piece := 3.0
	# Nord (z = r.y) und Sued
	var x := r.position.x + piece * 0.5
	while x < r.end.x:
		if not (x > gate_n.x and x < gate_n.y):
			_add_prop("hesco", Vector3(x, 0, r.position.y + 0.8), PI * 0.5, Color.WHITE)
		_add_prop("hesco", Vector3(x, 0, r.end.y - 0.8), PI * 0.5, Color.WHITE)
		x += piece
	var z := r.position.y + piece * 0.5
	while z < r.end.y:
		_add_prop("hesco", Vector3(r.position.x + 0.8, 0, z), 0.0, Color.WHITE)
		if not (z > gate_e.x and z < gate_e.y):
			_add_prop("hesco", Vector3(r.end.x - 0.8, 0, z), 0.0, Color.WHITE)
		z += piece
	# Nav: Wandstreifen sperren (mit Luecken fuer Tore)
	nav.block_rect(r.get_center().x, r.position.y + 0.8, r.size.x * 0.5, 0.9, true)
	nav.block_rect(r.get_center().x, r.end.y - 0.8, r.size.x * 0.5, 0.9, true)
	nav.block_rect(r.position.x + 0.8, r.get_center().y, 0.9, r.size.y * 0.5, true)
	nav.block_rect(r.end.x - 0.8, r.get_center().y, 0.9, r.size.y * 0.5, true)
	nav.block_rect((gate_n.x + gate_n.y) * 0.5, r.position.y + 0.8, (gate_n.y - gate_n.x) * 0.5, 1.2, false)
	nav.block_rect(r.end.x - 0.8, (gate_e.x + gate_e.y) * 0.5, 1.2, (gate_e.y - gate_e.x) * 0.5, false)
	# Torbalken / Schilder
	_add_prop("barrier", Vector3((gate_n.x + gate_n.y) * 0.5 - 5.5, 0, r.position.y - 2.0), PI * 0.5, Color.WHITE)
	_add_prop("barrier", Vector3((gate_n.x + gate_n.y) * 0.5 + 5.5, 0, r.position.y - 2.0), PI * 0.5, Color.WHITE)
	_add_prop("sandbags", Vector3(r.end.x + 2.0, 0, gate_e.x - 1.5), 0.0, Color.WHITE)
	_add_prop("sandbags", Vector3(r.end.x + 2.0, 0, gate_e.y + 1.5), 0.0, Color.WHITE)

# ======================================================================= Strassen-Props
func _street_props() -> void:
	# Palmen und Laternen
	for rd in roads:
		var c: Dictionary = rd.c
		var vert: bool = rd.vert
		var w: float = c.w
		var spacing := 9.5 if rd.type == "main" else 15.0
		var start: float = c.z0 if vert else c.x0
		var stop: float = c.z1 if vert else c.x1
		var t := start + 5.0
		var k := 0
		while t < stop - 4.0:
			for side in [-1.0, 1.0]:
				var off: float = side * (w * 0.5 + (2.0 if rd.type == "main" else 1.2))
				var p := Vector3(c.x + off, 0, t) if vert else Vector3(t, 0, c.z + off)
				if _near_intersection(p, 3.5):
					continue
				if BASE_RECT.grow(2.0).has_point(Vector2(p.x, p.z)):
					continue
				if _blocked_for_prop(p):
					continue
				if rd.type == "main" and k % 2 == 0:
					_add_palm(p)
				elif rd.type != "main" and k % 3 == 0 and rng.randf() < 0.5:
					_add_palm(p)
				elif rng.randf() < 0.5 and k % 2 == 1:
					_add_prop("lamp", p, (PI if side < 0 else 0.0) + (0.0 if vert else PI * 0.5), Color.WHITE)
			t += spacing
			k += 1
	# parkende Autos am Strassenrand
	for i in range(55):
		var rd: Dictionary = roads[rng.randi() % roads.size()]
		var c: Dictionary = rd.c
		var vert: bool = rd.vert
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var off: float = side * (c.w * 0.5 - 1.5)
		var along: float = rng.randf_range(c.z0 + 6.0, c.z1 - 6.0) if vert else rng.randf_range(c.x0 + 6.0, c.x1 - 6.0)
		var p := Vector3(c.x + off, 0, along) if vert else Vector3(along, 0, c.z + off)
		if _near_intersection(p, 7.0) or BASE_RECT.grow(4.0).has_point(Vector2(p.x, p.z)):
			continue
		var colr: Color = [Color(0.95, 0.95, 0.95), Color(0.7, 0.72, 0.75), Color(0.15, 0.15, 0.17), Color(0.7, 0.55, 0.35), Color(0.55, 0.12, 0.1), Color(0.2, 0.3, 0.55), Color(0.9, 0.75, 0.15)][rng.randi() % 7]
		var wreck := rng.randf() < 0.18
		_add_prop("car_wreck" if wreck else "car", p, (0.0 if vert else PI * 0.5) + (PI if rng.randf() < 0.5 else 0.0), colr)
		if wreck:
			wreck_spots.append(p)
	# Strommasten + Leitungen
	_power_lines()
	# Betonbarrieren / Checkpoints
	var cps := [Vector3(-42, 0, -20), Vector3(34, 0, 20), Vector3(-4, 0, 22), Vector3(34, 0, -55)]
	for p in cps:
		for i in range(3):
			_add_prop("barrier", p + Vector3(-3.0 + i * 3.1, 0, 0), PI * 0.5, Color.WHITE)
	# Aussenbereich: Buesche
	for i in range(60):
		var ang := rng.randf() * TAU
		var d := rng.randf_range(100.0, 150.0)
		var p := Vector3(cos(ang) * d, 0, sin(ang) * d)
		if absf(p.x) < 106.0 and absf(p.z) < 106.0:
			p = p.normalized() * 118.0
		_add_prop("dune_bush", p, rng.randf() * TAU, Color.WHITE)
	for i in range(30):
		var ang := rng.randf() * TAU
		var d := rng.randf_range(104.0, 140.0)
		_add_palm(Vector3(cos(ang) * d, 0, sin(ang) * d))

func _near_intersection(p: Vector3, pad: float) -> bool:
	for vr in V_ROADS:
		for hr in H_ROADS:
			if vr.z0 > hr.z or vr.z1 < hr.z or hr.x0 > vr.x or hr.x1 < vr.x:
				continue
			var rect := Rect2(vr.x - vr.w * 0.5 - pad, hr.z - hr.w * 0.5 - pad, vr.w + pad * 2.0, hr.w + pad * 2.0)
			if rect.has_point(Vector2(p.x, p.z)):
				return true
	return false

func _blocked_for_prop(p: Vector3) -> bool:
	var c := nav.world_to_cell(p)
	return nav.solid[nav.idx(c)] == 1

func _power_lines() -> void:
	var lines := PackedVector3Array()
	var segs := [
		{"vert": false, "c": 36.0, "a": -92.0, "b": 92.0, "off": 4.8},
		{"vert": true, "c": -4.0, "a": -92.0, "b": 30.0, "off": 4.6},
	]
	for s in segs:
		var poles: Array = []
		var t: float = s.a
		while t <= s.b:
			var p := Vector3(t, 0, s.c + s.off) if not s.vert else Vector3(s.c + s.off, 0, t)
			if not _near_intersection(p, 2.0) and not _blocked_for_prop(p) and not BASE_RECT.grow(2.0).has_point(Vector2(p.x, p.z)):
				_add_prop("pole", p, 0.0 if not s.vert else PI * 0.5, Color.WHITE)
				poles.append(p)
			t += 22.0
		for i in range(poles.size() - 1):
			var a: Vector3 = poles[i]
			var b: Vector3 = poles[i + 1]
			if a.distance_to(b) > 30.0:
				continue
			for off in [-1.3, 0.0, 1.3]:
				var lat := Vector3(0, 0, off) if not s.vert else Vector3(off, 0, 0)
				var pa := a + Vector3(0, 8.5, 0) + lat
				var pb := b + Vector3(0, 8.5, 0) + lat
				var prev := pa
				for k in range(1, 9):
					var tt := float(k) / 8.0
					var p := pa.lerp(pb, tt)
					p.y -= sin(tt * PI) * 0.9
					lines.append(prev)
					lines.append(p)
					prev = p
	if lines.size() == 0:
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = lines
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.08, 0.08, 0.08)
	mi.material_override = lm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ======================================================================= Props / Batches
func _add_prop(mesh_name: String, pos: Vector3, yaw: float, color: Color, scale: float = 1.0) -> void:
	if not _batches.has(mesh_name):
		_batches[mesh_name] = {"mesh": Props.get_mesh(mesh_name), "xf": [], "col": []}
	var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale)), pos)
	_batches[mesh_name].xf.append(t)
	_batches[mesh_name].col.append(color)

func _add_palm(pos: Vector3) -> void:
	var v := rng.randi() % 4
	var key := "palm_%d" % v
	if not _batches.has(key):
		_batches[key] = {"mesh": Props.palm_mesh(v), "xf": [], "col": []}
	var s := rng.randf_range(0.8, 1.3)
	var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), pos)
	_batches[key].xf.append(t)
	_batches[key].col.append(Color.WHITE)
	var c := nav.world_to_cell(pos)
	if nav.in_bounds(c):
		# Palmenstamm blockiert nur sehr schwach – keine Nav-Sperre
		pass

func _flush_batches() -> void:
	for k in _batches.keys():
		var d: Dictionary = _batches[k]
		var n: int = d.xf.size()
		if n == 0:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = d.mesh
		mm.instance_count = n
		for i in range(n):
			mm.set_instance_transform(i, d.xf[i])
			mm.set_instance_color(i, d.col[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "Batch_" + k
		add_child(mmi)
	_batches.clear()

## Zufaelliger begehbarer Punkt im Freien (fuer Zivilisten etc.)
func random_street_point(r: RandomNumberGenerator) -> Vector3:
	if civ_spots.size() > 0 and r.randf() < 0.55:
		var p: Vector3 = civ_spots[r.randi() % civ_spots.size()]
		return Vector3(p.x + r.randf_range(-2, 2), 0, p.z + r.randf_range(-2, 2))
	var rd: Dictionary = roads[r.randi() % roads.size()]
	var rect: Rect2 = rd.rect
	return Vector3(r.randf_range(rect.position.x + 1.0, rect.end.x - 1.0), 0, r.randf_range(rect.position.y + 1.0, rect.end.y - 1.0))
