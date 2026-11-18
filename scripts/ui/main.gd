extends Control
## Screen manager. Every screen is built in code from the Data/Game autoloads,
## so balance lives in res://data/*.json and layout lives here.

const Combat = preload("res://scripts/combat.gd")
const DieFace = preload("res://scripts/ui/die_face.gd")
const HpPips = preload("res://scripts/ui/hp_pips.gd")
const Portrait = preload("res://scripts/ui/portrait.gd")
const LinkLayer = preload("res://scripts/ui/link_layer.gd")
const TRAY_DIE := 76.0
const ROLE_COL := {"front": Color("#77a9cc"), "shooter": Color("#a9c64a"), "mage": Color("#a988e0"), "support": Color("#8cc47a")}
const ECAT := {"atk": "atk", "all": "atk", "shield": "def", "heal": "heal", "poison": "poison", "hex": "trick", "blank": "blank"}

const C_BG := Color("#0c0a1c")
const C_PANEL := Color("#221c40")
const C_PANEL2 := Color("#15112b")
const C_LINE := Color("#453b78")
const C_IVORY := Color("#f1e8d4")
const C_INK := Color("#2b231f")
const C_BRASS := Color("#e6bb52")
const C_TEXT := Color("#e8e4f5")
const C_MUTED := Color("#9d95c2")
const C_GLOW := Color("#5fe0ff")    # selectable things glow cyan
const C_DANGER := Color("#ff4f9a")  # threatened tiles glow magenta
const CAT := {
	"atk": Color("#d65a4a"), "def": Color("#77a9cc"), "heal": Color("#8cc47a"),
	"mana": Color("#a988e0"), "poison": Color("#a9c64a"), "trick": Color("#e0b850"),
	"blank": Color("#7d8781"), "hurt": Color("#e06a58"),
}

var font: Font
var bold: Font
var mid_font: Font
var pool_tex: GradientTexture2D
var pool_mat: CanvasItemMaterial
var anim := true   # tests switch this off so handlers run without waiting
var root: VBoxContainer
var fx: Control
var overlay: Control = null
var combat = null
var sel := -1
var armed_spell := ""
var busy := false
var enemy_cards := {}
var hero_cards := {}
var message := ""
var links: Control
var backdrop: TextureRect
var backdrop_dim: ColorRect
var info_lbl: Label = null
var info_default := ""
var arena: Control = null      # the open middle of the fight screen where loose dice lie
var arena_dice := []           # dice to drop into the arena once it has its size
var tipbox: CenterContainer = null
const PANEL_W := 300.0
const CELL_W := 150.0
const CELL_H := 128.0
const SLOT := 64.0
const ARENA_DIE := 84.0
var move_mode := false
var move_sel := -1


func _ready() -> void:
	font = _pixel_font("res://fonts/Galmuri11.ttf")
	bold = _pixel_font("res://fonts/Galmuri11-Bold.ttf")
	mid_font = _pixel_font("res://fonts/Galmuri14.ttf")
	theme = _make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	backdrop = TextureRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop_dim = ColorRect.new()
	backdrop_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_dim.color = Color(0, 0, 0, 0)
	add_child(backdrop_dim)
	var vg := GradientTexture2D.new()
	var vgrad := Gradient.new()
	vgrad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	vgrad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.0, 0.08, 0.0), Color(0.02, 0.0, 0.08, 0.9)])
	vg.gradient = vgrad
	vg.fill = GradientTexture2D.FILL_RADIAL
	vg.fill_from = Vector2(0.5, 0.5)
	vg.fill_to = Vector2(1.05, 0.5)
	var vignette := TextureRect.new()
	vignette.texture = vg
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	# slow glowing motes drifting up through every screen
	var motes := CPUParticles2D.new()
	motes.amount = 46
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(760, 420)
	motes.position = Vector2(640, 420)
	motes.direction = Vector2(0, -1)
	motes.spread = 40.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 5.0
	motes.initial_velocity_max = 16.0
	motes.scale_amount_min = 2.0
	motes.scale_amount_max = 4.0
	var tint := Gradient.new()
	tint.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	tint.colors = PackedColorArray([Color("#ff4fc3"), Color("#b98cff"), Color("#5fe0ff")])
	motes.color_initial_ramp = tint
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	motes.color_ramp = fade
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	motes.material = add_mat
	add_child(motes)
	var pg := Gradient.new()
	pg.offsets = PackedFloat32Array([0.0, 1.0])
	pg.colors = PackedColorArray([Color(1, 1, 1, 0.75), Color(1, 1, 1, 0)])
	pool_tex = GradientTexture2D.new()
	pool_tex.gradient = pg
	pool_tex.fill = GradientTexture2D.FILL_RADIAL
	pool_tex.fill_from = Vector2(0.5, 0.5)
	pool_tex.fill_to = Vector2(1.0, 0.5)
	pool_mat = add_mat
	links = LinkLayer.new()
	links.set_anchors_preset(Control.PRESET_FULL_RECT)
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(links)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	fx = Control.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx)
	show_title()


func _unhandled_key_input(event: InputEvent) -> void:
	# test shortcut: F9 starts a fight with a random party, F10 a boss fight
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F9, KEY_F10]:
		_random_party()
		var keys := []
		for role in Data.ROLES:
			keys.append(party_choice[role["key"]])
		Game.new_run(keys, Data)
		if event.keycode == KEY_F10:
			Game.run["stage"] = 7
		begin_stage()


# =============== theme & widget helpers ===============

func _pixel_font(path: String) -> Font:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


## Pixel fonts only look right at their own sizes, so every text size snaps to
## one of them: 12 and 24 (Galmuri11), 15 and 30 (Galmuri14), 36.
func pf(size: int, is_bold := false) -> Array:
	if size <= 13:
		return [bold if is_bold else font, 12]
	if size <= 19:
		return [mid_font, 15]
	if size <= 27:
		return [bold if is_bold else font, 24]
	if size <= 33:
		return [mid_font, 30]
	return [bold if is_bold else font, 36]


func sb(bg: Color, border: Color, radius := 8, bw := 1, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(maxi(bw, 2) if bw > 0 else 0)
	s.set_corner_radius_all(mini(radius, 2))
	s.anti_aliasing = false
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s


## Soft coloured light around a panel, used for anything that should read as lit.
func glow(s: StyleBoxFlat, col: Color, size := 8, alpha := 0.55) -> StyleBoxFlat:
	s.shadow_color = Color(col, alpha)
	s.shadow_size = size
	return s


## Chunky key-cap button: a thick lower edge that flattens when pressed.
func kb(bg: Color, edge: Color, down := false, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(2)
	s.border_width_bottom = 2 if down else 6
	s.set_corner_radius_all(2)
	s.anti_aliasing = false
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = 7 + (4 if down else 0)
	s.content_margin_bottom = 7
	return s


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = mid_font
	th.default_font_size = 15
	var key := Color("#3a3168")
	var edge := Color("#0d0a1c")
	th.set_stylebox("normal", "Button", kb(key, edge))
	th.set_stylebox("hover", "Button", kb(key.lightened(0.12), C_BRASS))
	th.set_stylebox("pressed", "Button", kb(key.darkened(0.1), C_BRASS, true))
	th.set_stylebox("disabled", "Button", kb(Color(key, 0.35), Color(edge, 0.5)))
	th.set_stylebox("focus", "Button", sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 2, 0))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(k, "Button", C_TEXT)
	th.set_color("font_disabled_color", "Button", Color(C_MUTED, 0.45))
	th.set_color("font_color", "Label", C_TEXT)
	th.set_stylebox("panel", "PanelContainer", sb(C_PANEL, C_LINE, 2, 2, 12))
	th.set_stylebox("panel", "TooltipPanel", sb(C_PANEL2, C_BRASS, 2, 2, 8))
	th.set_color("font_color", "TooltipLabel", C_TEXT)
	th.set_font_size("font_size", "TooltipLabel", 15)
	return th


func set_backdrop(key: String, dim := 0.55) -> void:
	var path := "res://art/bg/%s.jpg" % key
	if key != "" and ResourceLoader.exists(path):
		backdrop.texture = load(path)
		var night: bool = key.begins_with("act")
		backdrop.modulate = Color(0.62, 0.55, 1.0) if night else Color.WHITE
		backdrop_dim.color = Color(0.05, 0.02, 0.14, dim) if night else Color(0.03, 0.02, 0.08, dim)
	else:
		backdrop.texture = null
		backdrop_dim.color = Color(0, 0, 0, 0)


func ui_icon(parent: Node, key: String, px: float) -> void:
	var path := "res://art/ui/%s.png" % key
	if not ResourceLoader.exists(path):
		return
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)


