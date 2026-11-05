extends Control
## Branching dialogue: typewriter text, portraits, voice blips, choices,
## conditions and effects. Conversation format is documented in
## docs/STORY_DESIGN.md → "Writing dialogue".

const SpriteLib = preload("res://scripts/art/SpriteLib.gd")
const UITheme = preload("res://scripts/ui/UITheme.gd")

signal finished

var conv: Dictionary = {}
var conv_id: String = ""
var node: Dictionary = {}
var pages: Array = []
var page_i: int = 0
var on_done: Callable
var typing: bool = false
var type_t: float = 0.0
var choices: Array = []
var choice_i: int = 0
var pending_battle: Dictionary = {}
var pending_event: String = ""
var active: bool = false
var main  # set by Main; receives dialogue "event" hooks
var voice_pitch: float = 1.0

var box: PanelContainer
var portrait: TextureRect
var name_label: Label
var text_label: RichTextLabel
var choice_box: VBoxContainer
var arrow: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()
	box = PanelContainer.new()
	box.position = Vector2(16, 244)
	box.size = Vector2(608, 104)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(_on_box_input)
	add_child(box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	box.add_child(h)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(80, 80)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	name_label = UITheme.label("", 16, UITheme.GOLD)
	v.add_child(name_label)
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = false
	text_label.scroll_active = false
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.custom_minimum_size = Vector2(480, 56)
	v.add_child(text_label)
	arrow = UITheme.label("v", 14, UITheme.ACCENT)
	arrow.position = Vector2(588, 326)
	add_child(arrow)
	choice_box = VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 4)
	add_child(choice_box)
	hide()


func start(conversation_id: String, done: Callable = Callable()) -> void:
	conv_id = conversation_id
	conv = DB.dialogue(conversation_id)
	on_done = done
	pending_battle = {}
	pending_event = ""
	if conv.is_empty():
		push_warning("Dialogue not found: " + conversation_id)
		_finish()
		return
	active = true
	show()
	Events.dialogue_started.emit(conversation_id)
	_goto(conv.get("start", "start"))


func start_lines(lines: Array, done: Callable = Callable(), speaker: String = "") -> void:
	conv_id = "_inline"
	conv = {"nodes": {"start": {"speaker": speaker, "text": lines}}}
	on_done = done
	pending_battle = {}
	pending_event = ""
	active = true
	show()
	_goto("start")


func _goto(node_id: String) -> void:
	if node_id == "" or node_id == "end" or not conv.get("nodes", {}).has(node_id):
		_finish()
		return
	node = conv["nodes"][node_id]
	if node.has("branch"):
		for b in node["branch"]:
			if GameState.check(b.get("if", "")):
				_goto(b.get("next", ""))
				return
		_finish()
		return
	if node.has("if") and not GameState.check(node["if"]):
		_goto(node.get("else", node.get("next", "")))
		return
	var txt = node.get("text", "")
	pages = txt if txt is Array else [txt]
	page_i = 0
	if pages.is_empty() or (pages.size() == 1 and pages[0] == ""):
		_after_pages()
		return
	var speaker: String = node.get("speaker", "")
	name_label.text = GameState.format_text(speaker)
	var pname: String = node.get("portrait", conv.get("portraits", {}).get(speaker, speaker.to_lower().replace(" ", "_").replace("the_", "")))
	portrait.texture = SpriteLib.texture(pname) if SpriteLib.SPRITES.has(pname) else null
	portrait.visible = portrait.texture != null
	voice_pitch = float(conv.get("voices", {}).get(speaker, 0.8 + float(absi(speaker.hash()) % 60) / 100.0))
	_show_page()


func _show_page() -> void:
	choice_box.hide()
	text_label.text = GameState.format_text(str(pages[page_i]))
	text_label.visible_characters = 0
	typing = true
	type_t = 0.0
	arrow.hide()


