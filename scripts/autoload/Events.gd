extends Node
## Global signal bus. Systems talk through these instead of holding references
## to each other, which keeps scenes swappable and testable.

signal flag_changed(flag: String, value)
signal choice_recorded(choice_id: String, value)
signal quest_updated(quest_id: String, state: String)
signal companion_changed(companion_id: String)
signal loyalty_changed(companion_id: String, value: int)
signal item_changed(item_id: String, count: int)
signal stats_changed()
signal level_up(new_level: int)
signal toast(text: String)

signal dialogue_started(conversation_id: String)
signal dialogue_finished(conversation_id: String)

signal battle_requested(enemy_id: String, context: Dictionary)
signal battle_finished(result: Dictionary)

signal map_change_requested(map_id: String, spawn_id: String)
signal game_saved(slot: int)
signal achievement_unlocked(id: String)
