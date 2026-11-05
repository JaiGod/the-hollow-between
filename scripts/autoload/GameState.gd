extends Node
## Single source of truth for one playthrough: the player, every choice made,
## quests, companions, inventory and world flags. "The world remembers
## everything" is literally this file: nothing the player does is lost.

const XP_CURVE := [0, 10, 30, 60, 100, 160, 240, 350, 500, 700, 1000]
const MAX_FOCUS := 100

var player_name: String = "Wren"
var level: int = 1
var xp: int = 0
var hp: int = 20
var focus: int = 0
var shards: int = 0
var talent_points: int = 0
var talents_owned: Array = []

var map_id: String = "glade_of_waking"
var spawn_id: String = "start"
var position: Vector2 = Vector2.ZERO
var has_position: bool = false

var flags: Dictionary = {}
var history: Array = []
var stats: Dictionary = {}
var quests: Dictionary = {}
var companions: Dictionary = {}
var inventory: Dictionary = {}
var playtime: float = 0.0
var counting_time: bool = false


func _process(delta: float) -> void:
	if counting_time:
		playtime += delta


func new_game(name_in: String) -> void:
	player_name = name_in.strip_edges() if name_in.strip_edges() != "" else "Wren"
	level = 1
	xp = 0
	focus = 0
	shards = 0
	talent_points = 0
	talents_owned = []
	map_id = "glade_of_waking"
	spawn_id = "start"
	has_position = false
	flags = {}
	history = []
	stats = {
		"spared": 0, "killed": 0, "talked": 0, "helped": 0, "ignored": 0,
		"betrayed": 0, "bosses_defeated": 0, "bosses_spared": 0, "secrets": 0,
		"deaths": 0, "battles": 0, "grazes": 0,
	}
	quests = {}
	companions = {}
	for cid in DB.companions:
		companions[cid] = {"recruited": false, "loyalty": int(DB.companions[cid].get("base_loyalty", 0)), "in_party": false}
	inventory = {"dewbread": 2}
	playtime = 0.0
	hp = max_hp()
	if player_name.to_upper() == "WARDEN":
		set_flag("name_warden", true)
	Events.stats_changed.emit()


# ---------------------------------------------------------------- derived stats

func max_hp() -> int:
	return 16 + level * 4 + talent_bonus("max_hp")

func attack() -> int:
	return 8 + level * 2 + talent_bonus("attack")

func defense() -> int:
	return level + talent_bonus("defense")

func soul_speed() -> float:
	return 150.0 + float(talent_bonus("soul_speed"))

func graze_gain() -> int:
	return 4 + talent_bonus("graze")

func crit_window() -> float:
	return 0.06 + float(talent_bonus("crit_window")) / 100.0

func special_power() -> float:
	return 1.0 + float(talent_bonus("special_power")) / 100.0

func xp_to_next() -> int:
	if level >= XP_CURVE.size():
		return 999999
	return XP_CURVE[level]


func talent_bonus(stat: String) -> int:
	var total := 0
	for tid in talents_owned:
		var t: Dictionary = _find_talent(tid)
		total += int(t.get("bonus", {}).get(stat, 0))
	return total


func specials() -> Array:
	## Abilities usable from the SPECIAL battle menu.
	var out: Array = ["mend"]
	for tid in talents_owned:
		var t: Dictionary = _find_talent(tid)
		if t.has("unlocks"):
			out.append(t["unlocks"])
	if party().size() > 0:
		out.append("spirit_summon")
	return out


func _find_talent(tid: String) -> Dictionary:
	for branch in DB.talents.get("branches", {}).values():
		for t in branch.get("talents", []):
			if t.get("id") == tid:
				return t
	return {}


func can_learn(tid: String) -> bool:
	if talents_owned.has(tid) or talent_points <= 0:
		return false
	var t := _find_talent(tid)
	if t.is_empty():
		return false
	var req: String = t.get("requires", "")
	return req == "" or talents_owned.has(req)


func learn(tid: String) -> bool:
	if not can_learn(tid):
		return false
	talents_owned.append(tid)
	talent_points -= 1
	hp = min(hp + talent_bonus("max_hp"), max_hp())
	Events.stats_changed.emit()
	return true


# ------------------------------------------------------------------- progression

func add_xp(amount: int) -> void:
	xp += amount
	while level < XP_CURVE.size() and xp >= xp_to_next():
		level += 1
		talent_points += 1
		hp = max_hp()
		Events.level_up.emit(level)
		Events.toast.emit("LV %d! +1 talent point" % level)
	Events.stats_changed.emit()


func heal(amount: int) -> int:
	var before := hp
	hp = clampi(hp + amount, 0, max_hp())
	Events.stats_changed.emit()
	return hp - before


func add_focus(amount: int) -> void:
	focus = clampi(focus + amount, 0, MAX_FOCUS)


