extends Node
## Headless balance and sanity check. Run:
##   godot --headless --path . res://tests/sim.tscn
## Validates the data tables, then plays many full runs with a simple bot
## (fights only: normal x4, elite x1, boss per act, with rewards and promotions)
## and prints win rates. Prints "SIM OK" at the end when nothing broke.

const Combat = preload("res://scripts/combat.gd")
const RUNS := 120
const MAX_TURNS := 40

var errors := []


func _ready() -> void:
	validate()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var wins := 0
	var deaths := {0: 0, 1: 0, 2: 0}
	var stalls := 0
	var face_use := {}
	for r in RUNS:
		var keys := []
		for role in Data.ROLES:
			keys.append(role["opts"][rng.randi_range(0, 1)])
		Game.new_run(keys, Data)
		var run: Dictionary = Game.run
		var alive := true
		for act in 3:
			run["act"] = act
			var plan := ["fight", "fight", "fight", "elite", "fight", "boss"]
			for kind in plan:
				var enc: Dictionary = Data.encounters[act]
				var group: Array = enc["boss"] if kind == "boss" else enc["elite" if kind == "elite" else "normal"][rng.randi_range(0, enc["elite" if kind == "elite" else "normal"].size() - 1)]
				var res := play_fight(run, kind, group, face_use)
				if res == "stall":
					stalls += 1
					res = "lose"
				if res != "win":
					deaths[act] += 1
					alive = false
					break
				reward(run, rng, kind == "elite")
			if not alive:
				break
			if act == 0:
				for p in run["party"]:
					var promo: Array = Data.hero_class(p)["promo"]
					p["cls"] = promo[rng.randi_range(0, promo.size() - 1)]
			elif act == 1:
				for p in run["party"]:
					p["mastered"] = true
		if alive:
			wins += 1
	# save/load round trip
	Game.new_run(["shieldman", "archer", "pyro", "healer"], Data)
	Game.save()
	if not Game.load_saved(Data):
		errors.append("저장 불러오기 실패")
	Game.clear_save()
	print("SIM runs=%d wins=%d (%.0f%%) deaths_by_act=%s stalls=%d" % [RUNS, wins, 100.0 * wins / RUNS, str(deaths), stalls])
	var used := face_use.keys()
	used.sort()
	print("faces used: ", used)
	for k in Data.faces:
		if not k in face_use:
			print("WARN face never used by bot: ", k)
	if errors.is_empty():
		print("SIM OK")
		get_tree().quit(0)
	else:
		for e in errors:
			print("SIM ERROR: ", e)
		get_tree().quit(1)


func validate() -> void:
	for k in Data.classes:
		var c: Dictionary = Data.classes[k]
		if c["faces"].size() != 6:
			errors.append("%s 면 개수 %d" % [k, c["faces"].size()])
		for f in c["faces"]:
			if not Data.faces.has(f["k"]):
				errors.append("%s 알 수 없는 면 %s" % [k, f["k"]])
		for p in c["promo"]:
			if not Data.classes.has(p):
				errors.append("%s 승급 대상 없음 %s" % [k, p])
		if c["spell"] != "" and not Data.spells.has(c["spell"]):
			errors.append("%s 주문 없음 %s" % [k, c["spell"]])
	for k in Data.enemies:
		for f in Data.enemies[k]["faces"] + Data.enemies[k]["phase2"]:
			if not Data.enemy_faces.has(f["k"]):
				errors.append("%s 알 수 없는 적 면 %s" % [k, f["k"]])
	for a in Data.encounters:
		for g in a["normal"] + a["elite"] + [a["boss"]]:
			for k in g:
				if not Data.enemies.has(k):
					errors.append("조우에 없는 적 %s" % k)


