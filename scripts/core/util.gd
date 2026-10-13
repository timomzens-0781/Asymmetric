class_name U
extends RefCounted
## Kleine Helferfunktionen.

const TEAM_ADF := 0   # Aurelische Streitkraefte (Hightech-Supermacht)
const TEAM_REB := 1   # Hadar-Front (Guerilla)
const TEAM_CIV := 2   # Zivilbevoelkerung / neutral

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

static func dist2d(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return sqrt(dx * dx + dz * dz)

static func dist2d_sq(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz

static func dir2d(from: Vector3, to: Vector3) -> Vector3:
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var l := d.length()
	if l < 0.0001:
		return Vector3(0, 0, 1)
	return d / l

static func angle_toward(cur: float, target: float, max_step: float) -> float:
	var diff := wrapf(target - cur, -PI, PI)
	if absf(diff) <= max_step:
		return target
	return cur + signf(diff) * max_step

static func yaw_of(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)

static func rand_in_circle(rng: RandomNumberGenerator, r: float) -> Vector3:
	var a := rng.randf() * TAU
	var d := sqrt(rng.randf()) * r
	return Vector3(cos(a) * d, 0.0, sin(a) * d)

static func team_color(team: int) -> Color:
	match team:
		TEAM_ADF:
			return Color(0.26, 0.55, 0.95)
		TEAM_REB:
			return Color(0.95, 0.5, 0.12)
		_:
			return Color(0.85, 0.85, 0.8)

static func fmt_money(v: float) -> String:
	var n := int(round(v))
	var s := str(absi(n))
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + "$" + out

static func fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%02d:%02d" % [s / 60, s % 60]

## Wahrscheinlichkeitsbasiertes Runden einer Zahl (z.B. fuer Zufallsereignisse).
static func chance(rng: RandomNumberGenerator, p: float) -> bool:
	return rng.randf() < p
