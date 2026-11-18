extends Control
## Character tile. Shows res://art/<folder>/<key>.png when it exists,
## otherwise a coloured tile with the first letter of the name.

var tex: Texture2D = null
var letter := ""
var col := Color.WHITE
var font: Font
var boss := false
var plain := false
var bust := false   # show only the head and shoulders, for the small unit panels
var fit := false    # zoom in on the drawn pixels so small creatures fill the frame
static var bust_cache := {}
static var fit_cache := {}

const OUTLINE := """
shader_type canvas_item;
uniform vec4 line : source_color = vec4(1.0, 0.25, 0.4, 1.0);
uniform float width = 6.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	a = max(a, texture(TEXTURE, UV + px * 0.7).a);
	a = max(a, texture(TEXTURE, UV - px * 0.7).a);
	a = max(a, texture(TEXTURE, UV + vec2(px.x, -px.y) * 0.7).a);
	a = max(a, texture(TEXTURE, UV + vec2(-px.x, px.y) * 0.7).a);
	vec4 rim = vec4(line.rgb, a * line.a);
	COLOR = mix(rim, c, c.a);
}
"""
static var outline_shader: Shader = null


func setup(folder: String, key: String, name_text: String, color: Color, px: float, f: Font, is_boss := false) -> void:
	var path := "res://art/%s/%s.png" % [folder, key]
	if ResourceLoader.exists(path):
		tex = load(path)
	letter = name_text.substr(0, 1)
	col = color
	font = f
	boss = is_boss
	plain = true   # every character is a cut-out sprite standing on its tile
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if plain and tex != null:
		# enemies get a glowing rim so they stand out from the dark field
		if outline_shader == null:
			outline_shader = Shader.new()
			outline_shader.code = OUTLINE
		var m := ShaderMaterial.new()
		m.shader = outline_shader
		var rim := Color("#ff3d6e") if folder == "enemy" else color.lightened(0.25)
		m.set_shader_parameter("line", Color("#ffcf5a") if is_boss else rim)
		m.set_shader_parameter("width", maxf(1.0, 2.0 * tex.get_width() / px))
		material = m
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	if tex != null and plain:
		# cut-out sprite: no tile behind it
		if bust:
			draw_texture_rect_region(tex, Rect2(o, Vector2(s, s)), _bust_region())
		elif fit:
			draw_texture_rect_region(tex, Rect2(o, Vector2(s, s)), _fit_region())
		else:
			draw_texture_rect(tex, Rect2(o, Vector2(s, s)), false)
		return
	var box := StyleBoxFlat.new()
	box.bg_color = col.darkened(0.62)
	box.border_color = Color("#caa24e") if boss else col.darkened(0.15)
	box.set_border_width_all(3)
	box.set_corner_radius_all(2)
	box.anti_aliasing = false
	if tex != null:
		draw_texture_rect(tex, Rect2(o + Vector2(2, 2), Vector2(s - 4, s - 4)), false)
		box.draw_center = false
		draw_style_box(box, Rect2(o, Vector2(s, s)))
	else:
		draw_style_box(box, Rect2(o, Vector2(s, s)))
		if font != null:
			var fs: int = int(s * 0.5)
			draw_string(font, o + Vector2(0, s * 0.5 + fs * 0.36), letter, HORIZONTAL_ALIGNMENT_CENTER, s, fs, col.lightened(0.25))


func _bust_region() -> Rect2:
	if bust_cache.has(tex):
		return bust_cache[tex]
	var full := Rect2(Vector2.ZERO, tex.get_size())
	var out := full
	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var used: Rect2i = img.get_used_rect()
		var q: float = minf(float(used.size.x), float(used.size.y) * 0.56)
		out = Rect2(used.position.x + (used.size.x - q) * 0.5, maxf(0.0, used.position.y - q * 0.06), q, q)
	bust_cache[tex] = out
	return out


func _fit_region() -> Rect2:
	if fit_cache.has(tex):
		return fit_cache[tex]
	var out := Rect2(Vector2.ZERO, tex.get_size())
	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var used: Rect2i = img.get_used_rect()
		var q: float = minf(maxf(float(used.size.x), float(used.size.y)) * 1.08, out.size.x)
		var c := Vector2(used.position) + Vector2(used.size) * 0.5
		out = Rect2((c - Vector2(q, q) * 0.5).clamp(Vector2.ZERO, out.size - Vector2(q, q)), Vector2(q, q))
	fit_cache[tex] = out
	return out
