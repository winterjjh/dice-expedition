extends RefCounted
## Pure combat logic: no nodes, so the UI and the headless test both drive it.
## Turn flow: start_turn() rolls -> roll phase (lock / reroll) -> confirm() -> use phase
## (use_die / cast) -> end_turn() resolves enemy actions -> start_turn() again.

var D
var run: Dictionary
var kind := "fight"
var heroes := []
var enemies := []
var mana := 0
var rerolls := 0
var phase := "roll"
var turn := 0
var atk_bonus := 0
var logs := []
var events := []   # {"side": "hero"/"enemy", "i": int, "text": String, "color": String}
var result := ""
var rng := RandomNumberGenerator.new()


func _init(data, run_state: Dictionary, fight_kind: String, group: Array) -> void:
	D = data
	run = run_state
	kind = fight_kind
	rng.randomize()
	var party: Array = run["party"]
	for i in party.size():
		var p: Dictionary = party[i]
		var mh: int = D.hero_max_hp(p)
		heroes.append({
			"i": i, "p": p, "hp": mh, "maxhp": mh, "shield": 0, "poison": 0,
			"face": null, "face_idx": -1, "locked": false, "used": true, "rolled": false, "fresh": false,
			"streak": 0, "mom_used": false, "aimed": false, "aim_pending": false, "heat": 0,
			"seed": 0, "link": -1, "hexed": false, "hexed_now": false, "taunt": false, "double": false,
			"thorns": 0, "dodge": false, "guard": false, "ward": false, "keep_shield": false,
		})
	for j in group.size():
		var key: String = group[j]
		var e: Dictionary = D.enemies[key]
		enemies.append({
			"i": j, "key": key, "name": e["name"], "hp": e["hp"], "maxhp": e["hp"],
			"faces": e["faces"].duplicate(true), "phase2": e["phase2"], "phase_msg": e["phase_msg"],
			"shield": 0, "poison": 0, "weak": 0, "stunned": false, "face": null, "target": -1,
			"frozen": false, "mark": 0, "boss": fight_kind == "boss" and j == 0, "phased": false,
		})
	mana = 3 if party_has("tome") else 0


# ---------------- queries ----------------

func party_has(id: String) -> bool:
	for h in heroes:
		if id in h["p"]["items"]:
			return true
	return false


func has_item(h: Dictionary, id: String) -> bool:
	return id in h["p"]["items"]


func alive_heroes() -> Array:
	return heroes.filter(func(h): return h["hp"] > 0)


func live_enemies() -> Array:
	return enemies.filter(func(e): return e["hp"] > 0)


func hero_label(h: Dictionary) -> String:
	return D.hero_class(h["p"])["name"]


func log_add(t: String) -> void:
	logs.append(t)
	if logs.size() > 60:
		logs.pop_front()


func ev(side: String, i: int, text: String, color: String) -> void:
	events.append({"side": side, "i": i, "text": text, "color": color})


func face_value(h: Dictionary) -> int:
	var f: Dictionary = h["face"]
	var n := int(f["n"])
	if f["k"] in D.ATK_FAM:
		n += atk_bonus
		if f["k"] == "momentum":
			n += int(h["streak"])
		elif f["k"] == "bash":
			n += int(h["shield"])
		elif f["k"] == "frenzy":
			n += (int(h["maxhp"]) - int(h["hp"])) / 2
		if h["aimed"]:
			n *= 3
	if h["double"]:
		n *= 2
	return n


func shown_face(h: Dictionary) -> Dictionary:
	if h["face"] == null:
		return {"k": "blank", "n": 0}
	var f: Dictionary = h["face"].duplicate()
	if not f["k"] in D.NO_NUMBER:
		f["n"] = face_value(h)
	return f


func target_kind_of(h: Dictionary) -> String:
	if h["face"] == null:
		return "none"
	return D.face_target(h["face"]["k"])


func spells_available() -> Array:
	var out := []
	for h in alive_heroes():
		var s: String = D.hero_class(h["p"])["spell"]
		if s != "" and not s in out:
			out.append(s)
	return out


func enemy_value(e: Dictionary) -> int:
	var f: Dictionary = e["face"]
	var n := int(f["n"])
	if f["k"] in ["atk", "all"]:
		n = max(0, n - int(e["weak"]))
	return n


