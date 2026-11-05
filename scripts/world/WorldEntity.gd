extends Node2D
## Anything placed on a map: NPCs, enemies, save lanterns, items, signs,
## puzzle stones and blockers. Behaviour is chosen by data["type"].

const SpriteLib = preload("res://scripts/art/SpriteLib.gd")

var data: Dictionary = {}
var kind: String = ""
var sprite: Sprite2D
var origin: Vector2
var t: float = 0.0
var disabled_until: float = 0.0
var light: PointLight2D


func setup(d: Dictionary) -> void:
	data = d
	kind = d.get("type", "npc")
	origin = position
	t = randf() * 10.0
	sprite = Sprite2D.new()
	sprite.scale = Vector2(2, 2)
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	refresh_sprite()
	if d.get("flip", false):
		sprite.flip_h = true
	if kind == "save":
		light = PointLight2D.new()
		light.texture = _glow_texture()
		light.color = Color("ffd98a")
		light.energy = 0.0
		light.texture_scale = 2.5
		light.position = Vector2(0, -16)
		add_child(light)
	if kind == "enemy":
		sprite.modulate = Color(1, 1, 1, 0.92)


func refresh_sprite() -> void:
	var sname: String = data.get("sprite", "")
	match kind:
		"save": sname = "lantern"
		"stone": sname = "stone_lit" if GameState.get_flag("stone_lit." + data.get("id", "")) or GameState.get_flag(data.get("solved_flag", "")) else "stone"
		"item": sname = data.get("sprite", "shard")
		"sign": sname = "sign"
		"blocker": sname = "stone"
		"enemy": sname = DB.enemy(data.get("enemy", "")).get("sprite", "lostling")
	sprite.texture = SpriteLib.texture(sname)
	if kind == "blocker":
		sprite.modulate = Color("6a4a8a")


static func _glow_texture() -> Texture2D:
	var g := GradientTexture2D.new()
	g.width = 128
	g.height = 128
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	g.gradient = grad
	return g


func is_active() -> bool:
	## Hidden when its condition fails or it's been resolved (picked up, spared...).
	if data.has("if") and not GameState.check(data["if"]):
		return false
	if data.has("unless") and GameState.check(data["unless"]):
		return false
	var id: String = data.get("id", "")
	if kind == "enemy" and (GameState.get_flag("resolved." + id)):
		return false
	if kind == "item" and GameState.get_flag("picked." + id):
		return false
	return true


func is_solid() -> bool:
	return kind in ["npc", "save", "sign", "stone", "blocker"] and visible


func blocker_rect() -> Rect2:
	if kind == "blocker":
		return Rect2(position + Vector2(-16, -28), Vector2(32, 32))  # whole tile
	return Rect2(position + Vector2(-13, -12), Vector2(26, 14))


func interact_rect() -> Rect2:
	return Rect2(position + Vector2(-18, -30), Vector2(36, 36))


func _process(delta: float) -> void:
	t += delta
	if kind == "enemy" and visible:
		var wander: float = data.get("wander", 24.0)
		position = origin + Vector2(sin(t * 0.7) * wander, cos(t * 0.45) * wander * 0.4)
		sprite.offset.y = -8 + sin(t * 4.0) * 1.5
		sprite.modulate.a = 0.4 if Time.get_ticks_msec() / 1000.0 < disabled_until else 0.92
	elif data.get("float", false) or kind == "item":
		sprite.offset.y = -10 + sin(t * 2.2) * 2.0
	if light:
		var ow := get_parent().get_parent()
		var dl = ow.get("daylight") if ow else null
		var night: float = 1.0 - float(dl) if dl != null else 0.3
		light.energy = 0.35 + night * 0.9 + sin(t * 3.0) * 0.05
	if kind == "save":
		sprite.modulate = Color(1, 1, 1).lerp(Color(1.3, 1.2, 0.9), 0.5 + 0.5 * sin(t * 3.0))
