extends Node
## Audio: gepoolte Soundeffekte (Lautstaerke nach Abstand zum Kamerafokus) und dynamische Musik.

const SFX_DIR := "res://assets/audio/"
const NAMES := [
	"shot_rifle", "shot_mg", "cannon", "rocket", "arty", "arty_far", "explosion_s", "explosion_m", "explosion_l",
	"collapse", "jet", "bomb_fall", "lock", "scan", "ready", "click", "alert", "news", "level_up", "horn", "upload",
	"error", "launch_warn",
]

var listener := Vector3.ZERO
var listener_zoom := 40.0
var master_db := 0.0
var sfx_on := true
var music_on := true
var intensity := 0.0
var _streams: Dictionary = {}
var _pool: Array = []
var _pool_i := 0
var _last_play: Dictionary = {}
var _music_calm: AudioStreamPlayer
var _music_combat: AudioStreamPlayer
var _ui: AudioStreamPlayer
var _music_started := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(20):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_ui = AudioStreamPlayer.new()
	add_child(_ui)
	for n in NAMES:
		var path: String = SFX_DIR + n + ".wav"
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	_music_calm = _make_music("music_calm")
	_music_combat = _make_music("music_combat")

func _make_music(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = -80.0
	add_child(p)
	for ext in ["ogg", "wav"]:
		var path: String = SFX_DIR + n + "." + ext
		if ResourceLoader.exists(path):
			var s = load(path)
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			elif s is AudioStreamWAV:
				(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
				(s as AudioStreamWAV).loop_end = (s as AudioStreamWAV).data.size() / 2
			p.stream = s
			break
	return p

func start_music() -> void:
	if _music_started or not music_on:
		return
	_music_started = true
	if _music_calm.stream != null:
		_music_calm.play()
	if _music_combat.stream != null:
		_music_combat.play()

func stop_music() -> void:
	_music_started = false
	_music_calm.stop()
	_music_combat.stop()

func combat_pulse(v: float) -> void:
	intensity = clampf(intensity + v, 0.0, 1.0)

func _process(dt: float) -> void:
	intensity = maxf(0.0, intensity - dt * 0.05)
	var target_calm := lerpf(-9.0, -26.0, intensity)
	var target_combat := lerpf(-60.0, -9.0, clampf(intensity * 1.3 - 0.1, 0.0, 1.0))
	if not music_on:
		target_calm = -80.0
		target_combat = -80.0
	_music_calm.volume_db = lerpf(_music_calm.volume_db, target_calm, dt * 1.5)
	_music_combat.volume_db = lerpf(_music_combat.volume_db, target_combat, dt * 1.5)

func play_at(n: String, pos: Vector3, vol_db: float = 0.0) -> void:
	if not sfx_on or not _streams.has(n):
		return
	var d := U.dist2d(listener, pos)
	var range_m := 90.0 + listener_zoom * 2.0
	if d > range_m:
		return
	# Drosselung gleichartiger Sounds
	var now := Time.get_ticks_msec()
	var last: int = _last_play.get(n, 0)
	if now - last < 45:
		return
	_last_play[n] = now
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = _streams[n]
	p.volume_db = master_db + vol_db - clampf(d / range_m, 0.0, 1.0) * 24.0
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()
	if n.begins_with("explosion") or n == "cannon" or n == "collapse":
		combat_pulse(0.025)
	elif n.begins_with("shot"):
		combat_pulse(0.004)

func play_ui(n: String, vol_db: float = 0.0) -> void:
	if not sfx_on or not _streams.has(n):
		return
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = _streams[n]
	p.volume_db = master_db + vol_db
	p.pitch_scale = 1.0
	p.play()