func incoming_for(h: Dictionary) -> int:
	var dmg := 0
	for e in live_enemies():
		if e["stunned"] or e["face"] == null:
			continue
		var k: String = e["face"]["k"]
		if k == "all":
			dmg += enemy_value(e)
		elif k == "atk" and e["target"] == h["i"]:
			dmg += enemy_value(e)
	return dmg


func enemy_intent(e: Dictionary) -> Dictionary:
	if e["stunned"]:
		return {"c": "blank", "t": "기절 · 이번 행동 취소"}
	var f: Dictionary = e["face"]
	var tname := ""
	if e["target"] >= 0 and f["k"] in ["atk", "poison", "hex"]:
		tname = hero_label(heroes[e["target"]])
	match f["k"]:
		"atk": return {"c": "atk", "t": "공격 %d → %s" % [enemy_value(e), tname]}
		"all": return {"c": "atk", "t": "전체 공격 %d" % enemy_value(e)}
		"poison": return {"c": "poison", "t": "독 %d → %s" % [f["n"], tname]}
		"hex": return {"c": "trick", "t": "저주 → %s (다음 턴 빈 면)" % tname}
		"shield": return {"c": "def", "t": "방어 %d (적용됨)" % f["n"]}
		"heal":
			var nm := "자신"
			if e["target"] >= 0:
				nm = enemies[e["target"]]["name"]
			return {"c": "heal", "t": "회복 %d → %s" % [f["n"], nm]}
	return {"c": "blank", "t": "두리번거림"}


# ---------------- turn flow ----------------

func start() -> void:
	start_turn()


func start_turn() -> void:
	turn += 1
	atk_bonus = 0
	phase = "roll"
	for h in heroes:
		if not h["keep_shield"]:
			h["shield"] = 0
		h["keep_shield"] = false
		h["thorns"] = 0
		h["dodge"] = false
		h["guard"] = false
		h["ward"] = false
		h["taunt"] = false
		h["link"] = -1
		h["double"] = false
		h["locked"] = false
		h["aimed"] = h["aim_pending"]
		h["aim_pending"] = false
		if not h["mom_used"]:
			h["streak"] = 0
		h["mom_used"] = false
		h["hexed_now"] = h["hexed"]
		h["hexed"] = false
		h["used"] = true
		h["rolled"] = false
		h["face"] = null
		if h["hp"] <= 0:
			continue
		if h["poison"] > 0:
			hurt_raw_hero(h, h["poison"], "독")
			h["poison"] -= 1
		if h["hp"] > 0 and h["seed"] > 0:
			heal_hero(h, h["seed"])
			h["seed"] = 0
		if h["hp"] > 0 and has_item(h, "sprout"):
			heal_hero(h, 1)
		if h["hp"] > 0 and has_item(h, "charm"):
			h["shield"] += 2
		if h["hp"] > 0:
			h["rolled"] = true
			h["used"] = false
	if alive_heroes().is_empty():
		result = "lose"
		return
	for e in live_enemies():
		e["stunned"] = false
		e["mark"] = 0
		e["weak"] = 0
		e["shield"] = 0
		roll_enemy(e)
	rerolls = 2 + (1 if party_has("feather") else 0)
	roll_heroes(true)


func pick_hero_target() -> int:
	var hs := alive_heroes()
	var total := 0
	for h in hs:
		total += 3 if D.hero_class(h["p"])["role"] == "front" else 1
	var t := rng.randi_range(0, total - 1)
	for h in hs:
		t -= 3 if D.hero_class(h["p"])["role"] == "front" else 1
		if t < 0:
			return h["i"]
	return hs[0]["i"]


func roll_enemy(e: Dictionary) -> void:
	if e["frozen"] and e["face"] != null:
		e["frozen"] = false
	else:
		e["frozen"] = false
		e["face"] = e["faces"][rng.randi_range(0, e["faces"].size() - 1)].duplicate()
	e["target"] = -1
	var k: String = e["face"]["k"]
	if k == "shield":
		e["shield"] += int(e["face"]["n"])
	if k in ["atk", "poison", "hex"]:
		e["target"] = pick_hero_target()
	if k == "heal":
		var best = null
		for o in live_enemies():
			if best == null or float(o["hp"]) / o["maxhp"] < float(best["hp"]) / best["maxhp"]:
				best = o
		e["target"] = best["i"]
	for h in heroes:
		if h["taunt"] and h["hp"] > 0 and k in ["atk", "poison", "hex"]:
			e["target"] = h["i"]


