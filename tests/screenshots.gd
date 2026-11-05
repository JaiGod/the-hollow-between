extends Node
## Captures promo/QA screenshots of key screens into docs/screenshots/.
##   godot --path . res://tests/Screenshots.tscn   (needs a display; xvfb-run works)

const MainScene = preload("res://scenes/Main.tscn")
const OUT := "res://docs/screenshots/"

var main


func _ready() -> void:
	_run.call_deferred()


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("saved ", name)


func type_out() -> void:
	await wait(2.5)


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	main = MainScene.instantiate()
	add_child(main)
	await wait(1.6)
	await shot("01_title")

	main.start_new_game("Wren")
	await wait(1.4)
	await type_out()
	await shot("02_intro")
	while main.dialogue.active:
		main.dialogue._finish()
	main.run_dialogue("echo_glade")
	await type_out()
	await shot("03_echo")
	main.dialogue._finish()
	GameState.recruit("echo")
	GameState.recruit("clockmaker")
	GameState.playtime = 0.0
	main.overworld.refresh_entities()
	await wait(0.8)
	await shot("04_glade")

	await main.enter_map("forest_path", "from_glade")
	await wait(2.5)
	await shot("05_forest")

	await main.enter_map("lanternrest", "from_forest")
	main.overworld.player.position = main.overworld.tile_to_world(14, 7)
	await wait(2.5)
	await shot("06_village")

	await main.enter_map("archivist_grove", "from_forest")
	main.overworld.player.position = main.overworld.tile_to_world(12, 8)
	await wait(2.5)
	await shot("07_grove")

	Events.battle_requested.emit("lostling", {})
	await wait(2.8)
	await shot("08_battle_menu")
	var b = main.battle
	while b.state == b.S.TEXT:
		b._advance_text()
		await wait(0.05)
	b._choose(1)
	await wait(0.3)
	await shot("09_battle_talk")
	b._to_menu()
	b._start_fight()
	b.fight["x"] = 0.38
	await wait(0.05)
	await shot("10_battle_fight")
	b.state = b.S.MENU
	b.next_turn_fx = {"shield": 3}
	b.enemy["patterns"] = ["orbit"]
	b._enemy_turn()
	await wait(2.2)
	await shot("11_soul_orbit")
	b._end("fled")
	await wait(1.5)

	GameState.add_xp(30)
	Events.battle_requested.emit("archivist", {})
	await wait(2.5)
	b = main.battle
	while b.state == b.S.TEXT:
		b._advance_text()
		await wait(0.05)
	b.phase = 1
	b._enemy_turn()
	b.patterns.clear()
	for k in ["pages", "beam"]:
		var p = preload("res://scripts/battle/patterns/PatternLibrary.gd").make(k)
		p.start(b.arena, 1.6)
		b.patterns.append(p)
	b.arena.set_box(Rect2(200, 148, 240, 128))
	await wait(3.0)
	await shot("12_archivist_pages")
	b.phase = 2
	b.patterns.clear()
	b.arena.clear()
	var g = preload("res://scripts/battle/patterns/PatternLibrary.gd").make("gravity")
	g.start(b.arena, 1.5)
	b.patterns.append(g)
	await wait(2.5)
	await shot("13_archivist_gravity")
	b._end("fled")
	await wait(1.5)

	GameState.talent_points = 2
	GameState.talents_owned = ["guardian_skin", "chrono_slow"]
	main.open_pause_menu()
	await wait(0.3)
	var pm = main.ui_layer.get_child(main.ui_layer.get_child_count() - 1)
	pm._set_tab(3)
	await wait(0.3)
	await shot("14_talents")
	pm._set_tab(0)
	await wait(0.2)
	await shot("15_status")
	pm._close()

	GameState.set_flag("archivist_spared", true)
	main.show_ending()
	await wait(4.0)
	await shot("16_ending")
	get_tree().quit(0)
