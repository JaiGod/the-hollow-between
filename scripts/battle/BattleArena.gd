extends Node2D
## The bullet box: soul movement, bullets, beams, gravity zones, teleport
## markers, collision, grazing and i-frames. Patterns only call spawn/beam/
## zone/marker; everything else lives here.

const Bullet = preload("res://scripts/battle/Bullet.gd")
const SpriteLib = preload("res://scripts/art/SpriteLib.gd")

signal soul_hit(damage_mult: float)
signal soul_grazed()

const GRAZE_DIST := 11.0
const SOUL_R := 4.0
const IFRAMES := 0.9

var box: Rect2 = Rect2(40, 168, 560, 112)
var target_box: Rect2 = box
var running: bool = false
var soul: Vector2 = Vector2(320, 224)
var soul_vel_y: float = 0.0
var soul_speed: float = 150.0
var iframes: float = 0.0
var time_scale: float = 1.0
var bullets: Array = []
var beams: Array = []      # {a,b,width,warn,active,age,color}
var zones: Array = []      # {rect, gravity}
var markers: Array = []    # {pos, life, age}
var words: Array = []
var decoys: Array = []
var shield_hits: int = 0
var reflect_hits: int = 0
var illusion_chance: float = 0.0
var soul_tex: Texture2D
var flash: float = 0.0


func _ready() -> void:
	soul_tex = SpriteLib.texture("soul")


func set_box(r: Rect2, instant: bool = false) -> void:
	target_box = r
	if instant:
		box = r


func begin(speed: float) -> void:
	soul_speed = speed
	soul = box.get_center()
	soul_vel_y = 0.0
	clear()
	running = true


func clear() -> void:
	bullets.clear()
	beams.clear()
	zones.clear()
	markers.clear()
	decoys.clear()


func end_turn() -> void:
	running = false
	clear()


# ---------------------------------------------------------------- pattern API

func spawn(pos: Vector2, vel: Vector2, opts: Dictionary = {}):
	var b := Bullet.new()
	b.pos = pos
	b.vel = vel
	for k in opts:
		b.set(k, opts[k])
	bullets.append(b)
	return b


func beam(a: Vector2, b: Vector2, width: float = 14.0, warn: float = 0.7, active: float = 0.45, color: Color = Color("ff6a7a")) -> void:
	beams.append({"a": a, "b": b, "width": width, "warn": warn, "active": active, "age": 0.0, "color": color})
	AudioManager.play_sfx("move", 0.6)


func zone(r: Rect2, gravity: float = 520.0) -> void:
	zones.append({"rect": r, "gravity": gravity})


func marker(pos: Vector2, life: float = 0.6) -> void:
	markers.append({"pos": pos, "life": life, "age": 0.0})


func aim_target() -> Vector2:
	## Illusions make aimed attacks sometimes target a decoy.
	if decoys.size() > 0 and randf() < 0.5:
		return decoys[randi() % decoys.size()]
	return soul


# -------------------------------------------------------------------- update

func _process(delta: float) -> void:
	box.position = box.position.lerp(target_box.position, minf(1.0, delta * 10.0))
	box.size = box.size.lerp(target_box.size, minf(1.0, delta * 10.0))
	flash = maxf(0.0, flash - delta * 3.0)
	if running:
		_update_soul(delta)
		_update_hazards(delta * time_scale)
	queue_redraw()


func _in_zone() -> Dictionary:
	for z in zones:
		if (z["rect"] as Rect2).has_point(soul):
			return z
	return {}


func _update_soul(delta: float) -> void:
	iframes = maxf(0.0, iframes - delta)
	var dir: Vector2 = InputConfig.move_vector()
	var z := _in_zone()
	if z.is_empty():
		soul += dir * soul_speed * delta
		soul_vel_y = 0.0
	else:
		soul.x += dir.x * soul_speed * delta
		soul_vel_y += float(z["gravity"]) * delta
		var floor_y := box.end.y - 6.0
		if soul.y >= floor_y - 0.5 and (Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("confirm")):
			soul_vel_y = -290.0
		soul.y += soul_vel_y * delta
	var inner := box.grow(-6.0)
	soul.x = clampf(soul.x, inner.position.x, inner.end.x)
	soul.y = clampf(soul.y, inner.position.y, inner.end.y)
	if soul.y >= inner.end.y:
		soul_vel_y = 0.0


func _update_hazards(dt: float) -> void:
	for b in bullets:
		b.update(dt, soul)
		if b.kind == "mine" and b.dead:
			_explode(b.pos)
	for b in bullets:
		if b.dead or not b.is_harmful():
			continue
		var d: float = b.pos.distance_to(soul)
		if d < b.radius + SOUL_R:
			b.dead = true
			_hit(1.0, b)
		elif d < b.radius + SOUL_R + GRAZE_DIST and not b.grazed:
			b.grazed = true
			soul_grazed.emit()
	bullets = bullets.filter(func(x): return not x.dead and x.pos.x > -80 and x.pos.x < 720 and x.pos.y > -80 and x.pos.y < 440)

	for bm in beams:
		bm["age"] += dt
		if bm["age"] > bm["warn"] and bm["age"] < bm["warn"] + bm["active"]:
			if not bm.get("sounded", false):
				bm["sounded"] = true
				AudioManager.play_sfx("beam")
			var dist := _seg_dist(soul, bm["a"], bm["b"])
			if dist < bm["width"] * 0.5 + SOUL_R - 1.0:
				_hit(1.3, null)
	beams = beams.filter(func(x): return x["age"] < x["warn"] + x["active"] + 0.15)

	for m in markers:
		m["age"] += dt
	markers = markers.filter(func(x): return x["age"] < x["life"])