func clear_screen() -> void:
	close_overlay()
	set_backdrop("")
	enemy_cards.clear()
	hero_cards.clear()
	arena = null
	tipbox = null
	arena_dice = []
	info_lbl = null
	if links != null:
		links.set_links([])
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()


func lbl(parent: Node, text: String, size := 18, color := C_TEXT, is_bold := false, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	var fs := pf(size, is_bold)
	l.add_theme_font_override("font", fs[0])
	l.add_theme_font_size_override("font_size", fs[1])
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


func btn(parent: Node, text: String, cb: Callable, primary := false, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	if primary:
		var edge := Color("#6b4f1c")
		b.add_theme_stylebox_override("normal", kb(C_BRASS, edge))
		b.add_theme_stylebox_override("hover", kb(C_BRASS.lightened(0.18), edge))
		b.add_theme_stylebox_override("pressed", kb(C_BRASS.darkened(0.1), edge, true))
		b.add_theme_stylebox_override("disabled", kb(Color(C_BRASS.darkened(0.45), 0.6), Color(edge, 0.6)))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, Color("#1b1408"))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func choice(parent: Node, title: String, sub: String, cb: Callable, disabled := false, on := false) -> Button:
	var b := Button.new()
	b.text = title + ("\n" + sub if sub != "" else "")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = disabled
	b.add_theme_stylebox_override("normal", sb(C_PANEL2, C_BRASS if on else C_LINE, 10, 2 if on else 1, 14))
	b.add_theme_stylebox_override("hover", sb(C_LINE, C_BRASS, 10, 1, 14))
	b.add_theme_stylebox_override("disabled", sb(Color(C_PANEL2, 0.5), Color(C_LINE, 0.5), 10, 1, 14))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func hb(parent: Node, sep := 10, center := false) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	if center:
		h.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(h)
	return h


func vb(parent: Node, sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v


func panel(parent: Node, border := C_LINE) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(C_PANEL, border, 10, 1, 14))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v


func scroll_area(parent: Node) -> VBoxContainer:
	var s := ScrollContainer.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(s)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	s.add_child(v)
	return v


func spacer(parent: Node) -> void:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)


