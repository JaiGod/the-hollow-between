extends RefCounted
## Base for enemy attack patterns. To add a new attack:
##   1. Copy any pattern in this folder, override on_start() / step().
##   2. Register it in PatternLibrary.gd.
##   3. Reference its key in an enemy's "patterns" list in data/enemies.json.
## `difficulty` (≈0.6–2.0) scales density/speed; bosses raise it per phase.

var arena
var difficulty: float = 1.0
var t: float = 0.0
var _timers: Dictionary = {}
var box_size: Vector2 = Vector2(180, 112)


func start(a, diff: float) -> void:
	arena = a
	difficulty = diff
	on_start()


func on_start() -> void:
	pass


func update(dt: float) -> void:
	t += dt
	step(dt)


func step(_dt: float) -> void:
	pass


func every(key: String, interval: float, dt: float) -> bool:
	## True once each `interval` seconds — use for spawn cadence.
	_timers[key] = float(_timers.get(key, interval)) + dt
	if _timers[key] >= interval:
		_timers[key] = 0.0
		return true
	return false


func box() -> Rect2:
	return arena.box


func rand_edge_point(margin: float = 20.0) -> Vector2:
	var b: Rect2 = arena.box.grow(margin)
	match randi() % 4:
		0: return Vector2(randf_range(b.position.x, b.end.x), b.position.y)
		1: return Vector2(randf_range(b.position.x, b.end.x), b.end.y)
		2: return Vector2(b.position.x, randf_range(b.position.y, b.end.y))
	return Vector2(b.end.x, randf_range(b.position.y, b.end.y))
