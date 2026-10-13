class_name CmdButton
extends Control
## Quadratischer HUD-Button mit Piktogramm, Hotkey, Kosten, Abklingzeit-Ueberlagerung und Tooltip.

signal pressed
signal right_pressed
signal hover_changed(btn: CmdButton, hovered: bool)

var icon := ""
var label := ""
var hotkey := ""
var cost := -1.0
var tip_title := ""
var tip_text := ""
var enabled := true
var cooldown := 0.0
var cooldown_total := 1.0
var active := false
var accent := Color(0.85, 0.64, 0.25)
var badge := ""
var progress := -1.0
var center_text := false
var hovered := false
var _sb := StyleBoxFlat.new()

func _init() -> void:
	custom_minimum_size = Vector2(66, 66)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sb.set_corner_radius_all(5)
	_sb.set_border_width_all(2)

func _ready() -> void:
	mouse_entered.connect(func():
		hovered = true
		hover_changed.emit(self, true)
		queue_redraw())
	mouse_exited.connect(func():
		hovered = false
		hover_changed.emit(self, false)
		queue_redraw())

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			right_pressed.emit()
			accept_event()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var base := Color(0.13, 0.12, 0.11, 0.96)
	if active:
		base = Color(0.3, 0.22, 0.08, 0.98)
	elif hovered and enabled:
		base = Color(0.2, 0.18, 0.15, 0.98)
	_sb.bg_color = base
	_sb.border_color = accent if (hovered or active) and enabled else Color(0.38, 0.33, 0.24, 1.0)
	if not enabled:
		_sb.border_color = Color(0.25, 0.23, 0.2)
	draw_style_box(_sb, r)
	var ic := Color(0.93, 0.88, 0.76) if enabled else Color(0.45, 0.42, 0.38)
	if icon != "":
		var ir := r.grow(-size.x * 0.2)
		ir.position.y -= size.y * 0.04
		Icons.draw(self, icon, ir, ic)
	var font := ThemeDB.fallback_font
	if hotkey != "":
		draw_string(font, Vector2(5, 14), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.64, 0.25, 0.95))
	if label != "":
		if center_text:
			draw_string(font, Vector2(0, size.y * 0.5 + 5), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(0.93, 0.88, 0.76))
		else:
			draw_string(font, Vector2(0, size.y - 17), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color(0.85, 0.82, 0.74, 0.9))
	if cost > 0.0:
		var col := Color(0.55, 0.9, 0.5) if enabled else Color(0.9, 0.4, 0.35)
		draw_string(font, Vector2(0, size.y - 5), U.fmt_money(cost), HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, col)
	if badge != "":
		draw_circle(Vector2(size.x - 11, 12), 9, Color(0.85, 0.64, 0.25))
		draw_string(font, Vector2(size.x - 20, 16), badge, HORIZONTAL_ALIGNMENT_CENTER, 18, 12, Color(0.1, 0.08, 0.05))
	if progress >= 0.0:
		draw_rect(Rect2(4, size.y - 8, (size.x - 8) * clampf(progress, 0, 1), 4), Color(0.4, 0.85, 0.45))
	if cooldown > 0.0:
		var f := clampf(cooldown / maxf(cooldown_total, 0.01), 0.0, 1.0)
		draw_rect(Rect2(2, 2, size.x - 4, (size.y - 4) * f), Color(0, 0, 0, 0.62))
		draw_string(font, Vector2(0, size.y * 0.5 + 6), "%d" % ceil(cooldown), HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(1, 1, 1, 0.9))

func set_state(en: bool, cd: float = 0.0, cd_total: float = 1.0) -> void:
	if en != enabled or cd != cooldown:
		enabled = en
		cooldown = cd
		cooldown_total = cd_total
		queue_redraw()
