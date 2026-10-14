class_name MeshBuilder
extends RefCounted
## Baut Low-Poly-Meshes aus Primitiven mit Vertex-Farben (ein Mesh = ein Draw-Call).
## Alle Flaechen werden mit expliziten Normalen und korrekter Wicklung (CW = Vorderseite) erzeugt.

var st := SurfaceTool.new()
var xf := Transform3D.IDENTITY       # aktuelle Transformation (fuer verschachtelte Teile)
var ao_floor := 0.0                  # unterhalb dieser Hoehe wird abgedunkelt (Fake-AO)
var ao_strength := 0.0
var _n_tris := 0
var jitter := 0.0
var _jr := RandomNumberGenerator.new()

func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_jr.seed = 1234

func set_xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	b = b.scaled(scl)
	xf = Transform3D(b, pos)

func reset_xf() -> void:
	xf = Transform3D.IDENTITY

func _shade(c: Color, p: Vector3) -> Color:
	if ao_strength > 0.0:
		var k := clampf((p.y - ao_floor) / 1.2, 0.0, 1.0)
		var f := 1.0 - ao_strength * (1.0 - k)
		return Color(c.r * f, c.g * f, c.b * f, c.a)
	return c

func _emit(a: Vector3, b: Vector3, c: Vector3, outward: Vector3, col: Color) -> void:
	# a,b,c in lokalen Koordinaten; outward = erwartete Aussennormale (lokal)
	var n := (b - a).cross(c - a)
	if n.length() < 1e-9:
		return
	n = n.normalized()
	var wa := xf * a
	var wb := xf * b
	var wc := xf * c
	var wn := (xf.basis * outward).normalized()
	var geo := (wb - wa).cross(wc - wa)
	# geo zeigt (bei CCW von aussen) nach aussen. Godot-Vorderseite = CW -> Reihenfolge a,c,b
	if geo.dot(wn) >= 0.0:
		_v(wa, wn, col)
		_v(wc, wn, col)
		_v(wb, wn, col)
	else:
		_v(wa, wn, col)
		_v(wb, wn, col)
		_v(wc, wn, col)
	_n_tris += 1

func _emit_smooth(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, col: Color) -> void:
	var wa := xf * a
	var wb := xf * b
	var wc := xf * c
	var wna := (xf.basis * na).normalized()
	var wnb := (xf.basis * nb).normalized()
	var wnc := (xf.basis * nc).normalized()
	var geo := (wb - wa).cross(wc - wa)
	var avg := wna + wnb + wnc
	if geo.dot(avg) >= 0.0:
		_vn(wa, wna, col)
		_vn(wc, wnc, col)
		_vn(wb, wnb, col)
	else:
		_vn(wa, wna, col)
		_vn(wb, wnb, col)
		_vn(wc, wnc, col)
	_n_tris += 1

func _v(p: Vector3, n: Vector3, col: Color) -> void:
	st.set_color(_shade(col, p))
	st.set_normal(n)
	st.add_vertex(p)

func _vn(p: Vector3, n: Vector3, col: Color) -> void:
	st.set_color(_shade(col, p))
	st.set_normal(n)
	st.add_vertex(p)

func face(verts: Array, outward: Vector3, col: Color) -> void:
	for i in range(1, verts.size() - 1):
		_emit(verts[0], verts[i], verts[i + 1], outward, col)

## Quader. center = Mittelpunkt (lokal), size = Kantenlaengen.
func _jit(c: Color) -> Color:
	if jitter <= 0.0:
		return c
	var k := 1.0 + _jr.randf_range(-jitter, jitter)
	return Color(c.r * k, c.g * k, c.b * k, c.a)

