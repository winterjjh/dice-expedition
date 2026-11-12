extends Control
## Character tile. Shows res://art/<folder>/<key>.png when it exists,
## otherwise a coloured tile with the first letter of the name.

var tex: Texture2D = null
var letter := ""
var col := Color.WHITE
var font: Font
var boss := false


func setup(folder: String, key: String, name_text: String, color: Color, px: float, f: Font, is_boss := false) -> void:
	var path := "res://art/%s/%s.png" % [folder, key]
	if ResourceLoader.exists(path):
		tex = load(path)
	letter = name_text.substr(0, 1)
	col = color
	font = f
	boss = is_boss
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var box := StyleBoxFlat.new()
	box.bg_color = col.darkened(0.62)
	box.border_color = Color("#caa24e") if boss else col.darkened(0.15)
	box.set_border_width_all(3 if boss else 2)
	box.set_corner_radius_all(int(s * 0.14))
	box.anti_aliasing = true
	draw_style_box(box, Rect2(0, 0, s, s))
	if tex != null:
		draw_texture_rect(tex, Rect2(4, 4, s - 8, s - 8), false)
	elif font != null:
		var fs: int = int(s * 0.5)
		draw_string(font, Vector2(0, s * 0.5 + fs * 0.36), letter, HORIZONTAL_ALIGNMENT_CENTER, s, fs, col.lightened(0.25))