# ------------------------------------------------------------- flags & choices

func set_flag(flag: String, value = true) -> void:
	flags[flag] = value
	Events.flag_changed.emit(flag, value)


func get_flag(flag: String, default = false):
	return flags.get(flag, default)


func record_choice(choice_id: String, value) -> void:
	history.append({"id": choice_id, "value": value, "t": int(playtime)})
	flags["choice." + choice_id] = value
	Events.choice_recorded.emit(choice_id, value)


func add_stat(stat: String, delta: int = 1) -> void:
	stats[stat] = int(stats.get(stat, 0)) + delta
	Events.stats_changed.emit()


func stat(stat_name: String) -> int:
	return int(stats.get(stat_name, 0))


# --------------------------------------------------------------------- quests

func quest_state(qid: String) -> String:
	return quests.get(qid, {}).get("state", "none")


func start_quest(qid: String) -> void:
	if quest_state(qid) != "none":
		return
	quests[qid] = {"state": "active", "step": 0}
	Events.quest_updated.emit(qid, "active")
	Events.toast.emit("New quest: " + DB.quests.get(qid, {}).get("title", qid))


func advance_quest(qid: String) -> void:
	if quest_state(qid) != "active":
		return
	quests[qid]["step"] = int(quests[qid]["step"]) + 1
	Events.quest_updated.emit(qid, "active")


func complete_quest(qid: String) -> void:
	if quest_state(qid) == "done":
		return
	if not quests.has(qid):
		quests[qid] = {"state": "active", "step": 0}
	quests[qid]["state"] = "done"
	var q: Dictionary = DB.quests.get(qid, {})
	Events.quest_updated.emit(qid, "done")
	Events.toast.emit("Quest complete: " + q.get("title", qid))
	if q.has("reward"):
		apply_effects(q["reward"])
	add_stat("helped")
	var all_done := true
	for other in DB.quests:
		if quest_state(other) != "done":
			all_done = false
	if all_done:
		Achievements.unlock("all_quests")


func quest_step_text(qid: String) -> String:
	var q: Dictionary = DB.quests.get(qid, {})
	var steps: Array = q.get("steps", [])
	if quest_state(qid) == "done":
		return q.get("done_text", "Complete.")
	var i := int(quests.get(qid, {}).get("step", 0))
	return steps[min(i, steps.size() - 1)] if steps.size() > 0 else ""


# ------------------------------------------------------------------ companions

func recruit(cid: String) -> void:
	if not companions.has(cid):
		return
	companions[cid]["recruited"] = true
	companions[cid]["in_party"] = true
	Events.companion_changed.emit(cid)
	Events.toast.emit("%s joined you." % DB.companions.get(cid, {}).get("name", cid))


func dismiss(cid: String) -> void:
	if companions.has(cid):
		companions[cid]["in_party"] = false
		record_choice("dismissed_" + cid, true)
		Events.companion_changed.emit(cid)


func change_loyalty(cid: String, delta: int) -> void:
	if not companions.has(cid):
		return
	companions[cid]["loyalty"] = clampi(int(companions[cid]["loyalty"]) + delta, -100, 100)
	Events.loyalty_changed.emit(cid, companions[cid]["loyalty"])


func loyalty(cid: String) -> int:
	return int(companions.get(cid, {}).get("loyalty", 0))


func party() -> Array:
	var out: Array = []
	for cid in companions:
		if companions[cid].get("recruited") and companions[cid].get("in_party"):
			out.append(cid)
	return out


# ------------------------------------------------------------------- inventory

