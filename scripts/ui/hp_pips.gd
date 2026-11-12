extends Control
## Health shown as counted pips (small parties and monsters) or a bar (big monsters).
## Shield is drawn as extra outlined pips after the health.

var hp := 0
var maxhp := 1
var shield := 0
var col := Color.RED
var pip := 12.0
var gap := 2.0
var per_row := 10
var bar := false
var bar_w := 180.0


func setup(value: int, maxv: int, guard: int, color: Color, width: float) -> void:
	hp = value
	maxhp = maxi(1, maxv)
	shield = guard
	col = color
	bar_w = width
	bar = maxhp > 30
	if bar:
		custom_minimum_size = Vector2(width, 14)
	else:
		if maxhp > 20:
			pip = 9.0
			per_row = 15
		elif maxhp > 10:
			pip = 11.0
			per_row = 10
		var total: int = maxhp + mini(shield, per_row)
		var rows: int = int(ceil(float(total) / per_row))
		custom_minimum_size = Vector2(per_row * (pip + gap), rows * (pip + gap))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var empty := Color("#0c1916")
	if bar:
		draw_rect(Rect2(0, 0, bar_w, 12), empty)
		draw_rect(Rect2(0, 0, bar_w * float(hp) / maxhp, 12), col)
		draw_rect(Rect2(0, 0, bar_w, 12), col.darkened(0.5), false, 1.0)
		return
	var total: int = maxhp + mini(shield, per_row)
	for i in total:
		var x: float = (i % per_row) * (pip + gap)
		var y: float = (i / per_row) * (pip + gap)
		var r := Rect2(x, y, pip, pip)
		if i < maxhp:
			draw_rect(r, col if i < hp else empty)
			draw_rect(r, col.darkened(0.45), false, 1.0)
		else:
			draw_rect(r, Color("#77a9cc"))
			draw_rect(r, Color("#d7ecfa"), false, 1.0)
