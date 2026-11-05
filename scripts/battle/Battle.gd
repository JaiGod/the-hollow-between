extends Node2D
## Turn-based battle with a skill-based defense phase.
##   Player turn: FIGHT (timed hits + combos) · TALK (5 approaches) · DEFEND ·
##                SPECIAL (Focus abilities) · ITEM · MERCY (spare / flee)
##   Enemy turn:  steer your soul through bullet patterns; grazing builds Focus.
## Bosses have phases (by HP *or* by turns survived, so pacifists progress too).

const BattleArena = preload("res://scripts/battle/BattleArena.gd")
const PatternLibrary = preload("res://scripts/battle/patterns/PatternLibrary.gd")
const SpriteLib = preload("res://scripts/art/SpriteLib.gd")
const UITheme = preload("res://scripts/ui/UITheme.gd")

signal battle_ended(result: Dictionary)

enum S { INTRO, MENU, SUB, FIGHT, TEXT, ENEMY, END }

const MENU_BOX := Rect2(40, 168, 560, 112)
const MENU_ITEMS := ["FIGHT", "TALK", "DEFEND", "SPECIAL", "ITEM", "MERCY"]
const TALK_KEYS := ["reason", "joke", "comfort", "intimidate", "question"]
const SPECIALS := {
	"mend": {"name": "Mend", "cost": 20, "desc": "Heal 40% HP."},
	"time_slow": {"name": "Time Slow", "cost": 35, "desc": "Next attack moves at half speed."},
	"energy_shield": {"name": "Energy Shield", "cost": 30, "desc": "Block the next 3 hits."},
	"reflection": {"name": "Reflection", "cost": 40, "desc": "Turn 2 hits back on the enemy."},
	"illusions": {"name": "Illusions", "cost": 30, "desc": "Decoys: 40% of hits miss you."},
	"spirit_summon": {"name": "Spirit Summon", "cost": 40, "desc": "Your companions act."},
}

var enemy_id: String
var enemy: Dictionary
var context: Dictionary
var e_hp: int
var e_max_hp: int
var e_atk: int
var e_def: int
var mercy: int = 0
var phase: int = 0
var turn: int = 0
var talk_used: Dictionary = {}
var difficulty_mod: float = 0.0
var is_boss: bool = false

var state: int = S.INTRO
var arena
var enemy_sprite: Sprite2D
var enemy_base: Vector2 = Vector2(320, 96)
var shake: float = 0.0
var screen_shake: float = 0.0
var bg_t: float = 0.0
var fight_layer: Node2D
var ui: Control
var text_label: RichTextLabel
var sub_box: VBoxContainer
var buttons: Array = []
var menu_i: int = 0
var sub_items: Array = []
var sub_i: int = 0
var name_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var fp_bar: ProgressBar
var fp_label: Label
var mercy_label: Label
var bubble: PanelContainer
var bubble_label: Label
var popups: Array = []

var fight: Dictionary = {}
var patterns: Array = []
var turn_time: float = 6.0
var turn_t: float = 0.0
var defending: bool = false
var next_turn_fx: Dictionary = {}
var hits_taken: int = 0
var text_queue: Array = []
var after_text: Callable
var typing_t: float = 0.0


func start(id: String, ctx: Dictionary) -> void:
	enemy_id = id
	enemy = DB.enemy(id)
	context = ctx
	is_boss = enemy.get("boss", false)
	e_max_hp = int(enemy.get("hp", 20))
	e_hp = e_max_hp
	e_atk = int(enemy.get("atk", 4))
	e_def = int(enemy.get("def", 0))
	if is_boss and GameState.stat("killed") >= 3:
		difficulty_mod += 0.25  # the world remembers what you did
	GameState.add_stat("battles")
	_build()
	AudioManager.play_music(enemy.get("music", "boss" if is_boss else "battle"), 0.3)
	AudioManager.set_intensity(1.0)
	var intro: String = enemy.get("intro", "%s appears." % enemy.get("name", "Something"))
	for v in enemy.get("intro_if", []):
		if GameState.check(v.get("if", "")):
			intro = v["text"]
			break
	_say([intro], _to_menu)


# ---------------------------------------------------------------------- build

