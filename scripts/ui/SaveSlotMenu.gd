extends PanelContainer
## Save (at lanterns) or load (from title). Slot 0 is the autosave.

const UITheme = preload("res://scripts/ui/UITheme.gd")

signal closed

var mode: String = "save"
var main


func _ready() -> void:
	theme = UITheme.theme()
	position = Vector2(120, 60)
	custom_minimum_size = Vector2(400, 0)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	v.add_child(UITheme.label("Save to which memory?" if mode == "save" else "Load which memory?", 18, UITheme.GOLD))
	var first: Button = null
	var start := 1 if mode == "save" else 0
	for slot in range(start, SaveManager.SLOT_COUNT + 1):
		var s := SaveManager.slot_summary(slot)
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var label := "Autosave" if slot == 0 else "Slot %d" % slot
		if s.is_empty():
			b.text = "%s — empty" % label
			b.disabled = mode == "load"
		else:
			b.text = "%s — %s  LV%d  %s  %s" % [label, s["name"], s["level"], s["place"], s["time"]]
		b.pressed.connect(_pick.bind(slot))
		v.add_child(b)
		if first == null and not b.disabled:
			first = b
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_close)
	v.add_child(cancel)
	if first == null:
		first = cancel
	first.grab_focus.call_deferred()


func _pick(slot: int) -> void:
	if mode == "save":
		if SaveManager.save(slot):
			AudioManager.play_sfx("save")
			Events.toast.emit("Your memories are kept safe.")
		_close()
	else:
		AudioManager.play_sfx("select")
		closed.emit()
		queue_free()
		main.continue_game(slot)


func _close() -> void:
	AudioManager.play_sfx("back")
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()
