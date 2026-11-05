extends Node2D
## On-screen controls for phones/tablets. They press the same input actions
## as the keyboard, so no gameplay code knows touch exists.
## Only visible on touchscreens (TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY).
## Set the env var HOLLOW_TOUCH=1 or run with --touch to force them on desktop.

var groups: Dictionary = {"dpad": [], "a": [], "b": [], "menu": []}
var mode: String = ""
var forced: bool = false


func _ready() -> void:
	forced = OS.get_environment("HOLLOW_TOUCH") == "1" or "--touch" in OS.get_cmdline_user_args()
	var c := Vector2(76, 282)
	_btn("dpad", "move_up", c + Vector2(-22, -66), _arrow(0))
	_btn("dpad", "move_down", c + Vector2(-22, 22), _arrow(2))
	_btn("dpad", "move_left", c + Vector2(-66, -22), _arrow(3))
	_btn("dpad", "move_right", c + Vector2(22, -22), _arrow(1))
	_btn("a", "confirm", Vector2(560, 262), _circle("Z", Color("9fe0c0")))
	_btn("b", "cancel", Vector2(510, 300), _circle("X", Color("ff9aaa")))
	_btn("menu", "menu", Vector2(586, 12), _circle("≡", Color("c0a0ff"), 32))
	set_mode("none")


func _btn(group: String, action: String, pos: Vector2, tex: Texture2D) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = tex
	b.action = action
	b.position = pos
	b.passby_press = group == "dpad"
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS if forced else TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	b.modulate = Color(1, 1, 1, 0.55)
	add_child(b)
	groups[group].append(b)


func set_mode(m: String) -> void:
	if m == mode:
		return
	mode = m
	var shown: Array = {
		"world": ["dpad", "a", "b", "menu"],
		"soul": ["dpad", "a"],
		"none": [],
	}.get(m, [])
	for g in groups:
		for b in groups[g]:
			b.visible = g in shown
			if not b.visible:
				Input.action_release(b.action)


static func _arrow(dir: int) -> Texture2D:
	var img := Image.create(44, 44, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 44:
		for x in 44:
			var inside := x > 1 and y > 1 and x < 42 and y < 42
			if inside:
				img.set_pixel(x, y, Color(0.1, 0.07, 0.2, 0.75))
			if x <= 1 or y <= 1 or x >= 42 or y >= 42:
				img.set_pixel(x, y, Color(0.9, 0.88, 1.0, 0.9))
	# triangle pointing up, then rotate
	for row in 12:
		for col in range(-row, row + 1):
			var p := Vector2i(22 + col, 14 + row)
			match dir:
				1: p = Vector2i(44 - p.y, p.x)
				2: p = Vector2i(p.x, 44 - p.y)
				3: p = Vector2i(p.y, p.x)
			img.set_pixel(clampi(p.x, 0, 43), clampi(p.y, 0, 43), Color(0.95, 0.9, 1.0))
	return ImageTexture.create_from_image(img)


static func _circle(label: String, c: Color, sz: int = 44) -> Texture2D:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := sz / 2.0
	for y in sz:
		for x in sz:
			var d := Vector2(x - r + 0.5, y - r + 0.5).length()
			if d < r - 2:
				img.set_pixel(x, y, Color(c.r * 0.3, c.g * 0.3, c.b * 0.35, 0.8))
			elif d < r:
				img.set_pixel(x, y, c)
	# simple glyph dot so buttons are distinguishable without a font
	var g := int(r)
	img.fill_rect(Rect2i(g - 4, g - 4, 8, 8), c)
	if label == "X":
		img.fill_rect(Rect2i(g - 2, g - 9, 4, 18), c)
	return ImageTexture.create_from_image(img)