func _build() -> void:
	arena = BattleArena.new()
	add_child(arena)
	arena.set_box(MENU_BOX, true)
	arena.soul_hit.connect(_on_soul_hit)
	arena.soul_grazed.connect(_on_graze)
	var words: Array = [GameState.player_name.to_upper(), "lost", "forgotten", "again"]
	for h in GameState.history:
		words.append(str(h["id"]).replace("_", " ").left(12))
	if GameState.stat("killed") > 0:
		words.append("%d GONE" % GameState.stat("killed"))
	if GameState.stat("spared") > 0:
		words.append("%d SPARED" % GameState.stat("spared"))
	arena.words = words

	enemy_sprite = Sprite2D.new()
	enemy_sprite.texture = SpriteLib.texture(enemy.get("sprite", "lostling"))
	var tex_h: float = enemy_sprite.texture.get_height()
	enemy_sprite.scale = Vector2.ONE * (96.0 / tex_h if tex_h > 16 else 5.0)
	enemy_sprite.position = enemy_base
	add_child(enemy_sprite)
	move_child(enemy_sprite, 0)

	fight_layer = Node2D.new()
	fight_layer.draw.connect(_draw_fight)
	add_child(fight_layer)

	ui = Control.new()
	ui.theme = UITheme.theme()
	ui.size = Vector2(640, 360)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.scroll_active = false
	text_label.position = MENU_BOX.position + Vector2(16, 12)
	text_label.size = MENU_BOX.size - Vector2(32, 20)
	text_label.mouse_filter = Control.MOUSE_FILTER_STOP
	text_label.gui_input.connect(_on_text_input)
	ui.add_child(text_label)

	sub_box = VBoxContainer.new()
	sub_box.position = MENU_BOX.position + Vector2(14, 8)
	sub_box.size = Vector2(MENU_BOX.size.x - 28, 0)
	sub_box.add_theme_constant_override("separation", 1)
	ui.add_child(sub_box)

	var stats := HBoxContainer.new()
	stats.position = Vector2(40, 284)
	stats.size = Vector2(560, 20)
	stats.add_theme_constant_override("separation", 8)
	ui.add_child(stats)
	name_label = UITheme.label("%s  LV %d" % [GameState.player_name.to_upper(), GameState.level], 14)
	stats.add_child(name_label)
	stats.add_child(UITheme.label("HP", 14, UITheme.DIM))
	hp_bar = _bar(Color("ffd94a"), 90)
	stats.add_child(hp_bar)
	hp_label = UITheme.label("", 14)
	stats.add_child(hp_label)
	stats.add_child(UITheme.label("FOCUS", 14, UITheme.DIM))
	fp_bar = _bar(Color("9fdcff"), 70)
	stats.add_child(fp_bar)
	fp_label = UITheme.label("", 14)
	stats.add_child(fp_label)
	mercy_label = UITheme.label("", 14, UITheme.GOLD)
	stats.add_child(mercy_label)

	var row := HBoxContainer.new()
	row.position = Vector2(29, 310)
	row.add_theme_constant_override("separation", 6)
	ui.add_child(row)
	for i in MENU_ITEMS.size():
		var b := Button.new()
		b.text = MENU_ITEMS[i]
		b.custom_minimum_size = Vector2(92, 36)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_on_menu_button.bind(i))
		row.add_child(b)
		buttons.append(b)

	bubble = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UITheme.panel_style(Color("20182c"), Color("fff6d6"), 2))
	bubble.position = Vector2(376, 40)
	bubble_label = UITheme.label("", 13, Color("20182c"))
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_label.custom_minimum_size = Vector2(180, 0)
	bubble.add_child(bubble_label)
	bubble.hide()
	ui.add_child(bubble)
	_refresh_stats()


