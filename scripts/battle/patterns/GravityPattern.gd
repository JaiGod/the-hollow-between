extends "res://scripts/battle/patterns/BasePattern.gd"
## The whole box becomes a gravity zone: your soul falls, UP/confirm jumps.
## Low "thorns" slide along the floor; high ones arc over.

var made_zone := false


func on_start() -> void:
	box_size = Vector2(220, 110)


func step(dt: float) -> void:
	if not made_zone and t > 0.15:
		made_zone = true
		arena.zone(box().grow(4), 560.0)
	if every("thorn", 0.95 / difficulty, dt):
		var b := box()
		var from_left := randi() % 2 == 0
		var x := b.position.x - 10 if from_left else b.end.x + 10
		var vx := (120.0 + 30 * difficulty) * (1 if from_left else -1)
		if randi() % 3 == 0:
			arena.spawn(Vector2(x, b.position.y + 22), Vector2(vx, 0), {"kind": "shard", "radius": 5.0, "color": Color("c090e0")})
		else:
			arena.spawn(Vector2(x, b.end.y - 8), Vector2(vx, 0), {"kind": "shard", "radius": 6.0, "color": Color("c090e0")})
