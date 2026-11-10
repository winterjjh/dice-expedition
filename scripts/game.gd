extends Node
## Run state (party, gold, map), map generation and save/load. Autoload "Game".

const SAVE_PATH := "user://run.json"
const ROWS := 7
const COLS := 4
const NODE_INFO := {
	"fight": {"ch": "전", "name": "전투"},
	"elite": {"ch": "정", "name": "정예"},
	"forge": {"ch": "대", "name": "대장간"},
	"shop": {"ch": "상", "name": "상점"},
	"event": {"ch": "?", "name": "미지"},
	"boss": {"ch": "왕", "name": "보스"},
}

var run = null
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func new_run(class_keys: Array, D) -> void:
	var party := []
	for k in class_keys:
		party.append(D.make_hero(k))
	run = {
		"party": party, "gold": 20, "act": 0, "map": gen_map(),
		"pos": [-1, -1], "path": [], "floors": 0, "kills": 0, "seen": [], "pending": "",
	}


func gen_map() -> Array:
	var nodes := []
	for r in ROWS:
		var row := []
		for c in COLS:
			row.append(null)
		nodes.append(row)
	var starts := [0, 1, 2, 3]
	starts.shuffle()
	for p in 4:
		var c: int = starts[p] if p < 3 else starts[rng.randi_range(0, 2)]
		for r in ROWS:
			if nodes[r][c] == null:
				nodes[r][c] = {"type": "", "next": []}
			if r < ROWS - 1:
				var nc := clampi(c + rng.randi_range(-1, 1), 0, COLS - 1)
				if not nc in nodes[r][c]["next"]:
					nodes[r][c]["next"].append(nc)
				c = nc
	var has_shop := false
	for r in ROWS:
		for c in COLS:
			var n = nodes[r][c]
			if n == null:
				continue
			if r == 0:
				n["type"] = "fight"
			elif r == ROWS - 1:
				n["type"] = "forge"
			else:
				var w := [["fight", 46], ["event", 20], ["elite", 15 if r >= 2 else 0], ["shop", 11], ["forge", 8 if r >= 2 else 0]]
				var total := 0
				for x in w:
					total += x[1]
				var t := rng.randi_range(0, total - 1)
				n["type"] = "fight"
				for x in w:
					t -= x[1]
					if t < 0:
						n["type"] = x[0]
						break
			if n["type"] == "shop":
				has_shop = true
	if not has_shop:
		for c in COLS:
			if nodes[3][c] != null:
				nodes[3][c]["type"] = "shop"
				break
	return nodes


func open_nodes() -> Array:
	var out := []
	var pr := int(run["pos"][0])
	var pc := int(run["pos"][1])
	if pr < 0:
		for c in COLS:
			if run["map"][0][c] != null:
				out.append([0, c])
	elif pr == ROWS - 1:
		out.append([ROWS, 0])
	else:
		for nc in run["map"][pr][pc]["next"]:
			out.append([pr + 1, int(nc)])
	return out


func enter_node(r: int, c: int) -> String:
	var type := "boss"
	if r < ROWS:
		run["pos"] = [r, c]
		run["path"].append("%d,%d" % [r, c])
		type = run["map"][r][c]["type"]
	run["floors"] += 1
	run["pending"] = type
	save()
	return type


func next_act() -> void:
	run["act"] += 1
	run["map"] = gen_map()
	run["pos"] = [-1, -1]
	run["path"] = []
	run["seen"] = []
	run["pending"] = ""
	save()


func save() -> void:
	if run == null:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(run))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_saved(D) -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var v = JSON.parse_string(f.get_as_text())
	if typeof(v) != TYPE_DICTIONARY or not v.has("party"):
		return false
	for p in v["party"]:
		D.normalize_hero(p)
	for key in ["gold", "act", "floors", "kills"]:
		v[key] = int(v[key])
	v["pos"] = [int(v["pos"][0]), int(v["pos"][1])]
	for row in v["map"]:
		for n in row:
			if n != null:
				var nx := []
				for x in n["next"]:
					nx.append(int(x))
				n["next"] = nx
	run = v
	return true


func peek_saved_label() -> String:
	if not has_save():
		return ""
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var v = JSON.parse_string(f.get_as_text())
	if typeof(v) != TYPE_DICTIONARY or not v.has("act"):
		return ""
	return "%d막 %d층" % [int(v["act"]) + 1, int(v["floors"])]


func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
