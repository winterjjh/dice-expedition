extends Control
## Screen manager. Every screen is built in code from the Data/Game autoloads,
## so balance lives in res://data/*.json and layout lives here.

const Combat = preload("res://scripts/combat.gd")
const MapView = preload("res://scripts/ui/map_view.gd")
const DieFace = preload("res://scripts/ui/die_face.gd")
const HpPips = preload("res://scripts/ui/hp_pips.gd")
const Portrait = preload("res://scripts/ui/portrait.gd")
const LinkLayer = preload("res://scripts/ui/link_layer.gd")
const TRAY_DIE := 100.0
const ROLE_COL := {"front": Color("#77a9cc"), "shooter": Color("#a9c64a"), "mage": Color("#a988e0"), "support": Color("#8cc47a")}
const ECAT := {"atk": "atk", "all": "atk", "shield": "def", "heal": "heal", "poison": "poison", "hex": "trick", "blank": "blank"}

const C_BG := Color("#122420")
const C_PANEL := Color("#19302b")
const C_PANEL2 := Color("#10201c")
const C_LINE := Color("#2d4a43")
const C_IVORY := Color("#f1e8d4")
const C_INK := Color("#2b231f")
const C_BRASS := Color("#caa24e")
const C_TEXT := Color("#e6e0d0")
const C_MUTED := Color("#94a69f")
const CAT := {
	"atk": Color("#d65a4a"), "def": Color("#77a9cc"), "heal": Color("#8cc47a"),
	"mana": Color("#a988e0"), "poison": Color("#a9c64a"), "trick": Color("#e0b850"),
	"blank": Color("#7d8781"), "hurt": Color("#e06a58"),
}

var font: Font
var bold: Font
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
var move_mode := false
var move_sel := -1
var cell_ui := {}


func _ready() -> void:
	font = load("res://fonts/IBMPlexSansKR-Regular.ttf")
	bold = load("res://fonts/IBMPlexSansKR-Bold.ttf")
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
		show_party_select()
		_random_party()
		_start_run()
		start_fight("boss" if event.keycode == KEY_F10 else "fight")


# =============== theme & widget helpers ===============