func _bar(c: Color, w: float) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(w, 12)
	p.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = c
	p.add_theme_stylebox_override("fill", fill)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _refresh_stats() -> void:
	name_label.text = "%s  LV %d" % [GameState.player_name.to_upper(), GameState.level]
	hp_bar.max_value = GameState.max_hp()
	hp_bar.value = GameState.hp
	hp_label.text = "%d/%d" % [GameState.hp, GameState.max_hp()]
	fp_bar.max_value = GameState.MAX_FOCUS
	fp_bar.value = GameState.focus
	fp_label.text = str(GameState.focus)
	mercy_label.text = "SPARE!" if mercy >= 100 else ""
	for i in buttons.size():
		var sel: bool = state == S.MENU and i == menu_i
		buttons[i].add_theme_color_override("font_color", UITheme.GOLD if sel else Color.WHITE)
		buttons[i].add_theme_stylebox_override("normal", UITheme.panel_style(UITheme.GOLD if sel else UITheme.DIM, Color("2a1e4a") if sel else Color("1c1434"), 2))
	buttons[5].text = "MERCY*" if mercy >= 100 else "MERCY"


# ----------------------------------------------------------------- text flow

func _say(lines: Array, then: Callable) -> void:
	state = S.TEXT
	sub_box.hide()
	text_queue = lines.duplicate()
	after_text = then
	_next_line()


func _next_line() -> void:
	if text_queue.is_empty():
		var cb := after_text
		after_text = Callable()
		if cb.is_valid():
			cb.call()
		return
	var line: String = text_queue.pop_front()
	text_label.text = "* " + GameState.format_text(line.replace("{enemy}", enemy.get("name", "It")))
	text_label.visible_characters = 0
	typing_t = 0.0
	text_label.show()


func _to_menu() -> void:
	state = S.MENU
	sub_box.hide()
	text_label.show()
	var flavor: Array = enemy.get("flavor", ["{enemy} waits."])
	if mercy >= 100:
		flavor = [enemy.get("spare_ready", "{enemy} doesn't want to fight anymore.")]
	text_label.text = "* " + GameState.format_text(str(flavor[randi() % flavor.size()]).replace("{enemy}", enemy.get("name", "It")))
	text_label.visible_characters = -1
	_refresh_stats()


# ------------------------------------------------------------------ main loop

func _process(delta: float) -> void:
	bg_t += delta
	shake = maxf(0.0, shake - delta * 18.0)
	screen_shake = maxf(0.0, screen_shake - delta * 20.0)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * screen_shake
	if enemy_sprite and state != S.END:
		enemy_sprite.position = enemy_base + Vector2(sin(bg_t * 1.7) * 4.0 + randf_range(-shake, shake), sin(bg_t * 2.3) * 3.0)
	if state == S.TEXT and text_label.visible_characters != -1:
		typing_t += delta * 60.0
		text_label.visible_characters = int(typing_t)
		if int(typing_t) % 3 == 0:
			AudioManager.play_sfx("blip", 0.9)
		if text_label.visible_characters >= text_label.get_total_character_count():
			text_label.visible_characters = -1
	if state == S.FIGHT:
		_update_fight(delta)
	if state == S.ENEMY:
		_update_enemy_turn(delta)
	for p in popups.duplicate():
		p["t"] += delta
		p["node"].position.y -= delta * 30.0
		p["node"].modulate.a = 1.0 - p["t"] / 1.0
		if p["t"] > 1.0:
			p["node"].queue_free()
			popups.erase(p)
	queue_redraw()
	fight_layer.queue_redraw()


func _draw() -> void:
	var bgc := Color(enemy.get("bg", "#1a1030"))
	draw_rect(Rect2(-10, -10, 660, 380), Color("07040e"))
	for i in 14:
		var y := fmod(bg_t * 14.0 + i * 28.0, 170.0)
		draw_line(Vector2(0, y), Vector2(640, y), Color(bgc, 0.35), 1.0)
	for i in 21:
		var x := i * 32.0 + fmod(bg_t * 6.0, 32.0)
		draw_line(Vector2(x, 0), Vector2(x - 40, 170), Color(bgc, 0.25), 1.0)
	# enemy HP gauge (only after you've hurt it — you shouldn't see a target before you choose violence)
	if e_hp < e_max_hp:
		draw_rect(Rect2(260, 152, 120, 6), Color("3a1020"))
		draw_rect(Rect2(260, 152, 120.0 * e_hp / e_max_hp, 6), Color("ff6a7a"))


