extends "res://scripts/battle/patterns/BasePattern.gd"
## Energy beams: a blinking warning line, then a sweep of light.
## Alternates horizontal and vertical; at higher difficulty fires pairs.

var flip := false


func on_start() -> void:
	box_size = Vector2(200, 120)


func step(dt: float) -> void:
	if every("beam", 1.25 / difficulty, dt):
		var b := box()
		var n := 2 if difficulty > 1.3 else 1
		for i in n:
			if flip:
				var y := randf_range(b.position.y + 10, b.end.y - 10)
				arena.beam(Vector2(b.position.x - 10, y), Vector2(b.end.x + 10, y), 12.0)
			else:
				var x := randf_range(b.position.x + 10, b.end.x - 10)
				arena.beam(Vector2(x, b.position.y - 10), Vector2(x, b.end.y + 10), 12.0)
			flip = not flip
