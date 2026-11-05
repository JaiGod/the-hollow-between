extends "res://scripts/battle/patterns/BasePattern.gd"
## Rings of orbs that circle the box center and slowly close in.
## There's always a gap in each ring — find it.


func on_start() -> void:
	box_size = Vector2(150, 150)


func step(dt: float) -> void:
	if every("ring", 1.7 / difficulty, dt):
		var c: Vector2 = box().get_center()
		var count := int(10 + 4 * difficulty)
		var gap := randi() % count
		var dir := 1.0 if randi() % 2 == 0 else -1.0
		for i in count:
			if i == gap or i == (gap + 1) % count:
				continue
			var a := TAU * i / count
			var r := 110.0
			arena.spawn(c + Vector2(cos(a), sin(a)) * r, Vector2.ZERO, {
				"orbit_center": c, "orbit_radius": r, "orbit_speed": dir * (0.9 + 0.3 * difficulty),
				"orbit_shrink": 22.0 + 6.0 * difficulty, "radius": 5.0, "color": Color("c0a0ff"), "life": 7.0,
				"harmless_until": 0.25})
