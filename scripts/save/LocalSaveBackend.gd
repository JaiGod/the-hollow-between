extends RefCounted
## Local JSON files in user://saves. Atomic-ish: writes to .tmp then renames,
## so a crash mid-save can't corrupt the previous save.
##
## Backend contract (implement these to add cloud saves):
##   read(key) -> Dictionary   (empty if missing)
##   write(key, data) -> bool
##   exists(key) -> bool
##   remove(key) -> void

const DIR := "user://saves"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func _path(key: String) -> String:
	return "%s/%s.json" % [DIR, key]


func read(key: String) -> Dictionary:
	var p := _path(key)
	if not FileAccess.file_exists(p):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func write(key: String, data: Dictionary) -> bool:
	var tmp := _path(key) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: " + str(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var dir := DirAccess.open(DIR)
	if dir.file_exists(key + ".json"):
		dir.remove(key + ".json")
	return dir.rename(key + ".json.tmp", key + ".json") == OK


func exists(key: String) -> bool:
	return FileAccess.file_exists(_path(key))


func remove(key: String) -> void:
	if exists(key):
		DirAccess.remove_absolute(_path(key))