func _process(delta: float) -> void:
	if not active:
		return
	if typing:
		var speed := 45.0 * float(SaveManager.setting("text_speed", 1.0))
		type_t += delta * speed
		var n := int(type_t)
		if n != text_label.visible_characters:
			if n % 2 == 0:
				AudioManager.play_sfx("blip", voice_pitch)
			text_label.visible_characters = n
		if n >= text_label.get_total_character_count():
			_end_typing()
	else:
		arrow.position.y = 326 + sin(Time.get_ticks_msec() / 150.0) * 2.0


func _end_typing() -> void:
	typing = false
	text_label.visible_characters = -1
	if page_i == pages.size() - 1 and node.has("choices"):
		_show_choices()
	else:
		arrow.show()


func _show_choices() -> void:
	for c in choice_box.get_children():
		choice_box.remove_child(c)
		c.queue_free()
	choices = []
	for c in node["choices"]:
		if GameState.check(c.get("if", "")):
			choices.append(c)
	if choices.is_empty():
		_after_pages()
		return
	choice_i = 0
	for i in choices.size():
		var b := Button.new()
		b.text = GameState.format_text(choices[i]["text"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick_choice.bind(i))
		b.mouse_entered.connect(func(): choice_i = i; _refresh_choices())
		choice_box.add_child(b)
	choice_box.position = Vector2(624 - 300, 240 - choices.size() * 38)
	choice_box.size = Vector2(300, 0)
	choice_box.show()
	_refresh_choices()


func _refresh_choices() -> void:
	for i in choice_box.get_child_count():
		var b: Button = choice_box.get_child(i)
		b.add_theme_color_override("font_color", UITheme.GOLD if i == choice_i else Color.WHITE)
		b.text = ("> " if i == choice_i else "  ") + GameState.format_text(choices[i]["text"])


func _pick_choice(i: int) -> void:
	var c: Dictionary = choices[i]
	AudioManager.play_sfx("select")
	choice_box.hide()
	if c.has("do"):
		GameState.apply_effects(c["do"])
	if c.has("battle"):
		pending_battle = {"enemy": c["battle"], "id": c.get("battle_id", "")}
	_goto(c.get("next", ""))


func _after_pages() -> void:
	if node.has("do"):
		GameState.apply_effects(node["do"])
	if node.has("battle"):
		pending_battle = {"enemy": node["battle"], "id": node.get("battle_id", "")}
	if node.has("event"):
		pending_event = node["event"]
	_goto(node.get("next", ""))


func _advance() -> void:
	if typing:
		_end_typing()
		return
	if choice_box.visible:
		_pick_choice(choice_i)
		return
	AudioManager.play_sfx("move")
	if page_i < pages.size() - 1:
		page_i += 1
		_show_page()
	else:
		_after_pages()


func _finish() -> void:
	var was_active := active
	active = false
	hide()
	if was_active:
		Events.dialogue_finished.emit(conv_id)
	finished.emit()
	var cb := on_done
	on_done = Callable()
	if cb.is_valid():
		cb.call()
	if not pending_event.is_empty():
		var ev := pending_event
		pending_event = ""
		if main:
			main.handle_event(ev)
	if not pending_battle.is_empty():
		var pb := pending_battle
		pending_battle = {}
		Events.battle_requested.emit(pb["enemy"], {"entity_id": pb["id"]})


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("confirm"):
		_advance()
	elif event.is_action_pressed("cancel") and typing:
		_end_typing()
	elif choice_box.visible and event.is_action_pressed("move_up"):
		choice_i = (choice_i - 1 + choices.size()) % choices.size()
		AudioManager.play_sfx("move")
		_refresh_choices()
	elif choice_box.visible and event.is_action_pressed("move_down"):
		choice_i = (choice_i + 1) % choices.size()
		AudioManager.play_sfx("move")
		_refresh_choices()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_box_input(event: InputEvent) -> void:
	if active and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
		if not choice_box.visible:
			_advance()
