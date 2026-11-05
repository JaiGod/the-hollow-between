extends RefCounted
## Decides which ending the player's history earns. Rules are checked from
## rarest to most common; the first match wins. Every input is something the
## player did — that's the "choices matter" contract.
##
## Chapter 1 uses the same six endings as the full game, scoped to what's
## possible so far. Later chapters add conditions (see docs/STORY_DESIGN.md).


static func resolve() -> String:
	var gs = GameState
	var killed: int = gs.stat("killed")
	var spared_archivist: bool = gs.get_flag("archivist_spared")
	var all_quests: bool = gs.quest_state("lost_gear") == "done" and gs.quest_state("pip_home") == "done"

	if gs.get_flag("name_warden") and gs.get_flag("secret.unfinished") and gs.stat("unfinished_asked") >= 3 \
			and SaveManager.profile.get("endings_seen", []).size() > 0:
		return "developer"
	var hope: bool = killed == 0 and spared_archivist and all_quests and gs.loyalty("echo") >= 40
	if hope and gs.get_flag("secret.hollow") and gs.get_flag("secret.unfinished"):
		return "secret"
	if hope:
		return "true_hope"
	if killed >= 4 or (not spared_archivist and killed >= 3):
		return "corruption"
	if gs.party().is_empty() and gs.stat("helped") == 0:
		return "isolation"
	return "balance"


static func leaning() -> String:
	## Soft hint for the status screen; never names the ending outright.
	var id := resolve()
	return {
		"true_hope": "Your heart feels light.",
		"secret": "Something is watching you, kindly.",
		"developer": "The world feels... unfinished.",
		"corruption": "Your hands feel heavy.",
		"isolation": "It is very quiet around you.",
		"balance": "You feel steady, if uncertain.",
	}.get(id, "...")
