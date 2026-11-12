extends Control
## Screen manager. Every screen is built in code from the Data/Game autoloads,
## so balance lives in res://data/*.json and layout lives here.

const Combat = preload("res://scripts/combat.gd")
const MapView = preload("res://scripts/ui/map_view.gd")

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


func clear_screen() -> void:
	close_overlay()
	enemy_cards.clear()
	hero_cards.clear()
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


func chip(parent: Node, face: Dictionary, highlight := false) -> Label:
	var col: Color = CAT[Data.face_cat(face)]
	var l := Label.new()
	l.text = Data.face_short(face)
	l.tooltip_text = Data.face_desc(face)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_font_override("font", bold)
	l.add_theme_color_override("font_color", col)
	var s := sb(Color(col, 0.22) if highlight else Color(0, 0, 0, 0), col, 4, 1, 4)
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", s)
	parent.add_child(l)
	return l


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
		lbl(h, "골드 %d" % int(Game.run["gold"]), 17, C_BRASS, true)
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
	var c := CenterContainer.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(c)
	var v := vb(c, 18)
	var dice := hb(v, 12, true)
	for f in [{"k": "mark", "n": 2}, {"k": "steal", "n": 0}, {"k": "heat", "n": 2}, {"k": "seed", "n": 2}]:
		die_widget(dice, f, false, false, false, Callable())
	var t := lbl(v, "주사위 원정대", 54, C_BRASS, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := lbl(v, "영웅 넷이 저마다 다른 직업 주사위를 굴려 싸우는 원정.\n세 개의 막을 지나 운명의 도박사를 쓰러뜨리면 승리.", 18, C_MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		"성장 · 전투 보상으로 면 강화나 장비. 1막 보스 뒤 상위 직업으로 승급, 2막 보스 뒤 숙련. 영웅은 전투가 끝나면 모두 회복.",
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
	var area := scroll_area(root)
	lbl(area, "원정대 꾸리기", 26, C_BRASS, true)
	lbl(area, "역할마다 영웅 한 명씩 선택. 아래 칸은 그 영웅 주사위의 여섯 면 (마우스를 올리면 설명).", 16, C_MUTED, false, true)
	for role in Data.ROLES:
		lbl(area, role["name"], 15, C_MUTED, true)
		var row := hb(area, 10)
		for k in role["opts"]:
			var cls: Dictionary = Data.classes[k]
			var on: bool = party_choice.get(role["key"], "") == k
			var col := vb(row, 4)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			choice(col, "%s  (체력 %d)" % [cls["name"], cls["hp"]], cls["desc"] + _spell_note(cls), _pick_class.bind(role["key"], k), false, on)
			face_row(col, Data.make_hero(k))
	var act := hb(area, 10)
	btn(act, "무작위로 채우기", _random_party)
	btn(act, "출발", _start_run, true, party_choice.size() < Data.ROLES.size())


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
	top_bar()
	var mode := target_mode()
	var er := hb(root, 12, true)
	for e in c.enemies:
		enemy_card(er, e, mode == "enemy" and e["hp"] > 0)
	var last := ""
	if c.logs.size() > 0:
		last = c.logs[c.logs.size() - 1]
	var logl := lbl(root, message if message != "" else last, 16, C_MUTED)
	logl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message = ""
	var mrow := hb(root, 8, true)
	var ml := lbl(mrow, "마나 %d" % c.mana, 17, CAT["mana"], true)
	ml.add_theme_stylebox_override("normal", sb(Color(0, 0, 0, 0), CAT["mana"], 14, 1, 10))
	for s in c.spells_available():
		var spd: Dictionary = Data.spells[s]
		var off: bool = c.phase != "use" or c.mana < int(spd["cost"]) or busy
		var b := btn(mrow, "%s · 마나 %d\n%s" % [spd["name"], spd["cost"], spd["text"]], on_spell.bind(s), false, off)
		b.add_theme_font_size_override("font_size", 15)
		if armed_spell == s:
			b.add_theme_stylebox_override("normal", sb(CAT["mana"], C_IVORY))
			b.add_theme_color_override("font_color", Color("#1a1226"))
	var hr := hb(root, 10, true)
	hr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for h in c.heroes:
		var pick: bool = (mode == "ally" and h["hp"] > 0) or (mode == "dead" and h["hp"] <= 0)
		hero_card(hr, h, pick)
	var ar := hb(root, 12, true)
	var help := ""
	if c.phase == "roll":
		btn(ar, "다시 굴리기 (%d)" % c.rerolls, on_reroll, false, busy or not c.can_reroll())
		btn(ar, "굴림 확정", on_confirm, true, busy)
		help = "굴림 단계 · 마음에 드는 주사위를 눌러 고정하고 나머지를 다시 굴림. 다 정해지면 굴림 확정."
	else:
		if sel >= 0 or armed_spell != "":
			btn(ar, "선택 취소", _cancel_sel)
		btn(ar, "턴 종료", on_end_turn, true, busy)
		help = "사용 단계 · 주사위를 누른 뒤 빛나는 대상을 누르면 발동. 쓰지 않은 주사위는 사라짐. 적은 턴 종료 후 표시된 행동을 실행."
	lbl(root, help, 14, C_MUTED, false, true)
	_play_events.call_deferred()


func _cancel_sel() -> void:
	sel = -1
	armed_spell = ""
	refresh()


func _card_input(event: InputEvent, t: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pick_target(t)


func enemy_card(parent: Node, e: Dictionary, pickable: bool) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(C_LINE if pickable else C_PANEL, C_IVORY if pickable else C_LINE, 10, 2 if pickable else 1, 12))
	p.custom_minimum_size = Vector2(220, 0)
	if e["hp"] <= 0:
		p.modulate = Color(1, 1, 1, 0.3)
	if pickable:
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.gui_input.connect(_card_input.bind(e))
	parent.add_child(p)
	enemy_cards[int(e["i"])] = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var top := hb(v, 6)
	lbl(top, e["name"], 19, C_TEXT, true)
	spacer(top)
	if e["boss"]:
		lbl(top, "보스" + (" · 2단계" if e["phased"] else ""), 13, C_BRASS, true)
	var br := hb(v, 6)
	hp_bar(br, e["hp"], e["maxhp"], CAT["atk"])
	lbl(br, "%d/%d" % [e["hp"], e["maxhp"]], 14)
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
		st.append("표식 (받는 피해 +%d)" % e["mark"])
	if st.size() > 0:
		lbl(v, " · ".join(PackedStringArray(st)), 14, CAT["def"])
	if e["hp"] > 0 and e["face"] != null:
		var it: Dictionary = combat.enemy_intent(e)
		var il := lbl(v, it["t"], 16, CAT[it["c"]], true, true)
		il.add_theme_stylebox_override("normal", sb(Color(0, 0, 0, 0.15), CAT[it["c"]], 6, 1, 8))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(row)
		for f in e["faces"]:
			var l := Label.new()
			var info: Dictionary = Data.enemy_faces[f["k"]]
			var w: String = info["w"]
			var has_n: bool = int(f["n"]) > 0
			l.text = w.substr(0, 1) + (str(f["n"]) if has_n else "")
			l.tooltip_text = w + ((" %d" % f["n"]) if has_n else "") + ((" · " + str(info["d"])) if info.has("d") else "")
			l.mouse_filter = Control.MOUSE_FILTER_PASS
			l.add_theme_font_size_override("font_size", 12)
			l.add_theme_color_override("font_color", C_MUTED)
			row.add_child(l)
	elif e["hp"] <= 0:
		lbl(v, "쓰러짐", 15, C_MUTED)


func hero_card(parent: Node, h: Dictionary, pickable: bool) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(C_LINE if pickable else C_PANEL, C_IVORY if pickable else C_LINE, 10, 2 if pickable else 1, 12))
	p.custom_minimum_size = Vector2(250, 0)
	if h["hp"] <= 0 and not pickable:
		p.modulate = Color(1, 1, 1, 0.35)
	if pickable:
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.gui_input.connect(_card_input.bind(h))
	parent.add_child(p)
	hero_cards[int(h["i"])] = p
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var pp: Dictionary = h["p"]
	var top := hb(v, 6)
	lbl(top, Data.hero_class(pp)["name"], 19, C_TEXT, true)
	spacer(top)
	var inc := 0
	if h["hp"] > 0:
		inc = combat.incoming_for(h)
	if inc > 0:
		lbl(top, "받을 피해 %d" % inc, 14, CAT["hurt"], true)
	var br := hb(v, 6)
	hp_bar(br, h["hp"], h["maxhp"], CAT["heal"])
	lbl(br, "%d/%d" % [h["hp"], h["maxhp"]], 14)
	var st := []
	if h["shield"] > 0:
		st.append("방어 %d" % h["shield"])
	if h["poison"] > 0:
		st.append("독 %d" % h["poison"])
	if h["streak"] > 0:
		st.append("기세 %d" % h["streak"])
	if h["aimed"]:
		st.append("조준 완료 (공격 ×3)")
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
		st.append("저주 (다음 턴 빈 면)")
	if st.size() > 0:
		lbl(v, " · ".join(PackedStringArray(st)), 14, CAT["def"], false, true)
	var dr := hb(v, 0, true)
	dr.custom_minimum_size = Vector2(0, 92)
	if h["hp"] > 0 and h["face"] != null:
		var face: Dictionary = combat.shown_face(h)
		var locked: bool = combat.phase == "roll" and h["locked"]
		die_widget(dr, face, locked, sel == int(h["i"]), h["used"], on_die.bind(int(h["i"])), h["fresh"])
		h["fresh"] = false
	else:
		lbl(dr, "쓰러짐" if h["hp"] <= 0 else "다음 턴부터 굴림", 15, C_MUTED)
	var cur := -1
	if h["face"] != null:
		cur = int(h["face_idx"])
	face_row(v, pp, cur)


func die_widget(parent: Node, face: Dictionary, locked: bool, selected: bool, used: bool, cb: Callable, fresh := false) -> Button:
	var cat: String = Data.face_cat(face)
	var col: Color = CAT[cat]
	var b := Button.new()
	b.custom_minimum_size = Vector2(124, 86)
	var num := ""
	if not face["k"] in Data.NO_NUMBER:
		num = str(face["n"])
	b.text = Data.face_name(face)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.tooltip_text = Data.face_desc(face)
	b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", 18)
	if num != "":
		var nl := Label.new()
		nl.text = num
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nl.add_theme_font_override("font", bold)
		nl.add_theme_font_size_override("font_size", 13)
		nl.add_theme_color_override("font_color", C_IVORY)
		nl.add_theme_stylebox_override("normal", sb(col.darkened(0.25), col.darkened(0.25), 9, 0, 6))
		nl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 5)
		nl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		nl.grow_vertical = Control.GROW_DIRECTION_BEGIN
		b.add_child(nl)
	var bg := C_IVORY if cat != "blank" else Color("#9aa39d")
	var border := col
	if locked:
		border = C_BRASS
	elif selected:
		border = Color.WHITE
	var s := sb(bg, border, 12, 4 if (locked or selected) else 2, 6)
	s.border_width_top = 10
	b.add_theme_stylebox_override("normal", s)
	var hs: StyleBoxFlat = s.duplicate()
	hs.bg_color = bg.lightened(0.08)
	b.add_theme_stylebox_override("hover", hs)
	b.add_theme_stylebox_override("pressed", hs)
	b.add_theme_stylebox_override("disabled", s)
	b.add_theme_stylebox_override("focus", sb(Color(0, 0, 0, 0), C_BRASS, 12, 2))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(k, C_INK)
	if locked:
		b.text += "\n(고정)"
		b.add_theme_font_size_override("font_size", 15)
	if used:
		b.modulate = Color(1, 1, 1, 0.25)
	if cb.is_valid():
		b.pressed.connect(cb)
	else:
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	if fresh:
		b.pivot_offset = b.custom_minimum_size * 0.5
		b.scale = Vector2(0.6, 0.6)
		b.rotation = -0.6
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "rotation", 0.0, 0.35)
	return b


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
	if int(Game.run["act"]) == 0:
		_draw_promotion()
	else:
		_draw_mastery()


