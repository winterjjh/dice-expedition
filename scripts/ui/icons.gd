extends RefCounted
## Skill icons. Uses res://art/skill/<kind>.png when that file exists,
## otherwise draws a simple shape in code so the game never shows an empty face.

class G:
	var ci: CanvasItem
	var r: Rect2
	var col: Color
	var bg: Color

	func _init(item: CanvasItem, rect: Rect2, color: Color, back: Color) -> void:
		ci = item
		r = rect
		col = color
		bg = back

	func sub(x: float, y: float, s: float) -> G:
		return G.new(ci, Rect2(r.position + Vector2(x, y) * r.size, r.size * s), col, bg)

	func inv() -> G:
		return G.new(ci, r, bg, col)

	func pt(x: float, y: float) -> Vector2:
		return r.position + Vector2(x, y) * r.size

	func ln(x1: float, y1: float, x2: float, y2: float, w := 0.09) -> void:
		ci.draw_line(pt(x1, y1), pt(x2, y2), col, maxf(1.0, w * r.size.x), true)

	func pg(a: Array) -> void:
		var pts := PackedVector2Array()
		for i in range(0, a.size(), 2):
			pts.append(pt(float(a[i]), float(a[i + 1])))
		ci.draw_colored_polygon(pts, col)

	func dot(x: float, y: float, rad: float) -> void:
		ci.draw_circle(pt(x, y), rad * r.size.x, col)

	func arc(x: float, y: float, rad: float, a0: float, a1: float, w := 0.08) -> void:
		ci.draw_arc(pt(x, y), rad * r.size.x, a0, a1, 20, col, maxf(1.0, w * r.size.x), true)

	# ----- shapes -----
	func sword() -> void:
		ln(0.26, 0.74, 0.76, 0.24, 0.13)
		pg([0.9, 0.1, 0.68, 0.2, 0.8, 0.32])
		ln(0.2, 0.52, 0.48, 0.8, 0.09)
		dot(0.17, 0.83, 0.07)

	func sword_flip() -> void:
		ln(0.74, 0.74, 0.24, 0.24, 0.13)
		pg([0.1, 0.1, 0.32, 0.2, 0.2, 0.32])
		ln(0.8, 0.52, 0.52, 0.8, 0.09)
		dot(0.83, 0.83, 0.07)

	func shield() -> void:
		pg([0.18, 0.14, 0.82, 0.14, 0.82, 0.55, 0.5, 0.9, 0.18, 0.55])

	func heart() -> void:
		dot(0.34, 0.38, 0.19)
		dot(0.66, 0.38, 0.19)
		pg([0.16, 0.46, 0.84, 0.46, 0.5, 0.88])

	func drop() -> void:
		dot(0.5, 0.62, 0.23)
		pg([0.5, 0.12, 0.71, 0.53, 0.29, 0.53])

	func flame() -> void:
		pg([0.5, 0.08, 0.72, 0.45, 0.78, 0.68, 0.62, 0.9, 0.38, 0.9, 0.22, 0.68, 0.32, 0.4, 0.42, 0.52])

	func snow() -> void:
		ln(0.5, 0.1, 0.5, 0.9, 0.08)
		ln(0.15, 0.3, 0.85, 0.7, 0.08)
		ln(0.15, 0.7, 0.85, 0.3, 0.08)
		dot(0.5, 0.5, 0.1)

	func arrow() -> void:
		ln(0.18, 0.82, 0.74, 0.26, 0.09)
		pg([0.9, 0.1, 0.58, 0.2, 0.8, 0.42])
		ln(0.18, 0.82, 0.18, 0.64, 0.06)
		ln(0.18, 0.82, 0.36, 0.82, 0.06)

	func star(points := 5, inner := 0.2, outer := 0.42) -> void:
		var a := []
		for i in points * 2:
			var rad := outer if i % 2 == 0 else inner
			var ang := -PI / 2.0 + PI * i / points
			a.append(0.5 + cos(ang) * rad)
			a.append(0.5 + sin(ang) * rad)
		pg(a)

	func skull() -> void:
		dot(0.5, 0.42, 0.3)
		pg([0.34, 0.6, 0.66, 0.6, 0.66, 0.86, 0.34, 0.86])
		var o := inv()
		o.dot(0.38, 0.44, 0.08)
		o.dot(0.62, 0.44, 0.08)
		o.ln(0.5, 0.7, 0.5, 0.86, 0.04)

	func target() -> void:
		arc(0.5, 0.5, 0.34, 0.0, TAU, 0.08)
		dot(0.5, 0.5, 0.12)

	func note() -> void:
		ln(0.6, 0.18, 0.6, 0.72, 0.08)
		dot(0.47, 0.74, 0.15)
		ln(0.6, 0.2, 0.82, 0.34, 0.09)

	func orb() -> void:
		dot(0.5, 0.5, 0.32)
		inv().dot(0.4, 0.4, 0.08)

	func leaf() -> void:
		pg([0.5, 0.1, 0.8, 0.45, 0.5, 0.8, 0.2, 0.45])
		ln(0.5, 0.75, 0.5, 0.94, 0.07)

	func chain() -> void:
		arc(0.36, 0.5, 0.18, 0.0, TAU, 0.09)
		arc(0.64, 0.5, 0.18, 0.0, TAU, 0.09)

	func hand() -> void:
		pg([0.28, 0.45, 0.72, 0.45, 0.66, 0.88, 0.34, 0.88])
		ln(0.33, 0.48, 0.33, 0.22, 0.09)
		ln(0.44, 0.48, 0.44, 0.14, 0.09)
		ln(0.56, 0.48, 0.56, 0.14, 0.09)
		ln(0.67, 0.48, 0.67, 0.22, 0.09)

	func cloud() -> void:
		dot(0.33, 0.56, 0.18)
		dot(0.54, 0.44, 0.23)
		dot(0.72, 0.58, 0.16)
		ln(0.3, 0.68, 0.74, 0.68, 0.13)

	func coin() -> void:
		dot(0.5, 0.5, 0.33)
		inv().dot(0.5, 0.5, 0.23)
		dot(0.5, 0.5, 0.12)

	func bolt() -> void:
		pg([0.6, 0.08, 0.28, 0.55, 0.47, 0.55, 0.38, 0.92, 0.74, 0.42, 0.54, 0.42])

	func bricks() -> void:
		for row in 3:
			for c in 3:
				var x := 0.12 + c * 0.27 - (0.1 if row == 1 else 0.0)
				var y := 0.22 + row * 0.21
				pg([x, y, x + 0.23, y, x + 0.23, y + 0.16, x, y + 0.16])

	func spikes() -> void:
		pg([0.14, 0.86, 0.26, 0.3, 0.38, 0.86])
		pg([0.38, 0.86, 0.5, 0.14, 0.62, 0.86])
		pg([0.62, 0.86, 0.74, 0.3, 0.86, 0.86])

	func waves() -> void:
		arc(0.2, 0.5, 0.2, -1.0, 1.0, 0.08)
		arc(0.2, 0.5, 0.42, -0.9, 0.9, 0.08)
		arc(0.2, 0.5, 0.64, -0.8, 0.8, 0.08)

	func rot() -> void:
		arc(0.5, 0.5, 0.3, 0.9, 5.6, 0.09)
		pg([0.86, 0.36, 0.56, 0.3, 0.76, 0.62])

	func die() -> void:
		pg([0.18, 0.18, 0.82, 0.18, 0.82, 0.82, 0.18, 0.82])
		var o := inv()
		o.dot(0.34, 0.34, 0.07)
		o.dot(0.66, 0.66, 0.07)
		o.dot(0.5, 0.5, 0.07)

	func dagger() -> void:
		pg([0.5, 0.08, 0.62, 0.56, 0.38, 0.56])
		ln(0.3, 0.6, 0.7, 0.6, 0.09)
		ln(0.5, 0.6, 0.5, 0.9, 0.1)

	func slashes() -> void:
		ln(0.2, 0.2, 0.5, 0.85, 0.1)
		ln(0.42, 0.14, 0.68, 0.84, 0.1)
		ln(0.64, 0.14, 0.84, 0.74, 0.1)

	func shards() -> void:
		pg([0.2, 0.2, 0.48, 0.3, 0.3, 0.55])
		pg([0.58, 0.14, 0.86, 0.4, 0.6, 0.46])
		pg([0.3, 0.66, 0.56, 0.58, 0.5, 0.9])
		pg([0.66, 0.6, 0.86, 0.7, 0.7, 0.88])


