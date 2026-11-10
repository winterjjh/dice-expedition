extends Control
## Draws the branching act map and places one round button per node.

signal chosen(r: int, c: int)

const ROWS := 7
const COLS := 4
const C_LINE := Color("#2d4a43")
const C_WALK := Color("#caa24e")
const NODE_COLOR := {
	"fight": Color("#f1e8d4"), "elite": Color("#d65a4a"), "forge": Color("#77a9cc"),
	"shop": Color("#caa24e"), "event": Color("#a988e0"), "boss": Color("#caa24e"),
}

var run: Dictionary
var open := []
var buttons := {}


func setup(run_state: Dictionary, open_list: Array, node_info: Dictionary) -> void:
	run = run_state
	open = open_list
	for r in ROWS:
		for c in COLS:
			var n = run["map"][r][c]
			if n != null:
				_make_button(r, c, n["type"], node_info)
	_make_button(ROWS, 0, "boss", node_info)
	resized.connect(_layout)
	_layout()


func _is_open(r: int, c: int) -> bool:
	for o in open:
		if int(o[0]) == r and int(o[1]) == c:
			return true
	return false


func _visited(r: int, c: int) -> bool:
	return ("%d,%d" % [r, c]) in run["path"]


func _make_button(r: int, c: int, type: String, node_info: Dictionary) -> void:
	var b := Button.new()
	var big := type == "boss"
	b.custom_minimum_size = Vector2(56, 56) if big else Vector2(44, 44)
	b.size = b.custom_minimum_size
	b.text = node_info[type]["ch"]
	b.tooltip_text = node_info[type]["name"]
	var col: Color = NODE_COLOR[type]
	var op := _is_open(r, c)
	var vis := _visited(r, c)
	var bg := Color("#caa24e") if vis else Color("#19302b")
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(30)
	s.set_border_width_all(3 if op else 2)
	s.border_color = Color("#f1e8d4") if op else C_LINE
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("disabled", s)
	var hs := s.duplicate()
	hs.bg_color = C_LINE
	b.add_theme_stylebox_override("hover", hs)
	b.add_theme_stylebox_override("pressed", hs)
	b.add_theme_color_override("font_color", Color("#1b1408") if vis else col)
	b.add_theme_color_override("font_disabled_color", Color("#1b1408") if vis else col)
	b.disabled = not op
	if not op and not vis and int(run["pos"][0]) >= r:
		b.modulate = Color(1, 1, 1, 0.35)
	if op:
		b.pressed.connect(func(): chosen.emit(r, c))
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "self_modulate", Color(1, 1, 1, 0.55), 0.6)
		tw.tween_property(b, "self_modulate", Color(1, 1, 1, 1.0), 0.6)
	add_child(b)
	buttons[Vector2i(r, c)] = b


func node_pos(r: int, c: int) -> Vector2:
	var w := size.x
	var h := size.y
	var gap: float = min(120.0, w / 5.0)
	var cx := w * 0.5 + (c - 1.5) * gap
	if r == ROWS:
		cx = w * 0.5
	var y := h - 34.0 - r * ((h - 68.0) / ROWS)
	return Vector2(cx, y)


func _layout() -> void:
	for key in buttons:
		var b: Button = buttons[key]
		b.position = node_pos(key.x, key.y) - b.size * 0.5
	queue_redraw()


func _draw() -> void:
	for r in ROWS:
		for c in COLS:
			var n = run["map"][r][c]
			if n == null:
				continue
			var a := node_pos(r, c)
			if r < ROWS - 1:
				for nc in n["next"]:
					var walked := _visited(r, c) and _visited(r + 1, int(nc))
					draw_line(a, node_pos(r + 1, int(nc)), C_WALK if walked else C_LINE, 4.0 if walked else 2.0, true)
			else:
				draw_line(a, node_pos(ROWS, 0), C_LINE, 2.0, true)
