extends Node2D
## One loaded map: baked tiles, entities, player, followers, camera, lighting
## and weather. Built entirely from res://data/maps/<id>.json.

const TileBaker = preload("res://scripts/art/TileBaker.gd")
const SpriteLib = preload("res://scripts/art/SpriteLib.gd")
const WorldEntity = preload("res://scripts/world/WorldEntity.gd")
const PlayerScript = preload("res://scripts/world/Player.gd")

const TS := 32  # on-screen tile size (16px art at 2x)
const DAY_LENGTH := 300.0  # seconds for a full day/night cycle

var main
var map_id: String
var map: Dictionary
var rows: Array = []
var map_w: int = 0
var map_h: int = 0

var entities_root: Node2D
var player
var followers: Array = []
var camera: Camera2D
var modulate_node: CanvasModulate
var daylight: float = 1.0
var exit_cooldown: float = 0.0
var blocked_shown: Dictionary = {}


func setup(main_ref, id: String, spawn: String) -> void:
	main = main_ref
	map_id = id
	map = DB.map(id)
	rows = map.get("tiles", [])
	map_h = rows.size()
	for r in rows:
		map_w = max(map_w, (r as String).length())
	_build(spawn)


func _build(spawn: String) -> void:
	var bg := Sprite2D.new()
	bg.texture = TileBaker.bake(rows)
	bg.centered = false
	bg.scale = Vector2(2, 2)
	bg.z_index = -10
	add_child(bg)

	entities_root = Node2D.new()
	entities_root.y_sort_enabled = true
	add_child(entities_root)
	for e in map.get("entities", []):
		var ent := WorldEntity.new()
		ent.position = tile_to_world(e["x"], e["y"])
		entities_root.add_child(ent)
		ent.setup(e)

	player = PlayerScript.new()
	player.overworld = self
	entities_root.add_child(player)
	if GameState.has_position and GameState.map_id == map_id and spawn == "":
		player.position = GameState.position
	else:
		var sp: Array = map.get("spawns", {}).get(spawn, map.get("spawns", {}).get("start", [2, 2]))
		player.position = tile_to_world(sp[0], sp[1])
		if sp.size() > 2:
			player.facing = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}.get(sp[2], Vector2.DOWN)
	GameState.has_position = false
	GameState.map_id = map_id

	_build_followers()

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_w * TS
	camera.limit_bottom = map_h * TS
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)
	camera.position = Vector2(0, -16)
	camera.make_current()

	modulate_node = CanvasModulate.new()
	add_child(modulate_node)
	_build_weather(map.get("weather", ""))
	refresh_entities()
	_show_area_title()
	exit_cooldown = 0.4


func tile_to_world(tx, ty) -> Vector2:
	return Vector2(float(tx) * TS + TS / 2.0, float(ty) * TS + TS - 4)


func tile_at(world: Vector2) -> String:
	var tx := int(floor(world.x / TS))
	var ty := int(floor(world.y / TS))
	if ty < 0 or ty >= map_h or tx < 0:
		return "#"
	var row: String = rows[ty]
	return row[tx] if tx < row.length() else "#"


func can_stand(r: Rect2) -> bool:
	for p in [r.position, r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), r.end]:
		if TileBaker.is_solid(tile_at(p)):
			return false
	for e in entities_root.get_children():
		if e is WorldEntity and e.is_solid() and e.blocker_rect().intersects(r):
			return false
	return true


func is_busy() -> bool:
	return main == null or main.ui_busy()


func refresh_entities() -> void:
	for e in entities_root.get_children():
		if e is WorldEntity:
			e.visible = e.is_active()
			e.refresh_sprite()
	_build_followers()


# ------------------------------------------------------------------ followers

func _build_followers() -> void:
	for f in followers:
		f.queue_free()
	followers.clear()
	if player == null:
		return
	for cid in GameState.party():
		var f := Sprite2D.new()
		f.texture = SpriteLib.texture(DB.companions.get(cid, {}).get("sprite", "echo"))
		f.scale = Vector2(2, 2)
		f.offset = Vector2(0, -8)
		f.position = player.position - player.facing * 26.0 * (followers.size() + 1)
		entities_root.add_child(f)
		followers.append(f)


