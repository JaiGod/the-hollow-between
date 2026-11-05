extends "res://scripts/battle/patterns/BasePattern.gd"
## The Archivist's signature: pages inscribed with words from YOUR history
## (names of who you spared or fought, your own name) spiral into the box.


func on_start() -> void:
	box_size = Vector2(200, 130)


func step(dt: float) -> void:
	if every("page", 0.75 / difficulty, dt):
		var start := rand_edge_point(40.0)
		var target: Vector2 = arena.aim_target() + Vector2(randf_range(-30, 30), randf_range(-20, 20))
		var v := (target - start).normalized() * (70.0 + 25.0 * difficulty)
		var word: String = arena.words[randi() % arena.words.size()] if arena.words.size() > 0 else "lost"
		arena.spawn(start, v, {"kind": "page", "text": word, "radius": 8.0, "spin": randf_range(-2.0, 2.0), "life": 6.0})
