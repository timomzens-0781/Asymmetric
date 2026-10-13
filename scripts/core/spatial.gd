class_name SpatialHash
extends RefCounted
## Einfacher Spatial-Hash (x/z) fuer schnelle Nachbarschaftsabfragen.

var cell := 8.0
var cells: Dictionary = {}
var _stamp := 0

func _init(cell_size: float = 8.0) -> void:
	cell = cell_size

func clear() -> void:
	cells.clear()

func _key(cx: int, cz: int) -> int:
	return (cx + 512) * 1024 + (cz + 512)

func insert(e) -> void:
	var k := _key(int(floor(e.position.x / cell)), int(floor(e.position.z / cell)))
	if cells.has(k):
		cells[k].append(e)
	else:
		cells[k] = [e]

## Fuegt grosse (statische) Objekte in alle Zellen ihres Footprints ein.
func insert_rect(e, half_x: float, half_z: float) -> void:
	var x0 := int(floor((e.position.x - half_x) / cell))
	var x1 := int(floor((e.position.x + half_x) / cell))
	var z0 := int(floor((e.position.z - half_z) / cell))
	var z1 := int(floor((e.position.z + half_z) / cell))
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var k := _key(cx, cz)
			if cells.has(k):
				cells[k].append(e)
			else:
				cells[k] = [e]

func remove_rect(e, half_x: float, half_z: float) -> void:
	var x0 := int(floor((e.position.x - half_x) / cell))
	var x1 := int(floor((e.position.x + half_x) / cell))
	var z0 := int(floor((e.position.z - half_z) / cell))
	var z1 := int(floor((e.position.z + half_z) / cell))
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var k := _key(cx, cz)
			if cells.has(k):
				cells[k].erase(e)

## Liefert alle Eintraege in Zellen, die den Kreis (pos, r) beruehren (ggf. mit Duplikaten
## bei Rect-Eintraegen -> ueber query_unique abfragen).
func query(pos: Vector3, r: float) -> Array:
	var out: Array = []
	var x0 := int(floor((pos.x - r) / cell))
	var x1 := int(floor((pos.x + r) / cell))
	var z0 := int(floor((pos.z - r) / cell))
	var z1 := int(floor((pos.z + r) / cell))
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var k := _key(cx, cz)
			if cells.has(k):
				out.append_array(cells[k])
	return out

func query_unique(pos: Vector3, r: float) -> Array:
	_stamp += 1
	var out: Array = []
	var x0 := int(floor((pos.x - r) / cell))
	var x1 := int(floor((pos.x + r) / cell))
	var z0 := int(floor((pos.z - r) / cell))
	var z1 := int(floor((pos.z + r) / cell))
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var k := _key(cx, cz)
			if cells.has(k):
				for e in cells[k]:
					if e._qstamp != _stamp:
						e._qstamp = _stamp
						out.append(e)
	return out
