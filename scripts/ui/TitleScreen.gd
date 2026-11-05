extends Control
## Title screen + name entry. It changes once you've seen an ending —
## the Hollow remembers across playthroughs.

const UITheme = preload("res://scripts/ui/UITheme.gd")
const SpriteLib = preload("res://scripts/art/SpriteLib.gd")

var main
var t: float = 0.0
var stars: Array = []
var menu: VBoxContainer
var name_panel: PanelContainer
var name_edit: LineEdit


func _ready() -> void:
	size = Vector2(640, 360)
	theme = UITheme.theme()
	for i in 90:
		stars.append(Vector3(randf() * 640, randf() * 360, randf()))
	var title := UITheme.label("THE HOLLOW BETWEEN", 32, Color("e8e0ff"))
	title.position = Vector2(0, 44)
	title.size = Vector2(640, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var seen: Array = SaveManager.profile.get("endings_seen", [])
	var sub_text := "a world made of what everyone forgot"
	if seen.size() > 0:
		sub_text = "it remembers you."
	var sub := UITheme.label(sub_text, 14, UITheme.ACCENT)
	sub.position = Vector2(0, 84)
	sub.size = Vector2(640, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	menu = VBoxContainer.new()
	menu.position = Vector2(230, 150)
	menu.size = Vector2(180, 0)
	menu.add_theme_constant_override("separation", 5)
	add_child(menu)
	var has_save := SaveManager.has_any_save()
	if has_save:
		_button("Continue", func(): main.continue_game(SaveManager.AUTOSAVE_SLOT))
	_button("New Game", _ask_name)
	if has_save:
		_button("Load", func(): main.open_load_menu())
	_button("Settings", _open_settings)
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		_button("Quit", func(): get_tree().quit())
	(menu.get_child(0) as Button).grab_focus.call_deferred()

	var foot := UITheme.label("v%s  ·  endings found: %d/6" % [ProjectSettings.get_setting("application/config/version", "0.1"), seen.size()], 12, UITheme.DIM)
	foot.position = Vector2(12, 336)
	add_child(foot)


func _button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 28)
	b.pressed.connect(func():
		AudioManager.play_sfx("select")
		cb.call())
	menu.add_child(b)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("07040e"))
	for s in stars:
		var tw: float = 0.4 + 0.6 * absf(sin(t * (0.5 + s.z) + s.x))
		draw_rect(Rect2(s.x, fmod(s.y + t * 4.0 * s.z, 360.0), 2, 2), Color(0.8, 0.75, 1.0, tw * 0.8))
	var soul := SpriteLib.texture("soul")
	var p := Vector2(320, 124 + sin(t * 1.5) * 4.0)
	draw_texture_rect(soul, Rect2(p - Vector2(8, 8), Vector2(16, 16)), false)
	draw_arc(p, 14 + sin(t * 2.0) * 2.0, 0, TAU, 24, Color(0.75, 0.63, 1.0, 0.4), 1.0)


func _ask_name() -> void:
	menu.hide()
	name_panel = PanelContainer.new()
	name_panel.position = Vector2(170, 160)
	name_panel.size = Vector2(300, 140)
	add_child(name_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	name_panel.add_child(v)
	v.add_child(UITheme.label("Name the one who fell.", 16, UITheme.GOLD))
	name_edit = LineEdit.new()
	name_edit.max_length = 10
	name_edit.placeholder_text = "Wren"
	name_edit.text_submitted.connect(func(_t): _confirm_name())
	v.add_child(name_edit)
	var row := HBoxContainer.new()
	v.add_child(row)
	var ok := Button.new()
	ok.text = "Begin"
	ok.pressed.connect(_confirm_name)
	row.add_child(ok)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func():
		name_panel.queue_free()
		menu.show()
		(menu.get_child(0) as Button).grab_focus())
	row.add_child(back)
	name_edit.grab_focus()


func _confirm_name() -> void:
	var n := name_edit.text.strip_edges()
	if n.to_upper() == "WARDEN":
		AudioManager.play_sfx("save", 0.5)
	main.start_new_game(n)


func _open_settings() -> void:
	const SettingsPanel = preload("res://scripts/ui/SettingsPanel.gd")
	var s := SettingsPanel.new()
	s.position = Vector2(170, 130)
	s.closed.connect(func(): (menu.get_child(0) as Button).grab_focus())
	add_child(s)
