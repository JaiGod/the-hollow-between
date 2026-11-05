extends Node
## Root of the game. Owns the layers and switches between title, overworld,
## battle and ending. Everything else talks to it through Events or the few
## public methods below (run_dialogue, open_pause_menu, ...).

const Overworld = preload("res://scripts/world/Overworld.gd")
const Battle = preload("res://scripts/battle/Battle.gd")
const DialogueBox = preload("res://scripts/ui/DialogueBox.gd")
const TitleScreen = preload("res://scripts/ui/TitleScreen.gd")
const PauseMenu = preload("res://scripts/ui/PauseMenu.gd")
const SaveSlotMenu = preload("res://scripts/ui/SaveSlotMenu.gd")
const TouchControls = preload("res://scripts/ui/TouchControls.gd")
const EndingScreen = preload("res://scripts/ui/EndingScreen.gd")
const EndingResolver = preload("res://scripts/systems/EndingResolver.gd")
const UITheme = preload("res://scripts/ui/UITheme.gd")

var world: Node2D
var ui_layer: CanvasLayer
var dialogue
var touch
var fade: ColorRect
var toast_box: VBoxContainer
var area_title: Label
var overworld
var battle
var screen: Node
var menu_open: bool = false
var transitioning: bool = false
var autosave_timer: float = 0.0


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	dialogue = DialogueBox.new()
	dialogue.main = self
	ui_layer.add_child(dialogue)

	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(400, 8)
	toast_box.size = Vector2(232, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(toast_box)

	area_title = UITheme.label("", 20, UITheme.GOLD)
	area_title.position = Vector2(0, 40)
	area_title.size = Vector2(640, 60)
	area_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area_title.modulate.a = 0.0
	area_title.add_theme_constant_override("outline_size", 6)
	area_title.add_theme_color_override("font_outline_color", Color("0b0716"))
	ui_layer.add_child(area_title)

	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 20
	add_child(touch_layer)
	touch = TouchControls.new()
	touch_layer.add_child(touch)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 30
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.size = Vector2(640, 360)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade)

	Events.battle_requested.connect(_on_battle_requested)
	Events.map_change_requested.connect(enter_map)
	Events.toast.connect(show_toast)
	Events.level_up.connect(func(_l): AudioManager.play_sfx("levelup"))
	goto_title()


func _process(delta: float) -> void:
	touch.set_mode(_touch_mode())
	if overworld and overworld.is_inside_tree() and not ui_busy():
		autosave_timer += delta
		if autosave_timer > 120.0:
			autosave_timer = 0.0
			SaveManager.autosave()


func _touch_mode() -> String:
	if transitioning or screen != null:
		return "none"
	if battle:
		return "soul" if battle.state == Battle.S.ENEMY else "none"
	if menu_open:
		return "none"
	if dialogue.active:
		return "none"
	return "world"


func ui_busy() -> bool:
	return dialogue.active or menu_open or transitioning or battle != null or screen != null


# ------------------------------------------------------------------- screens

func _clear_world() -> void:
	for c in world.get_children():
		c.queue_free()
	overworld = null
	if battle:
		battle.queue_free()
		battle = null
	if screen:
		screen.queue_free()
		screen = null


func _fade_to(alpha: float, t: float = 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, t)
	await tw.finished


func goto_title() -> void:
	transitioning = true
	await _fade_to(1.0, 0.25)
	GameState.counting_time = false
	_clear_world()
	screen = TitleScreen.new()
	screen.main = self
	ui_layer.add_child(screen)
	AudioManager.play_music("title")
	transitioning = false
	await _fade_to(0.0, 0.6)


func start_new_game(player_name: String) -> void:
	GameState.new_game(player_name)
	SaveManager.profile["new_games"] = int(SaveManager.profile.get("new_games", 0)) + 1
	SaveManager.save_profile()
	await enter_map("glade_of_waking", "start")
	run_dialogue("intro")


func continue_game(slot: int) -> void:
	if not SaveManager.load_slot(slot):
		show_toast("That memory is empty.")
		return
	await enter_map(GameState.map_id, "")


func enter_map(map_id: String, spawn_id: String) -> void:
	transitioning = true
	await _fade_to(1.0, 0.3)
	if screen:
		screen.queue_free()
		screen = null
	for c in world.get_children():
		c.queue_free()
	overworld = Overworld.new()
	world.add_child(overworld)
	overworld.setup(self, map_id, spawn_id)
	GameState.counting_time = true
	if spawn_id != "":
		SaveManager.autosave()
	transitioning = false
	await _fade_to(0.0, 0.35)


func show_area_title(region: String, place: String) -> void:
	area_title.text = region + ("\n" + place if place != "" else "")
	var tw := create_tween()
	tw.tween_property(area_title, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.6)
	tw.tween_property(area_title, "modulate:a", 0.0, 0.8)


