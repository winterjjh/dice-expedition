extends Node
## Run state (party, progress through the 20 fights) and save/load. Autoload "Game".

const SAVE_PATH := "user://run.json"

## A run is twenty fights in a row with no map. Every fourth fight is a boss.
## "act" picks the enemy pool and backdrop, "kind" the pool inside it, and an
## optional "group" pins the exact enemies (the opening fight is kept gentle).
const STAGES := [
	{"act": 0, "kind": "fight", "group": ["rat", "rat"]},
	{"act": 0, "kind": "fight"},
	{"act": 0, "kind": "fight"},
	{"act": 0, "kind": "elite", "boss": true},
	{"act": 0, "kind": "fight"},
	{"act": 0, "kind": "fight"},
	{"act": 1, "kind": "fight"},
	{"act": 0, "kind": "boss", "boss": true},
	{"act": 1, "kind": "fight"},
	{"act": 1, "kind": "fight"},
	{"act": 1, "kind": "fight"},
	{"act": 1, "kind": "elite", "boss": true},
	{"act": 1, "kind": "fight"},
	{"act": 2, "kind": "fight"},
	{"act": 2, "kind": "fight"},
	{"act": 1, "kind": "boss", "boss": true},
	{"act": 2, "kind": "fight"},
	{"act": 2, "kind": "fight"},
	{"act": 2, "kind": "elite"},
	{"act": 2, "kind": "boss", "boss": true},
]
const DEFAULT_PARTY := ["shieldman", "archer", "pyro", "healer"]

var run = null
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func new_run(class_keys: Array, D) -> void:
	var party := []
	for k in class_keys:
		party.append(D.make_hero(k))
	run = {"party": party, "gold": 0, "act": 0, "stage": 0, "kills": 0, "seen": [], "pending": ""}


func stage_count() -> int:
	return STAGES.size()


func stage_info(i: int) -> Dictionary:
	return STAGES[clampi(i, 0, STAGES.size() - 1)]


func is_boss_stage(i: int) -> bool:
	return bool(stage_info(i).get("boss", false))


## After an odd-numbered fight the party picks an item, after an even one a hero changes class.
func reward_kind(cleared: int) -> String:
	return "item" if cleared % 2 == 1 else "levelup"


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
	if typeof(v) != TYPE_DICTIONARY or not v.has("party") or not v.has("stage"):
		return false
	for p in v["party"]:
		if not D.classes.has(str(p.get("cls", ""))):
			return false
		D.normalize_hero(p)
	for key in ["gold", "act", "stage", "kills"]:
		v[key] = int(v.get(key, 0))
	v["pending"] = str(v.get("pending", ""))
	if not v.has("seen"):
		v["seen"] = []
	run = v
	return true


func peek_saved_label() -> String:
	if not has_save():
		return ""
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var v = JSON.parse_string(f.get_as_text())
	if typeof(v) != TYPE_DICTIONARY or not v.has("stage"):
		return ""
	return "%d번째 전투" % (int(v["stage"]) + 1)


func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