func give_item(item_id: String, count: int = 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + count
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	Events.item_changed.emit(item_id, int(inventory.get(item_id, 0)))


func has_item(item_id: String, count: int = 1) -> bool:
	return int(inventory.get(item_id, 0)) >= count


# ----------------------------------------------------------- conditions/effects

func check(condition: String) -> bool:
	## Comma-separated AND of clauses. Examples:
	##   flag:met_echo   !flag:met_echo   stat:spared>=2   quest:pip=done
	##   companion:echo  loyalty:echo>=30 item:brass_gear  level>=3
	if condition.strip_edges() == "":
		return true
	for raw in condition.split(","):
		if not _check_clause(raw.strip_edges()):
			return false
	return true


func _check_clause(clause: String) -> bool:
	var negate := clause.begins_with("!")
	if negate:
		clause = clause.substr(1)
	var result := false
	var op := ""
	for o in [">=", "<=", "!=", "=", ">", "<"]:
		if clause.find(o) != -1:
			op = o
			break
	var lhs := clause
	var rhs := ""
	if op != "":
		var parts := clause.split(op, true, 1)
		lhs = parts[0]
		rhs = parts[1]
	var kind := lhs.get_slice(":", 0)
	var key := lhs.get_slice(":", 1) if lhs.find(":") != -1 else ""
	match kind:
		"flag":
			var v = get_flag(key, null)
			result = _truthy(v) if op == "" else _cmp(str(v), op, rhs)
		"stat":
			result = _cmp_num(stat(key), op, rhs)
		"quest":
			result = quest_state(key) != "none" if op == "" else _cmp(quest_state(key), op, rhs)
		"companion":
			result = bool(companions.get(key, {}).get("recruited", false))
		"party":
			result = party().has(key)
		"loyalty":
			result = _cmp_num(loyalty(key), op, rhs)
		"item":
			result = has_item(key)
		"level":
			result = _cmp_num(level, op, rhs)
		"shards":
			result = _cmp_num(shards, op, rhs)
		"choice":
			var c = flags.get("choice." + key, null)
			result = c != null if op == "" else _cmp(str(c), op, rhs)
		_:
			push_warning("Unknown condition: " + clause)
	return not result if negate else result


func _truthy(v) -> bool:
	match typeof(v):
		TYPE_NIL: return false
		TYPE_BOOL: return v
		TYPE_INT, TYPE_FLOAT: return v != 0
		TYPE_STRING: return v != "" and v != "false"
	return true


func _cmp(a: String, op: String, b: String) -> bool:
	match op:
		"=": return a == b
		"!=": return a != b
	return _cmp_num(float(a), op, b)


func _cmp_num(a: float, op: String, b: String) -> bool:
	var n := float(b)
	match op:
		">=": return a >= n
		"<=": return a <= n
		">": return a > n
		"<": return a < n
		"=": return is_equal_approx(a, n)
		"!=": return not is_equal_approx(a, n)
	return a != 0


func apply_effects(fx: Dictionary) -> void:
	for f in fx.get("set", {}):
		set_flag(f, fx["set"][f])
	for c in fx.get("record", {}):
		record_choice(c, fx["record"][c])
	for s in fx.get("stat", {}):
		add_stat(s, int(fx["stat"][s]))
	for cid in fx.get("loyalty", {}):
		change_loyalty(cid, int(fx["loyalty"][cid]))
	for i in fx.get("give", {}):
		give_item(i, int(fx["give"][i]))
	for i in fx.get("take", {}):
		give_item(i, -int(fx["take"][i]))
	if fx.has("quest_start"): start_quest(fx["quest_start"])
	if fx.has("quest_advance"): advance_quest(fx["quest_advance"])
	if fx.has("quest_complete"): complete_quest(fx["quest_complete"])
	if fx.has("recruit"): recruit(fx["recruit"])
	if fx.has("dismiss"): dismiss(fx["dismiss"])
	if fx.has("xp"): add_xp(int(fx["xp"]))
	if fx.has("shards"):
		shards += int(fx["shards"])
		Events.stats_changed.emit()
	if fx.has("heal"): heal(int(fx["heal"]))
	if fx.has("achievement"): Achievements.unlock(fx["achievement"])
	if fx.has("toast"): Events.toast.emit(fx["toast"])
	if fx.has("secret"):
		if not get_flag("secret." + fx["secret"]):
			set_flag("secret." + fx["secret"], true)
			add_stat("secrets")
			Events.toast.emit("A hidden memory surfaces...")


func format_text(text: String) -> String:
	return text.replace("{player}", player_name).replace("{spared}", str(stat("spared"))).replace("{killed}", str(stat("killed")))


# ---------------------------------------------------------------- serialization

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"player_name": player_name, "level": level, "xp": xp, "hp": hp,
		"focus": focus, "shards": shards, "talent_points": talent_points,
		"talents_owned": talents_owned, "map_id": map_id,
		"position": [position.x, position.y], "flags": flags, "history": history,
		"stats": stats, "quests": quests, "companions": companions,
		"inventory": inventory, "playtime": playtime,
	}


func from_dict(d: Dictionary) -> void:
	new_game(d.get("player_name", "Wren"))
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	focus = int(d.get("focus", 0))
	shards = int(d.get("shards", 0))
	talent_points = int(d.get("talent_points", 0))
	talents_owned = d.get("talents_owned", [])
	map_id = d.get("map_id", "glade_of_waking")
	var p: Array = d.get("position", [0, 0])
	position = Vector2(p[0], p[1])
	has_position = true
	flags = d.get("flags", {})
	history = d.get("history", [])
	for k in d.get("stats", {}):
		stats[k] = d["stats"][k]
	quests = d.get("quests", {})
	for cid in d.get("companions", {}):
		companions[cid] = d["companions"][cid]
	inventory = d.get("inventory", {})
	playtime = float(d.get("playtime", 0.0))
	hp = clampi(int(d.get("hp", max_hp())), 1, max_hp())
	Events.stats_changed.emit()