func show_toast(text: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.ACCENT, Color(0.08, 0.05, 0.15, 0.92), 2))
	var l := UITheme.label(text, 13)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	p.add_child(l)
	toast_box.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ dialogue

func run_dialogue(conv_id: String, done: Callable = Callable()) -> void:
	if conv_id == "":
		return
	dialogue.start(conv_id, done)


func run_dialogue_text(text, done: Callable = Callable()) -> void:
	var lines: Array = text if text is Array else [text]
	dialogue.start_lines(lines, done)


func handle_event(ev: String) -> void:
	## Events fired from dialogue nodes ("event": "...").
	match ev:
		"chapter_end":
			show_ending()
		"title":
			goto_title()
		"refresh":
			if overworld:
				overworld.refresh_entities()
		"heal":
			GameState.heal(999)
	if overworld:
		overworld.refresh_entities()


# --------------------------------------------------------------------- menus

func open_pause_menu() -> void:
	if menu_open:
		return
	menu_open = true
	AudioManager.play_sfx("select")
	var m := PauseMenu.new()
	m.closed.connect(_on_menu_closed)
	ui_layer.add_child(m)


func _on_menu_closed() -> void:
	menu_open = false
	if overworld:
		overworld.refresh_entities()


func open_save_lantern(text: String) -> void:
	run_dialogue_text([text, "(HP and Focus restored.)"], _open_save_slots)


func _open_save_slots() -> void:
	menu_open = true
	var m := SaveSlotMenu.new()
	m.mode = "save"
	m.main = self
	m.closed.connect(_on_menu_closed)
	ui_layer.add_child(m)


func open_load_menu(from_title: bool = true) -> void:
	var m := SaveSlotMenu.new()
	m.mode = "load"
	m.main = self
	ui_layer.add_child(m)


# -------------------------------------------------------------------- battle

func _on_battle_requested(enemy_id: String, ctx: Dictionary) -> void:
	if battle or overworld == null:
		return
	transitioning = true
	# Encounter flash
	for i in 3:
		fade.color = Color(1, 1, 1, 0.8)
		await get_tree().create_timer(0.06).timeout
		fade.color = Color(0, 0, 0, 0.0)
		await get_tree().create_timer(0.06).timeout
	await _fade_to(1.0, 0.2)
	world.remove_child(overworld)
	battle = Battle.new()
	battle.battle_ended.connect(_on_battle_ended)
	world.add_child(battle)
	battle.start(enemy_id, ctx)
	transitioning = false
	await _fade_to(0.0, 0.25)


func _on_battle_ended(result: Dictionary) -> void:
	transitioning = true
	await _fade_to(1.0, 0.2)
	battle.queue_free()
	battle = null
	if result.get("outcome") == "lost":
		transitioning = false
		overworld.queue_free()
		overworld = null
		_game_over()
		return
	world.add_child(overworld)
	overworld.camera.make_current()
	overworld.on_battle_result(result)
	AudioManager.play_music(overworld.map.get("music", "forest"))
	transitioning = false
	await _fade_to(0.0, 0.3)
	var enemy: Dictionary = DB.enemy(result.get("enemy", ""))
	var after: String = enemy.get("after_" + str(result.get("outcome", "")), "")
	if after != "":
		run_dialogue(after, overworld.refresh_entities)


func _game_over() -> void:
	_clear_world()
	var c := Control.new()
	c.size = Vector2(640, 360)
	c.theme = UITheme.theme()
	var bg := ColorRect.new()
	bg.color = Color("07040e")
	bg.size = c.size
	c.add_child(bg)
	var v := VBoxContainer.new()
	v.position = Vector2(170, 110)
	v.size = Vector2(300, 0)
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	var t := UITheme.label("YOUR MEMORIES SCATTER", 22, UITheme.DANGER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UITheme.label("...but something in the Hollow remembers you,\n%s. Stay determined to be remembered." % GameState.player_name, 14, UITheme.DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var b1 := Button.new()
	b1.text = "Return to last lantern"
	b1.pressed.connect(func(): continue_game(SaveManager.AUTOSAVE_SLOT))
	v.add_child(b1)
	var b2 := Button.new()
	b2.text = "Title screen"
	b2.pressed.connect(goto_title)
	v.add_child(b2)
	screen = c
	ui_layer.add_child(c)
	b1.grab_focus()
	AudioManager.play_music("title")
	await _fade_to(0.0, 0.8)


# -------------------------------------------------------------------- ending

func show_ending() -> void:
	transitioning = true
	await _fade_to(1.0, 1.2)
	var id: String = EndingResolver.resolve()
	SaveManager.mark_ending(id)
	if GameState.stat("killed") == 0:
		Achievements.unlock("pacifist_slice")
	SaveManager.autosave()
	_clear_world()
	GameState.counting_time = false
	var e = EndingScreen.new()
	e.ending_id = id
	e.main = self
	screen = e
	ui_layer.add_child(e)
	AudioManager.play_music("ending", 1.5)
	transitioning = false
	await _fade_to(0.0, 1.5)
