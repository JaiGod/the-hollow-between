extends Node
## Achievement service. Stores unlocks locally and forwards them to Steam when
## the GodotSteam extension is present (Engine singleton "Steam"). On other
## platforms it's a no-op bridge you can extend for Google Play Games / Game
## Center. IDs must match the API names you create in Steamworks.

const LIST := {
	"first_spare": {"name": "Mercy Remembers", "desc": "Spare your first enemy."},
	"first_friend": {"name": "Not Alone", "desc": "Recruit a companion."},
	"pacifist_slice": {"name": "Soft Footsteps", "desc": "Finish Chapter 1 without defeating anyone."},
	"archivist_spared": {"name": "Unwritten", "desc": "Spare the Archivist."},
	"archivist_defeated": {"name": "Last Page", "desc": "Defeat the Archivist."},
	"secret_hollow": {"name": "Between the Between", "desc": "Find the hidden hollow."},
	"graze_master": {"name": "Close Call", "desc": "Graze 100 projectiles."},
	"all_quests": {"name": "Lantern Keeper", "desc": "Finish every Chapter 1 quest."},
}

var unlocked: Array = []
var steam = null


func _ready() -> void:
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
		if steam.has_method("steamInit"):
			steam.steamInit()
	await get_tree().process_frame
	unlocked = SaveManager.profile.get("achievements", [])


func unlock(id: String) -> void:
	if unlocked.has(id) or not LIST.has(id):
		return
	unlocked.append(id)
	SaveManager.profile["achievements"] = unlocked
	SaveManager.save_profile()
	Events.achievement_unlocked.emit(id)
	Events.toast.emit("Achievement: " + LIST[id]["name"])
	if steam:
		steam.setAchievement(id)
		steam.storeStats()