func roll_heroes(all: bool) -> void:
	for h in heroes:
		if not h["rolled"] or h["hp"] <= 0:
			continue
		if not all and h["locked"]:
			continue
		if h["hexed_now"]:
			h["face"] = {"k": "blank", "n": 0}
			h["face_idx"] = -1
			continue
		h["face_idx"] = rng.randi_range(0, 5)
		h["face"] = D.hero_face(h["p"], h["face_idx"])
		h["fresh"] = true


func toggle_lock(i: int) -> void:
	if phase != "roll":
		return
	var h: Dictionary = heroes[i]
	if h["rolled"] and h["hp"] > 0:
		h["locked"] = not h["locked"]


func can_reroll() -> bool:
	if phase != "roll" or rerolls < 1:
		return false
	for h in heroes:
		if h["rolled"] and h["hp"] > 0 and not h["locked"] and not h["hexed_now"]:
			return true
	return false


func reroll() -> bool:
	if not can_reroll():
		return false
	rerolls -= 1
	roll_heroes(false)
	log_add("다시 굴림 · 남은 횟수 %d" % rerolls)
	return true


func confirm() -> void:
	phase = "use"
	for h in heroes:
		h["locked"] = false


# ---------------- damage helpers ----------------

func hit_enemy(e: Dictionary, n: int, src = null, ignore_shield := false) -> int:
	if e["hp"] <= 0:
		return 0
	if n > 0:
		n += int(e["mark"])
	var ab: int = 0 if ignore_shield else min(int(e["shield"]), n)
	e["shield"] -= ab
	var dmg := n - ab
	e["hp"] = max(0, int(e["hp"]) - dmg)
	ev("enemy", e["i"], "-%d" % dmg if dmg > 0 else "막힘", "hurt" if dmg > 0 else "def")
	if src != null and dmg > 0 and has_item(src, "fang"):
		heal_hero(src, 1)
	if e["boss"] and not e["phased"] and e["phase2"].size() > 0 and e["hp"] > 0 and e["hp"] * 2 <= e["maxhp"]:
		e["phased"] = true
		e["faces"] = e["phase2"].duplicate(true)
		log_add(e["phase_msg"])
		ev("enemy", e["i"], "2단계", "trick")
	if e["hp"] <= 0:
		log_add("%s 쓰러짐" % e["name"])
	return dmg


func hurt_raw_hero(h: Dictionary, n: int, why: String) -> void:
	if h["hp"] <= 0:
		return
	h["hp"] = max(0, int(h["hp"]) - n)
	ev("hero", h["i"], "%s -%d" % [why, n], "poison" if why == "독" else "hurt")
	if h["hp"] <= 0:
		h["face"] = null
		log_add("%s 쓰러짐" % hero_label(h))


func _apply_hero_damage(h: Dictionary, n: int) -> int:
	var ab: int = min(int(h["shield"]), n)
	h["shield"] -= ab
	var dmg := n - ab
	h["hp"] = max(0, int(h["hp"]) - dmg)
	ev("hero", h["i"], "-%d" % dmg if dmg > 0 else "막아냄", "hurt" if dmg > 0 else "def")
	if h["hp"] <= 0 and h["guard"]:
		h["hp"] = 1
		h["guard"] = false
		ev("hero", h["i"], "버팀", "heal")
		log_add("%s · 수호 기도로 버팀" % hero_label(h))
	if h["hp"] <= 0:
		h["face"] = null
		log_add("%s 쓰러짐" % hero_label(h))
	return dmg


