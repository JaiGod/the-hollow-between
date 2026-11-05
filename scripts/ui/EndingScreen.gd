extends Control
## End-of-chapter screen: which ending your choices earned, plus a recap.

const UITheme = preload("res://scripts/ui/UITheme.gd")

var ending_id: String = "balance"
var main
var t: float = 0.0
var color: Color = Color.WHITE


func _ready() -> void:
	theme = UITheme.theme()
	size = Vector2(640, 360)
	var e: Dictionary = DB.endings.get(ending_id, {})
	color = Color(e.get("color", "#ffffff"))
	var v := VBoxContainer.new()
	v.position = Vector2(60, 34)
	v.size = Vector2(520, 0)
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var ch := UITheme.label("CHAPTER ONE — THE MEMORY FOREST", 13, UITheme.DIM)
	ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ch)
	var title := UITheme.label(e.get("title", ending_id).to_upper(), 26, color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var body := UITheme.label(GameState.format_text(e.get("chapter_text", e.get("text", ""))), 14)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 0)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	var gs = GameState
	var recap := UITheme.label("Spared %d · Defeated %d · Companions %d · Quests %d · Secrets %d · LV %d" % [
		gs.stat("spared"), gs.stat("killed"), gs.party().size(), gs.stat("helped"), gs.stat("secrets"), gs.level], 13, UITheme.ACCENT)
	recap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(recap)
	var seen: Array = SaveManager.profile.get("endings_seen", [])
	var found := UITheme.label("Endings discovered: %d / 6" % seen.size(), 13, UITheme.DIM)
	found.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(found)
	var next := UITheme.label("To be continued in Chapter Two: The Silent City.", 13, UITheme.GOLD)
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(next)
	var b := Button.new()
	b.text = "Return to title"
	b.pressed.connect(func(): main.goto_title())
	v.add_child(b)
	b.grab_focus.call_deferred()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("07040e"))
	for i in 40:
		var x := fmod(i * 97.0 + t * (6 + i % 5), 640.0)
		var y := 360.0 - fmod(i * 53.0 + t * (10 + i % 7), 400.0)
		draw_rect(Rect2(x, y, 2, 2), Color(color, 0.35 + 0.3 * sin(t + i)))