func box(center: Vector3, size: Vector3, col: Color, top_col: Color = Color(0, 0, 0, 0)) -> void:
	col = _jit(col)
	var h := size * 0.5
	var x0 := center.x - h.x
	var x1 := center.x + h.x
	var y0 := center.y - h.y
	var y1 := center.y + h.y
	var z0 := center.z - h.z
	var z1 := center.z + h.z
	var tc := top_col if top_col.a > 0.0 else col
	face([Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], Vector3.UP, tc)
	face([Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)], Vector3.DOWN, col * 0.7)
	face([Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], Vector3.BACK, col)
	face([Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0)], Vector3.FORWARD, col * 0.92)
	face([Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0)], Vector3.RIGHT, col * 0.96)
	face([Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0)], Vector3.LEFT, col * 0.96)

## Box mit eigener Transformation (pos, Euler-Grad)
func box_t(pos: Vector3, size: Vector3, col: Color, rot_deg: Vector3 = Vector3.ZERO, top_col: Color = Color(0, 0, 0, 0)) -> void:
	var save := xf
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	xf = save * Transform3D(b, pos)
	box(Vector3.ZERO, size, col, top_col)
	xf = save

## Zylinder / Kegelstumpf entlang Y (axis 0), X (1) oder Z (2). Mittelpunkt center.
func cyl(center: Vector3, r_bottom: float, r_top: float, height: float, col: Color, sides: int = 10, axis: int = 0, caps: bool = true) -> void:
	col = _jit(col)
	var save := xf
	var b := Basis.IDENTITY
	if axis == 1:
		b = Basis.from_euler(Vector3(0, 0, deg_to_rad(-90)))
	elif axis == 2:
		b = Basis.from_euler(Vector3(deg_to_rad(90), 0, 0))
	xf = save * Transform3D(b, center)
	var hh := height * 0.5
	var slope := (r_bottom - r_top) / maxf(height, 0.0001)
	for i in range(sides):
		var a0 := TAU * float(i) / sides
		var a1 := TAU * float(i + 1) / sides
		var c0 := Vector3(cos(a0), 0, sin(a0))
		var c1 := Vector3(cos(a1), 0, sin(a1))
		var p00 := Vector3(c0.x * r_bottom, -hh, c0.z * r_bottom)
		var p10 := Vector3(c1.x * r_bottom, -hh, c1.z * r_bottom)
		var p01 := Vector3(c0.x * r_top, hh, c0.z * r_top)
		var p11 := Vector3(c1.x * r_top, hh, c1.z * r_top)
		var n0 := Vector3(c0.x, slope, c0.z).normalized()
		var n1 := Vector3(c1.x, slope, c1.z).normalized()
		_emit_smooth(p00, p10, p11, n0, n1, n1, col)
		_emit_smooth(p00, p11, p01, n0, n1, n0, col)
		if caps:
			if r_top > 0.001:
				_emit(Vector3(0, hh, 0), p01, p11, Vector3.UP, col * 1.05)
			if r_bottom > 0.001:
				_emit(Vector3(0, -hh, 0), p00, p10, Vector3.DOWN, col * 0.6)
	xf = save

func sphere(center: Vector3, r: float, col: Color, scl: Vector3 = Vector3.ONE, rings: int = 6, sides: int = 10, top_only: bool = false) -> void:
	var save := xf
	xf = save * Transform3D(Basis.IDENTITY.scaled(scl), center)
	var r_from := 0
	var r_to := rings
	if top_only:
		r_to = rings / 2
	for ri in range(r_from, r_to):
		var t0 := PI * float(ri) / rings
		var t1 := PI * float(ri + 1) / rings
		for si in range(sides):
			var p0 := TAU * float(si) / sides
			var p1 := TAU * float(si + 1) / sides
			var n00 := Vector3(sin(t0) * cos(p0), cos(t0), sin(t0) * sin(p0))
			var n01 := Vector3(sin(t0) * cos(p1), cos(t0), sin(t0) * sin(p1))
			var n10 := Vector3(sin(t1) * cos(p0), cos(t1), sin(t1) * sin(p0))
			var n11 := Vector3(sin(t1) * cos(p1), cos(t1), sin(t1) * sin(p1))
			if ri > 0:
				_emit_smooth(n00 * r, n01 * r, n11 * r, n00, n01, n11, col)
			_emit_smooth(n00 * r, n11 * r, n10 * r, n00, n11, n10, col)
	xf = save