func hurt_hero(h: Dictionary, n: int, attacker = null) -> void:
	if h["hp"] <= 0:
		return
	if attacker != null and h["dodge"]:
		h["dodge"] = false
		ev("hero", h["i"], "회피", "trick")
		log_add("%s · 연막으로 공격을 피함" % hero_label(h))
		return
	if attacker != null and n > 0 and int(h["thorns"]) > 0:
		hit_enemy(attacker, int(h["thorns"]))
	var partner = null
	if h["link"] >= 0 and heroes[h["link"]]["hp"] > 0:
		partner = heroes[h["link"]]
	if partner != null and n > 1:
		var half := n / 2
		_apply_hero_damage(h, n - half)
		_apply_hero_damage(partner, half)
	else:
		_apply_hero_damage(h, n)
	if attacker != null and n > 0 and has_item(h, "cloak"):
		hit_enemy(attacker, 2)


func heal_hero(h: Dictionary, n: int) -> void:
	if h["hp"] <= 0 or n <= 0:
		return
	var before: int = h["hp"]
	h["hp"] = min(int(h["maxhp"]), before + n)
	if h["hp"] > before:
		ev("hero", h["i"], "+%d" % (h["hp"] - before), "heal")


func shield_hero(h: Dictionary, n: int) -> void:
	if h["hp"] <= 0 or n <= 0:
		return
	h["shield"] += n
	ev("hero", h["i"], "방어 +%d" % n, "def")


func next_enemy(e: Dictionary):
	for j in range(e["i"] + 1, enemies.size()):
		if enemies[j]["hp"] > 0:
			return enemies[j]
	for j in range(0, e["i"]):
		if enemies[j]["hp"] > 0:
			return enemies[j]
	return null


func weakest_face(e: Dictionary) -> Dictionary:
	var best = null
	var best_score := 1e9
	for f in e["faces"]:
		var n := float(f["n"])
		var s := 0.0
		match f["k"]:
			"atk", "poison": s = n
			"all": s = n * 2.5
			"hex": s = 2.0
			"shield", "heal": s = n * 0.5
			_: s = 0.0
		if s < best_score:
			best_score = s
			best = f
	return best.duplicate()


func retarget_to(h: Dictionary) -> int:
	var count := 0
	for e in live_enemies():
		if e["stunned"] or e["face"] == null:
			continue
		if e["face"]["k"] in ["atk", "poison", "hex"] and e["target"] != h["i"]:
			e["target"] = h["i"]
			count += 1
		elif e["face"]["k"] == "all":
			count += 1
	return count


func engrave(h: Dictionary) -> void:
	var idx: int = h["face_idx"]
	if idx < 0:
		return
	var p: Dictionary = h["p"]
	p["uses"][idx] = int(p["uses"][idx]) + 1
	if int(p["uses"][idx]) in D.ENGRAVE_STEPS and D.can_upgrade(p, idx):
		p["bonus"][idx] = int(p["bonus"][idx]) + 1
		log_add("각인 · %s의 면이 손에 익어 강해짐 (%s)" % [hero_label(h), D.face_title(D.hero_face(p, idx))])
		ev("hero", h["i"], "각인", "trick")


# ---------------- using dice ----------------

func can_use(i: int, target) -> bool:
	var h: Dictionary = heroes[i]
	if phase != "use" or h["used"] or h["face"] == null or h["hp"] <= 0:
		return false
	var k: String = h["face"]["k"]
	var t: String = D.face_target(k)
	if t == "enemy":
		return target != null and target.has("key") and target["hp"] > 0
	if t == "ally":
		if target == null or target.has("key") or target["hp"] <= 0:
			return false
		if k in ["link", "bloodprice"] and target["i"] == h["i"]:
			return false
		if k == "bloodprice" and (target["used"] or target["face"] == null or int(h["hp"]) <= 2):
			return false
		if k in ["encore", "retune"] and (target["i"] == h["i"] or target["face"] == null):
			return false
		if k == "encore" and (not target["used"] or target["face"]["k"] in ["encore", "blank"]):
			return false
		if k == "retune" and (target["used"] or target["hexed_now"]):
			return false
		return true
	if k == "echo":
		return not echo_source(h).is_empty()
	return true


func echo_source(h: Dictionary) -> Dictionary:
	var n := heroes.size()
	for step in range(1, n):
		var o: Dictionary = heroes[(h["i"] - step + n) % n]
		if o["hp"] > 0 and o["face"] != null and o["face"]["k"] != "echo":
			return o
	return {}