func chip(parent: Node, face: Dictionary, highlight := false) -> Control:
	var col: Color = CAT[Data.face_cat(face)]
	var p := PanelContainer.new()
	var st := sb(Color(col, 0.22) if highlight else Color(0, 0, 0, 0), col if highlight else Color(col, 0.45), 6, 1, 4)
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", st)
	p.tooltip_text = Data.face_desc(face)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(p)
	var h := hb(p, 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d = make_die(h, face, 26.0)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := lbl(h, Data.face_title(face), 14, col, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func make_die(parent: Node, face: Dictionary, px: float) -> Control:
	var d = DieFace.new()
	var num := 0
	if not face["k"] in Data.NO_NUMBER:
		num = int(face["n"])
	d.setup(str(face["k"]), num, Data.face_name(face), CAT[Data.face_cat(face)], px, bold)
	d.tooltip_text = Data.face_desc(face)
	parent.add_child(d)
	return d


func face_row(parent: Node, p: Dictionary, current := -1) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	parent.add_child(row)
	for i in 6:
		chip(row, Data.hero_face(p, i), i == current)
	return row


func hp_bar(parent: Node, value: int, maxv: int, col: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = max(1, maxv)
	pb.value = value
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 12)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.add_theme_stylebox_override("background", sb(Color("#0d0a1c"), C_LINE, 5, 1, 0))
	pb.add_theme_stylebox_override("fill", sb(col, col, 5, 0, 0))
	parent.add_child(pb)
	return pb


func top_bar(in_fight := false) -> void:
	var h := hb(root, 12)
	if in_fight and combat != null:
		var tl := lbl(h, "%d턴" % combat.turn, 24, C_BRASS, true)
		tl.custom_minimum_size = Vector2(150, 0)
	else:
		lbl(h, "주사위 원정대", 24, C_BRASS, true)
	if Game.run != null:
		# the whole run at a glance: twenty fights, bosses marked, the current one lit
		var cur := int(Game.run["stage"])
		var strip := hb(h, 3)
		strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strip.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in Game.stage_count():
			var boss: bool = Game.is_boss_stage(i)
			var box := PanelContainer.new()
			var fill := Color("#1c1838")
			var edge := C_LINE
			if i < cur:
				fill = C_BRASS.darkened(0.25)
				edge = C_BRASS
			elif boss:
				fill = Color("#4d1846")
				edge = C_DANGER
			var st := sb(fill, edge, 0, 2, 0)
			if i == cur:
				st = glow(sb(Color("#123c4a"), C_GLOW, 0, 2, 0), C_GLOW, 8)
			st.content_margin_top = 0
			st.content_margin_bottom = 0
			box.add_theme_stylebox_override("panel", st)
			box.custom_minimum_size = Vector2(34 if boss else 26, 26)
			box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			box.tooltip_text = "%d번째 전투%s" % [i + 1, " · 보스" if boss else ""]
			strip.add_child(box)
			var num := lbl(box, "왕" if boss else str(i + 1), 12, Color("#14110f") if i < cur else (C_TEXT if i == cur else C_MUTED), true)
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		btn(h, "원정대 보기", show_party_overlay)
	else:
		spacer(h)


func open_overlay(title: String) -> VBoxContainer:
	close_overlay()
	overlay = ColorRect.new()
	overlay.color = Color(0.02, 0.06, 0.05, 0.86)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(C_PANEL, C_BRASS, 14, 1, 20))
	p.custom_minimum_size = Vector2(min(820.0, get_viewport_rect().size.x - 40), min(600.0, get_viewport_rect().size.y - 40))
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var top := hb(v)
	lbl(top, title, 24, C_BRASS, true)
	spacer(top)
	btn(top, "닫기", close_overlay)
	return scroll_area(v)


func close_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null


# =============== title & party ===============

var party_choice := {}
var promo_choice := {}
var offer := []   # the choices shown on the current reward screen


func show_title() -> void:
	Game.run = null
	combat = null
	clear_screen()
	set_backdrop("title", 0.5)
	var c := CenterContainer.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(c)
	var v := vb(c, 18)
	var dice := hb(v, 12, true)
	for f in [{"k": "taunt", "n": 1}, {"k": "steal", "n": 0}, {"k": "heat", "n": 2}, {"k": "seed", "n": 2}]:
		make_die(dice, f, 88.0)
	var t := lbl(v, "주사위 원정대", 54, C_BRASS, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := lbl(v, "영웅 넷이 저마다 다른 직업 주사위를 굴려 싸우는 원정.\n스무 번의 전투를 이어서 이기면 승리. 한 번 지면 처음부터.", 18, C_TEXT)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for l in [t, s]:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", 8)
	var row := hb(v, 12, true)
	var saved := Game.peek_saved_label()
	if saved != "":
		btn(row, "이어하기 · " + saved, continue_run, true)
	btn(row, "새 원정", _new_game, saved == "")
	btn(row, "원정대 고르기", show_party_select)
	btn(row, "규칙 보기", show_rules)


func _new_game() -> void:
	Game.clear_save()
	Game.new_run(Game.DEFAULT_PARTY, Data)
	begin_stage()


func continue_run() -> void:
	if not Game.load_saved(Data):
		_new_game()
		return
	if str(Game.run["pending"]) == "reward":
		show_reward()
	else:
		begin_stage()


func show_rules() -> void:
	var v := open_overlay("규칙")
	var lines := [
		"원정대 · 전위·사수·마법·지원 역할의 영웅 네 명. 영웅마다 직업 고유의 주사위가 있고, 여섯 면 모두가 그 직업만의 스킬. 매 턴 네 영웅에게 나온 스킬 조합으로 싸움.",
		"굴림 단계 · 매 턴 모든 주사위를 굴림. 마음에 드는 주사위는 눌러서 고정하고 나머지를 다시 굴림 (턴당 2번).",
		"사용 단계 · 주사위를 누르고 대상을 고르면 발동. 공격 계열은 적, 방어·회복 계열은 아군 대상. 대상이 필요 없는 면은 누르면 바로 발동.",
		"적의 행동 · 적도 매 턴 자기 주사위를 굴려 무엇을 누구에게 할지 미리 보여 줌. 턴을 마치기 전에 쓰러뜨리거나 기절시키면 취소.",
		"스킬 조합 · 얼린 적에게 산산조각, 독 걸린 적에게 급소 찌르기, 표식 찍은 적에게 집중 공격, 앙코르로 동료 스킬 한 번 더 등. 면에 마우스를 올리면 설명 표시.",
		"각인 · 같은 면을 런 동안 여러 번 쓰면(5번, 12번) 그 면이 손에 익어 영구히 강해짐.",
		"마나와 주문 · 마나는 전투 내내 유지. 마법·지원 직업의 고유 주문에 사용.",
		"진행 · 전투 스무 번을 한 줄로 이어 감. 네 번째마다 보스, 스무 번째가 최종 보스. 한 번 지면 처음부터.",
		"성장 · 홀수 번째 전투 뒤에는 장비 하나, 짝수 번째 전투 뒤에는 영웅 하나 전직. 견습은 빈 면이 있는 단순한 주사위로 시작해 전직할수록 새 스킬이 열림. 영웅은 전투가 끝나면 모두 회복.",
		"저장 · 전투와 보상 사이마다 자동 저장.",
	]
	for line in lines:
		lbl(v, line, 17, C_TEXT, false, true)


func show_party_select() -> void:
	party_choice = {}
	_draw_party_select()


func _draw_party_select() -> void:
	clear_screen()
	top_bar()
	var head := hb(root, 12)
	lbl(head, "원정대 꾸리기", 24, C_BRASS, true)
	lbl(head, "역할마다 영웅 한 명씩 선택. 아래 칸은 그 영웅 주사위의 여섯 면.", 15, C_MUTED, false, true)
	btn(head, "무작위로 채우기", _random_party)
	btn(head, "출발", _start_run, true, party_choice.size() < Data.ROLES.size())
	btn(head, "뒤로", show_title)
	var area := scroll_area(root)
	for role in Data.ROLES:
		var row := hb(area, 10)
		for k in role["opts"]:
			var cls: Dictionary = Data.classes[k]
			var on: bool = party_choice.get(role["key"], "") == k
			var col := vb(row, 4)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			choice(col, "%s · %s  (체력 %d)" % [role["name"], cls["name"], cls["hp"]], cls["desc"] + _spell_note(cls), _pick_class.bind(role["key"], k), false, on)
			face_row(col, Data.make_hero(k))


func _spell_note(cls: Dictionary) -> String:
	if cls["spell"] == "":
		return ""
	var spd: Dictionary = Data.spells[cls["spell"]]
	return " · 주문 %s(마나 %d): %s" % [spd["name"], spd["cost"], spd["text"]]


func _pick_class(role_key: String, k: String) -> void:
	party_choice[role_key] = k
	_draw_party_select()


func _random_party() -> void:
	for role in Data.ROLES:
		party_choice[role["key"]] = role["opts"][randi() % role["opts"].size()]
	_draw_party_select()


func _start_run() -> void:
	var keys := []
	for role in Data.ROLES:
		keys.append(party_choice[role["key"]])
	Game.clear_save()
	Game.new_run(keys, Data)
	begin_stage()


func show_party_overlay() -> void:
	var v := open_overlay("원정대")
	var seen := {}
	for p in Game.run["party"]:
		var pv := panel(v)
		var top := hb(pv)
		lbl(top, Data.hero_name(p), 20, C_TEXT, true)
		spacer(top)
		var cls: Dictionary = Data.hero_class(p)
		var spell_name := ""
		if cls["spell"] != "":
			spell_name = " · 주문 " + Data.spells[cls["spell"]]["name"]
		lbl(top, "체력 %d%s" % [Data.hero_max_hp(p), spell_name], 15, C_MUTED)
		face_row(pv, p)
		for i in 6:
			var f := Data.hero_face(p, i)
			seen[f["k"]] = f
		if p["items"].size() > 0:
			var names := []
			for it in p["items"]:
				names.append("%s(%s)" % [Data.items[it]["name"], Data.items[it]["text"]])
			lbl(pv, "장비: " + ", ".join(PackedStringArray(names)), 15, C_BRASS, false, true)
	lbl(v, "면 설명", 18, C_BRASS, true)
	for k in seen:
		lbl(v, Data.face_desc(seen[k]), 15, C_MUTED, false, true)


# =============== run flow ===============

## Starts the fight the run is currently on.
func begin_stage() -> void:
	var st: Dictionary = Game.stage_info(int(Game.run["stage"]))
	Game.run["act"] = int(st["act"])
	Game.run["pending"] = "fight"
	Game.save()
	start_fight(str(st["kind"]), "", st.get("group", []))


# =============== combat ===============

func start_fight(kind: String, note := "", fixed: Array = []) -> void:
	var enc: Dictionary = Data.encounters[int(Game.run["act"])]
	var group: Array
	if not fixed.is_empty():
		group = fixed
	elif kind == "boss":
		group = enc["boss"]
	else:
		var list: Array = enc["elite" if kind == "elite" else "normal"]
		var fresh := []
		for g in list:
			if not ",".join(PackedStringArray(g)) in Game.run["seen"]:
				fresh.append(g)
		var pool := fresh if fresh.size() > 0 else list
		group = pool[randi() % pool.size()]
		Game.run["seen"].append(",".join(PackedStringArray(group)))
	combat = Combat.new(Data, Game.run, kind, group)
	var names := []
	for e in combat.enemies:
		names.append(e["name"])
	var intro := ", ".join(PackedStringArray(names)) + " 등장"
	if note != "":
		intro = note + " " + intro
	combat.log_add(intro)
	combat.start()
	sel = -1
	armed_spell = ""
	busy = false
	refresh()


func target_mode() -> String:
	if combat == null or busy or combat.phase != "use":
		return ""
	if armed_spell != "":
		return Data.spells[armed_spell]["t"]
	if sel >= 0:
		return combat.target_kind_of(combat.heroes[sel])
	return ""


func refresh() -> void:
	var c = combat
	clear_screen()
	set_backdrop("act%d" % (int(Game.run["act"]) + 1), 0.22)
	top_bar(true)
	var mode := target_mode()
	# heroes down the left, enemies down the right, the dice thrown into the open middle
	var body := hb(root, 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena_dice = []
	board_panel(body, "hero", mode)
	arena = Control.new()
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(arena)
	board_panel(body, "enemy", mode)
	var order := 0
	for it in arena_dice:
		it["order"] = order
		if it["fresh"]:
			order += 1
	for h in c.heroes:
		h["fresh"] = false
	tipbox = CenterContainer.new()
	tipbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	tipbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(tipbox)
	# one line of guidance, then the bar: reroll or undo, spells, done
	var guide: bool = int(Game.run["stage"]) == 0 and not busy
	if c.phase == "roll":
		info_default = "가운데 주사위를 누르면 고정되어 영웅 옆 칸으로 들어감. 고정하지 않은 주사위만 다시 굴림. 붉은 칸은 적이 노리는 자리."
		if guide:
			info_default = "① 마음에 드는 주사위를 눌러 고정 → ② [다시 굴리기]로 나머지만 다시 굴림 → ③ [굴림 확정]"
	else:
		info_default = "영웅 옆 주사위를 누르고 빛나는 칸을 누르면 발동. [근접] 스킬은 각 가로줄 맨 앞의 적만 가능."
		if guide:
			info_default = "④ 영웅 옆 주사위를 하나 누르고 → ⑤ 빛나는 대상을 눌러 사용 → ⑥ 다 썼으면 [턴 종료]. 붉은 칸은 적이 이번 턴에 때릴 자리."
	if c.logs.size() > 0 and not guide:
		info_default = str(c.logs[c.logs.size() - 1])
	if move_mode:
		info_default = "이동 · 옮길 영웅을 누른 뒤 바로 옆 칸을 누름. 아군이 있는 칸이면 자리 바꿈."
	if busy:
		info_default = "적의 차례"
	if message != "":
		info_default = message
		message = ""
	info_lbl = lbl(root, info_default, 15, C_BRASS if guide else C_TEXT)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.clip_text = true
	info_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	info_lbl.add_theme_constant_override("outline_size", 4)
	var bar := hb(root, 8)
	bar.custom_minimum_size = Vector2(0, 92)
	var lb: Button
	if c.phase == "roll":
		lb = big_btn(bar, "다시 굴리기", "%d / %d" % [c.rerolls, 2 + (1 if c.party_has("feather") else 0)], on_reroll, false, busy or not c.can_reroll())
	else:
		lb = big_btn(bar, "되돌리기", "굴림은 그대로", on_undo, false, busy or not c.can_undo())
	lb.custom_minimum_size = Vector2(PANEL_W, 0)
	var mid := PanelContainer.new()
	mid.add_theme_stylebox_override("panel", sb(Color(C_PANEL2, 0.94), C_LINE, 2, 2, 8))
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(mid)
	var mrow := hb(mid, 8, true)
	var mv := big_btn(mrow, "이동 취소" if move_mode else "이동", "턴마다 한 번" if not c.hero_moved else "이미 이동함", _toggle_move, false, busy or c.hero_moved)
	mv.custom_minimum_size = Vector2(120, 64)
	mv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ui_icon(mrow, "mana", 30.0)
	lbl(mrow, "마나 %d" % c.mana, 15, CAT["mana"], true)
	for s in c.spells_available():
		var spd: Dictionary = Data.spells[s]
		var off: bool = c.phase != "use" or c.mana < int(spd["cost"]) or busy
		var b := big_btn(mrow, str(spd["name"]), "마나 %d" % int(spd["cost"]), on_spell.bind(s), false, off)
		b.custom_minimum_size = Vector2(150, 64)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tip := "%s (마나 %d) · %s" % [spd["name"], spd["cost"], spd["text"]]
		b.mouse_entered.connect(_info_show.bind(tip))
		b.mouse_exited.connect(_info_show.bind(""))
		if armed_spell == s:
			b.add_theme_stylebox_override("normal", kb(CAT["mana"], Color("#3a2a5c")))
	var rb: Button
	if c.phase == "roll":
		rb = big_btn(bar, "굴림 확정", "주사위 사용 단계로", on_confirm, true, busy)
	else:
		rb = big_btn(bar, "턴 종료", "적의 차례로", on_end_turn, true, busy)
	rb.custom_minimum_size = Vector2(PANEL_W, 0)
	_place_arena_dice.call_deferred()
	_play_events.call_deferred()
	_selected_tip.call_deferred()


## A two-line button for the bottom bar: what it does, and a smaller note under it.
func big_btn(parent: Node, title: String, note: String, cb: Callable, primary := false, disabled := false) -> Button:
	var b := btn(parent, "", cb, primary, disabled)
	b.custom_minimum_size = Vector2(0, 64)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ink := Color("#1a1226") if primary else C_TEXT
	if disabled:
		ink = C_MUTED.darkened(0.3)
	var t := lbl(v, title, 24 if primary else 15, ink, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := lbl(v, note, 12, ink.darkened(0.1) if primary else (C_MUTED if not disabled else ink))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _unit_box(fill: Color, edge: Color, lit: bool) -> StyleBoxFlat:
	var s := sb(fill, edge, 2, 3, 6)
	if lit:
		glow(s, C_GLOW, 10, 0.7)
	return s


## One side's 3x3 field. Every square is a tile; a unit on it is a small panel with its picture,
## health and die slot. Column 0 is the front line and sits next to the middle of the screen.
func board_panel(parent: Node, side: String, mode: String) -> void:
	var cb = combat
	var threat := {}
	if side == "hero":
		for e in cb.live_enemies():
			var strong: bool = str(e["tmode"]) != "row"
			for cell in cb.enemy_threat_cells(e):
				var key := Vector2i(int(cell[0]), int(cell[1]))
				threat[key] = maxi(int(threat.get(key, 0)), 2 if strong else 1)
			for v in cb.enemy_victims(e):
				threat[Vector2i(int(v["c"]), int(v["r"]))] = 2
	var units: Array = cb.heroes if side == "hero" else cb.enemies
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(g)
	for r in 3:
		for sx in 3:
			var c: int = (2 - sx) if side == "hero" else sx
			var u: Dictionary = cb.unit_at(units, c, r)
			if u.is_empty() and side == "hero":
				u = cb.unit_at(units, c, r, true)   # a fallen hero stays where it fell
			if u.is_empty() and side == "enemy":
				var gone: Dictionary = cb.unit_at(units, c, r, true)
				if not gone.is_empty() and _has_event("enemy", int(gone["i"])):
					u = gone   # one more draw so its last hit can be seen
			var alive: bool = not u.is_empty() and u["hp"] > 0
			var pick := false
			if move_mode and side == "hero":
				pick = alive if move_sel < 0 else cb.can_move(move_sel, c, r)
			elif alive:
				if side == "enemy" and mode == "enemy":
					pick = cb.can_cast(armed_spell, u) if armed_spell != "" else (sel >= 0 and cb.can_use(sel, u))
				elif side == "hero" and mode == "ally":
					pick = cb.can_cast(armed_spell, u) if armed_spell != "" else (sel >= 0 and cb.can_use(sel, u))
			elif not u.is_empty() and side == "hero" and mode == "dead":
				pick = true
			var chosen: bool = move_mode and side == "hero" and alive and int(u["i"]) == move_sel
			var fill := Color("#1b1636", 0.72) if (c + r) % 2 == 0 else Color("#221c42", 0.72)
			var edge := Color("#3a3166", 0.9)
			var th := int(threat.get(Vector2i(c, r), 0))
			if th == 2:
				fill = Color("#5a1838", 0.85)
				edge = C_DANGER
			elif th == 1:
				fill = Color("#3a1838", 0.8)
			if pick:
				edge = C_GLOW
			if chosen:
				edge = Color.WHITE
			var tile := Panel.new()
			var st := sb(fill, edge, 2, 3 if (pick or chosen or th == 2) else 2, 0)
			if pick:
				glow(st, C_GLOW, 10, 0.7)
			tile.add_theme_stylebox_override("panel", st)
			tile.custom_minimum_size = Vector2(CELL_W, CELL_H)
			tile.mouse_filter = Control.MOUSE_FILTER_STOP
			if pick or (side == "hero" and alive):
				tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			tile.gui_input.connect(_cell_input.bind(c, r, side))
			g.add_child(tile)
			if u.is_empty():
				continue
			tile.mouse_entered.connect(_show_card.bind(side, int(u["i"])))
			tile.mouse_exited.connect(_hide_card)
			var blocked: bool = alive and side == "enemy" and mode == "enemy" and not pick
			unit_tile(tile, side, u, blocked)


## The unit standing on a tile: name, picture next to its die slot, health underneath.
func unit_tile(tile: Control, side: String, u: Dictionary, blocked: bool) -> void:
	var cb = combat
	var i := int(u["i"])
	var alive: bool = u["hp"] > 0
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 3)
	card.size = Vector2(CELL_W - 12, CELL_H - 10)
	card.position = Vector2(6, 5)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(card)
	if side == "hero":
		hero_cards[i] = card
	else:
		enemy_cards[i] = card
	var rcol := Color("#b79cf0")
	var name_text: String = str(u.get("name", ""))
	if side == "hero":
		rcol = ROLE_COL[Data.hero_class(u["p"])["role"]]
		name_text = Data.hero_class(u["p"])["name"]
	elif u["boss"]:
		rcol = Color("#ffcf5a")
	if not alive:
		card.modulate = Color(0.5, 0.5, 0.6, 0.5)
	elif blocked:
		card.modulate = Color(0.55, 0.55, 0.65)
	var top := hb(card, 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl := lbl(top, name_text, 12, rcol.lightened(0.15), true)
	nl.clip_text = true
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if side == "hero" and alive:
		var inc: int = cb.incoming_for(u)
		if inc > 0:
			var lethal: bool = inc >= int(u["hp"]) + int(u["shield"])
			var il := lbl(top, "-%d" % inc, 12, Color("#1b0d0a") if lethal else CAT["hurt"], true)
			il.add_theme_stylebox_override("normal", sb(CAT["hurt"] if lethal else Color("#1b0d0a"), CAT["hurt"], 2, 2, 3))
	var row := hb(card, 6, true)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var po = Portrait.new()
	var slot := Panel.new()
	slot.add_theme_stylebox_override("panel", sb(Color("#0c0a18"), rcol.darkened(0.35), 2, 2, 0))
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if side == "hero":
		po.bust = true
		po.setup("hero", _hero_art_key(str(u["p"]["cls"])), name_text, rcol, SLOT, bold)
		row.add_child(po)
		row.add_child(slot)
		if alive and u["face"] != null:
			var face: Dictionary = cb.shown_face(u)
			if cb.phase != "roll" or u["locked"]:
				var d = make_die(slot, face, SLOT - 6)
				d.position = Vector2(3, 3)
				d.locked = cb.phase == "roll"
				d.selected = sel == i
				d.dim = u["used"]
				_wire_die(d, i, face)
			else:
				arena_dice.append({"h": u, "face": face, "fresh": bool(u["fresh"]), "col": rcol})
	else:
		po.fit = true
		po.setup("enemy", str(u["key"]), name_text, CAT["atk"], SLOT, bold, u["boss"])
		if u["stunned"] or u["frozen"]:
			po.modulate = Color(0.6, 0.75, 1.0) if u["frozen"] else Color(0.6, 0.6, 0.6)
		row.add_child(slot)
		row.add_child(po)
		if alive and u["face"] != null:
			var f: Dictionary = u["face"]
			var k: String = f["k"]
			var val: int = cb.enemy_value(u) if k in ["atk", "all"] else int(f["n"])
			var d2 = DieFace.new()
			d2.setup(k, 0 if u["stunned"] else val, "", CAT[ECAT.get(k, "blank")], SLOT - 6, bold)
			d2.position = Vector2(3, 3)
			d2.dim = u["stunned"]
			d2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(d2)
	var foot := hb(card, 4)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pips = HpPips.new()
	pips.setup(int(u["hp"]), int(u["maxhp"]), int(u["shield"]), CAT["heal"] if side == "hero" else CAT["atk"], CELL_W - 16, true)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(pips)
	_badge_row(card, _hero_badges(u) if side == "hero" else _enemy_badges(u))


func _cell_input(event: InputEvent, c: int, r: int, side: String) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if busy or combat == null:
		return
	var units: Array = combat.heroes if side == "hero" else combat.enemies
	var u: Dictionary = combat.unit_at(units, c, r)
	if move_mode and side == "hero":
		if move_sel >= 0 and combat.can_move(move_sel, c, r):
			combat.move_hero(move_sel, c, r)
			move_mode = false
			move_sel = -1
		elif not u.is_empty():
			move_sel = int(u["i"])
		refresh()
		return
	if u.is_empty():
		u = combat.unit_at(units, c, r, true)
	if u.is_empty():
		return
	var mode := target_mode()
	var wants_hero: bool = mode in ["ally", "dead"]
	if (sel >= 0 or armed_spell != "") and ((side == "enemy" and mode == "enemy") or (side == "hero" and wants_hero)):
		pick_target(u)
	elif side == "hero" and u["hp"] > 0:
		on_die(int(u["i"]))


func _toggle_move() -> void:
	move_mode = not move_mode
	move_sel = -1
	sel = -1
	armed_spell = ""
	refresh()


func _badge_row(parent: Node, badges: Array) -> void:
	if badges.is_empty():
		return
	var brow := hb(parent, 2)
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for bi in mini(badges.size(), 3):
		var bd: Array = badges[bi]
		var bcol: Color = CAT[bd[1]]
		var bl := lbl(brow, str(bd[0]), 12, Color("#0d0a1c"), true)
		bl.add_theme_stylebox_override("normal", sb(bcol, bcol.darkened(0.4), 2, 1, 3))
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if badges.size() > 3:
		lbl(brow, "+%d" % (badges.size() - 3), 12, C_MUTED, true)


func _wire_die(d, i: int, face: Dictionary) -> void:
	d.clickable = true
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	d.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	d.pressed.connect(on_die.bind(i))
	d.mouse_entered.connect(_show_card.bind("hero", i))
	d.mouse_exited.connect(_hide_card)
	d.tooltip_text = ""


## Dice that are not locked lie loose in the middle; freshly rolled ones are thrown in.
func _place_arena_dice() -> void:
	if arena == null or not is_instance_valid(arena) or combat == null:
		return
	var n: int = arena_dice.size()
	var mid: Vector2 = arena.size * 0.5
	var rows: int = int(ceil(n / 2.0))
	for k in n:
		var it: Dictionary = arena_dice[k]
		var h: Dictionary = it["h"]
		var i := int(h["i"])
		# each die keeps its own spot for the whole turn so locking one does not shuffle the rest
		var seed_v: int = combat.turn * 131 + i * 17
		var jit := Vector2(float(seed_v % 7) - 3.0, float(seed_v % 5) - 2.0) * 5.0
		var rest := mid + Vector2((float(k % 2) - 0.5) * (ARENA_DIE + 40.0), (float(k / 2) - float(rows - 1) * 0.5) * (ARENA_DIE + 44.0)) + jit
		if n % 2 == 1 and k == n - 1:
			rest.x = mid.x + jit.x
		var w := Control.new()
		w.size = Vector2(ARENA_DIE + 10, ARENA_DIE + 10)
		w.pivot_offset = w.size * 0.5
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arena.add_child(w)
		arena.move_child(w, 0)
		var rim := Panel.new()
		var rim_col: Color = it["col"]
		rim.add_theme_stylebox_override("panel", glow(sb(Color("#0c0a18"), rim_col, 2, 3, 0), Color.BLACK, 10, 0.5))
		rim.size = w.size
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w.add_child(rim)
		var d = make_die(w, it["face"], ARENA_DIE)
		d.position = Vector2(5, 5)
		_wire_die(d, i, it["face"])
		var tilt: float = (float(seed_v % 9) - 4.0) * 0.045
		w.position = rest - w.size * 0.5
		w.rotation = tilt
		if it["fresh"] and anim:
			var others := []
			for f in 6:
				others.append(Data.hero_face(h["p"], f))
			_throw_die(w, d, others, it["face"], int(it["order"]), tilt)


func _show_face(d, face: Dictionary) -> void:
	if not is_instance_valid(d):
		return
	var num := 0
	if not face["k"] in Data.NO_NUMBER:
		num = int(face["n"])
	d.kind = str(face["k"])
	d.n = num
	d.label = Data.face_name(face)
	d.col = CAT[Data.face_cat(face)]
	d.queue_redraw()


func _throw_die(w: Control, d, others: Array, face: Dictionary, order: int, tilt: float) -> void:
	var rest: Vector2 = w.position
	var from_left: bool = randf() < 0.5
	var start := rest + Vector2((-1.0 if from_left else 1.0) * (120.0 + randf() * 80.0), -110.0 - randf() * 40.0)
	var wait: float = 0.06 * order
	var dur := 0.66
	w.position = start
	w.rotation = TAU * (1.0 + randf()) * (-1.0 if from_left else 1.0)
	w.scale = Vector2(1.25, 1.25)
	_show_face(d, others[randi() % others.size()])
	var tx := w.create_tween().set_parallel(true)
	tx.tween_property(w, "position:x", rest.x, dur).set_delay(wait).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tx.tween_property(w, "rotation", tilt, dur).set_delay(wait).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tx.tween_property(w, "scale", Vector2.ONE, dur * 0.5).set_delay(wait)
	# falls onto the table and hops three times, each hop lower
	var ty := w.create_tween()
	ty.tween_interval(wait)
	ty.tween_property(w, "position:y", rest.y, dur * 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for hop in [26.0, 12.0, 5.0]:
		ty.tween_property(w, "position:y", rest.y - hop, dur * 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ty.tween_property(w, "position:y", rest.y, dur * 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# the face keeps changing while it tumbles
	var tf := w.create_tween()
	tf.tween_interval(wait)
	for k in 7:
		tf.tween_callback(_show_face.bind(d, others[randi() % others.size()]))
		tf.tween_interval(dur / 8.0)
	tf.tween_callback(_show_face.bind(d, face))


## The six faces of a die laid out unfolded, like a paper net.
func die_net(parent: Node, dice: Array, px: float) -> void:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 2)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(g)
	var spot := {1: 0, 4: 1, 5: 2, 6: 3, 7: 4, 9: 5}
	for cell in 12:
		if spot.has(cell) and int(spot[cell]) < dice.size():
			var d: Control = dice[int(spot[cell])]
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			g.add_child(d)
		else:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(px, px)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			g.add_child(gap)


func _hero_net_dice(pp: Dictionary, cur: int, px: float) -> Array:
	var out := []
	for f in 6:
		var face: Dictionary = Data.hero_face(pp, f)
		var d = DieFace.new()
		var num := 0
		if not face["k"] in Data.NO_NUMBER:
			num = int(face["n"])
		d.setup(str(face["k"]), num, Data.face_name(face), CAT[Data.face_cat(face)], px, bold)
		d.selected = f == cur
		out.append(d)
	return out


func _tip_panel(col: Color) -> VBoxContainer:
	for ch in tipbox.get_children():
		tipbox.remove_child(ch)
		ch.queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", glow(sb(Color("#0d0a1c", 0.97), col, 2, 2, 12), Color.BLACK, 12, 0.6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tipbox.add_child(p)
	var v := vb(p, 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


## Pointing at a hero or an enemy opens its card in the middle: health, die net, what it does.
func _show_card(side: String, i: int) -> void:
	if combat == null or tipbox == null or not is_instance_valid(tipbox):
		return
	var c = combat
	if side == "hero":
		var h: Dictionary = c.heroes[i]
		var pp: Dictionary = h["p"]
		var rcol: Color = ROLE_COL[Data.hero_class(pp)["role"]]
		var v := _tip_panel(rcol)
		lbl(v, "%s · 체력 %d/%d" % [Data.hero_class(pp)["name"], h["hp"], h["maxhp"]], 15, rcol.lightened(0.15), true)
		var st := _hero_status(h)
		if st != "":
			lbl(v, st, 12, CAT["def"])
		var row := vb(v, 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		die_net(row, _hero_net_dice(pp, int(h["face_idx"]) if h["face"] != null else -1, 46.0), 46.0)
		if h["hp"] > 0 and h["face"] != null:
			var dl := lbl(row, "이번 면: " + Data.face_desc(c.shown_face(h)), 12, C_TEXT, false, true)
			dl.custom_minimum_size = Vector2(250, 0)
		_hover_links(side, i)
	else:
		var e: Dictionary = c.enemies[i]
		var v2 := _tip_panel(C_DANGER)
		lbl(v2, "%s%s · 체력 %d/%d" % [e["name"], " (뒷줄)" if int(e["c"]) > 0 else "", e["hp"], e["maxhp"]], 15, C_DANGER.lightened(0.2), true)
		var es := _enemy_status(e)
		if es != "":
			lbl(v2, es, 12, CAT["def"])
		var row2 := vb(v2, 6)
		row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dice := []
		for f2 in e["faces"]:
			var d = DieFace.new()
			var k: String = f2["k"]
			d.setup(k, int(f2["n"]), "", CAT[ECAT.get(k, "blank")], 46.0, bold)
			d.selected = e["face"] != null and f2 == e["face"]
			dice.append(d)
		die_net(row2, dice, 46.0)
		if e["hp"] > 0 and e["face"] != null:
			var il := lbl(row2, "이번 턴: " + str(c.enemy_intent(e)["t"]), 12, C_TEXT, false, true)
			il.custom_minimum_size = Vector2(250, 0)
		_hover_links(side, i)


func _hide_card() -> void:
	if links != null:
		links.set_links([])
	_selected_tip()


## With a die or a spell chosen, the middle says what it does and asks for a target.
func _selected_tip() -> void:
	if tipbox == null or not is_instance_valid(tipbox):
		return
	for ch in tipbox.get_children():
		tipbox.remove_child(ch)
		ch.queue_free()
	if combat == null or busy or combat.phase != "use":
		return
	if sel >= 0:
		var h: Dictionary = combat.heroes[sel]
		if h["face"] == null:
			return
		var face: Dictionary = combat.shown_face(h)
		var v := _tip_panel(CAT[Data.face_cat(face)])
		var row := hb(v, 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var d = make_die(row, face, 56.0)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tl := lbl(row, Data.face_desc(face), 15, C_TEXT, false, true)
		tl.custom_minimum_size = Vector2(210, 0)
		lbl(v, "빛나는 대상을 눌러 사용", 12, C_GLOW)
	elif armed_spell != "":
		var spd: Dictionary = Data.spells[armed_spell]
		var v2 := _tip_panel(CAT["mana"])
		var tl2 := lbl(v2, "%s · %s" % [spd["name"], spd["text"]], 15, C_TEXT, false, true)
		tl2.custom_minimum_size = Vector2(280, 0)
		lbl(v2, "빛나는 대상을 눌러 사용", 12, C_GLOW)


## While a unit is pointed at, lines show who is aiming at whom.
func _hover_links(side: String, i: int) -> void:
	if links == null or combat == null:
		return
	var out := []
	for e in combat.live_enemies():
		if e["stunned"] or e["face"] == null:
			continue
		if side == "enemy" and int(e["i"]) != i:
			continue
		var ec = enemy_cards.get(int(e["i"]))
		if ec == null or not is_instance_valid(ec):
			continue
		var er: Rect2 = ec.get_global_rect()
		var k: String = e["face"]["k"]
		for v in combat.enemy_victims(e):
			if side == "hero" and int(v["i"]) != i:
				continue
			var hc = hero_cards.get(int(v["i"]))
			if hc == null or not is_instance_valid(hc):
				continue
			var hr: Rect2 = hc.get_global_rect()
			out.append({"a": Vector2(er.position.x, er.get_center().y), "b": Vector2(hr.end.x, hr.get_center().y), "col": Color(CAT[ECAT.get(k, "blank")], 0.8)})
	links.set_links(out)


func _has_event(side: String, i: int) -> bool:
	for e in combat.events:
		if e["side"] == side and int(e["i"]) == i:
			return true
	return false


func _hero_badges(h: Dictionary) -> Array:
	var st := []
	if h["hp"] <= 0:
		return st
	if h["poison"] > 0:
		st.append(["독%d" % h["poison"], "poison"])
	if h["hexed"]:
		st.append(["저주", "trick"])
	if h["taunt"]:
		st.append(["도발", "def"])
	if h["aimed"]:
		st.append(["조준×3", "trick"])
	if h["aim_pending"]:
		st.append(["조준중", "blank"])
	if h["heat"] > 0:
		st.append(["열%d" % h["heat"], "atk"])
	if h["streak"] > 0:
		st.append(["기세%d" % h["streak"], "atk"])
	if h["thorns"] > 0:
		st.append(["가시%d" % h["thorns"], "def"])
	if h["dodge"]:
		st.append(["연막", "blank"])
	if h["guard"]:
		st.append(["수호", "heal"])
	if h["link"] >= 0:
		st.append(["연결", "heal"])
	if h["seed"] > 0:
		st.append(["씨앗", "heal"])
	if h["double"]:
		st.append(["두배", "trick"])
	if h["ward"]:
		st.append(["정화", "heal"])
	if h["keep_shield"]:
		st.append(["얼음", "def"])
	return st


func _enemy_badges(e: Dictionary) -> Array:
	var st := []
	if e["hp"] <= 0:
		return st
	if e["stunned"]:
		st.append(["빙결" if e["frozen"] else "기절", "def" if e["frozen"] else "trick"])
	elif e["frozen"]:
		st.append(["빙결", "def"])
	if e["poison"] > 0:
		st.append(["독%d" % e["poison"], "poison"])
	if e["weak"] > 0:
		st.append(["약화%d" % e["weak"], "trick"])
	if e["mark"] > 0:
		st.append(["표식", "atk"])
	return st


func _hero_status(h: Dictionary) -> String:
	var st := []
	if h["hp"] <= 0:
		return "쓰러짐"
	if h["shield"] > 0:
		st.append("방어 %d" % h["shield"])
	if h["poison"] > 0:
		st.append("독 %d" % h["poison"])
	if h["streak"] > 0:
		st.append("기세 %d" % h["streak"])
	if h["aimed"]:
		st.append("조준 완료 ×3")
	if h["aim_pending"]:
		st.append("조준 중")
	if h["heat"] > 0:
		st.append("열 %d/5" % h["heat"])
	if h["seed"] > 0:
		st.append("씨앗 %d" % h["seed"])
	if h["thorns"] > 0:
		st.append("가시 %d" % h["thorns"])
	if h["dodge"]:
		st.append("연막")
	if h["guard"]:
		st.append("수호 기도")
	if h["ward"]:
		st.append("정화")
	if h["keep_shield"]:
		st.append("얼음 갑옷")
	if h["link"] >= 0:
		st.append("연결: " + combat.hero_label(combat.heroes[h["link"]]))
	if h["taunt"]:
		st.append("대신 맞는 중")
	if h["double"]:
		st.append("효과 두 배")
	if h["hexed"]:
		st.append("저주")
	return " · ".join(PackedStringArray(st))


func _enemy_status(e: Dictionary) -> String:
	var st := []
	if e["shield"] > 0:
		st.append("방어 %d" % e["shield"])
	if e["poison"] > 0:
		st.append("독 %d" % e["poison"])
	if e["weak"] > 0:
		st.append("약화 %d" % e["weak"])
	if e["frozen"]:
		st.append("얼어붙음")
	if e["stunned"]:
		st.append("행동 불가")
	if e["mark"] > 0:
		st.append("표식 +%d" % e["mark"])
	return " · ".join(PackedStringArray(st))


func _info_show(text: String) -> void:
	if info_lbl != null and is_instance_valid(info_lbl):
		info_lbl.text = text if text != "" else info_default
		info_lbl.add_theme_color_override("font_color", C_TEXT if text != "" else C_MUTED)


func _hero_art_key(cls: String) -> String:
	# promoted classes borrow the earlier class picture until they get their own
	var cur := cls
	for step in 3:
		if ResourceLoader.exists("res://art/hero/%s.png" % cur):
			return cur
		var parent := ""
		for k in Data.classes:
			if cur in Data.classes[k]["promo"]:
				parent = str(k)
				break
		if parent == "":
			break
		cur = parent
	return cur if ResourceLoader.exists("res://art/hero/%s.png" % cur) else cls


func _cancel_sel() -> void:
	sel = -1
	armed_spell = ""
	refresh()


func _float_text(at: Vector2, text: String, col: Color, size := 24, delay := 0.0, plate := false) -> void:
	var l := Label.new()
	l.text = text
	var fs := pf(size, true)
	l.add_theme_font_override("font", fs[0])
	l.add_theme_font_size_override("font_size", fs[1])
	l.add_theme_color_override("font_color", col)
	if plate:
		l.add_theme_stylebox_override("normal", glow(sb(Color("#0d0a1c"), col, 2, 2, 6), col, 8, 0.5))
	else:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 6)
	fx.add_child(l)
	l.reset_size()
	l.global_position = at - Vector2(l.size.x * 0.5, 0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 30, 1.0).set_delay(delay)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(delay + 0.6)
	tw.chain().tween_callback(l.queue_free)


## Shows who is acting: a name plate over the unit and a short lunge at the other side.
func _announce(side: String, i: int, text: String, col: Color) -> void:
	if not anim:
		return
	var card = (hero_cards if side == "hero" else enemy_cards).get(i)
	if card == null or not is_instance_valid(card):
		return
	var r: Rect2 = card.get_global_rect()
	_float_text(Vector2(r.get_center().x, r.position.y - 22), text, col, 15, 0.0, true)
	var dir := 1.0 if side == "hero" else -1.0
	var base: Vector2 = card.position
	var tw: Tween = card.create_tween()
	tw.tween_property(card, "position:x", base.x - dir * 6, 0.08)
	tw.tween_property(card, "position:x", base.x + dir * 30, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "position:x", base.x, 0.16)
	await get_tree().create_timer(0.3).timeout


func _react(card: Control, kind: String, fade: bool) -> void:
	var base: Vector2 = card.position
	var keep: Color = card.modulate
	var tw: Tween = card.create_tween()
	if kind == "hurt":
		card.modulate = Color(2.4, 0.6, 0.5, keep.a)
		for dx in [10, -9, 7, -5, 3, 0]:
			tw.tween_property(card, "position:x", base.x + dx, 0.04)
	elif kind == "def":
		card.modulate = Color(0.7, 1.2, 2.0, keep.a)
		tw.tween_property(card, "position:x", base.x + 3, 0.05)
		tw.tween_property(card, "position:x", base.x, 0.05)
	else:
		card.modulate = Color(0.8, 1.9, 0.8, keep.a)
		tw.tween_property(card, "position:y", base.y - 6, 0.1)
		tw.tween_property(card, "position:y", base.y, 0.12)
	var end := keep
	if fade:
		end = Color(1, 1, 1, 0)
	card.create_tween().tween_property(card, "modulate", end, 0.6 if fade else 0.35).set_delay(0.08)


func _play_events() -> void:
	if combat == null:
		return
	var list: Array = combat.events.duplicate()
	combat.events.clear()
	var stack := {}
	var reacts := {}
	for e in list:
		var card = null
		if e["side"] == "enemy":
			card = enemy_cards.get(int(e["i"]))
		else:
			card = hero_cards.get(int(e["i"]))
		if card == null or not is_instance_valid(card):
			continue
		var key: String = str(e["side"]) + str(e["i"])
		var n: int = stack.get(key, 0)
		stack[key] = n + 1
		var r: Rect2 = card.get_global_rect()
		_float_text(Vector2(r.get_center().x, r.position.y + 20 + n * 26), str(e["text"]), CAT.get(e["color"], C_TEXT), 24, n * 0.08)
		var kind := ""
		var txt: String = str(e["text"])
		if e["color"] == "hurt" or (e["color"] == "poison" and txt.contains("-")):
			kind = "hurt"
		elif e["color"] == "def":
			kind = "def"
		elif e["color"] == "heal":
			kind = "heal"
		if kind != "" and (not reacts.has(key) or kind == "hurt"):
			reacts[key] = [card, kind, e["side"], int(e["i"])]
	if not anim:
		return
	for key in reacts:
		var it: Array = reacts[key]
		var gone: bool = it[2] == "enemy" and int(combat.enemies[it[3]]["hp"]) <= 0
		_react(it[0], it[1], gone)


func _act_die(i: int, t) -> void:
	var c = combat
	if not c.can_use(i, t):
		message = "그 대상에는 쓸 수 없음" if t != null else "지금은 쓸 수 없는 면"
		sel = -1
		after_action()
		return
	busy = true
	var face: Dictionary = c.shown_face(c.heroes[i])
	await _announce("hero", i, Data.face_title(face), CAT[Data.face_cat(face)])
	if combat != c:
		return
	c.use_die(i, t)
	busy = false
	sel = -1
	after_action()


func on_die(i: int) -> void:
	if busy or combat == null:
		return
	move_mode = false
	move_sel = -1
	var c = combat
	if c.phase == "roll":
		c.toggle_lock(i)
		refresh()
		return
	var h: Dictionary = c.heroes[i]
	if h["used"]:
		return
	armed_spell = ""
	var t: String = c.target_kind_of(h)
	if t == "none":
		_act_die(i, null)
		return
	if sel == i:
		sel = -1
	else:
		sel = i
		message = "%s · %s · 대상 선택" % [c.hero_label(h), Data.face_desc(c.shown_face(h))]
	refresh()


func on_spell(s: String) -> void:
	if busy or combat == null:
		return
	sel = -1
	var t: String = Data.spells[s]["t"]
	if t == "none":
		combat.cast(s, null)
		armed_spell = ""
		after_action()
		return
	if armed_spell == s:
		armed_spell = ""
	else:
		armed_spell = s
		message = "%s · 대상 선택" % Data.spells[s]["name"]
	refresh()


func pick_target(t: Dictionary) -> void:
	if busy or combat == null:
		return
	if armed_spell != "":
		if not combat.cast(armed_spell, t):
			message = "그 대상에는 쓸 수 없음"
		armed_spell = ""
		after_action()
	elif sel >= 0:
		_act_die(sel, t)


func on_undo() -> void:
	if busy or combat == null:
		return
	sel = -1
	armed_spell = ""
	move_mode = false
	move_sel = -1
	combat.undo()
	refresh()


func on_reroll() -> void:
	if busy:
		return
	combat.reroll()
	refresh()


func on_confirm() -> void:
	if busy:
		return
	combat.confirm()
	combat.log_add("주사위를 누르고 대상을 골라 사용")
	refresh()


func on_end_turn() -> void:
	if busy:
		return
	move_mode = false
	move_sel = -1
	sel = -1
	armed_spell = ""
	var c = combat
	if not anim:
		c.end_turn()
		after_action()
		return
	busy = true
	refresh()
	await get_tree().create_timer(0.25).timeout
	if combat != c:
		return
	# enemies act one at a time so each attack and its result can be followed
	if c.end_turn_begin():
		refresh()
		for e in c.enemies:
			if not c.enemy_acts(e):
				continue
			await get_tree().process_frame
			var it: Dictionary = c.enemy_intent(e)
			await _announce("enemy", int(e["i"]), str(it["t"]), CAT.get(str(it["c"]), C_TEXT))
			if combat != c:
				return
			c.enemy_step(e)
			refresh()
			await get_tree().create_timer(0.5).timeout
			if combat != c:
				return
			if c.result != "":
				break
		c.end_turn_finish()
	busy = false
	after_action()


func after_action() -> void:
	if combat == null:
		return
	refresh()
	if combat.result != "":
		busy = true
		await get_tree().create_timer(0.9).timeout
		busy = false
		if combat == null:
			return
		if combat.result == "win":
			on_win()
		else:
			on_lose()


# =============== rewards & growth ===============

func on_win() -> void:
	Game.run["kills"] = int(Game.run["kills"]) + combat.enemies.size()
	combat = null
	Game.run["stage"] = int(Game.run["stage"]) + 1
	if int(Game.run["stage"]) >= Game.stage_count():
		Game.clear_save()
		show_end(true, "")
		return
	Game.run["pending"] = "reward"
	Game.save()
	show_reward()


## Rewards alternate: an item after odd fights, a class change after even ones.
func show_reward() -> void:
	combat = null
	offer = []
	var cleared := int(Game.run["stage"])
	if Game.reward_kind(cleared) == "item":
		var keys := Data.items.keys()
		keys.shuffle()
		for id in keys.slice(0, 3):
			offer.append({"item": str(id)})
	else:
		var idx := []
		var party: Array = Game.run["party"]
		for hi in party.size():
			if not Data.hero_class(party[hi])["promo"].is_empty():
				idx.append(hi)
		idx.shuffle()
		for hi in idx.slice(0, 2):
			var opts: Array = Data.hero_class(party[hi])["promo"]
			offer.append({"hero": hi, "cls": str(opts[randi() % opts.size()])})
	_draw_reward()


func _draw_reward() -> void:
	clear_screen()
	set_backdrop("act%d" % (int(Game.run["act"]) + 1), 0.6)
	top_bar()
	var cleared := int(Game.run["stage"])
	var area := scroll_area(root)
	var next_boss: bool = Game.is_boss_stage(cleared)
	lbl(area, "%d번째 전투 승리" % cleared, 26, C_BRASS, true)
	lbl(area, "다음은 %d번째 전투%s." % [cleared + 1, " · 보스" if next_boss else ""], 15, C_DANGER if next_boss else C_MUTED)
	if offer.is_empty():
		lbl(area, "전직할 영웅이 없어 주사위 면 하나를 강화.", 15, C_TEXT)
		btn(area, "면 강화 고르기", choose_face_upgrade.bind("주사위 면 강화", _after_reward, _draw_reward), true)
		return
	if offer[0].has("item"):
		lbl(area, "장비 하나 선택.", 15, C_TEXT)
		for o in offer:
			var id: String = o["item"]
			choice(area, "장비: " + str(Data.items[id]["name"]), str(Data.items[id]["text"]), choose_item_holder.bind(id, _after_reward))
		return
	lbl(area, "전직할 영웅 하나 선택. 면 강화와 각인은 같은 자리에 그대로 이어짐.", 15, C_TEXT, false, true)
	var row := hb(area, 10)
	for o in offer:
		var p: Dictionary = Game.run["party"][int(o["hero"])]
		var cls: Dictionary = Data.classes[o["cls"]]
		var col := vb(row, 6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice(col, "%s → %s  (체력 %d)" % [Data.hero_class(p)["name"], cls["name"], cls["hp"]], str(cls["desc"]) + _spell_note(cls), _take_levelup.bind(int(o["hero"]), str(o["cls"])))
		lbl(col, "지금", 12, C_MUTED, true)
		face_row(col, p)
		lbl(col, "전직 후", 12, C_GLOW, true)
		var tmp: Dictionary = p.duplicate(true)
		tmp["cls"] = o["cls"]
		face_row(col, tmp)


func _take_levelup(hi: int, k: String) -> void:
	Game.run["party"][hi]["cls"] = k
	_after_reward()


func _after_reward() -> void:
	Game.run["pending"] = ""
	begin_stage()


func on_lose() -> void:
	var names := []
	for e in combat.live_enemies():
		names.append(e["name"])
	combat = null
	Game.clear_save()
	show_end(false, ", ".join(PackedStringArray(names)))


func choose_face_upgrade(title: String, done: Callable, cancel: Callable) -> void:
	clear_screen()
	top_bar()
	var area := scroll_area(root)
	lbl(area, title, 26, C_BRASS, true)
	lbl(area, "강화할 스킬 선택. 위력 수치가 있는 스킬은 +1. 수치가 없는 스킬은 강화 불가.", 16, C_MUTED, false, true)
	for p in Game.run["party"]:
		var pv := panel(area)
		lbl(pv, Data.hero_name(p), 19, C_TEXT, true)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		pv.add_child(row)
		for i in 6:
			var f := Data.hero_face(p, i)
			var col: Color = CAT[Data.face_cat(f)]
			var b := Button.new()
			b.text = Data.face_title(f)
			b.tooltip_text = Data.face_desc(f)
			b.add_theme_color_override("font_color", col)
			b.add_theme_color_override("font_hover_color", col.lightened(0.2))
			b.disabled = not Data.can_upgrade(p, i)
			b.pressed.connect(_do_face_upgrade.bind(p, i, done))
			row.add_child(b)
	if cancel.is_valid():
		btn(area, "취소", cancel)


func _do_face_upgrade(p: Dictionary, i: int, done: Callable) -> void:
	p["bonus"][i] = int(p["bonus"][i]) + 1
	Game.save()
	done.call()


func choose_item_holder(id: String, done: Callable) -> void:
	clear_screen()
	top_bar()
	var v := panel(root)
	lbl(v, Data.items[id]["name"], 26, C_BRASS, true)
	lbl(v, Data.items[id]["text"] + ". 장착할 영웅 선택 (영웅마다 2칸, 가득 차면 가장 오래된 장비와 교체).", 16, C_MUTED, false, true)
	for p in Game.run["party"]:
		var its: Array = p["items"]
		var names := []
		for it in its:
			names.append(Data.items[it]["name"])
		var sub := "장비 없음"
		if names.size() > 0:
			sub = "장비: " + ", ".join(PackedStringArray(names))
		if its.size() >= 2:
			sub += " · %s와(과) 교체" % Data.items[its[0]]["name"]
		choice(v, Data.hero_name(p), sub, _equip.bind(p, id, done))


func _equip(p: Dictionary, id: String, done: Callable) -> void:
	var its: Array = p["items"]
	if its.size() >= 2:
		its.pop_front()
	its.append(id)
	Game.save()
	done.call()


# =============== end ===============

func show_end(won: bool, killer: String) -> void:
	clear_screen()
	top_bar()
	var area := scroll_area(root)
	lbl(area, "운명을 이긴 원정대" if won else "전멸한 원정대", 34, C_BRASS, true)
	var line := "운명의 도박사를 쓰러뜨리고 스무 번의 전투를 모두 돌파."
	if not won:
		line = "%d번째 전투에서 %s에게 전멸." % [int(Game.run["stage"]) + 1, killer]
	lbl(area, line, 18, C_MUTED, false, true)
	lbl(area, "쓰러뜨린 적 %d · 이긴 전투 %d · 모은 금화 %d" % [int(Game.run["kills"]), int(Game.run["stage"]), int(Game.run["gold"])], 17, C_TEXT)
	for p in Game.run["party"]:
		var pv := panel(area)
		lbl(pv, Data.hero_name(p), 19, C_TEXT, true)
		face_row(pv, p)
	btn(area, "새 원정", _new_game, true)
	btn(area, "처음 화면", show_title)
