extends "res://scripts/battle/patterns/BasePattern.gd"
## Falling memory-shards with a little sideways drift.

var color := Color("b9f3ff")


func step(dt: float) -> void:
	if every("drop", 0.32 / difficulty, dt):
		var b := box()
		var x := randf_range(b.position.x + 4, b.end.x - 4)
		arena.spawn(Vector2(x, b.position.y - 14), Vector2(randf_range(-15, 15), 70 + 35 * difficulty),
			{"kind": "shard", "radius": 4.0, "color": color, "acc": Vector2(0, 40)})