func use_die(i: int, target = null) -> bool:
	if not can_use(i, target):
		return false
	var h: Dictionary = heroes[i]
	var f: Dictionary = h["face"]
	var k: String = f["k"]
	var n := face_value(h)
	var who := hero_label(h)
	h["used"] = true
	match k:
		"atk":
			hit_enemy(target, n, h)
			_glove(h, target)
			log_add("%s · %s %d → %s" % [who, D.face_name(f), n, target["name"]])
		"multi":
			hit_enemy(target, n, h)
			hit_enemy(target, n, h)
			_glove(h, target)
			log_add("%s · %s %d×2 → %s" % [who, D.face_name(f), n, target["name"]])
		"all":
			for e in live_enemies():
				hit_enemy(e, n, h)
			log_add("%s · %s %d" % [who, D.face_name(f), n])
		"pierce":
			var nxt = next_enemy(target)
			hit_enemy(target, n, h)
			if nxt != null:
				hit_enemy(nxt, n, h)
			log_add("%s · 관통 %d" % [who, n])
		"momentum":
			hit_enemy(target, n, h)
			h["streak"] += 1
			h["mom_used"] = true
			log_add("%s · 기세 %d → %s (기세 %d)" % [who, n, target["name"], h["streak"]])
		"guardhit":
			hit_enemy(target, n, h)
			shield_hero(h, n)
			log_add("%s · %s %d" % [who, D.face_name(f), n])
		"execute":
			if target["hp"] <= n:
				target["hp"] = 0
				ev("enemy", target["i"], "처치", "hurt")
				log_add("%s · 마무리로 %s 처치" % [who, target["name"]])
			else:
				ev("enemy", target["i"], "실패", "blank")
				log_add("%s · 마무리 실패 (체력 %d 이하만 가능)" % [who, n])
		"poison":
			target["poison"] += n
			ev("enemy", target["i"], "독 %d" % n, "poison")
			log_add("%s · 독 %d → %s" % [who, n, target["name"]])
		"stun":
			target["stunned"] = true
			ev("enemy", target["i"], "기절", "trick")
			log_add("%s · %s → %s 행동 취소" % [who, D.face_name(f), target["name"]])
		"steal":
			_steal(h, target)
			return true
		"freeze":
			target["frozen"] = true
			ev("enemy", target["i"], "얼림", "trick")
			log_add("%s · %s의 주사위를 얼림 (다음 턴에도 같은 면)" % [who, target["name"]])
		"rewind":
			var old: Dictionary = target["face"]
			if old["k"] == "shield":
				target["shield"] = max(0, int(target["shield"]) - int(old["n"]))
			target["face"] = weakest_face(target)
			target["target"] = -1
			if target["face"]["k"] == "shield":
				target["shield"] += int(target["face"]["n"])
			if target["face"]["k"] in ["atk", "poison", "hex"]:
				target["target"] = pick_hero_target()
			ev("enemy", target["i"], "되감기", "trick")
			log_add("%s · %s의 주사위를 가장 약한 면으로" % [who, target["name"]])
		"shield":
			shield_hero(target, n)
			log_add("%s · 방어 %d → %s" % [who, n, hero_label(target)])
		"shieldadj":
			for d in [-1, 0, 1]:
				var j: int = h["i"] + d
				if j >= 0 and j < heroes.size():
					shield_hero(heroes[j], n)
			log_add("%s · 맞물림 방어 %d" % [who, n])
		"taunt":
			h["taunt"] = true
			var cnt := retarget_to(h)
			if cnt > 0:
				shield_hero(h, n * cnt)
			log_add("%s · 대신 맞기 (공격 %d개를 끌어옴)" % [who, cnt])
		"heal":
			heal_hero(target, n)
			log_add("%s · 회복 %d → %s" % [who, n, hero_label(target)])
		"healall":
			for x in alive_heroes():
				heal_hero(x, n)
			log_add("%s · 축복 %d" % [who, n])
		"seed":
			heal_hero(target, n)
			target["seed"] += n * 2
			log_add("%s · 씨앗 → %s (다음 턴 %d 회복)" % [who, hero_label(target), n * 2])
		"link":
			h["link"] = target["i"]
			target["link"] = h["i"]
			ev("hero", target["i"], "연결", "heal")
			log_add("%s · %s와 생명 연결" % [who, hero_label(target)])
		"bloodprice":
			hurt_raw_hero(h, 2, "대가")
			target["double"] = true
			ev("hero", target["i"], "두 배", "trick")
			log_add("%s · 피의 대가 → %s의 주사위 두 배" % [who, hero_label(target)])
		"aim":
			h["aim_pending"] = true
			log_add("%s · 조준 (다음 턴 공격 세 배)" % who)
		"heat":
			_add_heat(h, n)
		"mana":
			mana += n
			log_add("%s · %s · 마나 +%d" % [who, D.face_name(f), n])
		"harmony":
			_harmony(h, n)
		"echo":
			var src: Dictionary = echo_source(h)
			h["face"] = src["face"].duplicate()
			h["face_idx"] = -1
			h["used"] = false
			ev("hero", h["i"], "메아리", "trick")
			log_add("%s · 메아리로 %s의 %s 복사" % [who, hero_label(src), D.face_title(src["face"])])
			return true
		"bash", "frenzy":
			hit_enemy(target, n, h)
			log_add("%s · %s %d → %s" % [who, D.face_name(f), n, target["name"]])
		"thorns":
			shield_hero(h, n)
			h["thorns"] += n
			log_add("%s · 가시 버티기 %d" % [who, n])
		"wall":
			for x in alive_heroes():
				shield_hero(x, n)
			log_add("%s · %s · 모든 아군 방어 %d" % [who, D.face_name(f), n])
		"roar":
			for e in live_enemies():
				e["weak"] += n
				ev("enemy", e["i"], "위축 -%d" % n, "trick")
			log_add("%s · 위압의 함성 · 적 공격 -%d" % [who, n])
		"duel":
			hit_enemy(target, n, h)
			shield_hero(h, n)
			if target["hp"] > 0 and target["face"] != null and target["face"]["k"] in ["atk", "poison", "hex"]:
				target["target"] = h["i"]
			log_add("%s · 결투 신청 %d → %s" % [who, n, target["name"]])
		"mark":
			hit_enemy(target, n, h)
			if target["hp"] > 0:
				target["mark"] += 2
				ev("enemy", target["i"], "표식", "trick")
			log_add("%s · 표식 화살 %d → %s" % [who, n, target["name"]])
		"suppress":
			hit_enemy(target, n, h)
			target["weak"] += n
			log_add("%s · 견제 사격 %d → %s (공격 -%d)" % [who, n, target["name"], n])
		"snipe":
			var sn := n * 2 if int(target["hp"]) >= int(target["maxhp"]) else n
			hit_enemy(target, sn, h, true)
			log_add("%s · 저격 %d → %s" % [who, sn, target["name"]])
		"backstab":
			var bs := n * 2 if (target["stunned"] or target["frozen"] or int(target["poison"]) > 0) else n
			hit_enemy(target, bs, h)
			log_add("%s · 급소 찌르기 %d → %s" % [who, bs, target["name"]])
		"smoke":
			target["dodge"] = true
			ev("hero", target["i"], "연막", "trick")
			log_add("%s · 연막 → %s" % [who, hero_label(target)])
		"pilfer":
			hit_enemy(target, n, h)
			run["gold"] = int(run.get("gold", 0)) + n
			ev("hero", h["i"], "금화 +%d" % n, "mana")
			log_add("%s · 소매치기 %d → %s (금화 +%d)" % [who, n, target["name"], n])
		"ember":
			hit_enemy(target, n, h)
			log_add("%s · 불씨 던지기 %d → %s" % [who, n, target["name"]])
			_add_heat(h, 1)
		"firewall":
			shield_hero(target, n)
			target["thorns"] += n
			log_add("%s · 불꽃 장벽 %d → %s" % [who, n, hero_label(target)])
		"combust":
			var cb: int = max(2, int(h["heat"]) * 3)
			if h["aimed"]:
				cb *= 3
			if h["double"]:
				cb *= 2
			h["heat"] = 0
			hit_enemy(target, cb, h)
			log_add("%s · 연소 %d → %s" % [who, cb, target["name"]])
		"shatter":
			var sh := n * 3 if (target["stunned"] or target["frozen"]) else n
			hit_enemy(target, sh, h)
			log_add("%s · 산산조각 %d → %s" % [who, sh, target["name"]])
		"icearmor":
			shield_hero(target, n)
			target["keep_shield"] = true
			log_add("%s · 얼음 갑옷 %d → %s" % [who, n, hero_label(target)])
		"cleanse":
			target["poison"] = 0
			target["ward"] = true
			heal_hero(target, n)
			ev("hero", target["i"], "정화", "heal")
			log_add("%s · 정화 → %s" % [who, hero_label(target)])
		"guardian":
			target["guard"] = true
			ev("hero", target["i"], "수호", "heal")
			log_add("%s · 수호 기도 → %s" % [who, hero_label(target)])
		"encore":
			target["used"] = false
			ev("hero", target["i"], "앙코르", "trick")
			log_add("%s · 앙코르 → %s의 %s 한 번 더" % [who, hero_label(target), D.face_name(target["face"])])
		"discord":
			if not target["stunned"] and target["face"] != null and target["face"]["k"] in ["atk", "all"]:
				var dv := enemy_value(target)
				var other = next_enemy(target)
				if other != null and dv > 0:
					hit_enemy(other, dv)
					log_add("%s · 불협화음 · %s의 공격 %d이 %s에게" % [who, target["name"], dv, other["name"]])
			target["stunned"] = true
			ev("enemy", target["i"], "불협화음", "trick")
		"retune":
			target["face_idx"] = rng.randi_range(0, 5)
			target["face"] = D.hero_face(target["p"], target["face_idx"])
			target["fresh"] = true
			ev("hero", target["i"], "조율", "trick")
			log_add("%s · 조율 → %s의 주사위가 %s(으)로" % [who, hero_label(target), D.face_title(target["face"])])
		"blank":
			log_add("%s · 빈 면" % who)
	engrave(h)
	_check_end()
	return true