func sb(bg: Color, border: Color, radius := 8, bw := 1, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 18
	th.set_stylebox("normal", "Button", sb(C_PANEL, C_LINE))
	th.set_stylebox("hover", "Button", sb(C_LINE, C_BRASS))
	th.set_stylebox("pressed", "Button", sb(C_LINE, C_IVORY))
	th.set_stylebox("disabled", "Button", sb(Color(C_PANEL, 0.5), Color(C_LINE, 0.5)))
	th.set_stylebox("focus", "Button", sb(Color(0, 0, 0, 0), C_IVORY, 8, 2))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(k, "Button", C_TEXT)
	th.set_color("font_disabled_color", "Button", Color(C_MUTED, 0.6))
	th.set_color("font_color", "Label", C_TEXT)
	th.set_stylebox("panel", "PanelContainer", sb(C_PANEL, C_LINE, 10, 1, 12))
	th.set_stylebox("panel", "TooltipPanel", sb(C_PANEL2, C_BRASS, 6, 1, 8))
	th.set_color("font_color", "TooltipLabel", C_TEXT)
	th.set_font_size("font_size", "TooltipLabel", 16)
	return th


func set_backdrop(key: String, dim := 0.55) -> void:
	var path := "res://art/bg/%s.jpg" % key
	if key != "" and ResourceLoader.exists(path):
		backdrop.texture = load(path)
		backdrop_dim.color = Color(0.03, 0.07, 0.06, dim)
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
	cell_ui.clear()
	info_lbl = null
	if links != null:
		links.set_links([])
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()


func lbl(parent: Node, text: String, size := 18, color := C_TEXT, is_bold := false, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if is_bold:
		l.add_theme_font_override("font", bold)
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
		b.add_theme_stylebox_override("normal", sb(C_BRASS, C_BRASS))
		b.add_theme_stylebox_override("hover", sb(C_BRASS.lightened(0.15), C_IVORY))
		b.add_theme_stylebox_override("pressed", sb(C_BRASS.darkened(0.1), C_IVORY))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, Color("#1b1408"))
		b.add_theme_font_override("font", bold)
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
	pb.add_theme_stylebox_override("background", sb(Color("#0c1916"), C_LINE, 5, 1, 0))
	pb.add_theme_stylebox_override("fill", sb(col, col, 5, 0, 0))
	parent.add_child(pb)
	return pb


func top_bar() -> void:
	var h := hb(root, 16)
	lbl(h, "주사위 원정대", 26, C_BRASS, true)
	spacer(h)
	if Game.run != null:
		lbl(h, "%d막 · %d층" % [int(Game.run["act"]) + 1, int(Game.run["floors"])], 17, C_TEXT)
		var gh := hb(h, 4)
		ui_icon(gh, "coin", 24.0)
		lbl(gh, "골드 %d" % int(Game.run["gold"]), 17, C_BRASS, true)
		btn(h, "원정대 보기", show_party_overlay)


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
var shop_stock := []
var shop_face := {}
var cur_event := {}


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
		die_widget(dice, f, false, false, false, Callable())
	var t := lbl(v, "주사위 원정대", 54, C_BRASS, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := lbl(v, "영웅 넷이 저마다 다른 직업 주사위를 굴려 싸우는 원정.\n세 개의 막을 지나 운명의 도박사를 쓰러뜨리면 승리.", 18, C_TEXT)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for l in [t, s]:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("outline_size", 8)
	var row := hb(v, 12, true)
	var saved := Game.peek_saved_label()
	if saved != "":
		btn(row, "이어하기 · " + saved, continue_run, true)
	btn(row, "새 원정", _new_game, saved == "")
	btn(row, "규칙 보기", show_rules)


func _new_game() -> void:
	Game.clear_save()
	show_party_select()


func continue_run() -> void:
	if not Game.load_saved(Data):
		show_party_select()
		return
	if str(Game.run["pending"]) != "":
		run_node(str(Game.run["pending"]))
	else:
		show_map()


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
		"성장 · 전투 보상으로 면 강화나 장비. 막을 깰 때마다 전직해 새 스킬이 열림. 영웅은 전투가 끝나면 모두 회복.",
		"저장 · 지도 화면으로 돌아올 때마다 자동 저장.",
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
	Game.new_run(keys, Data)
	show_map()


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


# =============== map ===============

func show_map() -> void:
	combat = null
	Game.run["pending"] = ""
	Game.save()
	clear_screen()
	top_bar()
	var boss_key: String = Data.encounters[int(Game.run["act"])]["boss"][0]
	lbl(root, "%d막 · 갈림길 — 빛나는 칸을 골라 전진. 맨 위의 보스는 %s." % [int(Game.run["act"]) + 1, Data.enemies[boss_key]["name"]], 17, C_MUTED, false, true)
	var mv := Control.new()
	mv.set_script(MapView)
	mv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.custom_minimum_size = Vector2(300, 420)
	root.add_child(mv)
	mv.setup(Game.run, Game.open_nodes(), Game.NODE_INFO)
	mv.chosen.connect(_on_map_chosen)
	var legend := hb(root, 18, true)
	for k in ["fight", "elite", "event", "shop", "forge", "boss"]:
		lbl(legend, "%s %s" % [Game.NODE_INFO[k]["ch"], Game.NODE_INFO[k]["name"]], 15, C_MUTED)


func _on_map_chosen(r: int, c: int) -> void:
	run_node(Game.enter_node(r, c))


func run_node(type: String) -> void:
	match type:
		"fight", "elite", "boss":
			start_fight(type)
		"forge":
			show_forge()
		"shop":
			show_shop()
		"event":
			if randf() < 0.2:
				start_fight("fight", "매복이다!")
			else:
				show_event()
		_:
			show_map()


# =============== combat ===============

func start_fight(kind: String, note := "") -> void:
	move_mode = false
	move_sel = -1
	var enc: Dictionary = Data.encounters[int(Game.run["act"])]
	var group: Array
	if kind == "boss":
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
	set_backdrop("act%d" % (int(Game.run["act"]) + 1), 0.5)
	top_bar()
	var mode := target_mode()
	var body := hb(root, 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	grid_panel(body, "hero", mode)
	# dice tray in the middle
	var mid := vb(body, 12)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var last := ""
	if c.logs.size() > 0:
		last = c.logs[c.logs.size() - 1]
	var logl := lbl(mid, message if message != "" else last, 16, C_TEXT, false, true)
	logl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logl.custom_minimum_size = Vector2(0, 52)
	logl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	logl.add_theme_constant_override("outline_size", 5)
	message = ""
	var tray := hb(mid, 10, true)
	for h in c.heroes:
		tray_slot(tray, h)
	var ar := hb(mid, 10, true)
	var mv := btn(ar, "이동 취소" if move_mode else ("이동 (%d)" % (0 if c.hero_moved else 1)), _toggle_move, false, busy or c.hero_moved)
	mv.tooltip_text = "턴마다 한 번, 영웅 하나를 옆 칸으로 옮김. 아군이 있는 칸이면 자리 바꿈."
	var ub := btn(ar, "되돌리기", on_undo, false, busy or not c.can_undo())
	ub.tooltip_text = "이번 턴에 한 이동, 주사위 사용, 주문을 한 단계씩 취소. 굴림 결과는 그대로."
	if c.phase == "roll":
		btn(ar, "다시 굴리기 (%d)" % c.rerolls, on_reroll, false, busy or not c.can_reroll())
		btn(ar, "굴림 확정", on_confirm, true, busy)
		info_default = "굴림 단계 · 마음에 드는 주사위를 눌러 고정하고 나머지를 다시 굴림. 붉은 칸은 적이 노리는 자리."
	else:
		if sel >= 0 or armed_spell != "":
			btn(ar, "선택 취소", _cancel_sel)
		btn(ar, "턴 종료", on_end_turn, true, busy)
		info_default = "사용 단계 · 주사위를 누른 뒤 빛나는 칸을 누르면 발동. [근접] 스킬은 각 가로줄 맨 앞의 적만 가능."
	if move_mode:
		info_default = "이동 · 옮길 영웅을 누른 뒤 바로 옆 칸을 누름. 아군이 있는 칸이면 자리 바꿈."
	var mrow := HFlowContainer.new()
	mrow.alignment = FlowContainer.ALIGNMENT_CENTER
	mrow.add_theme_constant_override("h_separation", 8)
	mrow.add_theme_constant_override("v_separation", 6)
	mid.add_child(mrow)
	ui_icon(mrow, "mana", 30.0)
	var ml := lbl(mrow, "마나 %d" % c.mana, 16, CAT["mana"], true)
	ml.add_theme_stylebox_override("normal", sb(Color(0.05, 0.03, 0.1, 0.6), CAT["mana"], 14, 1, 10))
	for s in c.spells_available():
		var spd: Dictionary = Data.spells[s]
		var off: bool = c.phase != "use" or c.mana < int(spd["cost"]) or busy
		var b := btn(mrow, "%s · %d" % [spd["name"], spd["cost"]], on_spell.bind(s), false, off)
		b.add_theme_font_size_override("font_size", 15)
		b.tooltip_text = "%s (마나 %d) · %s" % [spd["name"], spd["cost"], spd["text"]]
		b.mouse_entered.connect(_info_show.bind(b.tooltip_text))
		b.mouse_exited.connect(_info_show.bind(""))
		if armed_spell == s:
			b.add_theme_stylebox_override("normal", sb(CAT["mana"], C_IVORY))
			b.add_theme_color_override("font_color", Color("#1a1226"))
	grid_panel(body, "enemy", mode)
	# hero details and the description box along the bottom
	var foot := hb(root, 8)
	for h in c.heroes:
		hero_strip(foot, h)
	var ip := PanelContainer.new()
	ip.add_theme_stylebox_override("panel", sb(Color(C_PANEL2, 0.92), C_LINE, 8, 1, 12))
	ip.custom_minimum_size = Vector2(0, 64)
	root.add_child(ip)
	info_lbl = lbl(ip, info_default, 15, C_MUTED, false, true)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_play_events.call_deferred()
	_update_links()


func _toggle_move() -> void:
	move_mode = not move_mode
	move_sel = -1
	sel = -1
	armed_spell = ""
	refresh()


func grid_panel(parent: Node, side: String, mode: String) -> void:
	var c = combat
	var wrap := vb(parent, 4)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := lbl(wrap, "뒷줄 ← 원정대 → 앞줄" if side == "hero" else "앞줄 ← 적 → 뒷줄", 12, C_MUTED, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	wrap.add_child(grid)
	# cells the enemies are aiming at
	var threat := {}
	if side == "hero":
		for e in c.live_enemies():
			var strong: bool = str(e["tmode"]) != "row"
			for cell in c.enemy_threat_cells(e):
				var key := Vector2i(int(cell[0]), int(cell[1]))
				threat[key] = maxi(int(threat.get(key, 0)), 2 if strong else 1)
			for v in c.enemy_victims(e):
				threat[Vector2i(int(v["c"]), int(v["r"]))] = 2
	for r in 3:
		for x in 3:
			var col: int = (2 - x) if side == "hero" else x
			grid_cell(grid, side, col, r, mode, int(threat.get(Vector2i(col, r), 0)))


func grid_cell(parent: Node, side: String, c: int, r: int, mode: String, threat: int) -> void:
	var cb = combat
	var units: Array = cb.heroes if side == "hero" else cb.enemies
	var u: Dictionary = cb.unit_at(units, c, r)
	var dead: Dictionary = {}
	if u.is_empty() and side == "hero":
		dead = cb.unit_at(units, c, r, true)
	var pick := false
	if move_mode and side == "hero":
		if move_sel < 0:
			pick = not u.is_empty()
		else:
			pick = cb.can_move(move_sel, c, r)
	elif not u.is_empty():
		if side == "enemy" and mode == "enemy":
			pick = true
			if sel >= 0 and armed_spell == "":
				pick = cb.can_use(sel, u)
		elif side == "hero" and mode == "ally":
			pick = true
	elif not dead.is_empty() and mode == "dead":
		pick = true
	var chosen: bool = move_mode and side == "hero" and not u.is_empty() and int(u["i"]) == move_sel
	var bg := Color(C_PANEL, 0.78)
	var border := Color(C_LINE, 0.9)
	var bw := 1
	if threat == 2:
		bg = Color(0.38, 0.1, 0.08, 0.62)
		border = CAT["hurt"]
		bw = 2
	elif threat == 1:
		border = Color(CAT["hurt"], 0.55)
	if pick:
		border = C_BRASS
		bw = 3
		bg = Color(C_LINE, 0.9)
	if chosen:
		border = Color.WHITE
		bw = 3
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, border, 8, bw, 5))
	p.custom_minimum_size = Vector2(126, 126)
	parent.add_child(p)
	cell_ui["%s%d%d" % [side, c, r]] = p
	if pick or (move_mode and side == "hero"):
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.gui_input.connect(_cell_input.bind(side, c, r))
	if pick:
		var tw := p.create_tween().set_loops()
		tw.tween_property(p, "self_modulate", Color(1.3, 1.25, 1.0), 0.5)
		tw.tween_property(p, "self_modulate", Color.WHITE, 0.5)
	var who: Dictionary = u if not u.is_empty() else dead
	if who.is_empty():
		return
	if side == "hero":
		hero_cards[int(who["i"])] = p
	else:
		enemy_cards[int(who["i"])] = p
	var v := vb(p, 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var desc := ""
	if side == "hero":
		var pp: Dictionary = who["p"]
		var role: String = Data.hero_class(pp)["role"]
		var top := hb(v, 4, true)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl(top, Data.hero_class(pp)["name"], 12, C_TEXT, true)
		var inc: int = cb.incoming_for(who) if who["hp"] > 0 else 0
		if inc > 0:
			var danger: bool = inc >= int(who["hp"]) + int(who["shield"])
			var il := lbl(top, "-%d" % inc, 12, Color("#1b0d0a") if danger else CAT["hurt"], true)
			il.add_theme_stylebox_override("normal", sb(CAT["hurt"] if danger else Color(0, 0, 0, 0.4), CAT["hurt"], 6, 1, 4))
		var po = Portrait.new()
		po.setup("hero", _hero_art_key(str(pp["cls"])), str(Data.hero_class(pp)["name"]), ROLE_COL[role], 70.0, bold)
		po.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(po)
		if who["hp"] <= 0:
			p.modulate = Color(1, 1, 1, 0.4)
		desc = "%s · 체력 %d/%d" % [Data.hero_class(pp)["name"], who["hp"], who["maxhp"]]
		var hs := _hero_status(who)
		if hs != "":
			desc += " · " + hs
	else:
		var top2 := hb(v, 3, true)
		top2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var it := {"c": "blank", "t": ""}
		if who["face"] != null:
			var f: Dictionary = who["face"]
			var k: String = f["k"]
			var val: int = cb.enemy_value(who) if k in ["atk", "all"] else int(f["n"])
			var d = DieFace.new()
			d.setup(k, 0, "", CAT[ECAT.get(k, "blank")], 26.0, bold)
			d.dim = who["stunned"]
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top2.add_child(d)
			it = cb.enemy_intent(who)
			if val > 0 and not who["stunned"]:
				lbl(top2, str(val), 15, CAT[ECAT.get(k, "blank")], true)
		var nl := lbl(top2, str(who["name"]), 11, C_BRASS if who["boss"] else C_TEXT, true)
		nl.clip_text = true
		nl.custom_minimum_size = Vector2(52, 0)
		var po2 = Portrait.new()
		po2.setup("enemy", str(who["key"]), str(who["name"]), CAT["atk"], 68.0, bold, who["boss"])
		po2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(po2)
		desc = "%s%s · 체력 %d/%d · %s" % [who["name"], " (원거리)" if who["ranged"] else "", who["hp"], who["maxhp"], it["t"]]
		var es := _enemy_status(who)
		if es != "":
			desc += " · " + es
		var fl := []
		for f2 in who["faces"]:
			var w: String = str(Data.enemy_faces[f2["k"]]["w"])
			fl.append(w + (str(f2["n"]) if int(f2["n"]) > 0 else ""))
		desc += "\n주사위: " + ", ".join(PackedStringArray(fl))
	var pips = HpPips.new()
	pips.setup(int(who["hp"]), int(who["maxhp"]), int(who["shield"]), CAT["heal"] if side == "hero" else CAT["atk"], 100.0, true)
	pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pips)
	p.mouse_entered.connect(_info_show.bind(desc))
	p.mouse_exited.connect(_info_show.bind(""))


func _cell_input(event: InputEvent, side: String, c: int, r: int) -> void:
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
	if not u.is_empty():
		pick_target(u)


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


func hero_strip(parent: Node, h: Dictionary) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(Color(C_PANEL, 0.9), C_LINE, 8, 1, 8))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if h["hp"] <= 0:
		p.modulate = Color(1, 1, 1, 0.4)
	parent.add_child(p)
	var row := hb(p, 8)
	var v := vb(row, 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pp: Dictionary = h["p"]
	var role: String = Data.hero_class(pp)["role"]
	lbl(v, Data.hero_class(pp)["name"], 15, ROLE_COL[role], true)
	var st := _hero_status(h)
	lbl(v, st if st != "" else "체력 %d/%d" % [h["hp"], h["maxhp"]], 12, CAT["def"] if st != "" else C_MUTED, false, true)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(grid)
	var cur := -1
	if h["face"] != null:
		cur = int(h["face_idx"])
	for i in 6:
		var face: Dictionary = Data.hero_face(pp, i)
		var m = make_die(grid, face, 32.0)
		m.selected = i == cur and h["hp"] > 0
		m.dim = h["hp"] <= 0
		m.mouse_entered.connect(_info_show.bind(Data.face_desc(face)))
		m.mouse_exited.connect(_info_show.bind(""))


func _info_show(text: String) -> void:
	if info_lbl != null and is_instance_valid(info_lbl):
		info_lbl.text = text if text != "" else info_default
		info_lbl.add_theme_color_override("font_color", C_TEXT if text != "" else C_MUTED)


func _update_links() -> void:
	await get_tree().process_frame
	if combat == null or links == null:
		return
	var out := []
	for e in combat.live_enemies():
		if e["stunned"] or e["face"] == null or str(e["tmode"]) == "":
			continue
		var ec = enemy_cards.get(int(e["i"]))
		if ec == null or not is_instance_valid(ec):
			continue
		var er: Rect2 = ec.get_global_rect()
		var k: String = e["face"]["k"]
		var cells := []
		if str(e["tmode"]) == "cross":
			cells = [[int(e["tc"]), int(e["tr"])]]
		else:
			for v in combat.enemy_victims(e):
				cells.append([int(v["c"]), int(v["r"])])
			if cells.is_empty():
				cells = [[0 if str(e["tmode"]) == "row" else int(e["tc"]), int(e["tr"])]]
		for cell in cells:
			var hc = cell_ui.get("hero%d%d" % [int(cell[0]), int(cell[1])])
			if hc == null or not is_instance_valid(hc):
				continue
			var hr: Rect2 = hc.get_global_rect()
			out.append({"a": Vector2(er.position.x, er.get_center().y), "b": hr.get_center(), "col": Color(CAT[ECAT[k]], 0.5)})
	links.set_links(out)


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


func tray_slot(parent: Node, h: Dictionary) -> void:
	var v := vb(parent, 4)
	v.custom_minimum_size = Vector2(TRAY_DIE, 0)
	if h["hp"] > 0 and h["face"] != null:
		var face: Dictionary = combat.shown_face(h)
		var locked: bool = combat.phase == "roll" and h["locked"]
		var d = die_widget(v, face, locked, sel == int(h["i"]), h["used"], on_die.bind(int(h["i"])), h["fresh"])
		d.mouse_entered.connect(_info_show.bind(Data.face_desc(face)))
		d.mouse_exited.connect(_info_show.bind(""))
		h["fresh"] = false
	else:
		var ph := Control.new()
		ph.custom_minimum_size = Vector2(TRAY_DIE, TRAY_DIE)
		v.add_child(ph)
	var role: String = Data.hero_class(h["p"])["role"]
	var nl := lbl(v, combat.hero_label(h), 14, ROLE_COL[role] if h["hp"] > 0 else Color(C_MUTED, 0.4), true)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _cancel_sel() -> void:
	sel = -1
	armed_spell = ""
	refresh()


func _card_input(event: InputEvent, t: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pick_target(t)


func die_widget(parent: Node, face: Dictionary, locked: bool, selected: bool, used: bool, cb: Callable, fresh := false) -> Control:
	var d = make_die(parent, face, TRAY_DIE)
	d.locked = locked
	d.selected = selected
	d.dim = used
	if cb.is_valid():
		d.clickable = true
		d.mouse_filter = Control.MOUSE_FILTER_STOP
		d.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		d.pressed.connect(cb)
	if fresh:
		d.tumble()
	return d


func _play_events() -> void:
	if combat == null:
		return
	var list: Array = combat.events.duplicate()
	combat.events.clear()
	var stack := {}
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
		var l := Label.new()
		l.text = e["text"]
		l.add_theme_font_override("font", bold)
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", CAT.get(e["color"], C_TEXT))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 6)
		fx.add_child(l)
		var r: Rect2 = card.get_global_rect()
		l.global_position = Vector2(r.position.x + r.size.x - 100, r.position.y + 4 + n * 26)
		var tw := l.create_tween().set_parallel(true)
		tw.tween_property(l, "position:y", l.position.y - 36, 0.9).set_delay(n * 0.08)
		tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(n * 0.08)
		tw.chain().tween_callback(l.queue_free)


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
		if not c.use_die(i, null):
			message = "지금은 쓸 수 없는 면"
		sel = -1
		after_action()
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
	var ok := false
	if armed_spell != "":
		ok = combat.cast(armed_spell, t)
		armed_spell = ""
	elif sel >= 0:
		ok = combat.use_die(sel, t)
		sel = -1
	if not ok:
		message = "그 대상에는 쓸 수 없음"
	after_action()


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
	sel = -1
	armed_spell = ""
	busy = true
	refresh()
	await get_tree().create_timer(0.25).timeout
	if combat == null:
		return
	combat.end_turn()
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
	var kind: String = combat.kind
	Game.run["kills"] = int(Game.run["kills"]) + combat.enemies.size()
	combat = null
	var gold := 10 + randi() % 8
	if kind == "boss":
		gold = 60
	elif kind == "elite":
		gold = 30 + randi() % 10
	Game.run["gold"] = int(Game.run["gold"]) + gold
	if kind == "boss" and int(Game.run["act"]) >= Data.encounters.size() - 1:
		Game.clear_save()
		show_end(true, "")
		return
	if kind != "boss":
		Game.run["pending"] = ""
		Game.save()
	var after := _after_reward.bind(kind)
	clear_screen()
	top_bar()
	var v := panel(root)
	lbl(v, "승리", 26, C_BRASS, true)
	lbl(v, "골드 +%d. 보상 하나 선택." % gold, 17, C_MUTED)
	choice(v, "주사위 면 강화", "영웅 하나의 스킬 면 하나를 골라 강화", choose_face_upgrade.bind("주사위 면 강화", after, Callable()))
	var keys := Data.items.keys()
	keys.shuffle()
	for id in keys.slice(0, 3 if kind == "elite" else 2):
		choice(v, "장비: " + Data.items[id]["name"], Data.items[id]["text"], choose_item_holder.bind(id, after))
	if kind == "elite":
		choice(v, "면 강화 두 번", "면 강화를 두 번 연속", _double_upgrade.bind("면 강화", after))


func _after_reward(kind: String) -> void:
	if kind == "boss":
		show_promotion()
	else:
		show_map()


func _double_upgrade(title: String, done: Callable) -> void:
	choose_face_upgrade(title + " (1/2)", choose_face_upgrade.bind(title + " (2/2)", done, Callable()), Callable())


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


func show_promotion() -> void:
	promo_choice = {}
	var party: Array = Game.run["party"]
	for hi in party.size():
		var opts: Array = Data.hero_class(party[hi])["promo"]
		if opts.size() == 1:
			promo_choice[hi] = str(opts[0])
	_draw_promotion()


func _draw_promotion() -> void:
	clear_screen()
	top_bar()
	var act := int(Game.run["act"])
	var area := scroll_area(root)
	var party: Array = Game.run["party"]
	var need := 0
	for p in party:
		if not Data.hero_class(p)["promo"].is_empty():
			need += 1
	btn(area, "전직하고 %d막으로" % (act + 2), _apply_promotion, true, promo_choice.size() < need)
	lbl(area, "%d막 돌파 · 전직" % (act + 1), 26, C_BRASS, true)
	var note := "모든 영웅이 다음 단계 직업으로 전직. 빈 면이 스킬로 채워지고 새 스킬이 열림." if act == 0 else "영웅마다 두 갈래 중 하나 선택."
	lbl(area, note + " 면 강화와 각인은 같은 자리에 그대로 이어짐.", 16, C_MUTED, false, true)
	for hi in party.size():
		var p: Dictionary = party[hi]
		var opts: Array = Data.hero_class(p)["promo"]
		if opts.is_empty():
			continue
		lbl(area, Data.hero_class(p)["name"], 15, C_MUTED, true)
		var row := hb(area, 10)
		for k in opts:
			var cls: Dictionary = Data.classes[k]
			var col := vb(row, 4)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			choice(col, "%s  (체력 %d)" % [cls["name"], cls["hp"]], cls["desc"] + _spell_note(cls), _pick_promo.bind(hi, k), false, promo_choice.get(hi, "") == k)
			var tmp: Dictionary = p.duplicate(true)
			tmp["cls"] = k
			face_row(col, tmp)


func _pick_promo(hi: int, k: String) -> void:
	promo_choice[hi] = k
	_draw_promotion()


func _apply_promotion() -> void:
	var party: Array = Game.run["party"]
	for hi in party.size():
		if promo_choice.has(hi):
			party[hi]["cls"] = promo_choice[hi]
	Game.next_act()
	show_map()


# =============== forge, shop, events ===============

func show_forge() -> void:
	clear_screen()
	top_bar()
	var v := panel(root)
	lbl(v, "대장간", 26, C_BRASS, true)
	lbl(v, "불꽃이 튀는 모루 앞. 하나만 선택.", 16, C_MUTED)
	choice(v, "면 벼리기", "주사위 면 강화 두 번", _double_upgrade.bind("면 벼리기", show_map))
	choice(v, "갑옷 손질", "모든 영웅 최대 체력 +1", _forge_hp)


func _forge_hp() -> void:
	for p in Game.run["party"]:
		p["hp_bonus"] = int(p["hp_bonus"]) + 1
	show_map()


func show_shop() -> void:
	var keys := Data.items.keys()
	keys.shuffle()
	shop_stock = []
	for id in keys.slice(0, 3):
		shop_stock.append({"id": id, "p": 55 + randi() % 25, "sold": false})
	shop_face = {"p": 35, "left": 2}
	_draw_shop()


func _draw_shop() -> void:
	clear_screen()
	top_bar()
	var v := panel(root)
	var gold := int(Game.run["gold"])
	lbl(v, "떠돌이 상점", 26, C_BRASS, true)
	lbl(v, "보따리를 펼친 상인. 소지금 %d 골드." % gold, 16, C_MUTED)
	for idx in shop_stock.size():
		var s: Dictionary = shop_stock[idx]
		var sub: String = Data.items[s["id"]]["text"]
		sub += "  ·  판매 완료" if s["sold"] else "  ·  %d 골드" % s["p"]
		choice(v, Data.items[s["id"]]["name"], sub, _buy_item.bind(idx), s["sold"] or gold < int(s["p"]))
	choice(v, "면 손질", "주사위 면 강화 한 번 (남은 수량 %d)  ·  %d 골드" % [shop_face["left"], shop_face["p"]], _buy_face, int(shop_face["left"]) < 1 or gold < int(shop_face["p"]))
	btn(v, "상점 떠나기", show_map, true)


func _buy_item(idx: int) -> void:
	choose_item_holder(shop_stock[idx]["id"], _bought_item.bind(idx))


func _bought_item(idx: int) -> void:
	var s: Dictionary = shop_stock[idx]
	Game.run["gold"] = int(Game.run["gold"]) - int(s["p"])
	s["sold"] = true
	Game.save()
	_draw_shop()


func _buy_face() -> void:
	choose_face_upgrade("면 손질", _bought_face, _draw_shop)


func _bought_face() -> void:
	Game.run["gold"] = int(Game.run["gold"]) - int(shop_face["p"])
	shop_face["left"] = int(shop_face["left"]) - 1
	Game.save()
	_draw_shop()


func show_event() -> void:
	var gold := int(Game.run["gold"])
	var list := [
		{"title": "수상한 샘", "text": "바위 틈에서 은빛 물이 솟는 샘. 한 명이 마셔 볼 수 있음.", "opts": [
			{"label": "한 명이 마신다", "sub": "반반 확률: 무작위 영웅 최대 체력 +3, 또는 최대 체력 -1", "id": "spring"},
			{"label": "그냥 지나간다", "sub": "아무 일도 없음", "id": "pass_spring"}]},
		{"title": "도박꾼의 탁자", "text": "길가에 주사위 탁자를 펼친 노인. \"20골드 걸고 한 판? 공격 면이 나오면 자네 승리.\"", "opts": [
			{"label": "20골드를 건다", "sub": "절반 확률로 골드 +30, 아니면 -20", "id": "gamble", "disabled": gold < 20},
			{"label": "거절한다", "sub": "아무 일도 없음", "id": "pass_gamble"}]},
		{"title": "버려진 배낭", "text": "쓰러진 모험가 곁에 놓인 낡은 배낭.", "opts": [
			{"label": "안을 뒤진다", "sub": "무작위 장비 1개", "id": "pack_item"},
			{"label": "주머니만 챙긴다", "sub": "골드 +30", "id": "pack_gold"}]},
		{"title": "낡은 제단", "text": "핏자국이 말라붙은 돌 제단. 피를 바치면 보답이 있을 듯한 기운.", "opts": [
			{"label": "피를 바친다", "sub": "무작위 영웅 최대 체력 -2, 면 강화 두 번", "id": "altar"},
			{"label": "떠난다", "sub": "아무 일도 없음", "id": "pass_altar"}]},
		{"title": "떠돌이 대장장이", "text": "모루를 짊어진 대장장이. \"주사위 좀 손봐 줄까? 공짜로.\"", "opts": [
			{"label": "부탁한다", "sub": "면 강화 한 번", "id": "smith"},
			{"label": "사양한다", "sub": "골드 +15 (길 안내 값)", "id": "smith_gold"}]},
	]
	cur_event = list[randi() % list.size()]
	clear_screen()
	top_bar()
	var v := panel(root)
	lbl(v, cur_event["title"], 26, C_BRASS, true)
	lbl(v, cur_event["text"], 17, C_MUTED, false, true)
	for o in cur_event["opts"]:
		choice(v, o["label"], o["sub"], _event_pick.bind(o["id"]), o.get("disabled", false))


func _event_pick(id: String) -> void:
	var party: Array = Game.run["party"]
	var title: String = cur_event["title"]
	var res := ""
	match id:
		"spring":
			var p: Dictionary = party[randi() % party.size()]
			if randf() < 0.5:
				p["hp_bonus"] = int(p["hp_bonus"]) + 3
				res = "%s의 몸에 힘이 차오름. 최대 체력 +3." % Data.hero_class(p)["name"]
			else:
				p["hp_bonus"] = int(p["hp_bonus"]) - 1
				res = "물이 썩어 있었음. %s의 최대 체력 -1." % Data.hero_class(p)["name"]
		"pass_spring":
			res = "샘을 뒤로하고 길을 재촉함."
		"gamble":
			if randf() < 0.5:
				Game.run["gold"] = int(Game.run["gold"]) + 30
				res = "공격 면. 골드 +30."
			else:
				Game.run["gold"] = int(Game.run["gold"]) - 20
				res = "빈 면. 골드 -20."
		"pass_gamble":
			res = "노인이 아쉬운 듯 혀를 참."
		"pack_item":
			var keys := Data.items.keys()
			choose_item_holder(keys[randi() % keys.size()], show_map)
			return
		"pack_gold":
			Game.run["gold"] = int(Game.run["gold"]) + 30
			res = "골드 +30."
		"altar":
			var p: Dictionary = party[randi() % party.size()]
			p["hp_bonus"] = int(p["hp_bonus"]) - 2
			_double_upgrade("%s · %s의 최대 체력 -2" % [title, Data.hero_class(p)["name"]], show_map)
			return
		"pass_altar":
			res = "불길한 기운을 피해 자리를 뜸."
		"smith":
			choose_face_upgrade(title, show_map, Callable())
			return
		"smith_gold":
			Game.run["gold"] = int(Game.run["gold"]) + 15
			res = "대장장이가 지름길을 알려 주고 골드 15를 건넴."
	Game.save()
	clear_screen()
	top_bar()
	var rv := panel(root)
	lbl(rv, title, 26, C_BRASS, true)
	lbl(rv, res, 18, C_TEXT, false, true)
	btn(rv, "계속", show_map, true)


# =============== end ===============

func show_end(won: bool, killer: String) -> void:
	clear_screen()
	top_bar()
	var area := scroll_area(root)
	lbl(area, "운명을 이긴 원정대" if won else "전멸한 원정대", 34, C_BRASS, true)
	var line := "운명의 도박사를 쓰러뜨리고 세 개의 막을 모두 돌파."
	if not won:
		line = "%d막에서 %s에게 전멸." % [int(Game.run["act"]) + 1, killer]
	lbl(area, line, 18, C_MUTED, false, true)
	lbl(area, "쓰러뜨린 적 %d · 지나온 층 %d" % [int(Game.run["kills"]), int(Game.run["floors"])], 17, C_TEXT)
	for p in Game.run["party"]:
		var pv := panel(area)
		lbl(pv, Data.hero_name(p), 19, C_TEXT, true)
		face_row(pv, p)
	btn(area, "새 원정", show_party_select, true)
