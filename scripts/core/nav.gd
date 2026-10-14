class_name Nav
extends RefCounted
## Navigationsraster (2m-Zellen) mit zwei A*-Gittern: Fussgaenger und Fahrzeuge (Gebaeude + 1 Zelle Abstand).

const HALF := 160.0
const CELL := 2.0
const N := 160

var foot := AStarGrid2D.new()
var veh := AStarGrid2D.new()
var solid := PackedByteArray()    # 1 = Gebaeude / Mauer
var rubble := PackedByteArray()   # 1 = Truemmer (nur Fahrzeuge blockiert)

func _init() -> void:
	solid.resize(N * N)
	rubble.resize(N * N)
	for g in [foot, veh]:
		g.region = Rect2i(0, 0, N, N)
		g.cell_size = Vector2(CELL, CELL)
		g.offset = Vector2(-HALF + CELL * 0.5, -HALF + CELL * 0.5)
		g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		g.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
		g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
		g.update()
	# Randstreifen sperren (Kartenrand)
	for i in range(N):
		for k in range(1):
			_set_solid(Vector2i(i, k), 1)
			_set_solid(Vector2i(i, N - 1 - k), 1)
			_set_solid(Vector2i(k, i), 1)
			_set_solid(Vector2i(N - 1 - k, i), 1)
	rebuild_vehicle_all()

func idx(c: Vector2i) -> int:
	return c.y * N + c.x

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N

func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor((p.x + HALF) / CELL)), 0, N - 1), clampi(int(floor((p.z + HALF) / CELL)), 0, N - 1))

func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL - HALF + CELL * 0.5, 0.0, c.y * CELL - HALF + CELL * 0.5)

func _set_solid(c: Vector2i, v: int) -> void:
	if not in_bounds(c):
		return
	solid[idx(c)] = v
	foot.set_point_solid(c, v == 1)

## Rechteck (Mittelpunkt, Halbmasse in Weltkoordinaten) sperren/freigeben.
func block_rect(cx: float, cz: float, hx: float, hz: float, blocked: bool) -> void:
	var c0 := world_to_cell(Vector3(cx - hx + 0.01, 0, cz - hz + 0.01))
	var c1 := world_to_cell(Vector3(cx + hx - 0.01, 0, cz + hz - 0.01))
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			var c := Vector2i(x, y)
			if x == 0 or y == 0 or x == N - 1 or y == N - 1:
				continue
			_set_solid(c, 1 if blocked else 0)
	_refresh_veh(c0 - Vector2i(1, 1), c1 + Vector2i(1, 1))

func mark_rubble(cx: float, cz: float, hx: float, hz: float) -> void:
	var c0 := world_to_cell(Vector3(cx - hx + 0.01, 0, cz - hz + 0.01))
	var c1 := world_to_cell(Vector3(cx + hx - 0.01, 0, cz + hz - 0.01))
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			rubble[idx(Vector2i(x, y))] = 1
	_refresh_veh(c0 - Vector2i(1, 1), c1 + Vector2i(1, 1))

func _refresh_veh(a: Vector2i, b: Vector2i) -> void:
	for x in range(maxi(a.x, 0), mini(b.x, N - 1) + 1):
		for y in range(maxi(a.y, 0), mini(b.y, N - 1) + 1):
			var blocked := false
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var c := Vector2i(x + dx, y + dy)
					if not in_bounds(c):
						blocked = true
					elif solid[idx(c)] == 1 or rubble[idx(c)] == 1:
						blocked = true
			# Fahrzeuge duerfen 1-Zellen-Rand (Rubble nur auf der Zelle selbst)
			veh.set_point_solid(Vector2i(x, y), blocked)

func rebuild_vehicle_all() -> void:
	_refresh_veh(Vector2i(0, 0), Vector2i(N - 1, N - 1))

func grid_for(layer: String) -> AStarGrid2D:
	return foot if layer == "foot" else veh

func is_solid_at(p: Vector3, layer: String) -> bool:
	var c := world_to_cell(p)
	if layer == "foot":
		return solid[idx(c)] == 1
	return veh.is_point_solid(c)

## Naechste freie Zelle (Spiralsuche).
func nearest_free_cell(c: Vector2i, layer: String, max_r: int = 14) -> Vector2i:
	var g := grid_for(layer)
	c = Vector2i(clampi(c.x, 0, N - 1), clampi(c.y, 0, N - 1))
	if not g.is_point_solid(c):
		return c
	for r in range(1, max_r + 1):
		var best := Vector2i(-1, -1)
		var best_d := 1e9
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var cc := Vector2i(c.x + dx, c.y + dy)
				if in_bounds(cc) and not g.is_point_solid(cc):
					var d := float(dx * dx + dy * dy)
					if d < best_d:
						best_d = d
						best = cc
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)

func nearest_free_pos(p: Vector3, layer: String, max_r: int = 14) -> Vector3:
	var c := nearest_free_cell(world_to_cell(p), layer, max_r)
	if c.x < 0:
		return p
	if not is_solid_at(p, layer):
		return p
	return cell_to_world(c)

## Sichtlinie auf dem Raster (Bresenham) – fuer Pfadglaettung.
func line_free(a: Vector2i, b: Vector2i, g: AStarGrid2D) -> bool:
	var x0 := a.x
	var y0 := a.y
	var dx := absi(b.x - a.x)
	var dy := absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx - dy
	while true:
		if g.is_point_solid(Vector2i(x0, y0)):
			return false
		if x0 == b.x and y0 == b.y:
			break
		var e2 := 2 * err
		var nx := x0
		var ny := y0
		if e2 > -dy:
			err -= dy
			nx += sx
		if e2 < dx:
			err += dx
			ny += sy
		if nx != x0 and ny != y0:
			# Diagonalschritt: keine Ecken schneiden
			if g.is_point_solid(Vector2i(nx, y0)) or g.is_point_solid(Vector2i(x0, ny)):
				return false
		x0 = nx
		y0 = ny
	return true

func find_path(from: Vector3, to: Vector3, layer: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var g := grid_for(layer)
	var c0 := nearest_free_cell(world_to_cell(from), layer)
	var c1 := nearest_free_cell(world_to_cell(to), layer)
	if c0.x < 0 or c1.x < 0:
		return out
	var pts: PackedVector2Array = g.get_point_path(c0, c1, true)
	if pts.size() == 0:
		return out
	# in Zell-IDs zurueckrechnen fuer die Glaettung
	var cells: Array[Vector2i] = []
	for p in pts:
		cells.append(Vector2i(int(floor((p.x + HALF) / CELL)), int(floor((p.y + HALF) / CELL))))
	var smooth: Array[Vector2i] = []
	var i := 0
	smooth.append(cells[0])
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1:
			if line_free(cells[i], cells[j], g):
				break
			j -= 1
		smooth.append(cells[j])
		i = j
	for k in range(1, smooth.size()):
		out.append(cell_to_world(smooth[k]))
	# letzter Punkt: exakter Zielpunkt, wenn dessen Zelle frei und gleiche Zelle erreicht wurde
	if out.size() > 0 and smooth[smooth.size() - 1] == world_to_cell(to) and not is_solid_at(to, layer):
		out[out.size() - 1] = Vector3(to.x, 0.0, to.z)
	elif out.size() == 0 and not is_solid_at(to, layer):
		out.append(Vector3(to.x, 0.0, to.z))
	return out
