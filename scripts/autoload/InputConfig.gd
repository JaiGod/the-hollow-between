extends Node
## Registers every input action at boot, so the project needs no editor-made
## input map and bindings live in one readable place.
## Touch controls (TouchControls.gd) press these same actions.

const BINDINGS := {
	"move_up": [KEY_UP, KEY_W],
	"move_down": [KEY_DOWN, KEY_S],
	"move_left": [KEY_LEFT, KEY_A],
	"move_right": [KEY_RIGHT, KEY_D],
	"confirm": [KEY_Z, KEY_ENTER, KEY_SPACE],
	"cancel": [KEY_X, KEY_SHIFT, KEY_BACKSPACE],
	"menu": [KEY_C, KEY_ESCAPE, KEY_TAB],
}

const PAD_BUTTONS := {
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"confirm": [JOY_BUTTON_A],
	"cancel": [JOY_BUTTON_B],
	"menu": [JOY_BUTTON_START, JOY_BUTTON_Y],
}

const PAD_AXES := {
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
}


func _ready() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.35)
		for key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for btn in PAD_BUTTONS.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = btn
			InputMap.action_add_event(action, jb)
		if PAD_AXES.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = PAD_AXES[action][0]
			jm.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, jm)
	# Let Z / X drive Godot's built-in menu navigation too.
	for pair in [["ui_accept", KEY_Z], ["ui_cancel", KEY_X]]:
		var k := InputEventKey.new()
		k.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], k)


func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
