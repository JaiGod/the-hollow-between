extends PanelContainer
## Volume, text speed and display options. Saved in the cross-save profile.

const UITheme = preload("res://scripts/ui/UITheme.gd")

signal closed


func _ready() -> void:
	theme = UITheme.theme()
	custom_minimum_size = Vector2(300, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	v.add_child(UITheme.label("Settings", 18, UITheme.GOLD))
	var first := _slider(v, "Music", "music", 0.7, func(): AudioManager.refresh_volume())
	_slider(v, "Sound", "sfx", 0.8, func(): AudioManager.play_sfx("select"))
	_slider(v, "Text speed", "text_speed", 1.0, func(): pass, 0.4, 3.0)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var fs := CheckButton.new()
		fs.text = "Fullscreen"
		fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
		v.add_child(fs)
	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(_close)
	v.add_child(done)
	first.grab_focus.call_deferred()


func _slider(parent: Control, label_text: String, key: String, default: float, on_change: Callable, lo: float = 0.0, hi: float = 1.0) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := UITheme.label(label_text, 14)
	l.custom_minimum_size = Vector2(100, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(SaveManager.setting(key, default))
	s.custom_minimum_size = Vector2(160, 20)
	s.value_changed.connect(func(val):
		SaveManager.set_setting(key, val)
		on_change.call())
	row.add_child(s)
	return s


func _close() -> void:
	AudioManager.play_sfx("back")
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_close()
