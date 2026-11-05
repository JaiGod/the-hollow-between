extends Node
## Read-only game database. All content (enemies, maps, dialogue, quests,
## companions, talents, items, endings) is JSON under res://data so writers
## and designers can add content without touching code.

var enemies: Dictionary = {}
var quests: Dictionary = {}
var companions: Dictionary = {}
var talents: Dictionary = {}
var items: Dictionary = {}
var endings: Dictionary = {}
var _maps: Dictionary = {}
var _dialogue: Dictionary = {}


func _ready() -> void:
	enemies = load_json("res://data/enemies.json")
	quests = load_json("res://data/quests.json")
	companions = load_json("res://data/companions.json")
	talents = load_json("res://data/talents.json")
	items = load_json("res://data/items.json")
	endings = load_json("res://data/endings.json")


func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DB: missing file " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DB: could not parse " + path)
		return {}
	return parsed


func map(map_id: String) -> Dictionary:
	if not _maps.has(map_id):
		_maps[map_id] = load_json("res://data/maps/%s.json" % map_id)
	return _maps[map_id]


func dialogue(conversation_id: String) -> Dictionary:
	if not _dialogue.has(conversation_id):
		_dialogue[conversation_id] = load_json("res://data/dialogue/%s.json" % conversation_id)
	return _dialogue[conversation_id]


func enemy(enemy_id: String) -> Dictionary:
	return enemies.get(enemy_id, {})
