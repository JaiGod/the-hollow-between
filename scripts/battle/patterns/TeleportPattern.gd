extends "res://scripts/battle/patterns/BasePattern.gd"
## An eye blinks in somewhere around the box, then fires an aimed spread.

var pending: Array = []  # [pos, fire_at]


func on_start() -> void:
	box_size = Vector2(160, 120)


func step(dt: float) -> void:
	if every("blink", 0.9 / difficulty, dt):
		var p := rand_edge_point(18.0)
		arena.marker(p, 0.55)
		pending.append([p, t + 0.55])
	for item in pending.duplicate():
		if t >= item[1]:
			pending.erase(item)
			var to: Vector2 = (arena.aim_target() - item[0]).normalized()
			var shots := 3 if difficulty < 1.3 else 5
			for i in shots:
				var ang := (i - (shots - 1) / 2.0) * 0.22
				arena.spawn(item[0], to.rotated(ang) * (120 + 30 * difficulty), {"radius": 4.5, "color": Color("ff6a7a")})