func _process(delta: float) -> void:
	exit_cooldown = maxf(0.0, exit_cooldown - delta)
	if player:
		for i in followers.size():
			var idx: int = (i + 1) * 14
			var target: Vector2
			if idx < player.trail.size():
				target = player.trail[idx]
			else:
				# Not enough walked history yet: stand just behind the player.
				target = player.position - player.facing * 26.0 * (i + 1) + Vector2(8 * i, 0)
			followers[i].position = followers[i].position.lerp(target, 0.25)
			followers[i].offset.y = -10 + sin(Time.get_ticks_msec() / 300.0 + i) * 1.5
	_update_daylight()


func _update_daylight() -> void:
	if not map.get("outdoor", false):
		daylight = 1.0
		modulate_node.color = Color(map.get("tint", "#ffffff"))
		return
	var phase := fmod(GameState.playtime / DAY_LENGTH, 1.0)
	# 0.0 morning .. 0.5 dusk .. 0.75 night .. 1.0 dawn
	daylight = clampf(0.55 + 0.45 * cos((phase - 0.15) * TAU), 0.0, 1.0)
	var day := Color(map.get("tint", "#ffffff"))
	var night := Color("5a5a9a")
	modulate_node.color = night.lerp(day, daylight)


func _build_weather(kind: String) -> void:
	if kind == "":
		return
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(360, 220)
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.z_index = 20
	match kind:
		"fireflies":
			p.color = Color("e8ff9a")
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 14.0
			p.color_ramp = _fade_ramp(Color("e8ff9a"))
		"motes":
			p.color = Color("b9f3ff")
			p.direction = Vector2(0, -1)
			p.spread = 25.0
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 20.0
			p.color_ramp = _fade_ramp(Color("b9f3ff"))
		"ink":
			p.amount = 70
			p.lifetime = 3.0
			p.direction = Vector2(0.1, 1)
			p.spread = 5.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 90.0
			p.color_ramp = _fade_ramp(Color("2a1e40"))
		"stars":
			p.amount = 30
			p.color_ramp = _fade_ramp(Color("fff6d6"))
			p.initial_velocity_max = 2.0
	camera.add_child(p)


static func _fade_ramp(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(c, 0.0))
	g.set_color(1, Color(c, 0.0))
	g.add_point(0.3, Color(c, 0.9))
	g.add_point(0.7, Color(c, 0.6))
	return g


func _show_area_title() -> void:
	if main and main.has_method("show_area_title"):
		main.show_area_title(map.get("region", ""), map.get("name", ""))
	AudioManager.play_music(map.get("music", "forest"))


# ------------------------------------------------------------------ gameplay

func on_player_moved() -> void:
	GameState.position = player.position
	var now := Time.get_ticks_msec() / 1000.0
	var feet: Rect2 = player.foot_rect(player.position)
	for e in entities_root.get_children():
		if e is WorldEntity and e.kind == "enemy" and e.visible and now >= e.disabled_until:
			if Rect2(e.position + Vector2(-14, -20), Vector2(28, 24)).intersects(feet):
				_touch_enemy(e)
				return
	if exit_cooldown > 0.0:
		return
	var tx := int(floor(player.position.x / TS))
	var ty := int(floor((player.position.y - 4) / TS))
	for ex in map.get("exits", []):
		var r: Array = ex["rect"]
		if tx >= r[0] and tx < r[0] + r[2] and ty >= r[1] and ty < r[1] + r[3]:
			if ex.has("if") and not GameState.check(ex["if"]):
				_bounce_back()
				if ex.has("blocked"):
					main.run_dialogue_text(ex["blocked"])
				return
			exit_cooldown = 1.0
			Events.map_change_requested.emit(ex["to"], ex.get("spawn", "start"))
			return