# ---------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	match state:
		S.TEXT:
			if event.is_action_pressed("confirm") or tap:
				_advance_text()
		S.MENU:
			if event.is_action_pressed("move_left"):
				menu_i = (menu_i - 1 + MENU_ITEMS.size()) % MENU_ITEMS.size()
				AudioManager.play_sfx("move")
				_refresh_stats()
			elif event.is_action_pressed("move_right"):
				menu_i = (menu_i + 1) % MENU_ITEMS.size()
				AudioManager.play_sfx("move")
				_refresh_stats()
			elif event.is_action_pressed("confirm"):
				_choose(menu_i)
		S.SUB:
			if event.is_action_pressed("move_up"):
				sub_i = (sub_i - 1 + sub_items.size()) % sub_items.size()
				AudioManager.play_sfx("move")
				_refresh_sub()
			elif event.is_action_pressed("move_down"):
				sub_i = (sub_i + 1) % sub_items.size()
				AudioManager.play_sfx("move")
				_refresh_sub()
			elif event.is_action_pressed("confirm"):
				_pick_sub(sub_i)
			elif event.is_action_pressed("cancel"):
				AudioManager.play_sfx("back")
				_to_menu()
		S.FIGHT:
			if event.is_action_pressed("confirm") or (tap and event.position.y < 300):
				_fight_press()
		_:
			return
	get_viewport().set_input_as_handled()


func _advance_text() -> void:
	if text_label.visible_characters != -1:
		text_label.visible_characters = -1
	else:
		AudioManager.play_sfx("move")
		_next_line()


