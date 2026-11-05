extends Control
## In-world menu: Status · Quests · Party · Talents · Items · Settings.

const UITheme = preload("res://scripts/ui/UITheme.gd")
const SpriteLib = preload("res://scripts/art/SpriteLib.gd")
const EndingResolver = preload("res://scripts/systems/EndingResolver.gd")
const SettingsPanel = preload("res://scripts/ui/SettingsPanel.gd")

signal closed

const TABS := ["Status", "Quests", "Party", "Talents", "Items", "Settings", "Title"]

var tab: int = 0
var tab_buttons: Array = []
var content: VBoxContainer
var panel: PanelContainer


func _ready() -> void:
	theme = UITheme.theme()
	size = Vector2(640, 360)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.size = size
	add_child(dim)
	panel = PanelContainer.new()
	panel.position = Vector2(24, 16)
	panel.size = Vector2(592, 328)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_set_tab.bind(i))
		row.add_child(b)
		tab_buttons.append(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)
	v.add_child(UITheme.label("←/→ tabs · Z select · X / C close", 11, UITheme.DIM))
	_set_tab(0)


func _set_tab(i: int) -> void:
	tab = i
	for j in tab_buttons.size():
		tab_buttons[j].add_theme_color_override("font_color", UITheme.GOLD if j == i else Color.WHITE)
	for c in content.get_children():
		c.queue_free()
	match TABS[i]:
		"Status": _status()
		"Quests": _quests()
		"Party": _party()
		"Talents": _talents()
		"Items": _items()
		"Settings":
			var s := SettingsPanel.new()
			s.closed.connect(func(): _set_tab(0))
			content.add_child(s)
		"Title":
			content.add_child(UITheme.label("Return to the title? Unsaved progress since your last lantern or autosave is lost.", 14))
			var b := Button.new()
			b.text = "Return to title"
			b.pressed.connect(func():
				_close()
				get_tree().current_scene.goto_title())
			content.add_child(b)
	tab_buttons[i].grab_focus.call_deferred()


func _line(text: String, color: Color = Color.WHITE, sz: int = 14) -> void:
	var l := UITheme.label(text, sz, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	content.add_child(l)


func _status() -> void:
	var gs = GameState
	_line("%s   LV %d" % [gs.player_name, gs.level], UITheme.GOLD, 18)
	_line("HP %d/%d    ATK %d    DEF %d    FOCUS %d" % [gs.hp, gs.max_hp(), gs.attack(), gs.defense(), gs.focus])
	_line("XP %d (next at %d)    Shards %d    Talent points %d" % [gs.xp, gs.xp_to_next(), gs.shards, gs.talent_points])
	var secs := int(gs.playtime)
	_line("Time %d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60], UITheme.DIM)
	_line("")
	_line("Spared %d · Defeated %d · Talked %d · Helped %d · Secrets %d" % [gs.stat("spared"), gs.stat("killed"), gs.stat("talked"), gs.stat("helped"), gs.stat("secrets")])
	_line(EndingResolver.leaning(), UITheme.ACCENT)


func _quests() -> void:
	if GameState.quests.is_empty():
		_line("No quests yet. Talk to people — everyone here lost something.", UITheme.DIM)
	for qid in GameState.quests:
		var q: Dictionary = DB.quests.get(qid, {})
		var done: bool = GameState.quest_state(qid) == "done"
		_line(("✓ " if done else "• ") + q.get("title", qid), UITheme.GOOD if done else UITheme.GOLD)
		_line("   " + GameState.quest_step_text(qid), UITheme.DIM, 13)


func _party() -> void:
	for cid in DB.companions:
		var c: Dictionary = DB.companions[cid]
		var st: Dictionary = GameState.companions.get(cid, {})
		if not st.get("recruited", false):
			_line("??? — " + c.get("hint", "Not yet met."), UITheme.DIM)
			continue
		var row := HBoxContainer.new()
		var tr := TextureRect.new()
		tr.texture = SpriteLib.texture(c.get("sprite", "echo"))
		tr.custom_minimum_size = Vector2(32, 32)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(tr)
		var info := UITheme.label("%s — %s\nLoyalty %d · %s" % [c["name"], c.get("role", ""), GameState.loyalty(cid), "in party" if st.get("in_party") else "waiting"], 13)
		info.custom_minimum_size = Vector2(380, 0)
		row.add_child(info)
		var b := Button.new()
		b.text = "Part ways" if st.get("in_party") else "Rejoin"
		b.pressed.connect(func():
			if st.get("in_party"):
				GameState.dismiss(cid)
				GameState.change_loyalty(cid, -15)
			else:
				GameState.companions[cid]["in_party"] = true
				GameState.change_loyalty(cid, 5)
			_set_tab(tab))
		row.add_child(b)
		content.add_child(row)


func _talents() -> void:
	_line("Talent points: %d   (earn 1 per level)" % GameState.talent_points, UITheme.GOLD)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 6)
	content.add_child(grid)
	for bid in DB.talents.get("branches", {}):
		var br: Dictionary = DB.talents["branches"][bid]
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(136, 0)
		grid.add_child(col)
		var head := UITheme.label(br.get("name", bid), 14, Color(br.get("color", "#ffffff")))
		col.add_child(head)
		var sub := UITheme.label(br.get("desc", ""), 10, UITheme.DIM)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(130, 0)
		col.add_child(sub)
		for tdef in br.get("talents", []):
			var tid: String = tdef["id"]
			var b := Button.new()
			var owned: bool = GameState.talents_owned.has(tid)
			b.text = ("✓ " if owned else "") + tdef["name"]
			b.tooltip_text = tdef.get("desc", "")
			b.add_theme_font_size_override("font_size", 12)
			b.disabled = not owned and not GameState.can_learn(tid)
			b.pressed.connect(func():
				if GameState.learn(tid):
					AudioManager.play_sfx("levelup")
					Events.toast.emit("Learned " + tdef["name"])
				_set_tab(tab))
			col.add_child(b)
			var d := UITheme.label(tdef.get("desc", ""), 10, UITheme.DIM)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(130, 0)
			col.add_child(d)
	_line("Mix branches freely — hybrid builds are encouraged.", UITheme.DIM, 11)


func _items() -> void:
	if GameState.inventory.is_empty():
		_line("Nothing but lint and a feeling you've forgotten something.", UITheme.DIM)
	for item_id in GameState.inventory:
		var it: Dictionary = DB.items.get(item_id, {})
		var row := HBoxContainer.new()
		var l := UITheme.label("%s x%d — %s" % [it.get("name", item_id), GameState.inventory[item_id], it.get("desc", "")], 13)
		l.custom_minimum_size = Vector2(440, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		if it.has("heal") or it.has("focus"):
			var b := Button.new()
			b.text = "Use"
			b.pressed.connect(func():
				GameState.give_item(item_id, -1)
				if it.has("heal"):
					GameState.heal(int(it["heal"]))
				if it.has("focus"):
					GameState.add_focus(int(it["focus"]))
				AudioManager.play_sfx("heal")
				_set_tab(tab))
			row.add_child(b)
		content.add_child(row)


func _close() -> void:
	AudioManager.play_sfx("back")
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
		_close()
	elif event.is_action_pressed("move_left") and not _focus_in_content():
		_set_tab((tab - 1 + TABS.size()) % TABS.size())
	elif event.is_action_pressed("move_right") and not _focus_in_content():
		_set_tab((tab + 1) % TABS.size())
	else:
		return
	get_viewport().set_input_as_handled()


func _focus_in_content() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f != null and content.is_ancestor_of(f) and f is HSlider
