extends "res://scripts/battle/patterns/BasePattern.gd"
## Walls of orbs sweep across the box with a gap that drifts along a sine wave.

var phase := 0.0


func on_start() -> void:
	box_size = Vector2(220, 112)


func step(dt: float) -> void:
	phase += dt
	if every("col", 0.42 / difficulty, dt):
		var b := box()
		var gap_center := b.get_center().y + sin(phase * 1.6) * (b.size.y * 0.32)
		var gap := 34.0 - 4.0 * difficulty
		var y := b.position.y + 4
		while y < b.end.y:
			if absf(y - gap_center) > gap:
				arena.spawn(Vector2(b.end.x + 12, y), Vector2(-(110 + 30 * difficulty), 0),
					{"radius": 4.0, "color": Color("6fd3ff")})
			y += 11.0
