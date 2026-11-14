extends Node
## Opens every screen of the real UI once so rendering code runs headless. Run:
##   godot --headless --path . res://tests/ui_smoke.tscn
## Prints "UI OK" when it reaches the end. CI also fails on any "SCRIPT ERROR".

var main


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await step("title")
	main.show_rules()
	await step("rules")
	main.close_overlay()
	main.show_party_select()
	main._random_party()
	await step("party select")
	main._start_run()
	await step("map")
	main.show_party_overlay()
	await step("party overlay")
	main.close_overlay()
	# a fight, driven through the same handlers the buttons call
	main.start_fight("fight")
	await step("fight roll")
	main.on_reroll()
	main.on_die(0)
	main.on_confirm()
	await step("fight use")
	for i in 4:
		var h: Dictionary = main.combat.heroes[i]
		if h["hp"] <= 0 or h["used"]:
			continue
		main.on_die(i)
		var mode: String = main.target_mode()
		if mode == "enemy":
			main.pick_target(main.combat.live_enemies()[0])
		elif mode == "ally":
			main.pick_target(main.combat.alive_heroes()[0])
		await step("use die %d" % i)
		if main.combat == null or main.combat.result != "":
			break
	if main.combat != null and main.combat.result == "":
		main.combat.end_turn()
		main.refresh()
		await step("after enemy turn")
	# rewards and the other screens
	main.start_fight("elite")
	main.combat.result = "win"
	main.on_win()
	await step("reward")
	main.choose_face_upgrade("면 강화", main.show_map, main.show_map)
	await step("face upgrade")
	main.choose_item_holder("whet", main.show_map)
	await step("item holder")
	main.show_forge()
	await step("forge")
	main.show_shop()
	await step("shop")
	main.show_event()
	await step("event")
	for id in ["spring", "gamble", "pack_gold", "pass_altar", "smith_gold"]:
		main.show_event()
		main._event_pick(id)
		await step("event " + id)
	main.start_fight("boss")
	await step("boss")
	main.show_promotion()
	await step("promotion")
	main._apply_promotion()
	Game.run["act"] = 1
	main.show_promotion()
	await step("promotion 2")
	main.show_end(true, "")
	await step("end win")
	main.show_end(false, "녹슨 기사")
	await step("end lose")
	Game.clear_save()
	print("UI OK")
	get_tree().quit(0)


func step(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("ui step: ", name)
