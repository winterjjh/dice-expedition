extends Control
## Curved lines from each enemy to the hero it is aiming at.

var links := []


func set_links(list: Array) -> void:
	links = list
	queue_redraw()


func _draw() -> void:
	for l in links:
		var a: Vector2 = l["a"]
		var b: Vector2 = l["b"]
		var c: Color = l["col"]
		var mid: Vector2 = (a + b) * 0.5 + Vector2(0, -50)
		var pts := PackedVector2Array()
		for i in 25:
			var t: float = i / 24.0
			pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
		draw_polyline(pts, c, 3.0, true)
		draw_circle(b, 7.0, c)
		draw_circle(a, 4.0, c)
