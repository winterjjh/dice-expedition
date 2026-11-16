extends Control
## The rolling tray: a sunken felt board under the battlefield where the party's dice land.

const WOOD := Color("#3a2a4e")
const WOOD_HI := Color("#5b4577")
const FELT := Color("#141a33")
const FELT_HI := Color("#1c2547")

var slots := 4
var slot_cols := []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(0, 4, size.x, size.y - 4), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(0, 0, size.x, size.y - 4), WOOD)
	draw_rect(Rect2(0, 0, size.x, 3), WOOD_HI)
	var inner := Rect2(8, 8, size.x - 16, size.y - 20)
	draw_rect(inner, FELT)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 5)), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(inner.position, Vector2(5, inner.size.y)), Color(0, 0, 0, 0.35))
	# felt weave
	var y := inner.position.y + 10.0
	while y < inner.end.y - 4.0:
		draw_rect(Rect2(inner.position.x + 8, y, inner.size.x - 16, 2), Color(FELT_HI, 0.5))
		y += 12.0
	# where each die comes to rest
	var w: float = inner.size.x / float(slots)
	for i in slots:
		var c := Vector2(inner.position.x + w * (i + 0.5), inner.position.y + inner.size.y * 0.5 + 2.0)
		var col: Color = slot_cols[i] if i < slot_cols.size() else Color.WHITE
		var half := 46.0
		draw_rect(Rect2(c - Vector2(half, half - 2.0), Vector2(half * 2.0, half * 2.0 - 4.0)), Color(col, 0.10))
		draw_rect(Rect2(c - Vector2(half, half - 2.0), Vector2(half * 2.0, half * 2.0 - 4.0)), Color(col, 0.35), false, 2.0)