func _add_heat(h: Dictionary, n: int) -> void:
	var who := hero_label(h)
	h["heat"] += n
	if h["heat"] >= 5:
		h["heat"] = 0
		for e in live_enemies():
			hit_enemy(e, 6, h)
		hurt_raw_hero(h, 2, "폭발")
		log_add("%s · 과열 폭발! 모든 적 6 피해" % who)
	else:
		ev("hero", h["i"], "열 %d/5" % h["heat"], "atk")
		log_add("%s · 열 %d/5" % [who, h["heat"]])


func _glove(h: Dictionary, target: Dictionary) -> void:
	if has_item(h, "glove") and target["hp"] > 0:
		target["poison"] += 1


func _steal(h: Dictionary, e: Dictionary) -> void:
	var ef: Dictionary = e["face"]
	var map := {"atk": "atk", "all": "all", "shield": "shield", "heal": "heal", "poison": "poison", "hex": "stun", "blank": "blank"}
	var nk: String = map.get(ef["k"], "blank")
	if ef["k"] == "shield":
		e["shield"] = max(0, int(e["shield"]) - int(ef["n"]))
	e["stunned"] = true
	h["face"] = {"k": nk, "n": int(ef["n"]) if not nk in D.NO_NUMBER else 0}
	h["face_idx"] = -1
	h["used"] = false
	ev("enemy", e["i"], "빼앗김", "trick")
	log_add("%s · %s의 %s 면을 훔침" % [hero_label(h), e["name"], D.enemy_faces[ef["k"]]["w"]])