static var cache := {}


static func art(kind: String) -> Texture2D:
	# keep loaded pictures alive: a texture freed before the frame is drawn shows as a white box
	if cache.has(kind):
		return cache[kind]
	var tex: Texture2D = null
	var path := "res://art/skill/%s.png" % kind
	if ResourceLoader.exists(path):
		tex = load(path)
	cache[kind] = tex
	return tex


static func draw(ci: CanvasItem, kind: String, r: Rect2, col: Color, bg: Color) -> void:
	var tex := art(kind)
	if tex != null:
		ci.draw_texture_rect(tex, r, false)
		return
	var g := G.new(ci, r, col, bg)
	match kind:
		"atk": g.sword()
		"shot": g.arrow()
		"multi":
			g.sub(0.0, 0.22, 0.78).arrow()
			g.sub(0.22, 0.0, 0.78).arrow()
		"all":
			g.arc(0.5, 0.62, 0.38, PI * 1.05, PI * 1.95, 0.14)
			g.sub(0.22, 0.32, 0.6).sword()
		"pierce":
			g.arrow()
			g.ln(0.34, 0.34, 0.5, 0.5, 0.06)
			g.ln(0.3, 0.52, 0.48, 0.7, 0.06)
		"momentum":
			g.sub(0.14, 0.0, 0.86).sword()
			g.ln(0.08, 0.36, 0.3, 0.14, 0.06)
			g.ln(0.08, 0.58, 0.2, 0.46, 0.06)
		"guardhit":
			g.sub(0.0, 0.14, 0.62).shield()
			g.sub(0.38, 0.3, 0.66).sword()
		"execute": g.skull()
		"poison": g.drop()
		"steal": g.hand()
		"stun", "hex": g.star()
		"freeze": g.snow()
		"rewind": g.rot()
		"shield": g.shield()
		"shieldadj":
			g.sub(0.0, 0.28, 0.44).shield()
			g.sub(0.56, 0.28, 0.44).shield()
			g.sub(0.25, 0.14, 0.5).shield()
		"taunt":
			g.shield()
			var o := g.inv()
			o.ln(0.5, 0.26, 0.5, 0.54, 0.1)
			o.dot(0.5, 0.68, 0.06)
		"heal": g.heart()
		"healall":
			g.sub(0.0, 0.3, 0.48).heart()
			g.sub(0.52, 0.3, 0.48).heart()
			g.sub(0.24, 0.02, 0.52).heart()
		"seed": g.leaf()
		"link": g.chain()
		"bloodprice":
			g.sub(0.0, 0.2, 0.62).drop()
			g.sub(0.42, 0.06, 0.58).arrow()
		"aim": g.target()
		"heat": g.flame()
		"mana": g.orb()
		"harmony":
			g.sub(0.0, 0.16, 0.72).note()
			g.sub(0.3, 0.0, 0.72).note()
		"echo": g.waves()
		"bash":
			g.sub(0.0, 0.2, 0.7).shield()
			g.sub(0.46, 0.0, 0.56).star(8, 0.22, 0.46)
		"thorns": g.spikes()
		"wall": g.bricks()
		"frenzy": g.slashes()
		"roar":
			g.dot(0.2, 0.5, 0.12)
			g.waves()
		"duel":
			g.sword()
			g.sword_flip()
		"mark":
			g.target()
			g.ln(0.5, 0.5, 0.9, 0.1, 0.07)
		"suppress":
			g.ln(0.5, 0.12, 0.5, 0.6, 0.1)
			g.pg([0.28, 0.5, 0.72, 0.5, 0.5, 0.76])
			g.ln(0.2, 0.86, 0.8, 0.86, 0.09)
		"snipe":
			g.arc(0.5, 0.5, 0.3, 0.0, TAU, 0.07)
			g.ln(0.5, 0.06, 0.5, 0.38, 0.06)
			g.ln(0.5, 0.62, 0.5, 0.94, 0.06)
			g.ln(0.06, 0.5, 0.38, 0.5, 0.06)
			g.ln(0.62, 0.5, 0.94, 0.5, 0.06)
		"backstab": g.dagger()
		"smoke": g.cloud()
		"pilfer": g.coin()
		"ember":
			g.sub(0.08, 0.16, 0.7).flame()
			g.dot(0.8, 0.28, 0.09)
		"firewall":
			g.sub(0.0, 0.2, 0.44).flame()
			g.sub(0.28, 0.06, 0.44).flame()
			g.sub(0.56, 0.2, 0.44).flame()
			g.ln(0.08, 0.84, 0.92, 0.84, 0.1)
		"combust": g.star(8, 0.2, 0.45)
		"shatter": g.shards()
		"icearmor":
			g.shield()
			g.inv().sub(0.25, 0.2, 0.5).snow()
		"cleanse":
			g.star(4, 0.12, 0.44)
			g.sub(0.6, 0.02, 0.36).star(4, 0.12, 0.44)
		"guardian":
			g.shield()
			g.inv().sub(0.27, 0.2, 0.46).heart()
		"encore":
			g.rot()
			g.sub(0.32, 0.32, 0.36).star()
		"discord":
			g.sub(0.0, 0.0, 0.74).note()
			g.sub(0.42, 0.3, 0.6).bolt()
		"retune": g.die()
		_:
			g.ln(0.36, 0.5, 0.64, 0.5, 0.08)
