extends RefCounted
## Maps pattern keys used in data/enemies.json to scripts.

const PATTERNS := {
	"rain": preload("res://scripts/battle/patterns/RainPattern.gd"),
	"orbit": preload("res://scripts/battle/patterns/OrbitPattern.gd"),
	"beam": preload("res://scripts/battle/patterns/BeamPattern.gd"),
	"mines": preload("res://scripts/battle/patterns/MinePattern.gd"),
	"wave": preload("res://scripts/battle/patterns/WavePattern.gd"),
	"gravity": preload("res://scripts/battle/patterns/GravityPattern.gd"),
	"teleport": preload("res://scripts/battle/patterns/TeleportPattern.gd"),
	"pages": preload("res://scripts/battle/patterns/PagePattern.gd"),
}


static func make(key: String):
	var script = PATTERNS.get(key, PATTERNS["rain"])
	return script.new()