func _bounce_back() -> void:
	if player.trail.size() > 6:
		player.position = player.trail[6]
		player.trail.clear()
	exit_cooldown = 0.6


func _touch_enemy(e) -> void:
	var enemy_id: String = e.data.get("enemy", "lostling")
	var pre: String = e.data.get("dialogue", "")
	var ctx := {"entity_id": e.data.get("id", ""), "map": map_id}
	if pre != "":
		main.run_dialogue(pre, func(): Events.battle_requested.emit(enemy_id, ctx))
	else:
		AudioManager.play_sfx("encounter")
		Events.battle_requested.emit(enemy_id, ctx)


func on_battle_result(result: Dictionary) -> void:
	var id: String = result.get("context", {}).get("entity_id", "")
	if id == "":
		return
	match result.get("outcome", ""):
		"spared", "killed":
			GameState.set_flag("resolved." + id, result["outcome"])
		"fled":
			for e in entities_root.get_children():
				if e is WorldEntity and e.data.get("id", "") == id:
					e.disabled_until = Time.get_ticks_msec() / 1000.0 + 3.0
	refresh_entities()


func _unhandled_input(event: InputEvent) -> void:
	if is_busy():
		return
	if event.is_action_pressed("confirm"):
		_try_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu"):
		main.open_pause_menu()
		get_viewport().set_input_as_handled()


func _try_interact() -> void:
	var probe: Vector2 = player.position + player.facing * 22.0 + Vector2(0, -8)
	for e in entities_root.get_children():
		if e is WorldEntity and e.visible and e.interact_rect().has_point(probe):
			interact(e)
			return


func interact(e) -> void:
	var d: Dictionary = e.data
	match e.kind:
		"npc", "sign":
			if d.has("face") and d["face"] and e.sprite:
				e.sprite.flip_h = player.position.x < e.position.x
			main.run_dialogue(d.get("dialogue", ""), refresh_entities)
		"save":
			AudioManager.play_sfx("save")
			GameState.heal(999)
			GameState.add_focus(100)
			main.open_save_lantern(d.get("text", "The lantern hums. Your memories feel steadier here."))
		"item":
			GameState.set_flag("picked." + d.get("id", ""), true)
			if d.has("item"):
				GameState.give_item(d["item"], int(d.get("count", 1)))
			if d.has("do"):
				GameState.apply_effects(d["do"])
			AudioManager.play_sfx("select")
			main.run_dialogue_text(d.get("text", "You picked something up."))
			refresh_entities()
		"stone":
			_touch_stone(e)
		"blocker":
			main.run_dialogue_text(d.get("text", "Something blocks the way."))


func _touch_stone(e) -> void:
	var puzzle: String = e.data.get("puzzle", "stones")
	var solved_flag := "puzzle." + puzzle
	if GameState.get_flag(solved_flag):
		main.run_dialogue_text("The stone glows softly. It remembers.")
		return
	var progress := int(GameState.get_flag(solved_flag + ".progress", 0))
	var order := int(e.data.get("order", 1))
	if order == progress + 1:
		GameState.set_flag("stone_lit." + e.data.get("id", ""), true)
		GameState.set_flag(solved_flag + ".progress", order)
		AudioManager.play_sfx("heal", 0.8 + order * 0.15)
		if order >= int(e.data.get("count", 3)):
			GameState.set_flag(solved_flag, true)
			AudioManager.play_sfx("spare")
			main.run_dialogue_text(e.data.get("solved_text", "The stones sing together. Somewhere, brambles unravel."))
	else:
		GameState.set_flag(solved_flag + ".progress", 0)
		for other in entities_root.get_children():
			if other is WorldEntity and other.kind == "stone" and other.data.get("puzzle", "") == puzzle:
				GameState.set_flag("stone_lit." + other.data.get("id", ""), false)
		AudioManager.play_sfx("back")
		main.run_dialogue_text("The light gutters out. The stones have forgotten again.")
	refresh_entities()
