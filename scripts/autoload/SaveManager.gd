extends Node
## Save slots + a cross-save "profile" (endings seen, resets) — the profile is
## what lets the world remember things even after you start over.
##
## Storage goes through a backend object, so swapping local files for Steam
## Cloud / Google Play Games / a web API only means writing a new backend
## with the same three methods (see docs/ARCHITECTURE.md).

const LocalBackend = preload("res://scripts/save/LocalSaveBackend.gd")

const AUTOSAVE_SLOT := 0
const SLOT_COUNT := 3  # manual slots 1..3

var backend
var profile: Dictionary = {}


func _ready() -> void:
	backend = LocalBackend.new()
	profile = backend.read("profile")
	if profile.is_empty():
		profile = {"endings_seen": [], "new_games": 0, "settings": {"music": 0.7, "sfx": 0.8, "text_speed": 1.0}}


func slot_key(slot: int) -> String:
	return "autosave" if slot == AUTOSAVE_SLOT else "slot_%d" % slot


func save(slot: int) -> bool:
	var data := GameState.to_dict()
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var ok: bool = backend.write(slot_key(slot), data)
	if ok:
		Events.game_saved.emit(slot)
	return ok


func autosave() -> void:
	save(AUTOSAVE_SLOT)


func load_slot(slot: int) -> bool:
	var data: Dictionary = backend.read(slot_key(slot))
	if data.is_empty():
		return false
	GameState.from_dict(data)
	return true


func slot_summary(slot: int) -> Dictionary:
	## Small dictionary for the load menu; empty if the slot is unused.
	var d: Dictionary = backend.read(slot_key(slot))
	if d.is_empty():
		return {}
	var map_name: String = DB.map(d.get("map_id", "")).get("name", "???")
	var secs := int(d.get("playtime", 0))
	return {
		"name": d.get("player_name", "?"), "level": d.get("level", 1),
		"place": map_name, "time": "%d:%02d" % [secs / 3600, (secs / 60) % 60],
		"saved_at": d.get("saved_at", ""),
	}


func has_any_save() -> bool:
	for s in range(0, SLOT_COUNT + 1):
		if backend.exists(slot_key(s)):
			return true
	return false


func delete_slot(slot: int) -> void:
	backend.remove(slot_key(slot))


func save_profile() -> void:
	backend.write("profile", profile)


func mark_ending(ending_id: String) -> void:
	if not profile["endings_seen"].has(ending_id):
		profile["endings_seen"].append(ending_id)
	save_profile()


func setting(key: String, default = null):
	return profile.get("settings", {}).get(key, default)


func set_setting(key: String, value) -> void:
	if not profile.has("settings"):
		profile["settings"] = {}
	profile["settings"][key] = value
	save_profile()
