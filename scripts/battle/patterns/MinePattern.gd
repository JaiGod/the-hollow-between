extends "res://scripts/battle/patterns/BasePattern.gd"
## Mines appear, pulse faster and faster, then burst into a ring.


func on_start() -> void:
	box_size = Vector2(170, 130)


func step(dt: float) -> void:
	if every("mine", 1.1 / difficulty, dt):
		var b := box().grow(-16)
		var p := Vector2(randf_range(b.position.x, b.end.x), randf_range(b.position.y, b.end.y))
		if p.distance_to(arena.soul) < 36:
			p = b.get_center() + (b.get_center() - arena.soul).normalized() * 40.0
		arena.spawn(p, Vector2.ZERO, {"kind": "mine", "radius": 7.0, "life": 1.5, "harmless_until": 9.0})
