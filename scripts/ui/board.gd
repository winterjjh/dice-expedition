extends Control
## One side's 3x3 battlefield drawn as a floor leaning toward the middle of the screen.
## Units are separate nodes standing on the tiles; this node draws the tiles and
## reports which one the pointer is on.

signal cell_pressed(c: int, r: int)
signal cell_hovered(c: int, r: int)   # (-1, -1) when the pointer leaves

const CW := 140.0     # tile width
const RH := 96.0      # tile depth on screen
const SKEW := 38.0    # sideways shift per row
const HEAD := 78.0    # room above the back row for tall sprites

var side := "hero"
var cells := {}       # Vector2i(c, r) -> {"fill": Color, "edge": Color, "glow": bool, "pulse": bool}
var unit_rects := []  # [{"rect": Rect2, "c": int, "r": int}], back rows first
var hot := Vector2i(-1, -1)
var t := 0.0


func setup(which: String) -> void:
	side = which
	custom_minimum_size = Vector2(CW * 3 + SKEW * 3, HEAD + RH * 3 + 8)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_leave)


func _screen_col(c: int) -> int:
	# column 0 is the front line, next to the other side
	return (2 - c) if side == "hero" else c


func pt(sx: float, sy: float) -> Vector2:
	var shift: float = (3.0 - sy) * SKEW
	if side != "hero":
		shift = SKEW * 3 - shift
	return Vector2(sx * CW + shift, HEAD + sy * RH)


func cell_poly(c: int, r: int) -> PackedVector2Array:
	var sx := float(_screen_col(c))
	return PackedVector2Array([pt(sx, r), pt(sx + 1, r), pt(sx + 1, r + 1), pt(sx, r + 1)])


## Where a unit's feet go on a tile.
func foot(c: int, r: int) -> Vector2:
	return pt(_screen_col(c) + 0.5, r + 0.78)


func cell_centre(c: int, r: int) -> Vector2:
	return pt(_screen_col(c) + 0.5, r + 0.5)


func _process(delta: float) -> void:
	t += delta
	for k in cells:
		if cells[k].get("pulse", false):
			queue_redraw()
			return


func _draw() -> void:
	# slab under the tiles so the floor has thickness
	var slab := PackedVector2Array([pt(0, 0), pt(3, 0), pt(3, 3), pt(0, 3)])
	var under := PackedVector2Array()
	for p in slab:
		under.append(p + Vector2(0, 8))
	draw_colored_polygon(under, Color("#07050f"))
	for r in 3:
		for c in 3:
			var info: Dictionary = cells.get(Vector2i(c, r), {})
			var fill: Color = info.get("fill", Color("#241d47"))
			if Vector2i(c, r) == hot:
				fill = fill.lightened(0.08)
			draw_colored_polygon(cell_poly(c, r), fill)
	for i in 4:
		draw_line(pt(0, i), pt(3, i), Color("#0d0a1c"), 2.0)
		draw_line(pt(i, 0), pt(i, 3), Color("#0d0a1c"), 2.0)
	for k in cells:
		var info2: Dictionary = cells[k]
		var edge: Color = info2.get("edge", Color(0, 0, 0, 0))
		if edge.a <= 0.0:
			continue
		var poly := cell_poly(k.x, k.y)
		poly.append(poly[0])
		var a := 1.0
		if info2.get("pulse", false):
			a = 0.65 + 0.35 * sin(t * 6.0)
		if info2.get("glow", false):
			draw_polyline(poly, Color(edge, 0.18 * a), 12.0)
			draw_polyline(poly, Color(edge, 0.3 * a), 7.0)
		draw_polyline(poly, Color(edge, a), 3.0)


func cell_at(pos: Vector2) -> Vector2i:
	# a sprite is taller than its tile, so the sprite itself counts as its tile
	for i in range(unit_rects.size() - 1, -1, -1):
		if unit_rects[i]["rect"].has_point(pos):
			return Vector2i(int(unit_rects[i]["c"]), int(unit_rects[i]["r"]))
	for r in 3:
		for c in 3:
			if Geometry2D.is_point_in_polygon(pos, cell_poly(c, r)):
				return Vector2i(c, r)
	return Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := cell_at(event.position)
		if cell != hot:
			hot = cell
			queue_redraw()
			cell_hovered.emit(cell.x, cell.y)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell2 := cell_at(event.position)
		if cell2.x >= 0:
			accept_event()
			cell_pressed.emit(cell2.x, cell2.y)


func _leave() -> void:
	if hot.x >= 0:
		hot = Vector2i(-1, -1)
		queue_redraw()
		cell_hovered.emit(-1, -1)