func _on_text_input(event: InputEvent) -> void:
	if state == S.TEXT and ((event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed):
		_advance_text()


func _on_menu_button(i: int) -> void:
	if state == S.MENU or state == S.SUB:
		menu_i = i
		_choose(i)


func _choose(i: int) -> void:
	AudioManager.play_sfx("select")
	match MENU_ITEMS[i]:
		"FIGHT":
			_start_fight()
		"TALK":
			var items: Array = []
			for k in TALK_KEYS:
				items.append({"label": k.capitalize() + (" (again)" if talk_used.has(k) else ""), "action": "talk", "arg": k, "enabled": true})
			_open_sub(items)
		"DEFEND":
			defending = true
			GameState.add_focus(10)
			_say(["You steady yourself and raise your guard. (+10 Focus)"], _enemy_turn)
		"SPECIAL":
			var items: Array = []
			for s in GameState.specials():
				var def: Dictionary = SPECIALS.get(s, {})
				if def.is_empty():
					continue
				items.append({"label": "%s  [%d FP]  %s" % [def["name"], def["cost"], def["desc"]], "action": "special", "arg": s, "enabled": GameState.focus >= int(def["cost"])})
			_open_sub(items)
		"ITEM":
			var items: Array = []
			for item_id in GameState.inventory:
				var it: Dictionary = DB.items.get(item_id, {})
				if it.get("battle", false):
					items.append({"label": "%s x%d  %s" % [it.get("name", item_id), GameState.inventory[item_id], it.get("desc", "")], "action": "item", "arg": item_id, "enabled": true})
			if items.is_empty():
				items.append({"label": "Your pockets are empty.", "action": "none", "arg": "", "enabled": false})
			_open_sub(items)
		"MERCY":
			_open_sub([
				{"label": "Spare" + ("  ★" if mercy >= 100 else ""), "action": "spare", "arg": "", "enabled": true},
				{"label": "Flee" if not is_boss else "Flee (impossible)", "action": "flee", "arg": "", "enabled": not is_boss},
			])


func _open_sub(items: Array) -> void:
	state = S.SUB
	sub_items = items
	sub_i = 0
	text_label.hide()
	for c in sub_box.get_children():
		sub_box.remove_child(c)
		c.queue_free()
	for i in items.size():
		var b := Button.new()
		b.text = items[i]["label"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.add_theme_font_size_override("font_size", 14)
		b.disabled = not items[i]["enabled"]
		b.pressed.connect(_pick_sub.bind(i))
		sub_box.add_child(b)
	sub_box.show()
	_refresh_sub()
	_refresh_stats()


func _refresh_sub() -> void:
	for i in sub_box.get_child_count():
		var b: Button = sub_box.get_child(i)
		var prefix := "> " if i == sub_i else "  "
		b.text = prefix + sub_items[i]["label"]
		if sub_items[i]["enabled"]:
			b.add_theme_color_override("font_color", UITheme.GOLD if i == sub_i else Color.WHITE)


func _pick_sub(i: int) -> void:
	if state != S.SUB or i >= sub_items.size():
		return
	var it: Dictionary = sub_items[i]
	if not it["enabled"]:
		AudioManager.play_sfx("back")
		return
	AudioManager.play_sfx("select")
	match it["action"]:
		"talk": _do_talk(it["arg"])
		"special": _do_special(it["arg"])
		"item": _do_item(it["arg"])
		"spare": _do_spare()
		"flee": _do_flee()


# ---------------------------------------------------------------------- FIGHT

func _start_fight() -> void:
	state = S.FIGHT
	text_label.hide()
	sub_box.hide()
	fight = {"x": 0.0, "dir": 1.0, "speed": 1.0, "hits": 0, "total": 0, "results": [], "flash": 0.0}


func _update_fight(delta: float) -> void:
	fight["flash"] = maxf(0.0, fight["flash"] - delta * 4.0)
	fight["x"] += fight["dir"] * delta * 0.9 * fight["speed"]
	if fight["x"] > 1.0 or fight["x"] < 0.0:
		if fight["hits"] == 0:
			_popup("MISS", enemy_base + Vector2(0, -50), UITheme.DIM)
		_finish_fight()


func _fight_press() -> void:
	var x: float = fight["x"]
	var off := absf(x - 0.5) * 2.0  # 0 = dead center, 1 = edge
	var quality := 1.0 - off
	var crit := absf(x - 0.5) < GameState.crit_window()
	var base := maxf(1.0, GameState.attack() - e_def)
	var dmg := int(round(base * (0.35 + quality) * (1.8 if crit else 1.0) * (0.6 if fight["hits"] > 0 else 1.0)))
	dmg = max(1, dmg)
	fight["hits"] += 1
	fight["total"] += dmg
	fight["flash"] = 1.0
	shake = 10.0 if crit else 6.0
	AudioManager.play_sfx("crit" if crit else "hit")
	_popup(("CRIT " if crit else "") + str(dmg), enemy_base + Vector2(randf_range(-30, 30), -40 - fight["hits"] * 10), UITheme.GOLD if crit else Color.WHITE)
	if quality > 0.62 and fight["hits"] < 3:
		fight["dir"] = -fight["dir"]
		fight["speed"] *= 1.3
		fight["x"] = 0.0 if fight["dir"] > 0 else 1.0
		_popup("COMBO!", Vector2(320, 150), UITheme.ACCENT)
	else:
		_finish_fight()


func _finish_fight() -> void:
	state = S.TEXT
	var total: int = fight["total"]
	e_hp = max(0, e_hp - total)
	if e_hp <= 0:
		_kill()
		return
	var lines: Array = []
	if total > 0:
		lines.append("You struck %d time%s for %d damage." % [fight["hits"], "" if fight["hits"] == 1 else "s", total])
		mercy = max(0, mercy - 10)
	else:
		lines.append("You missed.")
	_say(lines, _enemy_turn)


func _draw_fight() -> void:
	if state != S.FIGHT:
		return
	var track := Rect2(120, 200, 400, 44)
	fight_layer.draw_rect(track, Color("1c1434"))
	for i in 20:
		var w := track.size.x / 20.0
		var c := 1.0 - absf((i + 0.5) / 20.0 - 0.5) * 2.0
		fight_layer.draw_rect(Rect2(track.position.x + i * w + 1, track.position.y + 4, w - 2, track.size.y - 8), Color(0.3 + c * 0.6, 0.2 + c * 0.5, 0.5, 1))
	var cw: float = track.size.x * GameState.crit_window()
	fight_layer.draw_rect(Rect2(track.get_center().x - cw, track.position.y, cw * 2.0, track.size.y), Color("ffe08a"), false, 2.0)
	var cx: float = track.position.x + track.size.x * float(fight.get("x", 0.0))
	fight_layer.draw_rect(Rect2(cx - 3, track.position.y - 6, 6, track.size.y + 12), Color.WHITE.lerp(Color("ffe08a"), fight.get("flash", 0.0)))
	fight_layer.draw_string(ThemeDB.fallback_font, Vector2(170, 270), "Press Z / tap when the bar is in the center", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.DIM)


# ----------------------------------------------------------------------- TALK

func _do_talk(key: String) -> void:
	GameState.add_stat("talked")
	var talk: Dictionary = enemy.get("talk", {})
	var entry: Dictionary = talk.get(key, {"text": "You try. {enemy} doesn't understand.", "mercy": 5})
	var phase_talk: Dictionary = enemy.get("phases", [{}])[min(phase, enemy.get("phases", [{}]).size() - 1)].get("talk", {}) if is_boss else {}
	if phase_talk.has(key):
		entry = phase_talk[key]
	var gain := int(entry.get("mercy", 10))
	var lines: Array = [entry.get("text", "...")]
	if talk_used.has(key) and gain > 0:
		gain = int(gain * 0.3)
		lines = [entry.get("repeat", "You try that again. It means less the second time.")]
	elif entry.has("reply"):
		lines.append(entry["reply"])
	talk_used[key] = true
	mercy = clampi(mercy + gain, 0, 100)
	e_atk = max(1, e_atk + int(entry.get("atk", 0)))
	difficulty_mod += float(entry.get("difficulty", 0.0))
	if entry.has("do"):
		GameState.apply_effects(entry["do"])
	if mercy >= 100:
		lines.append(enemy.get("spare_ready", "{enemy} no longer wants to fight."))
	_say(lines, _enemy_turn)


# -------------------------------------------------------------------- SPECIAL

func _do_special(key: String) -> void:
	var def: Dictionary = SPECIALS[key]
	GameState.add_focus(-int(def["cost"]))
	var pw := GameState.special_power()
	var lines: Array = []
	match key:
		"mend":
			var healed := GameState.heal(int(GameState.max_hp() * 0.4 * pw))
			AudioManager.play_sfx("heal")
			lines.append("You gather your scattered memories. Recovered %d HP." % healed)
		"time_slow":
			next_turn_fx["time_scale"] = 0.55
			lines.append("Time thickens like honey around you.")
		"energy_shield":
			next_turn_fx["shield"] = 3
			lines.append("A lattice of light wraps your soul.")
		"reflection":
			next_turn_fx["reflect"] = 2
			lines.append("Your soul becomes a mirror.")
		"illusions":
			next_turn_fx["illusions"] = 0.4
			lines.append("Three of you flicker into being. Which is real?")
		"spirit_summon":
			for cid in GameState.party():
				var c: Dictionary = DB.companions.get(cid, {})
				var s: Dictionary = c.get("summon", {})
				lines.append(s.get("text", "%s helps!" % c.get("name", cid)))
				match s.get("effect", ""):
					"heal":
						GameState.heal(int(GameState.max_hp() * 0.3 * pw))
						AudioManager.play_sfx("heal")
					"slow":
						next_turn_fx["time_scale"] = 0.6
						next_turn_fx["short"] = 0.6
					"damage":
						var d := int(GameState.attack() * 1.2 * pw)
						e_hp = max(1, e_hp - d)
						_popup(str(d), enemy_base + Vector2(0, -40), UITheme.ACCENT)
					"mercy":
						mercy = clampi(mercy + 25, 0, 100)
				GameState.change_loyalty(cid, 2)
	_refresh_stats()
	_say(lines, _enemy_turn)


func _do_item(item_id: String) -> void:
	var it: Dictionary = DB.items.get(item_id, {})
	GameState.give_item(item_id, -1)
	var lines: Array = [it.get("use_text", "You use the %s." % it.get("name", item_id))]
	if it.has("heal"):
		var h := GameState.heal(int(it["heal"]))
		AudioManager.play_sfx("heal")
		lines.append("Recovered %d HP." % h)
	if it.has("focus"):
		GameState.add_focus(int(it["focus"]))
		lines.append("Focus +%d." % int(it["focus"]))
	_refresh_stats()
	_say(lines, _enemy_turn)


# ---------------------------------------------------------------------- MERCY

func _do_spare() -> void:
	if mercy < 100:
		_say([enemy.get("not_ready", "{enemy} isn't ready to stop. Maybe if you understood it better...")], _enemy_turn)
		return
	state = S.END
	AudioManager.play_sfx("spare")
	GameState.add_stat("spared")
	if is_boss:
		GameState.add_stat("bosses_spared")
	Achievements.unlock("first_spare")
	var xp := int(enemy.get("xp", 5) * 0.5)
	var shards := int(enemy.get("shards", 2))
	GameState.add_xp(xp)
	GameState.shards += shards
	if enemy.has("on_spare"):
		GameState.apply_effects(enemy["on_spare"])
	for cid in GameState.party():
		GameState.change_loyalty(cid, 3)
	var tw := create_tween()
	tw.tween_property(enemy_sprite, "modulate", Color(1, 1, 1, 0.35), 0.6)
	state = S.TEXT
	_say([enemy.get("spare_text", "You spared {enemy}."), "You gained %d XP and %d shards." % [xp, shards]], func(): _end("spared"))


func _do_flee() -> void:
	if randf() < 0.7:
		AudioManager.play_sfx("back")
		_say(["You slip away into the mist."], func(): _end("fled"))
	else:
		_say(["You tried to run, but {enemy} is in the way!"], _enemy_turn)


func _kill() -> void:
	state = S.TEXT
	GameState.add_stat("killed")
	if is_boss:
		GameState.add_stat("bosses_defeated")
	var xp := int(enemy.get("xp", 5))
	var shards := int(enemy.get("shards", 2)) * 2
	GameState.add_xp(xp)
	GameState.shards += shards
	if enemy.has("on_kill"):
		GameState.apply_effects(enemy["on_kill"])
	for cid in GameState.party():
		GameState.change_loyalty(cid, -6)  # companions notice
	AudioManager.play_sfx("boom")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(enemy_sprite, "modulate", Color(1, 1, 1, 0), 1.0)
	tw.tween_property(enemy_sprite, "scale", enemy_sprite.scale * Vector2(1.6, 0.2), 1.0)
	_say([enemy.get("kill_text", "{enemy} came apart like dust in the wind."), "You gained %d XP and %d shards." % [xp, shards]], func(): _end("killed"))


# ----------------------------------------------------------------- ENEMY TURN

func _current_phase() -> Dictionary:
	var phases: Array = enemy.get("phases", [])
	return phases[min(phase, phases.size() - 1)] if phases.size() > 0 else {}


func _enemy_turn() -> void:
	state = S.ENEMY
	text_label.hide()
	sub_box.hide()
	turn_t = 0.0
	hits_taken = 0
	var keys: Array = _current_phase().get("patterns", enemy.get("patterns", ["rain"]))
	var pick: Array = [keys[randi() % keys.size()]]
	if (is_boss and phase >= 1 and randf() < 0.55) or (not is_boss and turn >= 3 and randf() < 0.3):
		var second: String = keys[randi() % keys.size()]
		if second != pick[0]:
			pick.append(second)
	var diff: float = float(enemy.get("difficulty", 1.0)) + phase * 0.25 + difficulty_mod + turn * 0.04
	diff = clampf(diff, 0.5, 2.4)
	patterns.clear()
	var size := Vector2(140, 100)
	for k in pick:
		var p = PatternLibrary.make(k)
		p.box_size = Vector2(180, 112)
		patterns.append(p)
	for p in patterns:
		p.start(arena, diff)
		size = size.max(p.box_size)
	size = size.min(Vector2(240, 128))
	arena.set_box(Rect2(Vector2(320, 212) - size / 2.0, size))
	arena.begin(GameState.soul_speed())
	arena.time_scale = float(next_turn_fx.get("time_scale", 1.0))
	arena.shield_hits = int(next_turn_fx.get("shield", 0))
	arena.reflect_hits = int(next_turn_fx.get("reflect", 0))
	arena.illusion_chance = float(next_turn_fx.get("illusions", 0.0))
	if arena.illusion_chance > 0.0:
		arena.decoys = [arena.soul + Vector2(-40, 10), arena.soul + Vector2(40, -10)]
	turn_time = float(enemy.get("turn_time", 7.5 if is_boss else 5.5)) * float(next_turn_fx.get("short", 1.0))
	next_turn_fx = {}
	var taunts: Array = _current_phase().get("taunts", enemy.get("taunts", []))
	if taunts.size() > 0:
		_bubble(str(taunts[randi() % taunts.size()]))
	_refresh_stats()


func _update_enemy_turn(delta: float) -> void:
	turn_t += delta
	var scaled: float = delta * arena.time_scale
	for p in patterns:
		p.update(scaled)
	if turn_t > 1.8:
		bubble.hide()
	if turn_t >= turn_time:
		_end_enemy_turn()


func _end_enemy_turn() -> void:
	arena.end_turn()
	arena.set_box(MENU_BOX)
	turn += 1
	var lines: Array = []
	if defending and GameState.talents_owned.has("guardian_counter"):
		var c := int(GameState.attack() * 0.6)
		e_hp = max(1, e_hp - c)
		_popup(str(c), enemy_base + Vector2(0, -40), UITheme.GOOD)
		lines.append("You counter through the opening! %d damage." % c)
	defending = false
	if hits_taken == 0:
		GameState.add_focus(8)
	mercy = clampi(mercy + int(enemy.get("mercy_per_turn", 0)), 0, 100)
	if is_boss:
		lines.append_array(_check_phase())
	if lines.is_empty():
		_to_menu()
	else:
		_say(lines, _to_menu)


func _check_phase() -> Array:
	var phases: Array = enemy.get("phases", [])
	var lines: Array = []
	var target := phase
	for i in range(phase + 1, phases.size()):
		var ph: Dictionary = phases[i]
		var by_hp: bool = float(e_hp) / e_max_hp <= float(ph.get("hp_below", 0.0))
		var by_turn: bool = turn >= int(ph.get("turn", 999))
		if by_hp or by_turn:
			target = i
	if target != phase:
		phase = target
		var ph: Dictionary = phases[phase]
		lines.append(ph.get("text", "{enemy} changes."))
		for cid in GameState.party():
			var cl: Dictionary = ph.get("companion_lines", {})
			if cl.has(cid):
				lines.append(cl[cid])
		AudioManager.set_intensity(1.0 + phase * 0.06)
		screen_shake = 6.0
	return lines


func _on_soul_hit(mult: float) -> void:
	if mult < 0.0:
		var d := int(GameState.attack() * 0.8 * GameState.special_power())
		e_hp = max(1, e_hp - d)
		shake = 6.0
		_popup("REFLECT " + str(d), enemy_base + Vector2(0, -40), UITheme.GOLD)
		AudioManager.play_sfx("crit")
		return
	hits_taken += 1
	var dmg := int(round(e_atk * mult * (0.5 if defending else 1.0))) - GameState.defense() / 2
	dmg = max(1, dmg)
	GameState.hp = max(0, GameState.hp - dmg)
	screen_shake = 5.0
	AudioManager.play_sfx("hurt")
	_refresh_stats()
	if GameState.hp <= 0:
		_lose()


func _on_graze() -> void:
	GameState.add_focus(GameState.graze_gain())
	GameState.add_stat("grazes")
	AudioManager.play_sfx("graze")
	if GameState.stat("grazes") >= 100:
		Achievements.unlock("graze_master")
	_refresh_stats()


func _lose() -> void:
	state = S.END
	arena.end_turn()
	GameState.add_stat("deaths")
	AudioManager.stop_music(0.2)
	AudioManager.play_sfx("death")
	await get_tree().create_timer(1.2).timeout
	_end("lost")


func _end(outcome: String) -> void:
	state = S.END
	bubble.hide()
	var result := {"outcome": outcome, "enemy": enemy_id, "context": context, "boss": is_boss}
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(0, 0, 0, 1), 0.4)
	await tw.finished
	battle_ended.emit(result)


# --------------------------------------------------------------------- helpers

func _bubble(text: String) -> void:
	bubble_label.text = GameState.format_text(text)
	bubble.show()


func _popup(text: String, at: Vector2, color: Color) -> void:
	var l := UITheme.label(text, 18, color)
	l.position = at - Vector2(30, 0)
	ui.add_child(l)
	popups.append({"node": l, "t": 0.0})