func _draw_promotion() -> void:
	clear_screen()
	top_bar()
	var area := scroll_area(root)
	lbl(area, "1막 돌파 · 승급", 26, C_BRASS, true)
	lbl(area, "영웅마다 상위 직업 하나 선택. 면 강화와 각인은 같은 자리에 그대로 이어짐.", 16, C_MUTED, false, true)
	var party: Array = Game.run["party"]
	for hi in party.size():
		var p: Dictionary = party[hi]
		lbl(area, Data.hero_class(p)["name"], 15, C_MUTED, true)
		var row := hb(area, 10)
		for k in Data.hero_class(p)["promo"]:
			var cls: Dictionary = Data.classes[k]
			var col := vb(row, 4)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			choice(col, "%s  (체력 %d)" % [cls["name"], cls["hp"]], cls["desc"] + _spell_note(cls), _pick_promo.bind(hi, k), false, promo_choice.get(hi, "") == k)
			var tmp: Dictionary = p.duplicate(true)
			tmp["cls"] = k
			face_row(col, tmp)
	btn(area, "승급하고 2막으로", _apply_promotion, true, promo_choice.size() < party.size())


func _pick_promo(hi: int, k: String) -> void:
	promo_choice[hi] = k
	_draw_promotion()


func _apply_promotion() -> void:
	var party: Array = Game.run["party"]
	for hi in party.size():
		party[hi]["cls"] = promo_choice[hi]
	Game.next_act()
	show_map()


func _draw_mastery() -> void:
	clear_screen()
	top_bar()
	var area := scroll_area(root)
	lbl(area, "2막 돌파 · 숙련", 26, C_BRASS, true)
	lbl(area, "모든 영웅이 숙련 단계에 오름. 최대 체력 +2, 위력 수치가 있는 스킬 전부 +1.", 16, C_MUTED, false, true)
	for p in Game.run["party"]:
		var tmp: Dictionary = p.duplicate(true)
		tmp["mastered"] = true
		var pv := panel(area)
		lbl(pv, Data.hero_name(tmp), 19, C_TEXT, true)
		face_row(pv, tmp)
	btn(area, "3막으로", _apply_mastery, true)


func _apply_mastery() -> void:
	for p in Game.run["party"]:
		p["mastered"] = true
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
