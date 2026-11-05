extends Node
## Headless smoke test — plays through every system without a human.
##   godot --headless --path . res://tests/SmokeTest.tscn
## Exits 0 on success. Any GDScript error also shows up in the log, and CI
## fails the run if "SCRIPT ERROR" appears.

const MainScene = preload("res://scenes/Main.tscn")

var main
var failures: Array = []


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if not cond:
		failures.append(what)
		push_error("FAIL: " + what)
	else:
		print("  ok  ", what)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await get_tree().process_frame


func drain_dialogue(max_presses: int = 200) -> void:
	var n := 0
	while main.dialogue.active and n < max_presses:
		await press("confirm")
		n += 1


func _run() -> void:
	print("== The Hollow Between smoke test ==")
	main = MainScene.instantiate()
	add_child(main)
	await wait(1.2)
	check(main.screen != null, "title screen shows")

	# --- new game + intro
	main.start_new_game("Tester")
	await wait(1.5)
	check(main.overworld != null and main.overworld.map_id == "glade_of_waking", "new game loads glade")
	check(main.dialogue.active, "intro dialogue plays")
	await drain_dialogue()
	check(not main.dialogue.active, "intro dialogue finishes")

	# --- recruit Echo via real dialogue (choice 0 = trust, then come with me)
	main.run_dialogue("echo_glade")
	await drain_dialogue()
	check(GameState.party().has("echo"), "Echo recruited through dialogue")
	check(GameState.loyalty("echo") > 20, "loyalty changed by choices")

	# --- every conversation runs to completion
	for f in DirAccess.get_files_at("res://data/dialogue"):
		var id: String = f.get_basename()
		if id.begins_with("archivist_after"):
			continue  # these end the chapter; tested at the end
		main.run_dialogue(id)
		await drain_dialogue()
		check(not main.dialogue.active, "dialogue '%s' completes" % id)

	# --- quests via data
	GameState.start_quest("lost_gear")
	GameState.give_item("brass_gear")
	main.run_dialogue("clockmaker")
	await drain_dialogue()
	check(GameState.quest_state("lost_gear") == "done", "Clockmaker quest completes")
	check(GameState.get_flag("has_lantern"), "lantern reward unlocks north path")

	# --- every map loads, entities place, exits resolve
	for f in DirAccess.get_files_at("res://data/maps"):
		var id: String = f.get_basename()
		var spawn: String = DB.map(id)["spawns"].keys()[0]
		await main.enter_map(id, spawn)
		await wait(0.3)
		check(main.overworld.map_id == id, "map '%s' loads" % id)
		# walk a little to exercise collision
		Input.action_press("move_right")
		await wait(0.25)
		Input.action_release("move_right")

	# --- stones puzzle
	await main.enter_map("forest_path", "from_glade")
	await wait(0.3)
	for e in main.overworld.entities_root.get_children():
		if e.get("kind") == "stone":
			pass
	var stones := {}
	for e in main.overworld.entities_root.get_children():
		if e.get("kind") == "stone":
			stones[int(e.data["order"])] = e
	for i in [1, 2, 3]:
		main.overworld.interact(stones[i])
		await drain_dialogue()
	check(GameState.get_flag("puzzle.forest_stones"), "stone puzzle solves in order")

	# --- every enemy: talk, fight, every pattern, specials, spare/kill
	GameState.talents_owned = ["chrono_slow", "guardian_skin", "guardian_shield", "mystic_light", "mystic_illusions", "mystic_reflect"]
	var enemy_ids: Array = DB.enemies.keys()
	for i in enemy_ids.size():
		var eid: String = enemy_ids[i]
		GameState.hp = GameState.max_hp()
		Events.battle_requested.emit(eid, {"entity_id": "test_" + eid})
		await wait(1.4)
		var b = main.battle
		check(b != null, "battle '%s' starts" % eid)
		if b == null:
			continue
		while b.state == b.S.TEXT:
			await press("confirm")
		check(b.state == b.S.MENU, "%s: menu reached" % eid)
		# talk
		b._choose(1)
		await press("confirm")
		while b.state == b.S.TEXT:
			await press("confirm")
		# enemy turn runs
		await wait(0.6)
		check(b.state == b.S.ENEMY, "%s: enemy turn begins" % eid)
		await wait(b.turn_time - 0.4)
		GameState.hp = GameState.max_hp()
		while b.state == b.S.TEXT:
			await press("confirm")
		await wait(0.2)
		check(b.state == b.S.MENU, "%s: survived a turn, back to menu" % eid)
		# fight with a perfect-ish hit (HP padded so the special tests still run)
		b.e_max_hp = 500
		b.e_hp = 500
		b._start_fight()
		b.fight["x"] = 0.5
		b._fight_press()
		await wait(0.1)
		if b.state == b.S.FIGHT:
			b.fight["x"] = 0.1
			b._fight_press()
		while b.state == b.S.TEXT:
			await press("confirm")
			if b.state == b.S.END:
				break
		await wait(0.4)
		# every special
		for sp in ["mend", "time_slow", "energy_shield", "reflection", "illusions", "spirit_summon"]:
			if b.state == b.S.END:
				break
			while b.state == b.S.ENEMY:
				GameState.hp = GameState.max_hp()
				await wait(0.5)
			while b.state == b.S.TEXT:
				await press("confirm")
			if b.state != b.S.MENU:
				break
			GameState.focus = 100
			b._do_special(sp)
			while b.state == b.S.TEXT:
				await press("confirm")
			check(b.state == b.S.ENEMY, "%s: special '%s' then enemy turn" % [eid, sp])
			b.turn_t = b.turn_time - 0.05
			await wait(0.2)
		while b.state == b.S.ENEMY or b.state == b.S.TEXT:
			GameState.hp = GameState.max_hp()
			if b.state == b.S.TEXT:
				await press("confirm")
			else:
				await wait(0.3)
		# finish: spare odd ones, kill even ones
		if b.state == b.S.MENU:
			if i % 2 == 0:
				b.mercy = 100
				b._do_spare()
			else:
				b.e_hp = 1
				b._start_fight()
				b.fight["x"] = 0.5
				b._fight_press()
				if b.state == b.S.FIGHT:
					b.fight["x"] = 1.5
					await wait(0.05)
			while b.state == b.S.TEXT:
				await press("confirm")
			await wait(1.0)
		var waited := 0.0
		while main.battle != null and waited < 5.0:
			if main.battle.state == main.battle.S.TEXT:
				await press("confirm")
			await wait(0.1)
			waited += 0.1
		check(main.battle == null, "%s: battle ends and returns to world" % eid)
		await wait(0.5)
		await drain_dialogue()

	# --- each pattern in isolation at high difficulty
	const PatternLibrary = preload("res://scripts/battle/patterns/PatternLibrary.gd")
	const BattleArena = preload("res://scripts/battle/BattleArena.gd")
	var arena = BattleArena.new()
	add_child(arena)
	arena.words = ["TEST", "PAGE"]
	for key in PatternLibrary.PATTERNS:
		arena.begin(150.0)
		var p = PatternLibrary.make(key)
		p.start(arena, 2.0)
		for frame in 240:
			p.update(1.0 / 60.0)
			arena._update_hazards(1.0 / 60.0)
		check(true, "pattern '%s' runs 4s at difficulty 2.0 (%d bullets live)" % [key, arena.bullets.size()])
	arena.queue_free()

	# --- level up + talents
	GameState.talents_owned = []
	GameState.add_xp(200)
	check(GameState.level > 1 and GameState.talent_points > 0, "level up grants talent points")
	check(GameState.learn("ranger_feet"), "talent learnable")
	check(not GameState.learn("ranger_eye"), "talent prerequisites enforced")

	# --- save / load round-trip
	GameState.set_flag("smoke_flag", 42)
	check(SaveManager.save(3), "save to slot 3")
	GameState.set_flag("smoke_flag", 0)
	check(SaveManager.load_slot(3), "load slot 3")
	check(int(GameState.get_flag("smoke_flag")) == 42, "flags survive save/load")
	check(SaveManager.slot_summary(3).get("name") == "Tester", "slot summary readable")
	SaveManager.delete_slot(3)

	# --- conditions
	check(GameState.check("party:echo,quest:lost_gear=done,!flag:nope"), "condition grammar")
	check(GameState.check("stat:killed>=0,level>=1"), "numeric conditions")

	# --- pause menu tabs
	await main.enter_map("lanternrest", "from_forest")
	await wait(0.3)
	main.open_pause_menu()
	await wait(0.1)
	var pm = main.ui_layer.get_child(main.ui_layer.get_child_count() - 1)
	for t in pm.TABS.size():
		if pm.TABS[t] == "Title":
			continue
		pm._set_tab(t)
		await wait(0.05)
	pm._close()
	check(not main.menu_open, "pause menu opens all tabs and closes")

	# --- ending
	var ending: String = preload("res://scripts/systems/EndingResolver.gd").resolve()
	check(DB.endings.has(ending), "ending resolves to a known ending (%s)" % ending)
	main.run_dialogue("archivist_after_spared")
	await drain_dialogue()
	await wait(3.5)
	check(main.screen != null and main.screen.get("ending_id") != null, "chapter end shows ending screen")

	print("")
	if failures.is_empty():
		print("SMOKE OK — all checks passed")
		get_tree().quit(0)
	else:
		print("SMOKE FAILED: ", failures)
		get_tree().quit(1)
