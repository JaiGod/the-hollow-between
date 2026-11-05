# Setup Guide

## Requirements
- **Godot 4.4 or newer** (standard build — no C#/.NET needed; the whole game is GDScript)
- Python 3 (optional — only for `tools/build_maps.py`)

## Run
1. Open Godot → **Import** → choose `project.godot` → **Import & Edit**.
2. Press **F5** (Play). The first launch imports the icon; everything else is generated at runtime.

From a terminal:
```bash
godot --path .                                   # play
godot --headless --path . res://tests/SmokeTest.tscn   # automated test
xvfb-run godot --path . res://tests/Screenshots.tscn   # regenerate docs/screenshots
```

Force touch controls on desktop for testing: `HOLLOW_TOUCH=1 godot --path .`

## Project layout
```
project.godot          engine config, autoloads, renderer (GL Compatibility for mobile/web)
export_presets.cfg     Windows, Linux, macOS, Web, Android, iOS
scenes/Main.tscn       the only scene — everything else is built in code
scripts/
  Main.gd              router: title ↔ overworld ↔ battle ↔ ending, UI layers
  autoload/            Events (signal bus), InputConfig, DB, GameState, SaveManager,
                       AudioManager (procedural chiptune), Achievements (Steam bridge)
  world/               Overworld, Player, WorldEntity
  battle/              Battle (turn flow), BattleArena (soul/bullets), Bullet, patterns/
  ui/                  DialogueBox, TitleScreen, PauseMenu, SaveSlotMenu, Settings,
                       TouchControls, EndingScreen, UITheme
  art/                 SpriteLib (text → pixel sprites), TileBaker (ASCII maps → textures)
  systems/             EndingResolver
  save/                LocalSaveBackend
data/                  ALL content: enemies, quests, companions, talents, items, endings,
                       maps/*.json, dialogue/*.json
tools/build_maps.py    map authoring + validation (widths, walkability, reachability)
tests/                 SmokeTest + Screenshots scenes
web/index.html         GitHub Pages landing page (the game is exported to /play/)
docs/                  these guides + screenshots
art/sprites/, audio/music/   optional overrides (see Architecture)
```

## Saves
Stored in Godot's `user://saves/` (Windows: `%APPDATA%\Godot\app_userdata\The Hollow Between`; in the browser, IndexedDB). `profile.json` holds cross-save data (endings seen, achievements, settings); delete it to make the world forget you.