func _harmony(h: Dictionary, n: int) -> void:
	var counts := {}
	for o in heroes:
		if o["i"] == h["i"] or o["hp"] <= 0 or o["used"] or o["face"] == null:
			continue
		var c: String = D.face_cat(o["face"])
		if c == "blank" or o["face"]["k"] in D.NO_NUMBER:
			continue
		counts[c] = int(counts.get(c, 0)) + 1
	var best := ""
	for c in counts:
		if best == "" or counts[c] > counts[best]:
			best = c
	var boosted := 0
	if best != "":
		for o in heroes:
			if o["i"] == h["i"] or o["hp"] <= 0 or o["used"] or o["face"] == null:
				continue
			if D.face_cat(o["face"]) == best and not o["face"]["k"] in D.NO_NUMBER:
				o["face"]["n"] = int(o["face"]["n"]) + n
				ev("hero", o["i"], "+%d" % n, "trick")
				boosted += 1
	log_add("%s · 화음 · 면 %d개 +%d" % [hero_label(h), boosted, n])


# ---------------- spells ----------------

func can_cast(s: String, target = null) -> bool:
	if phase != "use" or not s in spells_available():
		return false
	var sp: Dictionary = D.spells[s]
	if mana < int(sp["cost"]):
		return false
	match sp["t"]:
		"enemy": return target != null and target.has("key") and target["hp"] > 0
		"dead": return target != null and not target.has("key") and target["hp"] <= 0
	return true