func reward(run: Dictionary, rng: RandomNumberGenerator, elite: bool) -> void:
	var times := 2 if elite else 1
	for t in times:
		if rng.randf() < 0.65:
			var party: Array = run["party"]
			for attempt in 12:
				var p: Dictionary = party[rng.randi_range(0, party.size() - 1)]
				var i := rng.randi_range(0, 5)
				if Data.can_upgrade(p, i):
					p["bonus"][i] = int(p["bonus"][i]) + 1
					break
		else:
			var keys: Array = Data.items.keys()
			var p: Dictionary = run["party"][rng.randi_range(0, 3)]
			if p["items"].size() >= 2:
				p["items"].pop_front()
			p["items"].append(keys[rng.randi_range(0, keys.size() - 1)])


func play_fight(run: Dictionary, kind: String, group: Array, face_use: Dictionary) -> String:
	var c = Combat.new(Data, run, kind, group)
	c.start()
	while c.result == "" and c.turn <= MAX_TURNS:
		# roll phase: keep useful faces, reroll blanks / weak ones
		while c.can_reroll():
			var any := false
			for h in c.heroes:
				if h["hp"] <= 0 or h["face"] == null:
					continue
				var k: String = h["face"]["k"]
				var keep: bool = k != "blank"
				h["locked"] = keep
				if not keep:
					any = true
			if not any:
				break
			c.reroll()
		c.confirm()
		# use phase
		var guard := 0
		var progress := true
		while progress and c.result == "" and guard < 30:
			guard += 1
			progress = false
			for s in c.spells_available():
				var t = pick_spell_target(c, s)
				if c.can_cast(s, t):
					c.cast(s, t)
					progress = true
			for h in c.heroes:
				if c.result != "":
					break
				if h["used"] or h["hp"] <= 0 or h["face"] == null:
					continue
				var k: String = h["face"]["k"]
				var t = pick_target(c, h)
				if c.can_use(h["i"], t):
					face_use[k] = int(face_use.get(k, 0)) + 1
					c.use_die(h["i"], t)
					progress = true
		if c.result != "":
			break
		c.end_turn()
	if c.result == "":
		return "stall"
	return c.result


func pick_spell_target(c, s: String):
	match Data.spells[s]["t"]:
		"enemy":
			var best = null
			for e in c.live_enemies():
				if best == null or e["hp"] > best["hp"]:
					best = e
			return best
		"dead":
			for h in c.heroes:
				if h["hp"] <= 0:
					return h
			return null
	return null


func pick_target(c, h: Dictionary):
	var k: String = h["face"]["k"]
	var t: String = Data.face_target(k)
	if t == "enemy":
		var live: Array = c.live_enemies()
		if live.is_empty():
			return null
		if k == "execute":
			var n: int = c.face_value(h)
			for e in live:
				if e["hp"] <= n:
					return e
			return live[0]
		if k in ["stun", "steal", "rewind"]:
			var worst = live[0]
			var wv := -1
			for e in live:
				var v := 0
				if not e["stunned"] and e["face"] != null and e["face"]["k"] in ["atk", "all"]:
					v = c.enemy_value(e) * (3 if e["face"]["k"] == "all" else 1)
				if v > wv:
					wv = v
					worst = e
			return worst
		var low = live[0]
		for e in live:
			if e["hp"] < low["hp"]:
				low = e
		return low
	if t == "ally":
		var hs: Array = c.alive_heroes()
		if k == "bloodprice":
			for o in hs:
				if o["i"] != h["i"] and not o["used"] and o["face"] != null and o["face"]["k"] in Data.ATK_FAM:
					return o
			return null
		if k in ["shield", "link"]:
			var best = null
			var bi := -1
			for o in hs:
				if k == "link" and o["i"] == h["i"]:
					continue
				var inc: int = c.incoming_for(o)
				if inc > bi:
					bi = inc
					best = o
			return best
		var low = null
		for o in hs:
			if low == null or float(o["hp"]) / o["maxhp"] < float(low["hp"]) / low["maxhp"]:
				low = o
		return low
	return null
