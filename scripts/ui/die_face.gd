extends Control
## One die face drawn in code: a bevelled tile with the skill icon, power pips and name.

const Icons = preload("res://scripts/ui/icons.gd")
const IVORY := Color("#f1e8d4")
const INK := Color("#2b231f")
const BRASS := Color("#caa24e")

signal pressed

var kind := "blank"
var n := 0
var label := ""
var col := Color.WHITE
var font: Font
var locked := false
var selected := false
var dim := false
var show_label := true
var clickable := false


func setup(k: String, power: int, text: String, color: Color, px: float, f: Font) -> void:
	kind = k
	n = power
	label = text
	col = color
	font = f
	custom_minimum_size = Vector2(px, px)
	size = custom_minimum_size
	show_label = px >= 72.0
	mouse_filter = Control.MOUSE_FILTER_PASS
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if clickable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func tumble() -> void:
	pivot_offset = custom_minimum_size * 0.5
	scale = Vector2(0.45, 0.45)
	rotation = -1.4
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", 0.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _box(rect: Rect2, fill: Color, border: Color, radius: int, bw: int) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	draw_style_box(s, rect)


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var rad := int(s * 0.16)
	var depth: float = maxf(2.0, s * 0.07)
	var face_col := IVORY if kind != "blank" else Color("#b9bdb4")
	var edge := col
	if locked:
		edge = BRASS
	if selected:
		edge = Color.WHITE
	if dim:
		face_col = face_col.darkened(0.5)
		edge = edge.darkened(0.4)
	var bw: int = maxi(1, int(s * (0.07 if (locked or selected) else 0.045)))
	_box(Rect2(0, depth, s, s - depth), face_col.darkened(0.4), edge.darkened(0.35), rad, bw)
	_box(Rect2(0, 0, s, s - depth), face_col, edge, rad, bw)
	var h: float = s - depth
	var icol := col.darkened(0.3)
	if dim:
		icol = icol.darkened(0.35)
	var has_label: bool = show_label and label != ""
	var label_h: float = s * 0.24 if has_label else 0.0
	var pad: float = s * 0.12
	var isz: float = h - pad * 1.5 - label_h
	var ix: float = (s - isz) * 0.5 - (s * 0.06 if n > 0 else 0.0)
	Icons.draw(self, kind, Rect2(ix, pad * 0.8, isz, isz), icol, face_col)
	if n > 0:
		var ps: float = maxf(2.0, s * 0.08)
		var px: float = s - bw - ps * 1.7
		var base_y: float = h - label_h - ps * 1.6
		if n <= 6:
			for i in n:
				draw_rect(Rect2(px, base_y - i * ps * 1.4, ps, ps), icol)
		elif font != null:
			var fs: int = maxi(8, int(s * 0.2))
			draw_string(font, Vector2(s - bw - fs * 1.5, pad + fs), str(n), HORIZONTAL_ALIGNMENT_RIGHT, fs * 1.4, fs, icol)
	if has_label and font != null:
		var fs2: int = maxi(8, int(s * 0.15))
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		if w > s - 8.0:
			fs2 = maxi(8, int(fs2 * (s - 8.0) / w))
		draw_string(font, Vector2(0, h - s * 0.085), label, HORIZONTAL_ALIGNMENT_CENTER, s, fs2, INK if not dim else Color("#151210"))
	if locked and show_label and font != null:
		var fs3: int = maxi(8, int(s * 0.12))
		draw_string(font, Vector2(bw + 4, bw + fs3 + 1), "고정", HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, BRASS.darkened(0.35))