## Extrusion eines konvexen Polygons (x,z) von y0 bis y1.
func extrude(poly: Array, y0: float, y1: float, col: Color, top_col: Color = Color(0, 0, 0, 0)) -> void:
	col = _jit(col)
	var n := poly.size()
	var cen := Vector2.ZERO
	for p in poly:
		cen += p
	cen /= n
	var tc := top_col if top_col.a > 0.0 else col
	var top: Array = []
	var bot: Array = []
	for p in poly:
		top.append(Vector3(p.x, y1, p.y))
		bot.append(Vector3(p.x, y0, p.y))
	face(top, Vector3.UP, tc)
	face(bot, Vector3.DOWN, col * 0.6)
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var mid := (a + b) * 0.5
		var out2 := (mid - cen)
		var edge := (b - a)
		var nrm := Vector2(edge.y, -edge.x)
		if nrm.dot(out2) < 0:
			nrm = -nrm
		nrm = nrm.normalized()
		var outward := Vector3(nrm.x, 0, nrm.y)
		var shade := 0.85 + 0.15 * clampf(outward.dot(Vector3(0.3, 0, 0.9)), -1.0, 1.0)
		face([Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y)], outward, col * shade)

## Keil (Rampe): Grundflaeche w x d, Hoehe h an der +Z-Seite abfallend auf 0 (Nase).
func wedge(center: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var x0 := center.x - h.x
	var x1 := center.x + h.x
	var y0 := center.y - h.y
	var y1 := center.y + h.y
	var z0 := center.z - h.z
	var z1 := center.z + h.z
	# Schraege von (y1 bei z0) nach (y0 bei z1)
	var slope_n := Vector3(0, size.z, size.y).normalized()
	face([Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)], slope_n, col * 1.08)
	face([Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1)], Vector3.DOWN, col * 0.6)
	face([Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0)], Vector3.FORWARD, col * 0.9)
	face([Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z0)], Vector3.RIGHT, col * 0.95)
	face([Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z0)], Vector3.LEFT, col * 0.95)

## Quader zwischen zwei Punkten (Streben, Rohre, Kabel). thick = Querschnitt.
func beam(a: Vector3, b: Vector3, thick: float, col: Color) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var z := d / l
	var up := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	var save := xf
	xf = save * Transform3D(Basis(x, y, z), (a + b) * 0.5)
	box(Vector3.ZERO, Vector3(thick, thick, l), col)
	xf = save

## Rad mit Reifenprofil und Nabe (Achse = X).
func wheel(center: Vector3, r: float, w: float, tire: Color, hub: Color, treads: int = 14) -> void:
	cyl(center, r, r, w, tire, 14, 1)
	var side := signf(center.x) if absf(center.x) > 0.001 else 1.0
	cyl(center + Vector3(side * w * 0.5, 0, 0), r * 0.62, r * 0.62, 0.06, hub, 12, 1)
	cyl(center + Vector3(side * (w * 0.5 + 0.04), 0, 0), r * 0.22, r * 0.22, 0.08, hub * 0.7, 8, 1)
	for i in range(8):
		var ang := TAU * float(i) / 8.0
		box(center + Vector3(side * (w * 0.5 + 0.04), sin(ang) * r * 0.4, cos(ang) * r * 0.4), Vector3(0.06, r * 0.08, r * 0.08), hub * 0.55)
	for i in range(treads):
		var ang2 := TAU * float(i) / treads
		box_t(center + Vector3(0, sin(ang2) * r * 0.99, cos(ang2) * r * 0.99), Vector3(w * 1.03, r * 0.1, r * 0.3), tire * 0.7, Vector3(-rad_to_deg(ang2), 0, 0))

func build(material: Material = null) -> ArrayMesh:
	var m := st.commit()
	if m != null and material != null and m.get_surface_count() > 0:
		m.surface_set_material(0, material)
	return m

func tri_count() -> int:
	return _n_tris