func _explode(at: Vector2) -> void:
	AudioManager.play_sfx("boom")
	for i in 10:
		var a := TAU * i / 10.0
		spawn(at, Vector2(cos(a), sin(a)) * 95.0, {"radius": 4.0, "color": Color("ff9a5a"), "life": 3.0})


func _hit(mult: float, b) -> void:
	if iframes > 0.0:
		return
	if illusion_chance > 0.0 and randf() < illusion_chance:
		iframes = 0.25
		return
	if shield_hits > 0:
		shield_hits -= 1
		iframes = 0.4
		flash = 0.6
		AudioManager.play_sfx("select", 0.6)
		return
	if reflect_hits > 0:
		reflect_hits -= 1
		iframes = 0.4
		if b:
			b.dead = false
			b.reflected = true
			b.vel = Vector2(0, -260)
		soul_hit.emit(-1.0)  # negative = reflected to enemy
		return
	iframes = IFRAMES
	soul_hit.emit(mult)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ---------------------------------------------------------------------- draw

func _draw() -> void:
	for z in zones:
		var zr: Rect2 = z["rect"]
		draw_rect(zr, Color(0.35, 0.2, 0.7, 0.22))
		for i in int(zr.size.x / 16):
			var y := zr.position.y + fmod(Time.get_ticks_msec() / 12.0 + i * 13.0, zr.size.y)
			draw_rect(Rect2(zr.position.x + i * 16 + 6, y, 2, 6), Color(0.6, 0.45, 1.0, 0.5))
	draw_rect(box.grow(3), Color.WHITE, false, 3.0)
	if flash > 0.0:
		draw_rect(box, Color(0.6, 0.9, 1.0, flash * 0.25))
	for bm in beams:
		var a: Vector2 = bm["a"]
		var b: Vector2 = bm["b"]
		if bm["age"] < bm["warn"]:
			var blink := 0.35 + 0.35 * sin(bm["age"] * 30.0)
			draw_line(a, b, Color(bm["color"], blink), 2.0)
		else:
			draw_line(a, b, Color(bm["color"], 0.45), bm["width"] + 6.0)
			draw_line(a, b, Color.WHITE, bm["width"] * 0.5)
	for m in markers:
		var r: float = 6.0 + 10.0 * (m["age"] / m["life"])
		draw_arc(m["pos"], 14.0 - r * 0.4, 0, TAU, 16, Color("ff6a7a"), 2.0)
		draw_circle(m["pos"], 3.0, Color("fff6d6"))
	var font := ThemeDB.fallback_font
	for b in bullets:
		var c: Color = b.color
		if b.age < b.harmless_until:
			c.a = 0.35
		match b.kind:
			"shard":
				var fwd: Vector2 = b.vel.normalized() * b.radius * 1.8 if b.vel.length() > 1.0 else Vector2(0, b.radius)
				var side := fwd.orthogonal() * 0.45
				draw_colored_polygon(PackedVector2Array([b.pos + fwd, b.pos + side, b.pos - fwd * 0.6, b.pos - side]), c)
			"page":
				draw_set_transform(b.pos, b.rot)
				var w: float = 10.0 + b.text.length() * 6.0
				draw_rect(Rect2(-w / 2, -8, w, 16), Color("e8e0c8"))
				draw_rect(Rect2(-w / 2, -8, w, 16), Color("20182c"), false, 1.0)
				if b.text != "":
					draw_string(font, Vector2(-w / 2 + 5, 5), b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("20182c"))
				draw_set_transform(Vector2.ZERO)
			"mine":
				var pulse := 0.5 + 0.5 * sin(b.age * (6.0 + b.age * 6.0))
				draw_circle(b.pos, b.radius, Color("3a2030"))
				draw_circle(b.pos, b.radius * 0.55, Color(1.0, 0.4 + pulse * 0.4, 0.3))
			"ring":
				draw_arc(b.pos, b.radius, 0, TAU, 20, c, 2.0)
			_:
				draw_circle(b.pos, b.radius, c)
				draw_circle(b.pos, b.radius * 0.45, Color(1, 1, 1, c.a))
	if running:
		for d in decoys:
			draw_texture_rect(soul_tex, Rect2(d - Vector2(8, 8), Vector2(16, 16)), false, Color(1, 1, 1, 0.35))
		var visible_soul := iframes <= 0.0 or int(iframes * 12.0) % 2 == 0
		if visible_soul:
			draw_texture_rect(soul_tex, Rect2(soul - Vector2(8, 8), Vector2(16, 16)), false)
		if shield_hits > 0:
			draw_arc(soul, 13.0, 0, TAU, 20, Color("9fe0ff"), 2.0)
		if reflect_hits > 0:
			draw_arc(soul, 15.0, 0, TAU, 6, Color("ffe08a"), 2.0)
