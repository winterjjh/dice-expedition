extends Node
## Loads every balance table from res://data/*.json and holds hero-die helpers.
## Used as the autoload "Data"; tests create it with load(...).new().

const ATK_FAM := ["atk", "multi", "all", "pierce", "momentum", "guardhit", "bash", "frenzy", "duel", "mark", "suppress", "snipe", "backstab", "pilfer", "ember", "shatter"]
const DEF_FAM := ["shield", "shieldadj", "taunt", "guardhit", "thorns", "wall", "firewall", "icearmor"]
const HEAL_FAM := ["heal", "healall", "seed", "cleanse"]
const NO_NUMBER := ["steal", "stun", "freeze", "rewind", "link", "bloodprice", "aim", "echo", "smoke", "combust", "guardian", "encore", "discord", "retune", "blank"]
const ENGRAVE_STEPS := [5, 12]

const ROLES := [
	{"key": "front", "name": "전위", "opts": ["shieldman", "gladiator"]},
	{"key": "shooter", "name": "사수", "opts": ["archer", "rogue"]},
	{"key": "mage", "name": "마법", "opts": ["pyro", "frost"]},
	{"key": "support", "name": "지원", "opts": ["healer", "bard"]},
]

var faces := {}
var classes := {}
var spells := {}
var items := {}
var enemies := {}
var enemy_faces := {}
var encounters := []


func _init() -> void:
	load_all()


func _read(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("데이터 파일 없음: " + path)
		return {}
	var v = JSON.parse_string(f.get_as_text())
	if v == null:
		push_error("JSON 해석 실패: " + path)
		return {}
	return v


func conv_faces(arr) -> Array:
	var out := []
	for x in arr:
		var f := {"k": str(x[0]), "n": int(x[1]) if x.size() > 1 else 0}
		if x.size() > 2:
			f["w"] = str(x[2])
		out.append(f)
	return out


func load_all() -> void:
	faces = _read("res://data/faces.json")
	spells = _read("res://data/spells.json")
	for k in spells:
		spells[k]["cost"] = int(spells[k]["cost"])
	items = _read("res://data/items.json")
	var c = _read("res://data/classes.json")
	classes = {}
	for k in c:
		var d: Dictionary = c[k]
		d["hp"] = int(d["hp"])
		d["faces"] = conv_faces(d["faces"])
		if not d.has("promo"):
			d["promo"] = []
		if not d.has("spell"):
			d["spell"] = ""
		classes[k] = d
	var e = _read("res://data/enemies.json")
	enemies = {}
	for k in e["enemies"]:
		var d: Dictionary = e["enemies"][k]
		d["hp"] = int(d["hp"])
		d["faces"] = conv_faces(d["faces"])
		d["phase2"] = conv_faces(d["phase2"]) if d.has("phase2") else []
		if not d.has("phase_msg"):
			d["phase_msg"] = ""
		enemies[k] = d
	enemy_faces = e["enemy_faces"]
	encounters = e["encounters"]


# ---------- hero model (plain dictionaries so runs save to JSON) ----------

func make_hero(cls: String) -> Dictionary:
	return {"cls": cls, "mastered": false, "bonus": [0, 0, 0, 0, 0, 0], "uses": [0, 0, 0, 0, 0, 0], "items": [], "hp_bonus": 0}


func normalize_hero(p: Dictionary) -> void:
	for key in ["bonus", "uses"]:
		var arr := []
		for v in p.get(key, [0, 0, 0, 0, 0, 0]):
			arr.append(int(v))
		p[key] = arr
	p["hp_bonus"] = int(p.get("hp_bonus", 0))
	p["mastered"] = bool(p.get("mastered", false))
	var its := []
	for it in p.get("items", []):
		its.append(str(it))
	p["items"] = its


func hero_class(p: Dictionary) -> Dictionary:
	return classes[p["cls"]]


func hero_name(p: Dictionary) -> String:
	return hero_class(p)["name"] + (" (숙련)" if p["mastered"] else "")


func hero_max_hp(p: Dictionary) -> int:
	var hp: int = hero_class(p)["hp"] + int(p["hp_bonus"])
	if p["mastered"]:
		hp += 2
	if "armor" in p["items"]:
		hp += 3
	return max(1, hp)


func _fill_face(cls: Dictionary) -> Dictionary:
	for f in cls["faces"]:
		if f["k"] != "blank":
			return {"k": f["k"], "n": max(1, int(f["n"]) - 1) if not f["k"] in NO_NUMBER else 0}
	return {"k": "atk", "n": 1}


func hero_face(p: Dictionary, i: int) -> Dictionary:
	var cls := hero_class(p)
	var face: Dictionary = cls["faces"][i].duplicate()
	if p["mastered"]:
		if face["k"] == "blank":
			face = _fill_face(cls)
		elif not face["k"] in NO_NUMBER:
			face["n"] += 1
	var b := int(p["bonus"][i])
	if b > 0:
		if face["k"] == "blank":
			face = _fill_face(cls)
			if not face["k"] in NO_NUMBER:
				face["n"] += b - 1
		elif not face["k"] in NO_NUMBER:
			face["n"] += b
	var its: Array = p["items"]
	if "whet" in its and face["k"] in ATK_FAM:
		face["n"] += 1
	if "buckler" in its and face["k"] in DEF_FAM:
		face["n"] += 1
	if "incense" in its and face["k"] in HEAL_FAM:
		face["n"] += 1
	if "crystal" in its and face["k"] in ["mana", "heat"]:
		face["n"] += 1
	if "glove" in its and face["k"] == "poison":
		face["n"] += 1
	return face


func can_upgrade(p: Dictionary, i: int) -> bool:
	var f := hero_face(p, i)
	return f["k"] == "blank" or not f["k"] in NO_NUMBER


func face_name(face: Dictionary) -> String:
	return str(face.get("w", faces[face["k"]]["w"]))


func face_short(face: Dictionary) -> String:
	return face_title(face)


func face_title(face: Dictionary) -> String:
	if face["k"] in NO_NUMBER:
		return face_name(face)
	return "%s %d" % [face_name(face), face["n"]]


func face_desc(face: Dictionary) -> String:
	var info: Dictionary = faces[face["k"]]
	return face_title(face) + " · " + str(info["d"]).replace("{n}", str(face["n"]))


func face_cat(face: Dictionary) -> String:
	return faces[face["k"]]["c"]


func face_target(k: String) -> String:
	return faces[k]["t"]
