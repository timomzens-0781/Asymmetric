class_name Gfx
extends RefCounted
## Materialien, Texturen und Mesh-Helfer (alles prozedural, keine externen Assets).

static var _cache: Dictionary = {}

## Standardmaterial fuer Vertex-Color-Meshes.
static func vcol_mat(rough: float = 0.82, metal: float = 0.05) -> Material:
	var key := "vcol_%.2f_%.2f" % [rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/gfx/shaders/vcol.gdshader")
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("metal", metal)
	_cache[key] = m
	return m

static func flat_mat(c: Color, rough: float = 0.9, emissive: float = 0.0) -> StandardMaterial3D:
	var key := "flat_%s_%.2f_%.2f" % [c.to_html(true), rough, emissive]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	_cache[key] = m
	return m

static func unshaded_mat(c: Color, additive: bool = false, double_sided: bool = true) -> StandardMaterial3D:
	var key := "unsh_%s_%s_%s" % [c.to_html(true), additive, double_sided]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	_cache[key] = m
	return m

static func shader_mat(path: String) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load(path)
	return sm

## weiche Kreis-Textur (Radialverlauf) fuer Partikel
static func soft_circle(size: int = 64, hardness: float = 0.0) -> ImageTexture:
	var key := "soft_%d_%.2f" % [size, hardness]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.0 + (1.0 - hardness) * 1.5)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

## wolkige Rauch-Textur (Blobs)
static func smoke_tex(size: int = 64) -> ImageTexture:
	var key := "smoke_%d" % size
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var blobs: Array = []
	for i in range(9):
		blobs.append([rng.randf_range(0.28, 0.72), rng.randf_range(0.28, 0.72), rng.randf_range(0.12, 0.26)])
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var u := float(x) / size
			var v := float(y) / size
			var a := 0.0
			for b in blobs:
				var d: float = Vector2(u - b[0], v - b[1]).length() / b[2]
				a = maxf(a, clampf(1.0 - d, 0.0, 1.0))
			var edge := clampf((0.5 - Vector2(u - 0.5, v - 0.5).length()) * 3.0, 0.0, 1.0)
			a = pow(a, 0.8) * edge
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

## Ring-Textur fuer Schockwellen / Selektionsringe
static func ring_tex(size: int = 128, thickness: float = 0.12) -> ImageTexture:
	var key := "ring_%d_%.2f" % [size, thickness]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - absf(d - (1.0 - thickness)) / thickness, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

static func quad_mesh(size: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	return q

## liegende Flaeche (XZ-Ebene)
static func plane_mesh(size: Vector2) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = size
	return p

static func color_variation(c: Color, rng: RandomNumberGenerator, amount: float = 0.06) -> Color:
	var k := rng.randf_range(-amount, amount)
	return Color(clampf(c.r + k, 0, 1), clampf(c.g + k * 0.9, 0, 1), clampf(c.b + k * 0.8, 0, 1), c.a)