func cast(s: String, target = null) -> bool:
	if not can_cast(s, target):
		return false
	var sp: Dictionary = D.spells[s]
	mana -= int(sp["cost"])
	match s:
		"fireball":
			for e in live_enemies():
				hit_enemy(e, 3)
		"inferno":
			for e in live_enemies():
				hit_enemy(e, 5)
		"blast":
			hit_enemy(target, 6)
		"frostjail":
			target["stunned"] = true
			hit_enemy(target, 2)
		"storm":
			for e in live_enemies():
				hit_enemy(e, 2)
				e["weak"] += 1
		"courage":
			atk_bonus += 1
		"warsong":
			atk_bonus += 2
		"mend":
			for x in alive_heroes():
				heal_hero(x, 3)
		"prayer":
			target["hp"] = int(ceil(float(target["maxhp"]) / 2.0))
			target["rolled"] = false
			target["used"] = true
			target["face"] = null
			ev("hero", target["i"], "부활", "heal")
		"confuse":
			target["stunned"] = true
	log_add("주문 · %s" % sp["name"])
	_check_end()
	return true


func _check_end() -> void:
	if live_enemies().is_empty():
		result = "win"
	elif alive_heroes().is_empty():
		result = "lose"


# ---------------- enemy phase ----------------

func end_turn() -> void:
	if result != "":
		return
	if phase == "roll":
		confirm()
	for e in live_enemies():
		if e["poison"] > 0:
			var p: int = e["poison"]
			e["hp"] = max(0, int(e["hp"]) - p)
			e["poison"] -= 1
			ev("enemy", e["i"], "독 -%d" % p, "poison")
			if e["hp"] <= 0:
				log_add("%s 독으로 쓰러짐" % e["name"])
	_check_end()
	if result != "":
		return
	for e in enemies:
		if e["hp"] <= 0:
			continue
		if e["stunned"]:
			continue
		var f: Dictionary = e["face"]
		var n := enemy_value(e)
		match f["k"]:
			"atk":
				var t = _enemy_target(e)
				if t != null:
					hurt_hero(t, n, e)
					log_add("%s의 공격 %d → %s" % [e["name"], n, hero_label(t)])
			"all":
				for h in alive_heroes():
					hurt_hero(h, n, e)
				log_add("%s의 전체 공격 %d" % [e["name"], n])
			"poison":
				var t = _enemy_target(e)
				if t != null and t["ward"]:
					ev("hero", t["i"], "정화됨", "heal")
				elif t != null:
					t["poison"] += n
					ev("hero", t["i"], "독 %d" % n, "poison")
					log_add("%s의 독 → %s" % [e["name"], hero_label(t)])
			"hex":
				var t = _enemy_target(e)
				if t != null and t["ward"]:
					ev("hero", t["i"], "정화됨", "heal")
				elif t != null:
					t["hexed"] = true
					ev("hero", t["i"], "저주", "trick")
					log_add("%s의 저주 → %s (다음 턴 빈 면)" % [e["name"], hero_label(t)])
			"heal":
				var t = enemies[e["target"]] if e["target"] >= 0 else e
				if t["hp"] <= 0:
					t = e
				var before: int = t["hp"]
				t["hp"] = min(int(t["maxhp"]), before + n)
				ev("enemy", t["i"], "+%d" % (t["hp"] - before), "heal")
				log_add("%s의 회복" % e["name"])
		_check_end()
		if result != "":
			return
	start_turn()


func _enemy_target(e: Dictionary):
	if e["target"] >= 0 and heroes[e["target"]]["hp"] > 0:
		return heroes[e["target"]]
	var hs := alive_heroes()
	if hs.is_empty():
		return null
	return hs[rng.randi_range(0, hs.size() - 1)]
