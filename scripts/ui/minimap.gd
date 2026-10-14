class_name Minimap
extends Control
## Minikarte: Stadtplan, sichtbare Einheiten, Kamera-Ausschnitt, Alarme. Linksklick = Kamera, Rechtsklick = Befehl.

var world: World
var player: PlayerController
var rig: RtsCamera
var _base: ImageTexture
var _pings: Array = []     # {pos, kind, t}
var _drag := false
var SIZE := 126.0

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE + 4, SIZE + 4)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.alert.connect(_on_alert)

func bind(w: World, p: PlayerController, r: RtsCamera) -> void:
	world = w
	player = p
	rig = r
	_pings.clear()
	_make_base()

func _on_alert(pos: Vector3, kind: String) -> void:
	_pings.append({"pos": pos, "kind": kind, "t": 0.0})
	if _pings.size() > 12:
		_pings.pop_front()

func _make_base() -> void:
	var city := world.city
	var img := Image.create(200, 200, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.64, 0.56, 0.4))
	var m := city.mask_img.duplicate() as Image
	m.resize(200, 200, Image.INTERPOLATE_BILINEAR)
	for y in range(200):
		for x in range(200):
			var c := m.get_pixel(x, y)
			if c.r > 0.5:
				img.set_pixel(x, y, Color(0.3, 0.3, 0.31))
			elif c.g > 0.5:
				img.set_pixel(x, y, Color(0.74, 0.68, 0.54))
	for b in city.buildings:
		var rect: Rect2 = b.rect
		var col := Color(0.52, 0.45, 0.34)
		if b.kind == "hospital":
			col = Color(0.95, 0.95, 0.95)
		elif b.kind == "school":
			col = Color(0.9, 0.8, 0.45)
		img.fill_rect(Rect2i(int(rect.position.x + 100), int(rect.position.y + 100), maxi(int(rect.size.x), 1), maxi(int(rect.size.y), 1)), col)
	# Basis-Gelaende
	var br := City.BASE_RECT
	img.fill_rect(Rect2i(int(br.position.x + 100), int(br.position.y + 100), int(br.size.x), int(br.size.y)), Color(0.5, 0.5, 0.42))
	_base = ImageTexture.create_from_image(img)

func _w2m(p: Vector3) -> Vector2:
	return Vector2((p.x + 100.0) * SIZE / 200.0 + 2.0, (p.z + 100.0) * SIZE / 200.0 + 2.0)

func _m2w(m: Vector2) -> Vector3:
	return Vector3((m.x - 2.0) * 200.0 / SIZE - 100.0, 0.0, (m.y - 2.0) * 200.0 / SIZE - 100.0)

func _process(dt: float) -> void:
	for p in _pings:
		p.t += dt
	_pings = _pings.filter(func(p): return p.t < 6.0)
	if world != null:
		queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if world == null:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			if mb.pressed:
				rig.jump_to(_m2w(mb.position))
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var wp := _m2w(mb.position)
			var us: Array = player._own_units()
			if not us.is_empty():
				player._formation_order(us, wp, false)
			accept_event()
	elif ev is InputEventMouseMotion and _drag:
		rig.jump_to(_m2w((ev as InputEventMouseMotion).position))
		accept_event()

func _draw() -> void:
	if world == null or _base == null:
		return
	draw_rect(Rect2(0, 0, SIZE + 4, SIZE + 4), Color(0.05, 0.05, 0.05, 0.95))
	draw_texture_rect(_base, Rect2(2, 2, SIZE, SIZE), false)
	var pt := player.team
	# zerstoerte Gebaeude (Truemmer)
	for rc in world.destroyed_rects:
		draw_rect(Rect2(_w2m(Vector3(rc.position.x, 0, rc.position.y)), rc.size * SIZE / 200.0), Color(0.2, 0.17, 0.14))
	# Gebaeude-Marker
	for s in world.structures:
		if not s.alive:
			continue
		if s.team == U.TEAM_ADF:
			draw_rect(Rect2(_w2m(s.position) - Vector2(s.hx, s.hz) * SIZE / 200.0, Vector2(s.hx, s.hz) * 2.0 * SIZE / 200.0), Color(0.3, 0.55, 0.95, 0.9))
		elif s.hub and (pt == U.TEAM_REB or s.revealed):
			var c := Color(1.0, 0.5, 0.1) if pt == U.TEAM_REB else Color(1.0, 0.2, 0.2)
			var mp := _w2m(s.position)
			draw_colored_polygon(PackedVector2Array([mp + Vector2(0, -5), mp + Vector2(5, 0), mp + Vector2(0, 5), mp + Vector2(-5, 0)]), c)
		elif s.hot_t > 0.0 and pt == U.TEAM_ADF:
			draw_circle(_w2m(s.position), 3.0, Color(1.0, 0.4, 0.2))
	# Einheiten
	for u in world.units:
		if not u.alive or not u.visible:
			continue
		var mp2 := _w2m(u.position)
		if u.is_civ:
			draw_rect(Rect2(mp2 - Vector2(1, 1), Vector2(2, 2)), Color(0.85, 0.85, 0.8, 0.8))
		elif u.team == pt and not (u.is_disguised() and false):
			var col := U.team_color(u.team)
			var sz := 3.0 if u.layer == "foot" else 4.0
			draw_rect(Rect2(mp2 - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
		else:
			if u.team == U.TEAM_REB and u.is_disguised():
				draw_rect(Rect2(mp2 - Vector2(1, 1), Vector2(2, 2)), Color(0.85, 0.85, 0.8, 0.8))
			else:
				var col2 := U.team_color(u.team)
				var sz2 := 3.0 if u.layer == "foot" else 4.5
				draw_rect(Rect2(mp2 - Vector2(sz2, sz2) * 0.5, Vector2(sz2, sz2)), col2)
	# Pings
	for p in _pings:
		var c2 := Color(1.0, 0.3, 0.2)
		match p.kind:
			"casualties": c2 = Color(1.0, 0.75, 0.2)
			"identified": c2 = Color(0.4, 1.0, 0.5)
			"base": c2 = Color(1.0, 0.3, 0.2)
			"outrage": c2 = Color(1.0, 0.5, 0.9)
		var k: float = p.t
		var rr := 3.0 + fmod(k * 14.0, 14.0)
		c2.a = clampf(1.0 - k / 6.0, 0.0, 1.0)
		draw_arc(_w2m(p.pos), rr, 0, TAU, 16, c2, 2.0)
	# Kamera-Ausschnitt
	var vp := get_viewport().get_visible_rect().size
	var pts := PackedVector2Array()
	for c in [Vector2(0, 0), Vector2(vp.x, 0), Vector2(vp.x, vp.y * 0.78), Vector2(0, vp.y * 0.78)]:
		var g := rig.ground_point(c)
		pts.append(_w2m(Vector3(clampf(g.x, -100, 100), 0, clampf(g.z, -100, 100))))
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 1, 1, 0.9), 1.4)
	draw_rect(Rect2(1, 1, SIZE + 2, SIZE + 2), Color(0.85, 0.64, 0.25, 0.9), false, 2.0)
