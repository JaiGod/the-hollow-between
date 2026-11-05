# Architecture Guide

## Principles
1. **Content is data.** Every enemy, line of dialogue, quest, talent, map and ending lives in `data/` as JSON. Adding content rarely touches code.
2. **One scene, built in code.** `Main.tscn` holds a single script. Screens are created with `.new()`, which keeps merges clean and makes the whole game testable headlessly.
3. **Systems talk through `Events`.** The battle doesn't know the overworld exists; it emits `battle_ended` and `Main` routes it.
4. **No `class_name` dependencies.** Scripts `preload()` each other, so a fresh clone runs without the editor's class cache (important for CI).
5. **Nothing is lost.** `GameState` records every choice; the profile survives new games.

## Autoloads (in load order)
| Autoload | Role |
|---|---|
| `Events` | Signal bus (`battle_requested`, `map_change_requested`, `toast`, `quest_updated`, …) |
| `InputConfig` | Registers all input actions (keyboard, gamepad) at boot; `move_vector()` |
| `DB` | Loads JSON; caches maps and conversations on demand |
| `GameState` | The playthrough: stats, flags, history, quests, companions, inventory, talents. Condition checker + effect applier |
| `SaveManager` | Slots, autosave, cross-save profile; storage via a backend object |
| `AudioManager` | Synthesizes SFX and music loops; crossfades; `set_intensity()` for adaptive boss music |
| `Achievements` | Local unlocks + Steam forwarding |

## Flow
```
TitleScreen ─New Game─▶ Main.start_new_game ─▶ Main.enter_map ─▶ Overworld
Overworld ──touch enemy──▶ Events.battle_requested ─▶ Main removes Overworld (kept alive)
                                                    ─▶ Battle ─▶ battle_ended(result)
Main ◀── re-adds Overworld, Overworld.on_battle_result, optional after_* dialogue
Dialogue node {"event":"chapter_end"} ─▶ Main.show_ending ─▶ EndingResolver ─▶ EndingScreen
```

## The condition / effect language
Used by dialogue, entities, exits and enemies. Implemented in `GameState.check()` and `GameState.apply_effects()`.

**Conditions** (comma = AND, `!` = NOT): `flag:x` · `stat:killed>=3` · `quest:pip_home=done` · `companion:echo` (recruited) · `party:echo` (with you now) · `loyalty:echo>=40` · `item:brass_gear` · `level>=3` · `shards>=5` · `choice:pip=help`

**Effects:** `set`, `record` (choice log), `stat`, `loyalty`, `give`, `take`, `quest_start`, `quest_advance`, `quest_complete`, `recruit`, `dismiss`, `xp`, `shards`, `heal`, `achievement`, `toast`, `secret`.

## Maps
Authored as ASCII in `tools/build_maps.py`, exported to `data/maps/*.json`. The script fails if a row is the wrong width, anything sits on a solid tile, an exit points to a missing spawn, or something is unreachable. Entity types: `npc`, `sign`, `save`, `item`, `enemy`, `stone` (ordered puzzle), `blocker` (vanishes when its `unless` condition is true).

## Pixel-art pipeline
- **Sprites:** `scripts/art/SpriteLib.gd` — rows of characters mapped to a 32-color palette. Put a PNG at `res://art/sprites/<name>.png` and it replaces the text sprite automatically.
- **Tiles:** `TileBaker` bakes a map's ASCII grid into one texture with deterministic per-tile detail, drawn at 2× with nearest filtering and pixel snapping.
- To move to hand-made tilesets later, swap `TileBaker.bake()` for a `TileMapLayer` — map JSON stays the same.

## Audio
Music is note data in `AudioManager.SONGS` (one token = an eighth note). The Hollow motif (A C E D C B A) appears in the title, boss and ending themes. Drop `res://audio/music/<song>.ogg` to replace any synthesized track.

## Saves & cloud
`SaveManager` talks to a backend with four methods: `read`, `write`, `exists`, `remove`. `LocalSaveBackend` writes atomically (tmp + rename). For Steam Cloud, enable Auto-Cloud on `user://saves/*.json` in Steamworks (zero code). For Google Play Games / iCloud / a web API, write a backend with the same four methods and assign it in `SaveManager._ready()`.

## Adding things
| To add… | Do this |
|---|---|
| An enemy | Entry in `data/enemies.json`, sprite in `SpriteLib`, place it on a map |
| An attack pattern | New file in `scripts/battle/patterns/`, register in `PatternLibrary.gd` |
| A map | Add to `tools/build_maps.py`, run it, link with an exit |
| A conversation | `data/dialogue/<id>.json`; reference it from an entity |
| A talent | `data/talents.json` (`bonus` stats and/or `unlocks` a special) |
| An ending rule | `scripts/systems/EndingResolver.gd` + text in `data/endings.json` |
