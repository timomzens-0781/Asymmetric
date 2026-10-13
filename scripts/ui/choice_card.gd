class_name ChoiceCard
extends Control
## Grosse Auswahlkarte fuer das Hauptmenue (Seitenwahl).

signal chosen

var title := ""
var subtitle := ""
var body := ""
var icons: Array = []
var accent := Color(0.3, 0.55, 0.95)
var details: Array = []
var _hover := false
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func(): _hover = false)

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		chosen.emit()
		accept_event()

func _wrap(text: String, font: Font, fs: int, width: float) -> Array:
	var words := text.split(" ")
	var lines: Array = []
	var cur := ""
	for w in words:
		var t := (cur + " " + w) if cur != "" else w
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			lines.append(cur)
			cur = w
		else:
			cur = t
	if cur != "":
		lines.append(cur)
	return lines

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var r := Rect2(Vector2.ZERO, size)
	var bg := Color(0.07, 0.065, 0.06, 0.93)
	if _hover:
		bg = Color(0.11, 0.1, 0.085, 0.96)
	draw_rect(r, bg)
	# Akzentstreifen oben
	draw_rect(Rect2(0, 0, size.x, 6), accent)
	var edge := accent if _hover else Color(accent.r, accent.g, accent.b, 0.45)
	draw_rect(r, edge, false, 3.0 if _hover else 2.0)
	# Symbole
	var x := 22.0
	for ic in icons:
		draw_rect(Rect2(x, 24, 62, 62), Color(0.12, 0.11, 0.1))
		draw_rect(Rect2(x, 24, 62, 62), Color(accent.r, accent.g, accent.b, 0.7), false, 1.5)
		Icons.draw(self, ic, Rect2(x + 8, 32, 46, 46), accent.lightened(0.25))
		x += 70.0
	draw_string(font, Vector2(22, 118), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 26, Color(0.96, 0.92, 0.82))
	draw_string(font, Vector2(22, 142), subtitle, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 14, accent.lightened(0.3))
	var y := 172.0
	for ln in _wrap(body, font, 14, size.x - 44):
		draw_string(font, Vector2(22, y), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.82, 0.74))
		y += 20.0
	y += 8.0
	for d in details:
		draw_string(font, Vector2(22, y), "▸ " + d, HORIZONTAL_ALIGNMENT_LEFT, size.x - 44, 13, Color(0.75, 0.72, 0.62))
		y += 19.0
	# Button-Zeile
	var br := Rect2(22, size.y - 56, size.x - 44, 38)
	draw_rect(br, accent if _hover else Color(accent.r, accent.g, accent.b, 0.55))
	var tw := font.get_string_size("EINSATZ WÄHLEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(br.position.x + (br.size.x - tw) * 0.5, br.position.y + 25), "EINSATZ WÄHLEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.05, 0.05, 0.05))
